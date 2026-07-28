# LLM vs Lean4 — CA Probate Simple Transfer Demo: Shared Contract (v2)

v2 re-targets the entire app onto the real Lean formalization vendored at `/Users/shariquekhatri/Alix/AlixHack`
(github.com/sharique2004/AlixHack, Lean 4.32.1, toolchain pinned by `AlixHack/lean-toolchain`).
Every component builds against THIS file. The Lean model — not this file — is the ultimate authority on
legal semantics; where this contract paraphrases it, `AlixHack/SimpleProbate/*.lean` wins.

## Purpose

Side-by-side demo. Same structured case JSON evaluated two ways:
- **LLM panel (left)**: Gemini receives the case JSON + `content/simple-transfer.md` (court page) and
  reasons in natural language. Probabilistic. It does NOT see the Lean code.
- **Lean4 panel (right)**: the vendored Lean project, extended with a partial-information layer and a JSON
  CLI bridge, assesses the case deterministically. Real `lake`-built binary, invoked per request.

## The three verdicts (+ one error state)

| `verdict` | Produced when (Lean side) |
|---|---|
| `INCOMPLETE_INFO` | overall outcome `unresolved`: no route qualifies, ≥1 route `needs_information` |
| `ELIGIBLE` | overall outcome `simplified_routes_available`: ≥1 simplified route `qualifies` |
| `OTHER_FORM_REQUIRED` | overall outcome `formal_probate_or_other_procedure`: EVERY simplified route `does_not_qualify` |

Aggregation precedence (per the approved spec in `AlixHack/docs/superpowers/specs/2026-07-28-exact-partial-probate-api-design.md`):
any route qualifies → ELIGIBLE (even if other routes are unresolved); else any route needs information →
INCOMPLETE_INFO; else → OTHER_FORM_REQUIRED. Within one route: known violations beat unknowns
(`does_not_qualify` even when other facts are unknown); unknowns beat satisfaction; all satisfied → `qualifies`.
**Unknown is never treated as false.**

Separate from the three verdicts, a structural **case error** (invalid date; death date after 2026-12-31,
the model's supported snapshot end; malformed case such as a bad `target_index`) is NOT a verdict. It is
returned as a top-level `error` object and rendered as an error state in the panel.

NOTE (semantic flip vs v1): DE-305 / DE-310 / DE-221 routes were "other form" in v1. In the repo's model
they are simplified routes, i.e. **ELIGIBLE** outcomes. `OTHER_FORM_REQUIRED` now means the formal-probate
/ other-procedure fallback only.

## Directory layout

```
/Users/shariquekhatri/Alix
├── CONTRACT.md              ← this file
├── AlixHack/                ← vendored Lean repo. Existing SimpleProbate/*.lean files are the user's
│   │                          verified baseline: DO NOT modify them. New files only:
│   ├── SimpleProbate/Partial.lean   ← NEW: partial-information layer (Knowledge/Option fields,
│   │                                   atomic checks, per-route aggregation, assessRoutes)
│   ├── SimpleProbate/Api.lean       ← NEW: JSON codecs (Lean.Data.Json) for case + assessment
│   ├── ApiMain.lean                 ← NEW: exe root — read one case JSON on stdin, write one
│   │                                   assessment JSON on stdout, exit 0 (even for case errors;
│   │                                   nonzero exit only for unparseable input/internal panic)
│   └── lakefile.toml                ← MAY EDIT: add [[lean_exe]] name = "probate-api", root = "ApiMain";
│                                       also add the two new modules to SimpleProbate.lean imports
├── content/
│   ├── simple-transfer.md   ← court-page markdown (LLM context) — unchanged from v1
│   ├── rules.md             ← REWRITE: route model, thresholds, aggregation semantics, form map
│   └── sample_cases.json    ← REWRITE to v2 schema
├── backend/                 ← FastAPI, port 8000 (re-target existing code)
└── frontend/                ← Vite React TS, port 5173 (re-target existing code)
```

## Case input JSON (`CaseInput` v2) — mirrors `SimpleProbate.TransferCase`, all facts nullable

`null` (or absent) = **unknown**, never false. Money is **integer cents**. Dates are structured, matching
`CivilDate`.

```jsonc
{
  "death_date": {"year": 2025, "month": 5, "day": 10},   // or null. Supported range: valid civil dates ≤ 2026-12-31
  "days_since_death": 444,                                // Nat | null (supplied directly, matching the model)
  "six_months_elapsed": true,                             // bool | null (small-value real property route)
  "claimant_is_successor": true,                          // bool | null
  "no_superior_right": true,                              // bool | null
  "funeral_last_illness_and_unsecured_debts_paid": true,  // bool | null
  "authority": "no_proceeding",                           // "no_proceeding" | "written_personal_representative_consent"
                                                          //   | "blocked_by_proceeding" | null
  "survivor_status": "none",                              // "none" | "spouse" | "registered_domestic_partner" | null
  "property_passes_to_survivor": false,                   // bool | null
  "property_belongs_to_survivor": false,                  // bool | null
  "estate": {
    "inventory_complete": true,                           // bool | null — if not KNOWN true, capped routes can be
                                                          //   disqualified by a known-over-cap subtotal but can
                                                          //   never QUALIFY (they need this fact)
    "assets": [
      {
        "name": "Chase checking",                         // string, required, unique within the list
        "kind": "personal",                               // "personal" | "california_real" | "outside_california_real" | null
        "gross_value_cents": 5000000,                     // Nat | null
        "encumbrances_cents": 0,                          // Nat | null (never reduces eligibility values)
        "treatment": "counted",                           // one of the 14 ValuationTreatment values in snake_case:
          // "counted" | "joint_tenancy" | "terminable_at_death" | "revocable_trust" | "spouse_passage" |
          // "multiple_party_survivor" | "registered_vehicle" | "vessel" | "registered_home" |
          // "direct_beneficiary" | "transfer_on_death" | "government_benefit" | "military_compensation" |
          // "employment_compensation" | null
        "included_in_primary_residence_petition": false,  // bool | null
        "is_primary_residence": false                     // bool | null
      }
    ]
  },
  "target_index": 0        // int, required: which asset the claimant is trying to transfer.
                           // Out-of-range ⇒ case error `malformed_case`. (Demo restriction: target is
                           // always part of the estate; TransferCase.targetIsPartOfEstate := true.)
}
```

## Routes

Snake_case route ids, mirroring `SimpleProbate.Route`:

| route id | Lean constructor | forms / mechanism |
|---|---|---|
| `direct_transfer` | `.directTransfer basis` | no probate; basis ∈ government_benefit, named_beneficiary, revocable_trust, joint_tenancy, transfer_on_death, multiple_party_account, spouse_passage (derived from the TARGET's treatment) |
| `personal_property_affidavit` | `.personalPropertyAffidavit` | §13100–13101 affidavit presented to the holder (no court filing) |
| `small_value_real_property_affidavit` | `.smallValueRealPropertyAffidavit` | DE-305 (§13200) |
| `primary_residence_petition` | `.primaryResidencePetition` | DE-310 / DE-315 (§13150–13154) |
| `spousal_property_petition` | `.spousalPropertyPetition` | DE-221 / DE-226 (§13500, 13650–13656) |
| `formal_probate_or_other_procedure` | `.formalProbateOrOtherProcedure` | DE-111 full probate or another procedure |

`direct_transfer` is reported as a single route row; when it qualifies, `detail` names the basis.
Eligibility semantics per route = the Prop predicates in `Eligibility.lean` (the partial layer's checks
must decompose exactly those conjuncts). Thresholds/exclusions = `Thresholds.lean` / `Estate.lean`
(incl. the §13050 treatment table and the employment-compensation handling as implemented by the
baseline's `Asset.personalAffidavitValue` — mirror the CODE, not the spec's future correction).

## Result JSON (`CheckResult` v2) — BOTH engines return this shape

```jsonc
{
  "verdict": "ELIGIBLE",              // or "INCOMPLETE_INFO" | "OTHER_FORM_REQUIRED" — null iff error is set
  "error": null,                      // or {"type": "invalid_date" | "after_snapshot" | "malformed_case",
                                      //     "detail": "human-readable"}
  "overall": "simplified_routes_available",  // "simplified_routes_available" | "unresolved"
                                      //   | "formal_probate_or_other_procedure" — null iff error
  "routes": [                         // one entry per route id above — all six in stable order for verdict
                                      //   results; [] when `error` is set (no assessment happened; the
                                      //   frontend renders absent rows as "not assessed")
    {
      "route": "personal_property_affidavit",
      "status": "qualifies",          // "qualifies" | "does_not_qualify" | "needs_information"
      "reasons": [],                  // non-empty iff does_not_qualify: stable snake_case disqualifier ids
                                      //   with human-readable text, e.g.
                                      //   {"id": "waiting_period_not_met", "text": "Fewer than 40 days since death"}
      "missing_facts": [],            // non-empty iff needs_information: JSON paths into CaseInput,
                                      //   e.g. "death_date", "estate.assets[1].gross_value_cents"
      "detail": "Qualifying personal-property value $50,000.00 ≤ $208,850.00 limit",  // one line, may be ""
      "forms": []                     // e.g. ["DE-305"]; [] when none apply
    }
  ],
  "reasoning": "…",                   // LLM: free-text reasoning. Lean: one-sentence summary.
  "engine": "lean4",                  // "lean4" | Gemini model name
  "latency_ms": 87,
  "usage": {                     // null when nothing measurable
    "input_tokens": 12340,       // LLM only; null for Lean
    "output_tokens": 512,        // LLM only (includes thinking tokens); null for Lean
    "cpu_ms": null,              // Lean only: subprocess CPU time (user+sys); null for LLM
    "estimated_cost_usd": 0.005, // both, estimate; null if unpriceable
    "pricing_note": "gemini-2.5-flash @ $0.30/M in + $2.50/M out (est.)"
  }
}
```

The Lean binary does NOT emit `usage` — the backend measures the subprocess's CPU time and attaches
the object itself (same as `latency_ms`), so no Lean-side changes are involved. On the LLM side the
backend derives it from the Gemini response's `usageMetadata`. Pricing comes from backend env vars
(`GEMINI_PRICE_IN_PER_M`, `GEMINI_PRICE_OUT_PER_M`, `LEAN_VCPU_PRICE_PER_HOUR`); when nothing is
measurable, `usage` is `null`.

The LLM is prompted to produce the same `verdict`/`overall`/`routes` structure (so the panels align
row-by-row) and graded leniently: if its JSON parses but a route entry is missing, the frontend renders the
row as "not assessed". If its output is unparseable, the backend returns `verdict: null` with
`error: {"type": "malformed_case", "detail": "LLM output was not valid JSON: …"}` and `reasoning` = raw text.

## Lean-side architecture (new files; existing baseline files are read-only)

**`SimpleProbate/Partial.lean`** — partial-information layer per the approved spec, executable scope:
`Knowledge α` (or plain `Option`), `AtomicResult` (satisfied / violated Disqualifier / unknown FactPath),
per-route ordered check lists decomposing the `Eligibility.lean` conjuncts, aggregation with the precedence
above, `PartialTransferCase` structure, and
`assessRoutes : PartialTransferCase → Except CaseError CaseAssessment`.
Valuation under partial info: if every needed asset fact is known, compute exactly as the baseline does;
a known subtotal already above a cap ⇒ `violated` even if other assets have unknown values; otherwise a
value-dependent check with any needed unknown fact (including `estate.inventory_complete` ≠ known-true) ⇒
`unknown`. Include regression `example`s (compile-time, `by decide`/`rfl`) for: a fully-known eligible
case; unknown value ⇒ needs_information; known-over-cap with unknowns ⇒ does_not_qualify; total-case
agreement with `RouteEligible` on at least 3 concrete cases. The spec's full proof contract (completeness
theorems, partial soundness) is OUT OF SCOPE for this pass — leave a `-- TODO(proof-contract)` comment
block listing the deferred theorems. No `sorry`/`axiom` anywhere (omit statements rather than stub them).

**`SimpleProbate/Api.lean`** — `FromJson`/`ToJson` between the wire schemas above and the Lean types.
Tolerant decode: absent key = null = unknown. Reject non-integer/negative money with `malformed_case`.

**`ApiMain.lean`** + lakefile `[[lean_exe]] name = "probate-api"` — stdin→stdout, one JSON document each
way. Unparseable JSON: print a result with `error.type = "malformed_case"` and exit 0. Only an internal
panic exits nonzero.

Backend invokes `AlixHack/.lake/build/bin/probate-api` directly (subprocess, 10 s timeout), falling back to
`~/.elan/bin/lake exe probate-api` (cwd `AlixHack/`) if the binary is missing. If both fail ⇒ HTTP 503
`{"detail": "Lean engine unavailable: <why>"}` — the panel renders that as its error state. No Python
mirror of the rules exists in v2 (delete `backend/app/rules.py`); Lean is the only deterministic engine.

## Backend HTTP API (unchanged routes, v2 payloads)

| Method & path | Body | Returns |
|---|---|---|
| `POST /api/analyze/llm` | `CaseInput` | `CheckResult` (Gemini; 503 if `GEMINI_API_KEY` unset) |
| `POST /api/analyze/lean` | `CaseInput` | `CheckResult` (probate-api binary; 503 if Lean engine unavailable) |
| `GET /api/cases` | – | `content/sample_cases.json` |
| `GET /api/lean-source` | – | `{"files": [{"name": "SimpleProbate/Partial.lean", "content": "…"}, …]}` — every `AlixHack/SimpleProbate/*.lean` + `ApiMain.lean`, stable order: Date, Thresholds, Estate, Eligibility, Procedure, Partial, Api, Examples, then ApiMain |
| `GET /api/health` | – | `{"ok": true, "gemini_configured": bool, "lean_engine": "binary" \| "lake" \| "unavailable"}` |

Gemini call details carry over from v1 (httpx REST `generateContent`, `responseMimeType: application/json`,
`GEMINI_MODEL` default `gemini-2.5-flash`). The prompt = court-page markdown + case JSON + the exact v2
result schema with the three-verdict definitions and route ids. Send the case JSON EXACTLY as received
(nulls intact) so both engines see identical input.

## Sample cases (`content/sample_cases.json`) — v2 schema

`[{ "name", "blurb" (one line, shown in the picker), "expected_verdict", "case": CaseInput }]`. Must cover:
1. eligible-personal-affidavit (personal target, well under cap, 444 days) → ELIGIBLE
2. eligible-direct-transfer (target treatment joint_tenancy) → ELIGIBLE
3. eligible-multiple-routes (spouse; community property passing to survivor AND affidavit-eligible personal target) → ELIGIBLE
4. needs-info-unknown-value (one counted asset's gross_value_cents null) → INCOMPLETE_INFO
5. needs-info-unknown-death-date → INCOMPLETE_INFO
6. needs-info-inventory-not-confirmed (values known & under cap, inventory_complete null) → INCOMPLETE_INFO
7. over-cap-despite-unknowns (known counted subtotal > $208,850 with another value unknown; violation beats unknown) → OTHER_FORM_REQUIRED
8. too-soon-20-days (all facts known, personal target, 20 days) → OTHER_FORM_REQUIRED (reasons show waiting_period_not_met)
9. eligible-primary-residence (CA real target, primary residence, ≤ $750,000, death 2025-06-15) → ELIGIBLE
10. eligible-small-value-real-property (CA real target ≤ $69,625, six_months_elapsed, debts paid) → ELIGIBLE
11. pre-2022-death-over-old-cap (death 2021-10-01, personal value between $166,250 and $208,850) → OTHER_FORM_REQUIRED
12. error-after-snapshot (death 2027-03-01) → error state, expected_verdict "ERROR"

## Frontend (re-target)

Keep the v1 shell (top bar, JSON editor + sample picker, two-panel grid, per-panel loading/error states,
badge colors: INCOMPLETE_INFO amber, ELIGIBLE green, OTHER_FORM_REQUIRED blue; add slate/red badge for the
error state). Changes:
- `types.ts` regenerated to v2 (all nullable facts typed `T | null`).
- Under each verdict badge: the six-row **route table** — status icon (✓ qualifies / ✕ does_not_qualify /
  ? needs_information / — not assessed), route display name, forms chips, and an expandable row body with
  reasons / missing_facts / detail. LLM and Lean tables use the identical component so rows align.
- Lean panel extras: engine chip ("Lean 4.32.1 · probate-api"), Lean-source viewer now a file-tabbed
  collapsible (from `/api/lean-source`), and the model-boundary disclaimer line from the repo README
  ("Lean proves consequences of supplied facts; it does not establish their truth — educational model,
  not legal advice"). Show it small under the panel.
- Sample picker shows `name` + `blurb`; loading a sample replaces the editor content (pretty-printed).

## Design note

Unchanged from v1: clean legal-tech tone, hand-rolled CSS, two visually parallel panels, dark-on-light.
