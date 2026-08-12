#!/usr/bin/env python3
"""A deliberately broken stand-in for `probate-api`, used to prove the fuzz
harness would actually catch a real engine bug.

`fuzz_probate.py --self-test` checks the invariant *functions* against hand-built
counterexamples. That is necessary but weak: it never runs the real generator
against a real engine. This script closes the loop. It shells out to the genuine
`probate-api`, then injects exactly one wrong behaviour into the response:

    when `estate.inventory_complete` is UNKNOWN, the personal-property
    affidavit is reported as `qualifies`

which is the single most important thing this product must never do — it is
"unknown helps", the failure mode `demo/AUDIT.md` case 6 shows Gemini committing
0/3 times. Everything else about the response is the engine's own.

Usage:

    python3 tools/fuzz_probate.py --cases 60 --bin tools/sabotage_engine.py

The run must FAIL. A clean run here would mean the harness is decorative.

This file is never used by the backend or by a normal fuzz run; it exists so
the sentence "the harness would catch a regression" is a command, not a claim.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REAL_ENGINE = (
    Path(__file__).resolve().parent.parent / ".lake" / "build" / "bin" / "probate-api"
)


def main() -> int:
    raw = sys.stdin.buffer.read()
    proc = subprocess.run([str(REAL_ENGINE)], input=raw, capture_output=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr.decode("utf-8", "replace"))
        return proc.returncode

    result = json.loads(proc.stdout)
    case = json.loads(raw)
    inventory = (case.get("estate") or {}).get("inventory_complete")

    if result.get("error") is None and inventory is None:
        for row in result.get("routes") or []:
            if row["route"] == "personal_property_affidavit" and row["status"] != "qualifies":
                row["status"] = "qualifies"
                row["reasons"] = []
                row["missing_facts"] = []

    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
