#!/usr/bin/env python3
"""Deterministic, seeded property-based fuzz harness for the Lean `probate-api`.

Generates `PartialTransferCase` JSON (the `CaseInput` wire shape of
`demo/CONTRACT.md`), drives the built engine over stdin/stdout, and checks
properties that must hold *by construction* — not by comparison against a
second oracle for the legal answer. There is no second legal oracle here and
this harness does not pretend to be one. What it does establish is that the
engine's doctrine holds across a large input space:

  shape         every non-error response is contract-shaped and carries all six
                CA route rows, in the contract's stable order
  aggregation   the fallback row and `overall` are exactly the function of the
                five simplified rows that `Partial.lean` specifies
  monotonicity  raising a known asset value never turns a simplified route from
                `does_not_qualify` into `qualifies`
  unknown_safe  replacing a known fact with `null` never turns any route from
                `does_not_qualify` or `needs_information` into `qualifies`, and
                never turns a non-ELIGIBLE verdict into ELIGIBLE
  snapshot      every death date after 2026-12-31 returns the typed
                `after_snapshot` error — never a verdict
  invalid_date  an impossible civil date returns the typed `invalid_date` error
  determinism   byte-identical input produces byte-identical output

Run:
    python3 tools/fuzz_probate.py                 # default corpus, ~30 s
    python3 tools/fuzz_probate.py --cases 250000  # overnight run
    python3 tools/fuzz_probate.py --seed 7 --jobs 4 --report /tmp/r.json
    python3 tools/fuzz_probate.py --self-test     # do the checkers fire at all?
    python3 tools/fuzz_probate.py --cases 60 --bin tools/sabotage_engine.py
                                                  # ...and against a real bug

Every case is derived from `--seed` and its own index, so a run is reproducible
regardless of `--jobs`, and any reported violation replays on its own with
`--only <index>`.

Exit status is 0 only when no invariant was violated, so this is usable as a
CI gate. See `tools/README.md` for what these properties do and do not
establish — in particular, they are NOT the machine-checked refinement proofs,
which remain an open TODO in `SimpleProbate/Partial.lean` lines 24-38.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import random
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BIN = REPO_ROOT / ".lake" / "build" / "bin" / "probate-api"
DEFAULT_REPORT = REPO_ROOT / "tools" / "fuzz_report.json"

# demo/CONTRACT.md — stable route order, and the five "simplified" routes whose
# eligibility is a conjunction of statutory conditions. The sixth row is the
# catch-all fallback and is NOT monotone in asset value by design: raising a
# value can push every simplified route over its cap, which is exactly when the
# fallback is supposed to start qualifying. Its behaviour is pinned by the
# `aggregation` invariant instead.
SIMPLIFIED_ROUTES = [
    "direct_transfer",
    "personal_property_affidavit",
    "small_value_real_property_affidavit",
    "primary_residence_petition",
    "spousal_property_petition",
]
FALLBACK_ROUTE = "formal_probate_or_other_procedure"
ROUTE_ORDER = SIMPLIFIED_ROUTES + [FALLBACK_ROUTE]

ROUTE_STATUSES = {"qualifies", "does_not_qualify", "needs_information"}
VERDICTS = {"ELIGIBLE", "INCOMPLETE_INFO", "OTHER_FORM_REQUIRED"}
OVERALLS = {
    "simplified_routes_available",
    "unresolved",
    "formal_probate_or_other_procedure",
}
ERROR_TYPES = {"invalid_date", "after_snapshot", "malformed_case"}

# SimpleProbate/Date.lean
SNAPSHOT_END = (2026, 12, 31)

PROPERTY_KINDS = ["personal", "california_real", "outside_california_real"]
TREATMENTS = [
    "counted",
    "joint_tenancy",
    "terminable_at_death",
    "revocable_trust",
    "spouse_passage",
    "multiple_party_survivor",
    "registered_vehicle",
    "vessel",
    "registered_home",
    "direct_beneficiary",
    "transfer_on_death",
    "government_benefit",
    "military_compensation",
    "employment_compensation",
]
AUTHORITIES = [
    "no_proceeding",
    "written_personal_representative_consent",
    "blocked_by_proceeding",
]
SURVIVOR_STATUSES = ["none", "spouse", "registered_domestic_partner"]

ASSET_FIELDS = [
    "kind",
    "gross_value_cents",
    "encumbrances_cents",
    "treatment",
    "included_in_primary_residence_petition",
    "is_primary_residence",
]
TOP_LEVEL_FACT_FIELDS = [
    "death_date",
    "days_since_death",
    "six_months_elapsed",
    "claimant_is_successor",
    "no_superior_right",
    "funeral_last_illness_and_unsecured_debts_paid",
    "authority",
    "survivor_status",
    "property_passes_to_survivor",
    "property_belongs_to_survivor",
]

DAYS_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


# --------------------------------------------------------------------------- #
# Engine
# --------------------------------------------------------------------------- #


class EngineError(RuntimeError):
    pass


class Engine:
    """One subprocess per case, exactly as the FastAPI backend does it."""

    def __init__(self, binary: Path, timeout_s: float = 20.0) -> None:
        self.binary = binary
        self.timeout_s = timeout_s
        self.invocations = 0
        # `+=` on an attribute is load/add/store, so it is not atomic across
        # worker threads. The invocation count is a number this harness
        # publishes; it does not get to be approximate.
        self._lock = threading.Lock()

    def run_raw(self, case: Dict[str, Any]) -> Tuple[bytes, Dict[str, Any]]:
        payload = json.dumps(case, sort_keys=True).encode("utf-8")
        try:
            proc = subprocess.run(
                [str(self.binary)],
                input=payload,
                capture_output=True,
                timeout=self.timeout_s,
            )
        except subprocess.TimeoutExpired as exc:
            raise EngineError(f"engine timed out after {self.timeout_s}s") from exc
        with self._lock:
            self.invocations += 1
        if proc.returncode != 0:
            err = proc.stderr.decode("utf-8", "replace")[:300]
            raise EngineError(f"engine exited {proc.returncode}: {err}")
        try:
            parsed = json.loads(proc.stdout.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise EngineError(
                f"engine emitted unparseable output: {proc.stdout[:200]!r}"
            ) from exc
        return proc.stdout, parsed

    def run(self, case: Dict[str, Any]) -> Dict[str, Any]:
        return self.run_raw(case)[1]


# --------------------------------------------------------------------------- #
# Generator — deterministic in (master seed, case index)
# --------------------------------------------------------------------------- #


def case_rng(seed: int, index: int) -> random.Random:
    """Per-case RNG. Independent of scheduling, so --jobs never changes a run."""
    return random.Random(f"{seed}:{index}")


def maybe(rng: random.Random, p_unknown: float, value: Any) -> Any:
    """`value`, or an explicit null with probability `p_unknown`.

    Explicit `null` rather than an absent key: `Api.optField` treats the two
    identically, and sending the null exercises the branch that actually has to
    make that promise.
    """
    return None if rng.random() < p_unknown else value


def random_valid_date(rng: random.Random) -> Dict[str, int]:
    """A real civil date at or before the 2026-12-31 snapshot end."""
    year = rng.randint(1998, 2026)
    month = rng.randint(1, 12)
    max_day = DAYS_IN_MONTH[month - 1]
    if month == 2 and (year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)):
        max_day = 29
    day = rng.randint(1, max_day)
    if (year, month, day) > SNAPSHOT_END:  # only reachable in Dec 2026
        day = 31
    return {"year": year, "month": month, "day": day}


def random_post_snapshot_date(rng: random.Random) -> Dict[str, int]:
    return {
        "year": rng.randint(2027, 2099),
        "month": rng.randint(1, 12),
        "day": rng.randint(1, 28),
    }


def random_invalid_date(rng: random.Random) -> Dict[str, int]:
    """An impossible civil date. Never post-snapshot, so `invalid_date` is the
    only typed error the engine can legitimately return."""
    return rng.choice(
        [
            {"year": 2024, "month": 2, "day": 30},
            {"year": 2023, "month": 2, "day": 29},
            {"year": 2024, "month": 13, "day": 1},
            {"year": 2024, "month": 0, "day": 12},
            {"year": 2024, "month": 4, "day": 31},
            {"year": 2024, "month": 6, "day": 0},
        ]
    )


def random_asset(rng: random.Random, index: int, p_unknown: float) -> Dict[str, Any]:
    # Values straddle every published band boundary ($55,425 / $61,500 /
    # $69,625 / $166,250 / $184,500 / $208,850 / $750,000) so cap comparisons
    # land on both sides and occasionally on the boundary itself.
    value = rng.choice(
        [
            rng.randint(0, 500_000),
            rng.randint(500_000, 25_000_000),
            rng.randint(1_000_000, 100_000_000),
            rng.choice(
                [5_542_500, 6_150_000, 6_962_500, 16_625_000, 18_450_000,
                 20_887_500, 20_885_000, 75_000_000]
            ),
        ]
    )
    return {
        "name": f"asset-{index}",
        "kind": maybe(rng, p_unknown, rng.choice(PROPERTY_KINDS)),
        "gross_value_cents": maybe(rng, p_unknown, value),
        "encumbrances_cents": maybe(rng, p_unknown, rng.randint(0, 30_000_000)),
        "treatment": maybe(rng, p_unknown, rng.choice(TREATMENTS)),
        "included_in_primary_residence_petition": maybe(
            rng, p_unknown, rng.choice([True, False])
        ),
        "is_primary_residence": maybe(rng, p_unknown, rng.choice([True, False])),
    }


# SimpleProbate/Thresholds.lean, in CENTS. Band start dates from
# SimpleProbate/Date.lean. Used only to aim the generator at cap boundaries —
# the engine remains the sole authority on which band applies.
THRESHOLD_BANDS = [
    ((2025, 4, 1), {"ppa": 20_885_000, "prp": 75_000_000, "svrp": 6_962_500}),
    ((2022, 4, 1), {"ppa": 18_450_000, "prp": 18_450_000, "svrp": 6_150_000}),
    ((0, 0, 0), {"ppa": 16_625_000, "prp": 16_625_000, "svrp": 5_542_500}),
]

# The treatments `Asset.directTransferBasis` maps to a basis (Estate.lean).
DIRECT_BASIS_TREATMENTS = [
    "government_benefit",
    "direct_beneficiary",
    "revocable_trust",
    "joint_tenancy",
    "transfer_on_death",
    "multiple_party_survivor",
    "spouse_passage",
]
# Treatments that contribute 0 to every §13050 valuation, so filler assets
# never perturb a cap the generator is aiming at.
INERT_TREATMENTS = [
    "joint_tenancy",
    "terminable_at_death",
    "revocable_trust",
    "spouse_passage",
    "multiple_party_survivor",
    "registered_vehicle",
    "vessel",
    "registered_home",
    "direct_beneficiary",
    "transfer_on_death",
    "government_benefit",
    "military_compensation",
]


def caps_for(date: Dict[str, int]) -> Dict[str, int]:
    key = (date["year"], date["month"], date["day"])
    for start, caps in THRESHOLD_BANDS:
        if key >= start:
            return caps
    return THRESHOLD_BANDS[-1][1]


def split_total(rng: random.Random, total: int, parts: int) -> List[int]:
    """`total` split into `parts` non-negative integers."""
    if parts <= 1:
        return [total]
    cuts = sorted(rng.randint(0, total) for _ in range(parts - 1))
    bounds = [0] + cuts + [total]
    return [bounds[i + 1] - bounds[i] for i in range(parts)]


def near_cap(rng: random.Random, cap: int) -> int:
    """A total that lands on, just under, or just over `cap`.

    Cap boundaries are where monotonicity has any teeth at all; a purely random
    corpus almost never puts a route within a dollar of its threshold.
    """
    return max(
        0,
        cap
        + rng.choice(
            [0, 0, -1, 1, -100, 100, -rng.randint(1, cap // 4 + 1),
             rng.randint(1, cap // 4 + 1)]
        ),
    )


def filler_asset(rng: random.Random, index: int, p_unknown: float) -> Dict[str, Any]:
    return {
        "name": f"asset-{index}",
        "kind": maybe(rng, p_unknown, rng.choice(PROPERTY_KINDS)),
        "gross_value_cents": maybe(rng, p_unknown, rng.randint(0, 90_000_000)),
        "encumbrances_cents": maybe(rng, p_unknown, rng.randint(0, 10_000_000)),
        "treatment": maybe(rng, p_unknown, rng.choice(INERT_TREATMENTS)),
        "included_in_primary_residence_petition": maybe(rng, p_unknown, False),
        "is_primary_residence": maybe(rng, p_unknown, False),
    }


def generate_targeted_case(rng: random.Random) -> Dict[str, Any]:
    """A case built to sit on one route's decision boundary.

    Every conjunct of the chosen route is satisfied and the relevant §13050
    valuation is placed within a few cents of that route's cap, then a small
    fraction of facts is blanked back to unknown. Without this the corpus
    almost never reaches `qualifies` on the capped routes, and the monotonicity
    and unknown-safety invariants would be checked only on cases where they are
    vacuous.
    """
    route = rng.choice(SIMPLIFIED_ROUTES)
    p_unknown = rng.choice([0.0, 0.0, 0.0, 0.06, 0.15])
    date = random_valid_date(rng)
    caps = caps_for(date)

    n_counted = rng.randint(1, 3)
    counted: List[Dict[str, Any]] = []
    if route == "direct_transfer":
        counted = [
            {
                "name": "asset-0",
                "kind": rng.choice(PROPERTY_KINDS),
                "gross_value_cents": rng.randint(0, 90_000_000),
                "encumbrances_cents": 0,
                "treatment": rng.choice(DIRECT_BASIS_TREATMENTS),
                "included_in_primary_residence_petition": False,
                "is_primary_residence": rng.choice([True, False]),
            }
        ]
    elif route == "spousal_property_petition":
        counted = [filler_asset(rng, 0, 0.0)]
    else:
        if route == "personal_property_affidavit":
            kind, primary, cap = "personal", False, caps["ppa"]
        elif route == "small_value_real_property_affidavit":
            kind, primary, cap = "california_real", False, caps["svrp"]
        else:  # primary_residence_petition
            kind, primary, cap = "california_real", True, caps["prp"]
        for i, value in enumerate(
            split_total(rng, near_cap(rng, cap), n_counted)
        ):
            counted.append(
                {
                    "name": f"asset-{i}",
                    "kind": kind,
                    "gross_value_cents": value,
                    "encumbrances_cents": 0,
                    "treatment": "counted",
                    "included_in_primary_residence_petition": False,
                    "is_primary_residence": primary,
                }
            )

    assets = counted + [
        filler_asset(rng, len(counted) + i, p_unknown)
        for i in range(rng.randint(0, 2))
    ]
    # Blank a few of the target's own facts back to unknown.
    for asset in counted:
        for field in ASSET_FIELDS:
            asset[field] = maybe(rng, p_unknown, asset[field])

    spousal = route == "spousal_property_petition"
    return {
        "death_date": maybe(rng, p_unknown, date),
        "days_since_death": maybe(rng, p_unknown, rng.randint(40, 900)),
        "six_months_elapsed": maybe(rng, p_unknown, True),
        "claimant_is_successor": maybe(rng, p_unknown, True),
        "no_superior_right": maybe(rng, p_unknown, True),
        "funeral_last_illness_and_unsecured_debts_paid": maybe(rng, p_unknown, True),
        "authority": maybe(
            rng,
            p_unknown,
            rng.choice(["no_proceeding", "written_personal_representative_consent"]),
        ),
        "survivor_status": maybe(
            rng,
            p_unknown,
            rng.choice(["spouse", "registered_domestic_partner"]) if spousal
            else rng.choice(SURVIVOR_STATUSES),
        ),
        "property_passes_to_survivor": maybe(
            rng, p_unknown, True if spousal else rng.choice([True, False])
        ),
        "property_belongs_to_survivor": maybe(
            rng, p_unknown, rng.choice([True, False])
        ),
        "estate": {
            "inventory_complete": maybe(rng, p_unknown, True),
            "assets": assets,
        },
        "target_index": 0,
    }


def generate_case(rng: random.Random) -> Dict[str, Any]:
    """One well-formed `CaseInput`.

    Well-formed is deliberate: `target_index` is always in range and asset
    names are unique, so every generated case reaches the eligibility layer
    rather than short-circuiting to `malformed_case`. Structural rejection is
    already covered by the Lean unit examples; what needs volume is the
    partial-information layer.

    Roughly half the corpus is uniformly random over the input space and half
    is aimed at a route's decision boundary — see `generate_targeted_case`.
    """
    if rng.random() < 0.55:
        return generate_targeted_case(rng)
    p_unknown = rng.choice([0.0, 0.1, 0.25, 0.4, 0.6])
    n_assets = rng.randint(1, 4)
    assets = [random_asset(rng, i, p_unknown) for i in range(n_assets)]
    return {
        "death_date": maybe(rng, p_unknown, random_valid_date(rng)),
        "days_since_death": maybe(rng, p_unknown, rng.randint(0, 900)),
        "six_months_elapsed": maybe(rng, p_unknown, rng.choice([True, False])),
        "claimant_is_successor": maybe(rng, p_unknown, rng.choice([True, False])),
        "no_superior_right": maybe(rng, p_unknown, rng.choice([True, False])),
        "funeral_last_illness_and_unsecured_debts_paid": maybe(
            rng, p_unknown, rng.choice([True, False])
        ),
        "authority": maybe(rng, p_unknown, rng.choice(AUTHORITIES)),
        "survivor_status": maybe(rng, p_unknown, rng.choice(SURVIVOR_STATUSES)),
        "property_passes_to_survivor": maybe(
            rng, p_unknown, rng.choice([True, False])
        ),
        "property_belongs_to_survivor": maybe(
            rng, p_unknown, rng.choice([True, False])
        ),
        "estate": {
            "inventory_complete": maybe(rng, p_unknown, rng.choice([True, False])),
            "assets": assets,
        },
        "target_index": rng.randrange(n_assets),
    }


# --------------------------------------------------------------------------- #
# Mutations
# --------------------------------------------------------------------------- #


def known_fact_paths(case: Dict[str, Any]) -> List[str]:
    """Every fact currently KNOWN (non-null) that may be nulled.

    `target_index` and `estate.assets[i].name` are excluded: they are structural
    identifiers, not facts, and nulling them is a `malformed_case`, not an
    unknown.
    """
    paths = [f for f in TOP_LEVEL_FACT_FIELDS if case.get(f) is not None]
    estate = case["estate"]
    if estate.get("inventory_complete") is not None:
        paths.append("estate.inventory_complete")
    for i, asset in enumerate(estate["assets"]):
        paths.extend(
            f"estate.assets[{i}].{field}"
            for field in ASSET_FIELDS
            if asset.get(field) is not None
        )
    return paths


def with_fact_unknown(case: Dict[str, Any], path: str) -> Dict[str, Any]:
    """`case` with the fact at `path` replaced by an explicit null."""
    out = copy.deepcopy(case)
    if path.startswith("estate.assets["):
        index_str, field = path[len("estate.assets[") :].split("].", 1)
        out["estate"]["assets"][int(index_str)][field] = None
    elif path == "estate.inventory_complete":
        out["estate"]["inventory_complete"] = None
    else:
        out[path] = None
    return out


def with_values_raised(
    case: Dict[str, Any], rng: random.Random
) -> Optional[Dict[str, Any]]:
    """`case` with every KNOWN gross value strictly increased.

    None when no asset has a known value — there is nothing to raise, so the
    monotonicity property is vacuous for that case.
    """
    out = copy.deepcopy(case)
    raised = False
    for asset in out["estate"]["assets"]:
        if asset.get("gross_value_cents") is not None:
            asset["gross_value_cents"] += rng.randint(1, 200_000_000)
            raised = True
    return out if raised else None


# --------------------------------------------------------------------------- #
# Invariants
# --------------------------------------------------------------------------- #


def route_map(result: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    return {row["route"]: row for row in result.get("routes") or []}


def route_statuses(result: Dict[str, Any]) -> Dict[str, str]:
    """Route → status, for "did this mutation change anything?" bookkeeping."""
    return {row["route"]: row["status"] for row in result.get("routes") or []}


def check_shape(result: Dict[str, Any]) -> List[str]:
    """Contract shape + total route coverage. Returns failure descriptions."""
    problems: List[str] = []
    if result.get("engine") != "lean4":
        problems.append(f"engine is {result.get('engine')!r}, expected 'lean4'")
    if not isinstance(result.get("latency_ms"), int):
        problems.append("latency_ms is not an integer")

    error = result.get("error")
    if error is not None:
        # A typed error is not a verdict (doctrine 5).
        if error.get("type") not in ERROR_TYPES:
            problems.append(f"unknown error type {error.get('type')!r}")
        if not isinstance(error.get("detail"), str) or not error["detail"]:
            problems.append("error carries no detail")
        if result.get("verdict") is not None:
            problems.append("error response also carries a verdict")
        if result.get("overall") is not None:
            problems.append("error response also carries an overall outcome")
        if result.get("routes"):
            problems.append("error response also carries route rows")
        return problems

    if result.get("verdict") not in VERDICTS:
        problems.append(f"verdict {result.get('verdict')!r} outside the enum")
    if result.get("overall") not in OVERALLS:
        problems.append(f"overall {result.get('overall')!r} outside the enum")

    routes = result.get("routes") or []
    order = [row.get("route") for row in routes]
    if order != ROUTE_ORDER:
        problems.append(f"route rows are {order!r}, expected {ROUTE_ORDER!r}")
        return problems
    for row in routes:
        status = row.get("status")
        if status not in ROUTE_STATUSES:
            problems.append(f"{row['route']}: status {status!r} outside the enum")
            continue
        # CONTRACT.md: reasons iff does_not_qualify, missing_facts iff
        # needs_information. A row that says "no" without saying why, or
        # "unknown" without naming the unknown, is unusable downstream.
        if status == "does_not_qualify" and not row.get("reasons"):
            problems.append(f"{row['route']}: does_not_qualify with no reasons")
        if status != "does_not_qualify" and row.get("reasons"):
            problems.append(f"{row['route']}: {status} carries reasons")
        if status == "needs_information" and not row.get("missing_facts"):
            problems.append(
                f"{row['route']}: needs_information with no missing_facts"
            )
        if status != "needs_information" and row.get("missing_facts"):
            problems.append(f"{row['route']}: {status} carries missing_facts")
    return problems


def dedup(items: List[str]) -> List[str]:
    """Order-stable dedup, matching `Partial.dedup`."""
    seen: set = set()
    out: List[str] = []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def check_aggregation(result: Dict[str, Any]) -> List[str]:
    """The fallback row and `overall` are exact functions of the five
    simplified rows (SimpleProbate/Partial.lean, `assessRoutes`)."""
    rows = route_map(result)
    if set(rows) != set(ROUTE_ORDER):
        return []  # already reported by check_shape
    simplified = [rows[r] for r in SIMPLIFIED_ROUTES]
    fallback = rows[FALLBACK_ROUTE]
    any_qualifies = any(r["status"] == "qualifies" for r in simplified)
    unresolved = dedup(
        [
            fact
            for row in simplified
            if row["status"] == "needs_information"
            for fact in row.get("missing_facts") or []
        ]
    )

    problems: List[str] = []
    if any_qualifies:
        expected_status, expected_overall = "does_not_qualify", "simplified_routes_available"
    elif not unresolved:
        expected_status, expected_overall = "qualifies", "formal_probate_or_other_procedure"
    else:
        expected_status, expected_overall = "needs_information", "unresolved"

    if fallback["status"] != expected_status:
        problems.append(
            f"fallback row is {fallback['status']}, expected {expected_status}"
        )
    if result.get("overall") != expected_overall:
        problems.append(
            f"overall is {result.get('overall')!r}, expected {expected_overall!r}"
        )
    if expected_status == "needs_information":
        actual = fallback.get("missing_facts") or []
        if actual != unresolved:
            problems.append(
                "fallback missing_facts are not the order-stable union of the "
                f"simplified rows': {actual!r} vs {unresolved!r}"
            )
    return problems


def check_monotonicity(
    base: Dict[str, Any], raised: Dict[str, Any]
) -> List[str]:
    """Raising a known asset value never turns a simplified route from
    `does_not_qualify` into `qualifies`, and never yields ELIGIBLE from a
    non-ELIGIBLE verdict.

    Scoped to the five simplified routes on purpose: the sixth row is the
    catch-all, and pushing every simplified route over its cap is precisely
    when it is supposed to start qualifying. See `check_aggregation`.
    """
    if base.get("error") or raised.get("error"):
        return []
    before, after = route_map(base), route_map(raised)
    problems: List[str] = []
    for route in SIMPLIFIED_ROUTES:
        if route not in before or route not in after:
            continue
        if (
            before[route]["status"] == "does_not_qualify"
            and after[route]["status"] == "qualifies"
        ):
            problems.append(
                f"{route}: does_not_qualify became qualifies after raising values"
            )
    if base.get("verdict") != "ELIGIBLE" and raised.get("verdict") == "ELIGIBLE":
        problems.append("verdict became ELIGIBLE after raising values")
    return problems


def check_unknown_safety(
    base: Dict[str, Any], blanked: Dict[str, Any], path: str
) -> List[str]:
    """Unknown must never help. Replacing a known fact with `null` may downgrade
    a route to `needs_information`, but must never promote one to `qualifies`,
    and must never produce ELIGIBLE where the fuller case was not."""
    if base.get("error"):
        return []
    if blanked.get("error"):
        # Removing a fact can only make the case less determined, never
        # structurally invalid. (target_index/name are excluded from blanking.)
        return [
            f"nulling {path} produced a typed error "
            f"{blanked['error'].get('type')!r} from a well-formed case"
        ]
    before, after = route_map(base), route_map(blanked)
    problems: List[str] = []
    for route in ROUTE_ORDER:
        if route not in before or route not in after:
            continue
        if (
            before[route]["status"] in ("does_not_qualify", "needs_information")
            and after[route]["status"] == "qualifies"
        ):
            problems.append(
                f"{route}: {before[route]['status']} became qualifies "
                f"after nulling {path}"
            )
    if base.get("verdict") != "ELIGIBLE" and blanked.get("verdict") == "ELIGIBLE":
        problems.append(f"verdict became ELIGIBLE after nulling {path}")
    return problems


# --------------------------------------------------------------------------- #
# Per-case driver
# --------------------------------------------------------------------------- #


def violation(
    invariant: str, index: int, detail: str, **extra: Any
) -> Dict[str, Any]:
    return {"invariant": invariant, "case_index": index, "detail": detail, **extra}


def run_one(
    engine: Engine, seed: int, index: int, unknown_probes: int
) -> Tuple[List[Dict[str, Any]], int, Dict[str, int]]:
    """All invariants for one generated case.

    Returns (violations, checks_run, coverage counters). The counters exist so
    a clean run can be read honestly: "zero violations" means nothing unless
    the corpus actually reached a spread of verdicts and route statuses.
    """
    rng = case_rng(seed, index)
    case = generate_case(rng)
    found: List[Dict[str, Any]] = []
    cover: Dict[str, int] = {}
    checks = 0

    def bump(key: str) -> None:
        cover[key] = cover.get(key, 0) + 1

    try:
        raw, base = engine.run_raw(case)
    except EngineError as exc:
        return [violation("engine", index, str(exc), case=case)], 1, cover

    if base.get("error"):
        bump(f"base.error.{base['error'].get('type')}")
    else:
        bump(f"base.verdict.{base.get('verdict')}")
        for row in base.get("routes") or []:
            bump(f"route.{row.get('route')}.{row.get('status')}")

    # --- shape / total coverage ------------------------------------------- #
    checks += 1
    for problem in check_shape(base):
        found.append(violation("shape", index, problem, case=case, result=base))

    # --- aggregation exactness -------------------------------------------- #
    if not base.get("error"):
        checks += 1
        for problem in check_aggregation(base):
            found.append(
                violation("aggregation", index, problem, case=case, result=base)
            )

    # --- determinism ------------------------------------------------------- #
    checks += 1
    try:
        raw2, _ = engine.run_raw(case)
    except EngineError as exc:
        found.append(violation("determinism", index, str(exc), case=case))
        raw2 = raw
    if raw2 != raw:
        found.append(
            violation(
                "determinism",
                index,
                "byte-identical input produced different output",
                case=case,
                first=raw.decode("utf-8", "replace"),
                second=raw2.decode("utf-8", "replace"),
            )
        )

    # --- monotonicity ------------------------------------------------------ #
    raised_case = with_values_raised(case, rng)
    if raised_case is None:
        bump("monotonicity.vacuous_no_known_values")
    else:
        checks += 1
        bump("monotonicity.exercised")
        try:
            raised = engine.run(raised_case)
        except EngineError as exc:
            found.append(violation("monotonicity", index, str(exc), case=raised_case))
        else:
            if route_statuses(raised) != route_statuses(base):
                bump("monotonicity.mutation_changed_the_answer")
            for problem in check_monotonicity(base, raised):
                found.append(
                    violation(
                        "monotonicity",
                        index,
                        problem,
                        case=case,
                        mutated_case=raised_case,
                        result=base,
                        mutated_result=raised,
                    )
                )

    # --- unknown safety ---------------------------------------------------- #
    paths = known_fact_paths(case)
    rng.shuffle(paths)
    for path in paths[:unknown_probes]:
        checks += 1
        bump("unknown_safety.exercised")
        blanked_case = with_fact_unknown(case, path)
        try:
            blanked = engine.run(blanked_case)
        except EngineError as exc:
            found.append(
                violation("unknown_safety", index, str(exc), case=blanked_case)
            )
            continue
        if route_statuses(blanked) != route_statuses(base):
            bump("unknown_safety.mutation_changed_the_answer")
        for problem in check_unknown_safety(base, blanked, path):
            found.append(
                violation(
                    "unknown_safety",
                    index,
                    problem,
                    case=case,
                    mutated_case=blanked_case,
                    result=base,
                    mutated_result=blanked,
                )
            )

    # --- snapshot discipline ----------------------------------------------- #
    checks += 1
    after_case = copy.deepcopy(case)
    after_case["death_date"] = random_post_snapshot_date(rng)
    try:
        after = engine.run(after_case)
    except EngineError as exc:
        found.append(violation("snapshot", index, str(exc), case=after_case))
    else:
        kind = (after.get("error") or {}).get("type")
        if kind != "after_snapshot":
            found.append(
                violation(
                    "snapshot",
                    index,
                    f"death date {after_case['death_date']} past 2026-12-31 returned "
                    f"{kind or 'verdict ' + str(after.get('verdict'))}, "
                    "expected the typed after_snapshot error",
                    case=after_case,
                    result=after,
                )
            )

    # --- invalid dates are typed errors too --------------------------------- #
    checks += 1
    bad_case = copy.deepcopy(case)
    bad_case["death_date"] = random_invalid_date(rng)
    try:
        bad = engine.run(bad_case)
    except EngineError as exc:
        found.append(violation("invalid_date", index, str(exc), case=bad_case))
    else:
        kind = (bad.get("error") or {}).get("type")
        if kind != "invalid_date":
            found.append(
                violation(
                    "invalid_date",
                    index,
                    f"impossible date {bad_case['death_date']} returned "
                    f"{kind or 'verdict ' + str(bad.get('verdict'))}, "
                    "expected the typed invalid_date error",
                    case=bad_case,
                    result=bad,
                )
            )

    return found, checks, cover


# --------------------------------------------------------------------------- #
# Self-test — does the harness actually detect the failures it claims to?
# --------------------------------------------------------------------------- #


def _row(route: str, status: str, **extra: Any) -> Dict[str, Any]:
    row = {"route": route, "status": status, "reasons": [], "missing_facts": [],
           "detail": "", "forms": []}
    if status == "does_not_qualify":
        row["reasons"] = [{"id": "x", "text": "x"}]
    if status == "needs_information":
        row["missing_facts"] = ["death_date"]
    row.update(extra)
    return row


def _result(statuses: Dict[str, str], verdict: str, overall: str) -> Dict[str, Any]:
    return {
        "engine": "lean4",
        "latency_ms": 0,
        "error": None,
        "verdict": verdict,
        "overall": overall,
        "reasoning": "",
        "routes": [_row(r, statuses[r]) for r in ROUTE_ORDER],
    }


def self_test() -> int:
    """Assert every invariant checker fires on a hand-built counterexample.

    A property harness that cannot fail is worth nothing; this is the cheap
    version of mutation testing for the checkers themselves.
    """
    all_dnq = {r: "does_not_qualify" for r in ROUTE_ORDER}
    good = _result(
        {**all_dnq, "personal_property_affidavit": "qualifies"},
        "ELIGIBLE",
        "simplified_routes_available",
    )
    cases: List[Tuple[str, List[str]]] = []

    cases.append(("shape/clean", check_shape(good)))
    bad_engine = copy.deepcopy(good)
    bad_engine["engine"] = "gemini"
    cases.append(("shape/engine", check_shape(bad_engine)))
    missing_row = copy.deepcopy(good)
    missing_row["routes"] = missing_row["routes"][:-1]
    cases.append(("shape/missing_route", check_shape(missing_row)))
    silent_no = copy.deepcopy(good)
    silent_no["routes"][0]["reasons"] = []
    cases.append(("shape/reasonless_no", check_shape(silent_no)))
    verdict_with_error = copy.deepcopy(good)
    verdict_with_error["error"] = {"type": "after_snapshot", "detail": "d"}
    cases.append(("shape/verdict_with_error", check_shape(verdict_with_error)))

    cases.append(("aggregation/clean", check_aggregation(good)))
    wrong_fallback = _result(
        {**all_dnq, "personal_property_affidavit": "qualifies",
         FALLBACK_ROUTE: "qualifies"},
        "ELIGIBLE",
        "simplified_routes_available",
    )
    cases.append(("aggregation/fallback", check_aggregation(wrong_fallback)))
    wrong_overall = _result(all_dnq, "ELIGIBLE", "simplified_routes_available")
    cases.append(("aggregation/overall", check_aggregation(wrong_overall)))

    dnq_base = _result(all_dnq, "OTHER_FORM_REQUIRED",
                       "formal_probate_or_other_procedure")
    cases.append(("monotonicity/clean", check_monotonicity(dnq_base, dnq_base)))
    cases.append(("monotonicity/promoted", check_monotonicity(dnq_base, good)))

    needs = _result(
        {**all_dnq, "personal_property_affidavit": "needs_information",
         FALLBACK_ROUTE: "needs_information"},
        "INCOMPLETE_INFO",
        "unresolved",
    )
    cases.append(("unknown_safety/clean", check_unknown_safety(needs, needs, "p")))
    cases.append(("unknown_safety/promoted",
                  check_unknown_safety(needs, good, "p")))
    cases.append((
        "unknown_safety/error_from_blank",
        check_unknown_safety(needs, {"error": {"type": "malformed_case"}}, "p"),
    ))

    failures = 0
    for name, problems in cases:
        should_be_clean = name.endswith("/clean")
        ok = (not problems) if should_be_clean else bool(problems)
        print(f"  {'ok  ' if ok else 'FAIL'}  {name:<34} {problems}")
        failures += 0 if ok else 1
    print(f"\nself-test: {len(cases) - failures}/{len(cases)} checks behaved as specified")
    return 0 if failures == 0 else 1


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Property-based fuzz harness for the Lean probate-api engine.",
    )
    parser.add_argument("--cases", type=int, default=1000,
                        help="generated cases (default 1000, ~30 s; each case "
                             "runs several engine invocations)")
    parser.add_argument("--seed", type=int, default=20260812,
                        help="master seed; a run is fully determined by it")
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 4,
                        help="parallel workers (does not affect results)")
    parser.add_argument("--unknown-probes", type=int, default=3,
                        help="known facts nulled per case for unknown-safety")
    parser.add_argument("--bin", type=Path, default=DEFAULT_BIN,
                        help="path to the built probate-api binary")
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT,
                        help="where to write the JSON report")
    parser.add_argument("--only", type=int, default=None,
                        help="replay one case index from --seed and exit")
    parser.add_argument("--max-findings", type=int, default=50,
                        help="violations recorded in the report (all are counted)")
    parser.add_argument("--self-test", action="store_true",
                        help="check that each invariant fires on a hand-built "
                             "counterexample, then exit (no engine needed)")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    if not args.bin.is_file():
        print(
            f"error: {args.bin} not found. Build it first:\n"
            f"  cd {REPO_ROOT} && ~/.elan/bin/lake build",
            file=sys.stderr,
        )
        return 2

    indices = [args.only] if args.only is not None else list(range(args.cases))
    engine = Engine(args.bin)
    started = time.perf_counter()

    violations: List[Dict[str, Any]] = []
    coverage: Dict[str, int] = {}
    checks_run = 0
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        results = pool.map(
            lambda i: run_one(engine, args.seed, i, args.unknown_probes), indices
        )
        for found, checks, cover in results:
            violations.extend(found)
            checks_run += checks
            for key, count in cover.items():
                coverage[key] = coverage.get(key, 0) + count
    wall_s = time.perf_counter() - started

    by_invariant: Dict[str, int] = {}
    for item in violations:
        by_invariant[item["invariant"]] = by_invariant.get(item["invariant"], 0) + 1

    try:  # repo-relative so the committed report is machine-independent
        engine_binary = str(args.bin.resolve().relative_to(REPO_ROOT))
    except ValueError:
        engine_binary = str(args.bin)
    report = {
        "harness": "tools/fuzz_probate.py",
        "engine_binary": engine_binary,
        "seed": args.seed,
        "cases": len(indices),
        "engine_invocations": engine.invocations,
        "invariant_checks": checks_run,
        "unknown_probes_per_case": args.unknown_probes,
        "jobs": args.jobs,
        "wall_seconds": round(wall_s, 2),
        "cases_per_second": round(len(indices) / wall_s, 1) if wall_s else None,
        "violations": len(violations),
        "violations_by_invariant": by_invariant,
        # Proof the corpus is not vacuous — see the note in `run_one`.
        "coverage": dict(sorted(coverage.items())),
        "findings": violations[: args.max_findings],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print(f"cases                {len(indices)}")
    print(f"seed                 {args.seed}")
    print(f"engine invocations   {engine.invocations}")
    print(f"invariant checks     {checks_run}")
    print(f"wall time            {wall_s:.2f}s  ({args.jobs} workers)")
    print(f"violations           {len(violations)}")
    print("\ncoverage reached")
    for key, count in sorted(coverage.items()):
        print(f"  {key:<58} {count}")
    if violations:
        for name, count in sorted(by_invariant.items()):
            print(f"  {name:<16} {count}")
        print(f"\nFirst finding:\n{json.dumps(violations[0], indent=2)[:2000]}")
    print(f"\nreport               {args.report}")
    return 1 if violations else 0


if __name__ == "__main__":
    raise SystemExit(main())
