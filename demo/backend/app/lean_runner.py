"""Run the vendored Lean 4 probate-api engine as a per-request subprocess.

Per CONTRACT.md: invoke `AlixHack/.lake/build/bin/probate-api` directly
(one case JSON on stdin, one assessment JSON on stdout, 10 s timeout), falling
back to `~/.elan/bin/lake exe probate-api` with cwd `AlixHack/` when the binary
has not been built. If neither is available ⇒ HTTP 503
`{"detail": "Lean engine unavailable: <why>"}`.

The raw request body is forwarded EXACTLY as received (nulls intact) so both
engines see identical input. `latency_ms` in the engine's output is always
overwritten with the measured wall time. All output parsing/validation happens
inside the try so an unusable engine payload degrades to the contract's 503
detail instead of an HTTP 500.
"""

from __future__ import annotations

import asyncio
import contextlib
import json
import os
import resource
import time
from pathlib import Path
from typing import List, Optional

from fastapi import HTTPException
from pydantic import ValidationError

from .schemas import CheckResult, Usage

DEMO_ROOT = Path(__file__).resolve().parent.parent.parent
# The Lean project is the repository root (demo/ lives inside it).
ALIXHACK_DIR = DEMO_ROOT.parent
PROBATE_API_BIN = ALIXHACK_DIR / ".lake" / "build" / "bin" / "probate-api"
LAKE_BIN = Path.home() / ".elan" / "bin" / "lake"

SUBPROCESS_TIMEOUT_S = 10.0


def lean_engine_status() -> str:
    """Which invocation path /api/analyze/lean would use right now."""
    if PROBATE_API_BIN.is_file():
        return "binary"
    if LAKE_BIN.is_file():
        return "lake"
    return "unavailable"


def _unavailable(why: str) -> HTTPException:
    return HTTPException(status_code=503, detail=f"Lean engine unavailable: {why}")


def _children_cpu_ms() -> Optional[float]:
    """Cumulative CPU time (user+sys, ms) of all reaped child processes.

    Deltas of this around one subprocess run give that child's CPU time.
    NOTE: RUSAGE_CHILDREN is process-wide, so under concurrent requests
    another request's Lean child can land in this request's delta — an
    approximation that is fine for a demo. Returns None on error; usage then
    becomes null rather than breaking the endpoint.
    """
    try:
        ru = resource.getrusage(resource.RUSAGE_CHILDREN)
        return (ru.ru_utime + ru.ru_stime) * 1000.0
    except Exception:  # noqa: BLE001 — never let getrusage break the endpoint
        return None


def _build_usage(
    cpu_before: Optional[float], cpu_after: Optional[float]
) -> Optional[Usage]:
    """CONTRACT.md `usage` for the Lean engine. The Lean binary does not emit
    usage — the backend attaches it, same as latency_ms."""
    try:
        if cpu_before is None or cpu_after is None:
            return None
        cpu_ms = max(cpu_after - cpu_before, 0.0)
        price_raw = os.environ.get("LEAN_VCPU_PRICE_PER_HOUR", "0.04").strip()
        try:
            price = float(price_raw)
        except ValueError:
            price, price_raw = 0.04, "0.04"
        return Usage(
            input_tokens=None,
            output_tokens=None,
            cpu_ms=cpu_ms,
            estimated_cost_usd=(cpu_ms / 1000.0) / 3600.0 * price,
            pricing_note=f"vCPU @ ${price_raw}/hr (est.)",
        )
    except Exception:  # noqa: BLE001 — usage becomes null, never a 500
        return None


async def _run(cmd: List[str], cwd: Optional[Path], stdin_bytes: bytes) -> bytes:
    label = Path(cmd[0]).name
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            cwd=str(cwd) if cwd is not None else None,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except OSError as exc:
        raise _unavailable(f"could not start {label}: {exc}") from exc
    try:
        stdout, stderr = await asyncio.wait_for(
            proc.communicate(stdin_bytes), timeout=SUBPROCESS_TIMEOUT_S
        )
    except asyncio.TimeoutError:
        with contextlib.suppress(ProcessLookupError):
            proc.kill()
        await proc.wait()
        raise _unavailable(
            f"{label} timed out after {int(SUBPROCESS_TIMEOUT_S)}s"
        ) from None
    if proc.returncode != 0:
        err = stderr.decode("utf-8", errors="replace").strip()[:500]
        raise _unavailable(
            f"{label} exited with code {proc.returncode}: {err or 'no stderr'}"
        )
    return stdout


async def analyze_lean(raw_body: bytes) -> CheckResult:
    started = time.perf_counter()
    # RUSAGE_CHILDREN delta around the subprocess await = the Lean child's CPU
    # time (approximate under concurrent requests; see _children_cpu_ms).
    cpu_before = _children_cpu_ms()
    if PROBATE_API_BIN.is_file():
        stdout = await _run([str(PROBATE_API_BIN)], None, raw_body)
    elif LAKE_BIN.is_file():
        stdout = await _run(
            [str(LAKE_BIN), "--quiet", "exe", "probate-api"],
            ALIXHACK_DIR,
            raw_body,
        )
    else:
        raise _unavailable(
            f"{PROBATE_API_BIN} is not built and {LAKE_BIN} is not installed"
        )
    cpu_after = _children_cpu_ms()

    latency_ms = int((time.perf_counter() - started) * 1000)
    try:
        text = stdout.decode("utf-8", errors="replace")
        # The lake fallback path may interleave build chatter around the result
        # line, so accept the first '{' from which a JSON object parses and
        # ignore trailing bytes (raw_decode) instead of strict whole-tail loads.
        decoder = json.JSONDecoder()
        payload = None
        start = text.find("{")
        while start >= 0:
            try:
                candidate, _end = decoder.raw_decode(text, start)
            except ValueError:
                candidate = None
            if isinstance(candidate, dict):
                payload = candidate
                break
            start = text.find("{", start + 1)
        if payload is None:
            raise ValueError(f"no JSON object in engine output: {text[:200]!r}")
        payload.setdefault("engine", "lean4")
        payload["latency_ms"] = latency_ms  # overwritten with measured wall time
        result = CheckResult.model_validate(payload)
    except (ValueError, ValidationError) as exc:
        raise _unavailable(
            f"engine returned unusable output: {str(exc)[:300]}"
        ) from exc
    result.latency_ms = latency_ms
    # Attached after validation, like latency_ms — the binary never emits it.
    result.usage = _build_usage(cpu_before, cpu_after)
    return result
