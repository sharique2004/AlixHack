"""Contract-level behavior checks for the HTTP validation boundary."""

from __future__ import annotations

import asyncio
import json
import unittest
from pathlib import Path

from app.main import ALIXHACK_DIR, get_lean_source
from app.schemas import Asset


class AssetValuationContractTests(unittest.TestCase):
    """Protect the three-key valuation wire contract accepted by Lean."""

    def test_asset_accepts_legacy_only_value(self) -> None:
        """Removing legacy compatibility would reject existing sample assets."""
        asset = Asset(name="Legacy asset", gross_value_cents=125_000)

        self.assertEqual(asset.model_dump()["gross_value_cents"], 125_000)
        self.assertIsNone(asset.model_dump()["current_gross_value_cents"])
        self.assertIsNone(asset.model_dump()["date_of_death_value_cents"])

    def test_asset_accepts_explicit_value_fields(self) -> None:
        """Dropping either exact valuation fact would lose a supplied value."""
        asset = Asset(
            name="Explicit asset",
            current_gross_value_cents=125_000,
            date_of_death_value_cents=100_000,
        )

        dumped = asset.model_dump()
        self.assertIsNone(dumped["gross_value_cents"])
        self.assertEqual(dumped["current_gross_value_cents"], 125_000)
        self.assertEqual(dumped["date_of_death_value_cents"], 100_000)

    def test_asset_keeps_all_three_numeric_values(self) -> None:
        """Ignoring an explicit wire key would alter the adapter's precedence inputs."""
        asset = Asset(
            name="All values",
            gross_value_cents=125_000,
            current_gross_value_cents=150_000,
            date_of_death_value_cents=100_000,
        )

        self.assertEqual(
            asset.model_dump(),
            {
                "name": "All values",
                "kind": None,
                "gross_value_cents": 125_000,
                "current_gross_value_cents": 150_000,
                "date_of_death_value_cents": 100_000,
                "encumbrances_cents": None,
                "treatment": None,
                "included_in_primary_residence_petition": None,
                "is_primary_residence": None,
            },
        )

    def test_asset_dump_preserves_explicit_null_valuation_fields(self) -> None:
        """Collapsing explicit nulls would change the raw JSON forwarded to Lean."""
        asset = Asset(
            name="Unknown values",
            gross_value_cents=125_000,
            current_gross_value_cents=None,
            date_of_death_value_cents=None,
        )

        dumped = asset.model_dump()
        self.assertIsNone(dumped["current_gross_value_cents"])
        self.assertIsNone(dumped["date_of_death_value_cents"])


class LeanSourceContractTests(unittest.TestCase):
    """Protect the source viewer's exact-engine module inventory."""

    def test_source_endpoint_lists_exact_modules_and_no_retired_partial_layer(self) -> None:
        """A stale inventory would present a retired module as the authority."""
        response = asyncio.run(get_lean_source())
        payload = json.loads(response.body)
        names = [file["name"] for file in payload["files"]]

        self.assertEqual(
            names,
            [
                "SimpleProbate/Date.lean",
                "SimpleProbate/Thresholds.lean",
                "SimpleProbate/Decision.lean",
                "SimpleProbate/Estate.lean",
                "SimpleProbate/Case.lean",
                "SimpleProbate/Eligibility.lean",
                "SimpleProbate/Procedure.lean",
                "SimpleProbate/ProcedureAssessment.lean",
                "SimpleProbate/Api.lean",
                "SimpleProbate/Examples.lean",
                "ApiMain.lean",
            ],
        )
        self.assertNotIn("SimpleProbate/" + "Partial" + ".lean", names)
        for name in (
            "SimpleProbate/Decision.lean",
            "SimpleProbate/Case.lean",
            "SimpleProbate/Eligibility.lean",
            "SimpleProbate/ProcedureAssessment.lean",
            "SimpleProbate/Api.lean",
        ):
            self.assertIn(name, names)

    def test_every_source_endpoint_reference_exists(self) -> None:
        """A missing viewer file would make the published source inventory misleading."""
        response = asyncio.run(get_lean_source())
        payload = json.loads(response.body)

        for file in payload["files"]:
            self.assertTrue((ALIXHACK_DIR / file["name"]).is_file(), file["name"])
