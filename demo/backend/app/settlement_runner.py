"""Run the vendored Lean 4 `settlement-api` engine as a per-request subprocess.

Same discipline as `lean_runner.py` (which serves the older CA-only
`probate-api`), applied to the settlement router of CONTRACT-SETTLEMENT.md:

* invoke `AlixHack/.lake/build/bin/settlement-api` directly, one `IntakeCase`
  JSON on stdin, one `SettlementAssessment` **or** `ErrorEnvelope` JSON on
  stdout, 10 s timeout;
* fall back to `~/.elan/bin/lake exe settlement-api` with cwd `AlixHack/` when
  the binary has not been built;
* tolerate build chatter around the result by scanning stdout for the first
  parseable JSON object;
* measure wall time and child CPU time (returned as response headers, since the
  frozen contract has no field for them);
* never surface an HTTP 500 — an unusable or missing engine is a clean 503 with
  the reason.

The raw request body is forwarded EXACTLY as received. This is not an
optimisation: the whole product turns on `null` ≡ absent ≡ *unknown*, so
Pydantic must never coerce a null into a default before the engine sees it.

The contract's **error envelope is a legitimate 200 response**, not an HTTP
error: `POST /api/settlement/assess → SettlementAssessment | ErrorEnvelope`,
and the frontend narrows that union on the body. A malformed case, an invalid
date, and a post-snapshot death date all arrive as `{"error": {...}}` with
status 200. Only an engine that cannot be run, times out, crashes, or emits
something that is neither shape produces a 503.
"""

from __future__ import annotations

import asyncio
import contextlib
import json
import os
import resource
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException

DEMO_ROOT = Path(__file__).resolve().parent.parent.parent
# The Lean project is the repository root (demo/ lives inside it).
ALIXHACK_DIR = DEMO_ROOT.parent

def _bin_path(name: str) -> Path:
    """Where the compiled engine lives. In-repo build by default; LEAN_BIN_DIR
    overrides it for container images, which have no repo checkout."""
    override = os.environ.get("LEAN_BIN_DIR", "").strip()
    if override:
        return Path(override) / name
    return ALIXHACK_DIR / ".lake" / "build" / "bin" / name


SETTLEMENT_API_BIN = _bin_path("settlement-api")
LAKE_BIN = Path.home() / ".elan" / "bin" / "lake"

SUBPROCESS_TIMEOUT_S = 10.0

# CONTRACT-SETTLEMENT.md §3. Keys whose absence means the engine did not
# produce an assessment at all — a 503, not a partially rendered case file.
REQUIRED_ASSESSMENT_KEYS = (
    "engine",
    "snapshot",
    "asset_map",
    "probate_estate",
    "jurisdictions",
)
# Contract list-valued sections. An absent list is unambiguous, so it is
# normalised to `[]` rather than 503-ing the whole request. This is a SHAPE
# normalisation only — no value is ever invented, and a section the engine did
# not compute stays visibly empty.
OPTIONAL_ASSESSMENT_LISTS = (
    "federal",
    "flags",
    "deadlines",
    "next_actions",
    "unresolved_facts",
    "notes",
)

VALID_ERROR_CODES = ("invalid_date", "after_snapshot", "malformed_case")


def settlement_engine_status() -> str:
    """Which invocation path /api/settlement/assess would use right now."""
    if SETTLEMENT_API_BIN.is_file():
        return "binary"
    if LAKE_BIN.is_file():
        return "lake"
    return "unavailable"


def _unavailable(why: str) -> HTTPException:
    return HTTPException(status_code=503, detail=f"Settlement engine unavailable: {why}")


def _children_cpu_ms() -> Optional[float]:
    """Cumulative CPU time (user+sys, ms) of all reaped child processes.

    Deltas around one subprocess run approximate that child's CPU time.
    RUSAGE_CHILDREN is process-wide, so a concurrent request's child can land
    in this delta — acceptable for a demo metric. None on error.
    """
    try:
        ru = resource.getrusage(resource.RUSAGE_CHILDREN)
        return (ru.ru_utime + ru.ru_stime) * 1000.0
    except Exception:  # noqa: BLE001 — never let getrusage break the endpoint
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


def _first_json_object(text: str) -> Optional[Dict[str, Any]]:
    """First `{...}` in `text` from which a JSON object parses.

    The lake fallback path interleaves build chatter around the result line, so
    trailing bytes are ignored (raw_decode) instead of strict whole-tail loads.
    """
    decoder = json.JSONDecoder()
    start = text.find("{")
    while start >= 0:
        try:
            candidate, _end = decoder.raw_decode(text, start)
        except ValueError:
            candidate = None
        if isinstance(candidate, dict):
            return candidate
        start = text.find("{", start + 1)
    return None


def _validate_error_envelope(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Check a `{"error": {...}}` body against CONTRACT-SETTLEMENT.md §3."""
    error = payload["error"]
    if not isinstance(error, dict):
        raise _unavailable("engine emitted a non-object `error` field")
    code = error.get("code")
    if code not in VALID_ERROR_CODES:
        raise _unavailable(
            f"engine emitted unknown error code {code!r} "
            f"(expected one of {', '.join(VALID_ERROR_CODES)})"
        )
    if not isinstance(error.get("detail"), str):
        raise _unavailable("engine emitted an error envelope without a string detail")
    # Returned verbatim — the envelope IS the contract response for this case.
    return {"error": {"code": code, "detail": error["detail"]}}


def _validate_assessment(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Check a `SettlementAssessment` body against CONTRACT-SETTLEMENT.md §3."""
    missing = [k for k in REQUIRED_ASSESSMENT_KEYS if k not in payload]
    if missing:
        raise _unavailable(
            "engine output is neither an error envelope nor a settlement "
            f"assessment (missing: {', '.join(missing)})"
        )
    if not isinstance(payload["jurisdictions"], list):
        raise _unavailable("engine emitted a non-list `jurisdictions`")
    if not isinstance(payload["asset_map"], list):
        raise _unavailable("engine emitted a non-list `asset_map`")
    if not isinstance(payload["probate_estate"], dict):
        raise _unavailable("engine emitted a non-object `probate_estate`")
    for key in OPTIONAL_ASSESSMENT_LISTS:
        value = payload.get(key)
        if value is None:
            payload[key] = []  # shape normalisation; never a value
        elif not isinstance(value, list):
            raise _unavailable(f"engine emitted a non-list `{key}`")
    return payload


async def assess_settlement(raw_body: bytes) -> Tuple[Dict[str, Any], Dict[str, str]]:
    """Run the engine on `raw_body`.

    Returns `(body, headers)` where `body` is a `SettlementAssessment` or an
    `ErrorEnvelope` exactly as the contract defines it, and `headers` carries
    the timing/telemetry that has no place in the frozen JSON shape.
    """
    started = time.perf_counter()
    cpu_before = _children_cpu_ms()
    if SETTLEMENT_API_BIN.is_file():
        engine_path = "binary"
        stdout = await _run([str(SETTLEMENT_API_BIN)], None, raw_body)
    elif LAKE_BIN.is_file():
        engine_path = "lake"
        stdout = await _run(
            [str(LAKE_BIN), "--quiet", "exe", "settlement-api"],
            ALIXHACK_DIR,
            raw_body,
        )
    else:
        raise _unavailable(
            f"{SETTLEMENT_API_BIN} is not built and {LAKE_BIN} is not installed"
        )
    cpu_after = _children_cpu_ms()
    latency_ms = int((time.perf_counter() - started) * 1000)

    text = stdout.decode("utf-8", errors="replace")
    payload = _first_json_object(text)
    if payload is None:
        raise _unavailable(f"no JSON object in engine output: {text[:200]!r}")

    if "error" in payload and payload["error"] is not None:
        body = _validate_error_envelope(payload)
    else:
        body = _validate_assessment(payload)

    headers = {
        "X-Engine-Path": engine_path,
        "X-Engine-Latency-Ms": str(latency_ms),
    }
    if cpu_before is not None and cpu_after is not None:
        headers["X-Engine-Cpu-Ms"] = f"{max(cpu_after - cpu_before, 0.0):.1f}"
    return body, headers
