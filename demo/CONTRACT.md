# LLM vs Lean4 — CA Probate Simple Transfer Demo: Shared Contract (v2)

The authoritative deterministic implementation is the theorem-backed exact
`SimpleProbate` API in this repository. `SimpleProbate/Api.lean` is a wire
adapter: it decodes JSON into the typed exact partial case, calls the proved
assessment, and serializes the result. The Python backend is only an HTTP
shape gate and process launcher; it does not reimplement legal rules.

The demo is educational, not legal advice. Lean proves consequences of the
facts supplied to this model; it does not establish that those facts are true.

## Input JSON

`CaseInput` accepts nullable facts. An absent field and an explicit `null` both
mean **unknown**, never false. Money values are non-negative integer cents;
the exact adapter reports malformed input as a top-level error.

Each asset accepts all three value keys:

| key | role |
|---|---|
| `gross_value_cents` | legacy fallback for compatibility |
| `current_gross_value_cents` | explicit fact for current-value rules |
| `date_of_death_value_cents` | explicit fact for date-at-death rules |

The adapter applies precedence independently: current-value rules use
`current_gross_value_cents` when it is a number and otherwise
`gross_value_cents`; date-at-death rules use `date_of_death_value_cents` when
it is a number and otherwise `gross_value_cents`. Pydantic preserves the raw
body and performs no such selection. Thus, an absent or explicit `null`
explicit-value key falls back to a supplied legacy value; the exact fact is
unknown only when neither its explicit key nor the legacy fallback supplies a
number.

```jsonc
{
  "death_date": {"year": 2025, "month": 5, "day": 10},
  "days_since_death": 444,
  "six_months_elapsed": true,
  "claimant_is_successor": true,
  "no_superior_right": true,
  "funeral_last_illness_and_unsecured_debts_paid": true,
  "authority": "no_proceeding",
  "survivor_status": "none",
  "property_passes_to_survivor": false,
  "property_belongs_to_survivor": false,
  "estate": {
    "inventory_complete": true,
    "assets": [{
      "name": "Checking account",
      "kind": "personal",
      "gross_value_cents": 5000000,
      "current_gross_value_cents": 5500000,
      "date_of_death_value_cents": 5000000,
      "encumbrances_cents": 0,
      "treatment": "counted",
      "included_in_primary_residence_petition": false,
      "is_primary_residence": false
    }]
  },
  "target_index": 0
}
```

Assets are assigned zero-based `AssetId`s in input-list order. `target_index`
is converted to `AssetId(target_index)` by the adapter, so index `0` selects
the first asset. An out-of-range index is a Lean-side `malformed_case` error,
not an HTTP 422.

## Result JSON

Both panels use `CheckResult`: `verdict` is `ELIGIBLE`, `INCOMPLETE_INFO`, or
`OTHER_FORM_REQUIRED`; a structural/date error instead has `verdict: null` and
an `error` object (`invalid_date`, `after_snapshot`, or `malformed_case`). The
exact engine returns six stable route rows in this order:

1. `direct_transfer`
2. `personal_property_affidavit`
3. `small_value_real_property_affidavit`
4. `primary_residence_petition`
5. `spousal_property_petition`
6. `formal_probate_or_other_procedure`

Internally the exact assessment evaluates eleven simplified reports: seven
direct-transfer bases plus the four court routes. `Api.lean` projects those
seven direct reports into one `direct_transfer` row, preserves one row for
each court route, and synthesizes the fallback row from the exact overall
outcome. The fallback qualifies only when every simplified route is
conclusively disqualified; it needs information when the exact assessment is
unresolved; it is disqualified when a simplified route qualifies.

Unknown facts use exact typed paths, including
`estate.assets[0].current_gross_value_cents` for a current-value question and
`estate.assets[0].date_of_death_value_cents` for a date-at-death question.
Legacy `gross_value_cents` is an input compatibility key, not an exact missing
fact path.

Within a route, a known failure beats unknown information; otherwise an
unknown required fact yields `needs_information`; otherwise the route
qualifies. Across routes: any qualifying simplified route yields `ELIGIBLE`;
otherwise any unresolved route yields `INCOMPLETE_INFO`; otherwise the
fallback yields `OTHER_FORM_REQUIRED`.

## HTTP boundary

`POST /api/analyze/lean` and `POST /api/analyze/llm` validate a `CaseInput`
but forward the original request bytes, preserving absent keys and explicit
nulls. The Lean process is the only deterministic semantic evaluator.
`GET /api/cases` serves the sample fixtures and `GET /api/lean-source` serves
the following exact-engine inventory in dependency order:

1. `SimpleProbate/Date.lean`
2. `SimpleProbate/Thresholds.lean`
3. `SimpleProbate/Decision.lean`
4. `SimpleProbate/Estate.lean`
5. `SimpleProbate/Case.lean`
6. `SimpleProbate/Eligibility.lean`
7. `SimpleProbate/Procedure.lean`
8. `SimpleProbate/ProcedureAssessment.lean`
9. `SimpleProbate/Api.lean`
10. `SimpleProbate/Examples.lean`
11. `ApiMain.lean`

`GET /api/health` reports configured Gemini and Lean-engine availability.
