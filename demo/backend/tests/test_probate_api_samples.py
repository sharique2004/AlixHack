"""End-to-end demo-fixture contract checks against the compiled Lean API."""

from __future__ import annotations

import asyncio
import json
import subprocess
import unittest
from pathlib import Path
from typing import Any

from app.lean_runner import analyze_lean


REPO_ROOT = Path(__file__).resolve().parents[3]
SAMPLES_PATH = REPO_ROOT / "demo" / "content" / "sample_cases.json"
PROBATE_API_BIN = REPO_ROOT / ".lake" / "build" / "bin" / "probate-api"
ROUTE_ORDER = [
    "direct_transfer",
    "personal_property_affidavit",
    "small_value_real_property_affidavit",
    "primary_residence_petition",
    "spousal_property_petition",
    "formal_probate_or_other_procedure",
]

# These literals are independently derived from sample_cases.derivation.md.
# A status change here identifies a changed externally visible route result.
EXPECTED_ROUTE_STATUSES = {
    "eligible-personal-affidavit": [
        "does_not_qualify",
        "qualifies",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
    ],
    "eligible-direct-transfer": [
        "qualifies",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
    ],
    "eligible-multiple-routes": [
        "does_not_qualify",
        "qualifies",
        "does_not_qualify",
        "does_not_qualify",
        "qualifies",
        "does_not_qualify",
    ],
    "needs-info-unknown-value": [
        "does_not_qualify",
        "needs_information",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "needs_information",
    ],
    "needs-info-unknown-death-date": [
        "does_not_qualify",
        "needs_information",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "needs_information",
    ],
    "needs-info-inventory-not-confirmed": [
        "does_not_qualify",
        "needs_information",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "needs_information",
    ],
    "over-cap-despite-unknowns": [
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "qualifies",
    ],
    "too-soon-20-days": [
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "qualifies",
    ],
    "eligible-primary-residence": [
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "qualifies",
        "does_not_qualify",
        "does_not_qualify",
    ],
    "eligible-small-value-real-property": [
        "does_not_qualify",
        "does_not_qualify",
        "qualifies",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
    ],
    "pre-2022-death-over-old-cap": [
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "does_not_qualify",
        "qualifies",
    ],
}
EXPECTED_MISSING_FACTS = {
    "needs-info-unknown-value": [
        "estate.assets[0].current_gross_value_cents",
        "estate.assets[0].current_gross_value_cents",
    ],
    "needs-info-unknown-death-date": ["death_date", "death_date"],
    "needs-info-inventory-not-confirmed": [
        "estate.inventory_complete",
        "estate.inventory_complete",
    ],
}
DOCUMENTED_TOP_LEVEL_FACTS = {
    "death_date",
    "target_index",
    "authority",
    "days_since_death",
    "six_months_elapsed",
    "claimant_is_successor",
    "no_superior_right",
    "funeral_last_illness_and_unsecured_debts_paid",
    "survivor_status",
    "property_passes_to_survivor",
    "property_belongs_to_survivor",
    "estate.inventory_complete",
}
DOCUMENTED_ASSET_FACT_KEYS = {
    "kind",
    "current_gross_value_cents",
    "date_of_death_value_cents",
    "treatment",
    "is_primary_residence",
    "included_in_primary_residence_petition",
}


def load_samples() -> list[dict[str, Any]]:
    with SAMPLES_PATH.open(encoding="utf-8") as samples_file:
        return json.load(samples_file)


def run_probate_api(case: dict[str, Any]) -> dict[str, Any]:
    completed = subprocess.run(
        [str(PROBATE_API_BIN)],
        cwd=REPO_ROOT,
        input=json.dumps(case),
        capture_output=True,
        check=False,
        text=True,
        timeout=10,
    )
    if completed.returncode != 0:
        raise AssertionError(
            f"probate-api exited {completed.returncode}: {completed.stderr.strip()}"
        )
    try:
        result = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise AssertionError(
            f"probate-api did not emit one JSON result: {completed.stdout!r}"
        ) from exc
    if not isinstance(result, dict):
        raise AssertionError(f"probate-api result was not an object: {result!r}")
    return result


def is_documented_missing_fact(path: str, case: dict[str, Any]) -> bool:
    """Whether a Lean missing-fact path belongs to the documented input API."""
    if path in DOCUMENTED_TOP_LEVEL_FACTS:
        return True
    prefix = "estate.assets["
    if not path.startswith(prefix):
        return False
    remainder = path[len(prefix) :]
    index_text, separator, field = remainder.partition("].")
    if separator != "]." or not index_text.isdecimal():
        return False
    assets = case["estate"]["assets"]
    return int(index_text) < len(assets) and field in DOCUMENTED_ASSET_FACT_KEYS


class ProbateApiSampleContractTests(unittest.TestCase):
    """Protect fixture verdicts and the six-row result projection."""

    def test_every_sample_matches_the_compiled_probate_api_contract(self) -> None:
        """Changed Lean verdicts, routes, or missing-path names break demo samples."""
        self.assertTrue(PROBATE_API_BIN.is_file(), "run `lake build probate-api`")

        samples = load_samples()
        self.assertEqual(len(samples), 12)
        for sample in samples:
            with self.subTest(sample=sample["name"]):
                result = run_probate_api(sample["case"])
                expected_verdict = sample["expected_verdict"]
                if expected_verdict == "ERROR":
                    self.assertIsNone(result["verdict"])
                    self.assertIsNotNone(result["error"])
                    self.assertEqual(result["routes"], [])
                    continue

                self.assertEqual(result["verdict"], expected_verdict)
                self.assertIsNone(result["error"])
                routes = result["routes"]
                self.assertEqual(len(routes), 6)
                self.assertEqual([route["route"] for route in routes], ROUTE_ORDER)
                self.assertEqual(
                    [route["status"] for route in routes],
                    EXPECTED_ROUTE_STATUSES[sample["name"]],
                )

                emitted_missing_facts: list[str] = []
                for route in routes:
                    status = route["status"]
                    reasons = route["reasons"]
                    missing_facts = route["missing_facts"]
                    self.assertEqual(
                        bool(reasons),
                        status == "does_not_qualify",
                        f"{route['route']} reasons must appear only for a disqualification",
                    )
                    self.assertEqual(
                        bool(missing_facts),
                        status == "needs_information",
                        f"{route['route']} missing facts must appear only for unresolved information",
                    )
                    for path in missing_facts:
                        self.assertTrue(
                            is_documented_missing_fact(path, sample["case"]),
                            f"undocumented missing-fact path: {path}",
                        )
                    emitted_missing_facts.extend(missing_facts)
                self.assertEqual(
                    emitted_missing_facts,
                    EXPECTED_MISSING_FACTS.get(sample["name"], []),
                )

    def test_backend_preserves_lean_results_for_legacy_and_dual_value_inputs(self) -> None:
        """Raw-body forwarding must not alter Lean routes while adding backend metrics."""
        samples = {sample["name"]: sample for sample in load_samples()}
        cases = {
            "legacy": samples["eligible-direct-transfer"]["case"],
            "dual": samples["eligible-personal-affidavit"]["case"],
        }
        legacy_asset = cases["legacy"]["estate"]["assets"][0]
        self.assertEqual(legacy_asset["gross_value_cents"], 45_000_000)
        self.assertNotIn("current_gross_value_cents", legacy_asset)
        self.assertNotIn("date_of_death_value_cents", legacy_asset)
        dual_asset = cases["dual"]["estate"]["assets"][0]
        self.assertEqual(dual_asset["gross_value_cents"], 5_000_000)
        self.assertEqual(dual_asset["current_gross_value_cents"], 5_200_000)
        self.assertEqual(dual_asset["date_of_death_value_cents"], 4_800_000)

        for input_shape, case in cases.items():
            with self.subTest(input_shape=input_shape):
                raw_body = json.dumps(case).encode()
                engine_result = run_probate_api(case)
                backend_result = asyncio.run(analyze_lean(raw_body))

                self.assertEqual(backend_result.verdict.value, engine_result["verdict"])
                self.assertIsNone(backend_result.error)
                self.assertEqual(
                    [route.model_dump(mode="json") for route in backend_result.routes],
                    engine_result["routes"],
                )
                self.assertEqual(backend_result.engine, "lean4")
                self.assertGreater(
                    backend_result.latency_ms,
                    engine_result["latency_ms"],
                    "backend must replace Lean's placeholder latency with elapsed wall time",
                )
                self.assertIsNotNone(backend_result.usage)
                self.assertIsNone(backend_result.usage.input_tokens)
                self.assertIsNone(backend_result.usage.output_tokens)
                self.assertIsNotNone(backend_result.usage.cpu_ms)
