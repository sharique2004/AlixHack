#!/usr/bin/env python3
"""Re-run the 12 ground-truth cases of `demo/AUDIT.md` against the Lean engine.

`demo/AUDIT.md` claims **"Lean: 12/12 correct"** and cites raw engine outputs in
an `audit_runs.json` that was never committed to the repo. This script closes
that gap: it reads the expected verdicts out of AUDIT.md's own scoreboard table
(not out of a hardcoded copy), replays each case through the built
`probate-api`, and writes `tools/audit_runs.json` with expected-vs-actual and
the complete six-row route table for every case.

What this establishes, precisely:

  * the **verdict-level** 12/12 is reproducible from the repo, by anyone, in
    about a second;
  * the raw route tables AUDIT.md's per-case prose refers to are now committed,
    so its route-level claims can be read against real output rather than
    taken on trust;
  * `--check` re-runs and diffs against the committed `audit_runs.json`, so a
    later change to the Lean engine that silently moves an answer fails loudly.

What it does NOT establish: the route-level ground truth itself. AUDIT.md
derived that by hand, per case, in prose; this script records the engine's
route tables, it does not re-derive what they ought to be.

The Gemini half of AUDIT.md (23/36 runs correct) is **not** reproduced by
default. It costs money, hits a third-party API, and is sampled at non-zero
temperature, so it is opt-in via `--llm N` and is otherwise reported as
`skipped` with the reason. It is never simulated, estimated, or filled in.

Run:
    python3 tools/run_audit.py                # Lean replay, writes audit_runs.json
    python3 tools/run_audit.py --check        # replay and diff against the file
    python3 tools/run_audit.py --llm 3        # also sample Gemini 3x per case
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
AUDIT_MD = REPO_ROOT / "demo" / "AUDIT.md"
SAMPLE_CASES = REPO_ROOT / "demo" / "content" / "sample_cases.json"
PROBATE_API_BIN = REPO_ROOT / ".lake" / "build" / "bin" / "probate-api"
LAKE_BIN = Path.home() / ".elan" / "bin" / "lake"
DEFAULT_OUT = REPO_ROOT / "tools" / "audit_runs.json"

# `| 1 | eligible-personal-affidavit | ELIGIBLE | ✓ correct | 3/3 correct |`
SCOREBOARD_ROW = re.compile(
    r"^\|\s*(\d+)\s*\|\s*`?([a-z0-9-]+)`?\s*\|\s*([A-Z_]+)\s*\|(.*)\|(.*)\|\s*$"
)


# --------------------------------------------------------------------------- #
# Inputs
# --------------------------------------------------------------------------- #


def parse_audit_scoreboard(path: Path) -> List[Dict[str, str]]:
    """Ground truth as AUDIT.md itself states it, row by row."""
    rows: List[Dict[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = SCOREBOARD_ROW.match(line.strip())
        if not match:
            continue
        number, name, truth, lean_col, gemini_col = match.groups()
        rows.append(
            {
                "number": int(number),
                "case": name,
                "ground_truth": truth,
                "audit_md_lean": lean_col.strip(),
                "audit_md_gemini": gemini_col.strip(),
            }
        )
    return rows


def load_sample_cases(path: Path) -> Dict[str, Dict[str, Any]]:
    return {entry["name"]: entry for entry in json.loads(path.read_text("utf-8"))}


# --------------------------------------------------------------------------- #
# Engine
# --------------------------------------------------------------------------- #


def engine_command() -> Tuple[List[str], Optional[Path], str]:
    """Same fallback ladder as `demo/backend/app/lean_runner.py`."""
    if PROBATE_API_BIN.is_file():
        return [str(PROBATE_API_BIN)], None, "binary"
    if LAKE_BIN.is_file():
        return [str(LAKE_BIN), "--quiet", "exe", "probate-api"], REPO_ROOT, "lake"
    raise SystemExit(
        f"error: neither {PROBATE_API_BIN} nor {LAKE_BIN} is available.\n"
        f"  cd {REPO_ROOT} && ~/.elan/bin/lake build"
    )


def first_json_object(text: str) -> Optional[Dict[str, Any]]:
    """First `{...}` that parses — the lake path interleaves build chatter."""
    decoder = json.JSONDecoder()
    start = text.find("{")
    while start >= 0:
        try:
            candidate, _ = decoder.raw_decode(text, start)
        except ValueError:
            candidate = None
        if isinstance(candidate, dict):
            return candidate
        start = text.find("{", start + 1)
    return None


def run_lean(cmd: List[str], cwd: Optional[Path], case: Dict[str, Any]) -> Dict[str, Any]:
    payload = json.dumps(case).encode("utf-8")
    started = time.perf_counter()
    proc = subprocess.run(
        cmd, cwd=str(cwd) if cwd else None, input=payload, capture_output=True,
        timeout=60,
    )
    latency_ms = round((time.perf_counter() - started) * 1000, 1)
    stdout = proc.stdout.decode("utf-8", "replace")
    parsed = first_json_object(stdout)
    if parsed is None:
        raise SystemExit(
            f"error: engine emitted no JSON object (exit {proc.returncode}): "
            f"{stdout[:200]!r}"
        )
    return {
        "result": parsed,
        "measured_latency_ms": latency_ms,
        "stdout_sha256": hashlib.sha256(proc.stdout).hexdigest(),
    }


# --------------------------------------------------------------------------- #
# Grading
# --------------------------------------------------------------------------- #


def grade(expected: str, result: Dict[str, Any]) -> Tuple[str, bool]:
    """AUDIT.md's ground truth is a verdict, or the literal `ERROR`."""
    error = result.get("error")
    actual = "ERROR" if error else result.get("verdict")
    if expected == "ERROR":
        return actual, bool(error)
    return actual, (error is None and actual == expected)


def route_table(result: Dict[str, Any]) -> List[Dict[str, Any]]:
    return [
        {
            "route": row.get("route"),
            "status": row.get("status"),
            "reasons": [r.get("id") for r in row.get("reasons") or []],
            "missing_facts": row.get("missing_facts") or [],
            "forms": row.get("forms") or [],
            "detail": row.get("detail") or "",
        }
        for row in result.get("routes") or []
    ]


# --------------------------------------------------------------------------- #
# Optional Gemini half
# --------------------------------------------------------------------------- #


def run_llm_half(cases: List[Dict[str, Any]], samples: int) -> Dict[str, Any]:
    """Sample the Gemini engine `samples` times per case, or explain the skip.

    Never invents a result. If the key is missing, the backend is not
    importable, or a call fails, that fact is what gets recorded.
    """
    if samples <= 0:
        return {
            "status": "skipped",
            "reason": (
                "not requested. The Gemini half of AUDIT.md is opt-in because it "
                "costs money, calls a third-party API, and is sampled at non-zero "
                "temperature. Re-run with --llm 3 and a GEMINI_API_KEY to "
                "reproduce it."
            ),
            "runs": [],
        }

    sys.path.insert(0, str(REPO_ROOT / "demo" / "backend"))
    try:
        import asyncio
        import os

        from dotenv import load_dotenv

        load_dotenv(REPO_ROOT / "demo" / "backend" / ".env")
        if not os.environ.get("GEMINI_API_KEY"):
            return {
                "status": "skipped",
                "reason": "GEMINI_API_KEY is not set (checked env and demo/backend/.env)",
                "runs": [],
            }
        from app.llm import analyze_llm, default_model  # type: ignore
    except Exception as exc:  # noqa: BLE001 — a skip, never a fabricated result
        return {
            "status": "skipped",
            "reason": f"backend LLM module unavailable: {exc}",
            "runs": [],
        }

    model = default_model()
    runs: List[Dict[str, Any]] = []

    async def one(entry: Dict[str, Any]) -> Dict[str, Any]:
        # The same bytes the Lean engine saw — `input_case`, not the case name.
        body = json.dumps(entry["input_case"]).encode("utf-8")
        try:
            result = await analyze_llm(body)
        except Exception as exc:  # noqa: BLE001
            return {"error": f"{type(exc).__name__}: {exc}"}
        return json.loads(result.model_dump_json())

    for entry in cases:
        for sample in range(samples):
            payload = asyncio.run(one(entry))
            expected = entry["ground_truth"]
            if "error" in payload and "verdict" not in payload:
                # The call itself failed; recorded as a failure, never guessed.
                actual, correct = None, False
            else:
                # A malformed LLM response surfaces as CheckResult.error, which
                # grade() reports as "ERROR" — correct only where AUDIT.md's
                # ground truth is itself ERROR.
                actual, correct = grade(expected, payload)
            runs.append(
                {
                    "case": entry["case"],
                    "sample": sample + 1,
                    "expected_verdict": expected,
                    "actual_verdict": actual,
                    "correct": correct,
                    "raw": payload,
                }
            )
    correct = sum(1 for r in runs if r["correct"])
    return {
        "status": "ran",
        "model": model,
        "samples_per_case": samples,
        "runs_correct": correct,
        "runs_total": len(runs),
        "runs": runs,
    }


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Replay demo/AUDIT.md's 12 ground-truth cases against the "
                    "Lean engine and write tools/audit_runs.json.",
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--llm", type=int, default=0, metavar="N",
                        help="also run N Gemini samples per case (default 0 = "
                             "skipped; needs GEMINI_API_KEY and spends money)")
    parser.add_argument("--check", action="store_true",
                        help="diff this run's route tables against the existing "
                             "--out file instead of only overwriting it")
    args = parser.parse_args(argv)

    scoreboard = parse_audit_scoreboard(AUDIT_MD)
    if not scoreboard:
        print(f"error: no scoreboard rows parsed from {AUDIT_MD}", file=sys.stderr)
        return 2
    samples = load_sample_cases(SAMPLE_CASES)

    cmd, cwd, engine_path = engine_command()
    entries: List[Dict[str, Any]] = []
    discrepancies: List[str] = []

    for row in scoreboard:
        name = row["case"]
        sample = samples.get(name)
        if sample is None:
            discrepancies.append(
                f"{name}: named in AUDIT.md but absent from sample_cases.json"
            )
            continue
        # AUDIT.md and sample_cases.json each carry the expected verdict.
        # They are independent copies, so a divergence is itself a finding.
        declared = sample.get("expected_verdict")
        if declared != row["ground_truth"]:
            discrepancies.append(
                f"{name}: AUDIT.md says {row['ground_truth']}, "
                f"sample_cases.json says {declared}"
            )
        run = run_lean(cmd, cwd, sample["case"])
        actual, correct = grade(row["ground_truth"], run["result"])
        entries.append(
            {
                "number": row["number"],
                "case": name,
                "title": sample.get("title"),
                "ground_truth": row["ground_truth"],
                "audit_md_lean_grade": row["audit_md_lean"],
                "audit_md_gemini_grade": row["audit_md_gemini"],
                "lean_actual": actual,
                "lean_correct": correct,
                "lean_error": run["result"].get("error"),
                "lean_overall": run["result"].get("overall"),
                "lean_routes": route_table(run["result"]),
                "lean_reasoning": run["result"].get("reasoning", ""),
                "measured_latency_ms": run["measured_latency_ms"],
                "stdout_sha256": run["stdout_sha256"],
                "input_case": sample["case"],
            }
        )

    correct = sum(1 for e in entries if e["lean_correct"])
    llm = run_llm_half(entries, args.llm)

    report = {
        "harness": "tools/run_audit.py",
        "generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "ground_truth_source": "demo/AUDIT.md scoreboard (parsed, not copied)",
        "case_source": "demo/content/sample_cases.json",
        "engine_path": engine_path,
        "lean": {
            "cases": len(entries),
            "correct": correct,
            "score": f"{correct}/{len(entries)}",
            "scope": "verdict level; route tables are recorded, not re-derived",
        },
        "llm": llm,
        "input_discrepancies": discrepancies,
        "cases": entries,
    }

    previous_mismatches: List[str] = []
    if args.check and args.out.is_file():
        try:
            old = json.loads(args.out.read_text("utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            previous_mismatches.append(f"could not read {args.out}: {exc}")
        else:
            old_by_case = {c["case"]: c for c in old.get("cases", [])}
            for entry in entries:
                before = old_by_case.get(entry["case"])
                if before is None:
                    previous_mismatches.append(f"{entry['case']}: new case")
                elif before.get("lean_routes") != entry["lean_routes"]:
                    previous_mismatches.append(
                        f"{entry['case']}: route table changed since the "
                        "committed run"
                    )
                elif before.get("lean_actual") != entry["lean_actual"]:
                    previous_mismatches.append(
                        f"{entry['case']}: verdict changed "
                        f"{before.get('lean_actual')} → {entry['lean_actual']}"
                    )
        try:  # repo-relative so the committed file is machine-independent
            against = str(args.out.resolve().relative_to(REPO_ROOT))
        except ValueError:
            against = str(args.out)
        report["regression_check"] = {
            "against": against,
            "mismatches": previous_mismatches,
        }

    if not (args.check and previous_mismatches):
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    width = max(len(e["case"]) for e in entries) if entries else 10
    print(f"engine: {engine_path}   ground truth: {AUDIT_MD.relative_to(REPO_ROOT)}\n")
    for entry in entries:
        mark = "ok  " if entry["lean_correct"] else "FAIL"
        print(
            f"  {mark}  {entry['number']:>2}  {entry['case']:<{width}}  "
            f"expected {entry['ground_truth']:<18} got {entry['lean_actual']}"
        )
    print(f"\nLean (verdict level): {correct}/{len(entries)}")
    print(f"LLM  half:            {llm['status']}"
          + (f" — {llm.get('reason')}" if llm["status"] == "skipped" else
             f" — {llm.get('runs_correct')}/{llm.get('runs_total')} "
             f"({llm.get('model')})"))
    if discrepancies:
        print("\ninput discrepancies:")
        for item in discrepancies:
            print(f"  - {item}")
    if args.check:
        print(f"\nregression vs {args.out.name}: "
              + ("clean" if not previous_mismatches else "MISMATCH"))
        for item in previous_mismatches:
            print(f"  - {item}")
    print(f"\nwrote {args.out}" if not (args.check and previous_mismatches)
          else f"\n{args.out} left untouched (mismatch)")

    failed = correct != len(entries) or discrepancies or previous_mismatches
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
