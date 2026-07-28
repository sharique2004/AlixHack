# Main/Demo Integration with the Exact Probate API

**Date:** 2026-07-28

**Status:** Approved

**Base branch:** `feat/exact-partial-probate-api`

**Merge source:** `origin/main` at `28e1b03`

## Goal

Merge the demo and JSON executable from `main` into the exact,
theorem-backed probate branch without retaining two competing partial-case
engines.

The exact branch remains the sole semantic authority. The JSON executable is
an adapter over its public API, and the demo remains backward-compatible with
the existing input shape while gaining optional support for distinct current
and date-of-death values.

## Observed Merge Failure

Git reports one textual conflict in `SimpleProbate.lean`, where the feature
branch imports `SimpleProbate.ProcedureAssessment` and `main` imports
`SimpleProbate.Partial` and `SimpleProbate.Api`.

Keeping all imports is not a valid resolution. A reproduced merge followed by
`lake build` fails because `main`'s `Partial.lean` redeclares:

- `PartialAsset`, `PartialEstate`, and `PartialTransferCase`;
- `RouteReport`, `OverallOutcome`, and `CaseAssessment`;
- `CaseError`; and
- `assessRoutes`.

It also targets the superseded model: `Option` fields, one `grossValue`,
`targetIndex`, string diagnostics, and string malformed-case details. The
exact branch uses `Knowledge`, separate current/date-of-death values,
`AssetId`/`targetId`, typed facts and failures, and typed structural issues.

The conflict is therefore architectural, not merely an import-order conflict.

## Approaches Considered

### 1. Exact engine with a compatibility adapter — selected

Retire the duplicate `Partial.lean` engine and rewrite `Api.lean` to decode
into, assess with, and encode from the exact branch's public types.

This keeps the proved semantics, retains the demo, and creates one source of
truth. The cost is a deliberate adapter for the existing six-row wire format.

### 2. Keep both engines under different namespaces — rejected

Renaming `main`'s implementation would avoid declaration collisions, but the
repository would expose two evaluators with different valuation semantics,
error models, route cardinality, and proof guarantees. The demo could disagree
with the theorem-backed API while still calling itself the Lean
formalization.

### 3. Drop the JSON API and demo additions — rejected

Removing `Partial.lean`, `Api.lean`, `ApiMain.lean`, the `probate-api` target,
and `demo/` would make the Lean branch easy to merge, but it would discard the
two new features on `main`.

## Canonical Module Architecture

The merged public module order is:

```lean
import SimpleProbate.Date
import SimpleProbate.Thresholds
import SimpleProbate.Decision
import SimpleProbate.Estate
import SimpleProbate.Case
import SimpleProbate.Eligibility
import SimpleProbate.Procedure
import SimpleProbate.ProcedureAssessment
import SimpleProbate.Api
import SimpleProbate.Examples
```

`SimpleProbate.Partial` is removed. Partial route assessment is already
provided by `Decision`, `Estate`, `Case`, and `Eligibility`; partial packet
assessment is provided by `ProcedureAssessment`.

`SimpleProbate.Api` imports the exact assessment layer directly. Wire-only
types live in the `SimpleProbate.Api` namespace and use names such as
`WireRouteReport` when a separate representation is needed. They do not
redeclare public semantic types in `SimpleProbate`.

## Input Adapter

### Stable existing fields

The adapter continues to accept the existing demo fields, including:

- `gross_value_cents`;
- `target_index`;
- optional booleans and enums, where absent or `null` means unknown; and
- the existing authority, survivor, kind, and treatment strings.

Invalid JSON types, negative money, unknown enum strings, missing required
container fields, and an out-of-range `target_index` remain
`malformed_case` errors.

### Dual valuation fields

Each asset may additionally supply:

- `current_gross_value_cents`; and
- `date_of_death_value_cents`.

Resolution is field-specific:

```text
currentGrossValue =
  current_gross_value_cents if supplied,
  otherwise gross_value_cents,
  otherwise unknown

dateOfDeathValue =
  date_of_death_value_cents if supplied,
  otherwise gross_value_cents,
  otherwise unknown
```

The explicit field wins when both it and `gross_value_cents` are present.
This is backward-compatible for existing cases while allowing the exact
valuation-time distinction to be represented.

### Identity and target conversion

Assets receive deterministic `AssetId` values equal to their zero-based array
indices. `target_index` is range-checked and converted to the corresponding
`targetId`.

The asset name remains required. Every optional semantic field becomes
`Knowledge.known value` or `Knowledge.unknown`. `inventory_complete` is
converted in the same way.

## Output Adapter

The exact engine reports eleven `SimplifiedRoute` values: seven direct
transfer bases and four court routes. The existing demo contract expects six
rows: one collapsed direct-transfer row, four court-route rows, and one
formal-probate/fallback row.

The adapter preserves the six-row contract in this stable order:

1. `direct_transfer`
2. `personal_property_affidavit`
3. `small_value_real_property_affidavit`
4. `primary_residence_petition`
5. `spousal_property_petition`
6. `formal_probate_or_other_procedure`

### Direct-transfer projection

The seven direct-basis reports are projected as follows:

- `qualifies` if any basis qualifies; `detail` lists the qualifying basis or
  bases in the exact engine's stable order;
- otherwise `needs_information` if any basis needs information, with stable,
  deduplicated mapped facts;
- otherwise `does_not_qualify` with one stable
  `no_direct_transfer_basis` reason.

### Court-route projection

Each court route maps one-for-one. Typed `EligibilityFailure` values become
stable wire reason IDs and text; typed `EligibilityFact` values become stable
JSON paths.

Failure IDs preserve the existing contract where it has an equivalent:

| Typed failure | Wire ID |
| --- | --- |
| direct basis absent | `no_direct_transfer_basis` |
| target not personal | `target_not_personal_property` |
| target not California real | `target_not_california_real_property` |
| target not counted | `target_not_counted` |
| target not primary residence | `target_not_primary_residence` |
| claimant not successor | `claimant_not_successor` |
| superior right exists | `superior_right_exists` |
| forty days not elapsed | `waiting_period_not_met` |
| six months not elapsed | `six_month_period_not_met` |
| blocked by proceeding | `blocked_by_pending_proceeding` |
| required debts unpaid | `debts_not_paid` |
| any route value over cap | `value_over_limit` |
| no spouse or partner | `no_surviving_spouse_or_partner` |
| property neither passes nor belongs | `property_not_community_or_survivor` |

Value-over-cap reason text includes both the computed lower bound/value and
the applicable cap.

Fact paths use the existing field names when no ambiguity is introduced.
Value facts use the exact field:

- `estate.assets[i].current_gross_value_cents`; or
- `estate.assets[i].date_of_death_value_cents`.

The demo fixtures and audit text are updated where they previously expected
`gross_value_cents` as the missing-fact output.

### Formal fallback projection

The formal-probate row is synthesized from `CaseAssessment.overall`:

- `formalProbateOrOtherProcedure` becomes a qualifying fallback row;
- `unresolved` becomes `needs_information` with the stable union of unresolved
  facts from the simplified routes; and
- `simplifiedRoutesAvailable` becomes `does_not_qualify`, because the fallback
  is not applicable while a simplified route qualifies.

The top-level verdict and reasoning are derived from the same exact overall
outcome. The adapter never computes fallback independently.

## Error Mapping

`CaseError.invalidDate` and `CaseError.afterSnapshot` retain their current wire
types and messages.

`CaseError.malformedCase issues` is encoded as `malformed_case`. Its detail is
a stable, human-readable rendering of the ordered `StructuralIssue` list.
Decode failures that occur before a `PartialTransferCase` exists also use
`malformed_case` with a path-specific message.

Errors have `null` verdict/overall and no route rows, matching the existing
contract.

## Demo Integration

The backend continues to invoke `lake exe probate-api`. The frontend and
Python schemas accept the two new optional value fields while retaining
`gross_value_cents`.

The source-view endpoint removes `SimpleProbate/Partial.lean` and adds the
exact modules in dependency order:

```text
Decision, Estate, Case, Eligibility, Procedure,
ProcedureAssessment, Api
```

Demo contract, product documentation, rules, and sample-case derivations must
describe the exact engine rather than the retired executable-only partial
layer. References to deferred theorem obligations are removed because the
proofs now exist.

## Merge Procedure

1. Fetch and merge `origin/main` into
   `feat/exact-partial-probate-api` with `--no-commit --no-ff`.
2. Resolve `SimpleProbate.lean` to the canonical import order.
3. Remove `SimpleProbate/Partial.lean`.
4. Port `SimpleProbate/Api.lean` and retain `ApiMain.lean` plus the
   `probate-api` Lake target.
5. Update demo schemas, source lists, contract prose, fixtures, and audit
   expectations.
6. Add focused Lean API examples for legacy input, dual values, invalid target
   index, direct-route collapse, fallback synthesis, and typed error encoding.
7. Verify all Lean modules, both executables, backend tests/type checks, and
   frontend build.
8. Commit the merge, push the feature branch, and confirm PR #1 is conflict
   free.

## Testing and Acceptance Criteria

### Lean

- `lake build` succeeds with both executables.
- The existing 38-job exact-proof suite remains green.
- `probate-api` accepts every existing sample case.
- A legacy single-value asset populates both exact valuation fields.
- Explicit current and date-of-death fields override the legacy field
  independently.
- Unknown values remain unknown and produce the correct typed-field wire path.
- Out-of-range `target_index` produces `malformed_case`.
- Seven direct-basis reports collapse deterministically to one wire row.
- The fallback wire row is derived only from the proved overall outcome.
- No `sorry`, `admit`, `axiom`, or `unsafe` is introduced.

### Demo/backend

- Python schema validation accepts legacy and dual-value assets.
- The Lean subprocess returns the documented six-row response.
- Existing sample cases retain their expected top-level verdicts.
- The source endpoint lists existing files only and includes the exact proof
  modules.

### Frontend

- TypeScript compiles.
- Existing samples render.
- Editing a legacy gross value still works.
- Dual valuation fields, when present, survive editor round-trips.

### Git/PR

- `git diff --check` is clean.
- The merge commit contains both the exact engine and the demo/API additions.
- PR #1 reports no merge conflicts and its description explains the canonical
  engine and compatibility adapter.

## Non-Goals

- No second semantic evaluator is retained.
- The wire response is not expanded to eleven route rows in this merge.
- Packet readiness is not added to the demo response.
- No post-2026 legal thresholds or sources are introduced.
- No new external runtime dependency is added to the Lean project.
