# AlixHack

## California Simple Transfer — Lean 4

This project formalizes the California Courts simple-transfer probate decision
process using law and official guidance available on July 28, 2026. It supports
death dates through December 31, 2026, computes candidate routes, and checks
typed eligibility and procedural-readiness predicates.

## Legal-model boundary

This is an educational formal model, not legal advice. Lean proves consequences
of supplied facts; it does not establish ownership, heirship, property value,
community-property character, primary-residence status, consent, notice,
document truth, or court acceptance. The fallback is deliberately named
`formalProbateOrOtherProcedure` because another procedure may apply.

Lower-level date and threshold APIs return an explicit `DateError` for invalid
dates and death dates after December 31, 2026. Assessment APIs instead return
`CaseError.invalidDate` or `CaseError.afterSnapshot`; the model does not infer
rules beyond its supported death-date horizon. Its source-as-of date is July
28, 2026.

## Build and inspect

```bash
lake build
lake env lean SimpleProbate/Examples.lean
lake exe simple-probate
```

## Modules

- `Date`: validates dates and enforces the December 31, 2026 supported
  death-date endpoint.
- `Thresholds`: contains the date-of-death threshold schedule in cents.
- `Estate`: applies section 13050 exclusions and gross-value aggregation.
- `Eligibility`: states, decides, and assesses complete or incomplete transfer
  cases.
- `Procedure`: checks route-specific packets and exposes ordered workflows.
- `ProcedureAssessment`: assesses incomplete, route-indexed court packets.
- `Examples`: compile-checked boundary scenarios and regression theorems.

## Exact partial-case API

The public entry point is:

```lean
assessRoutes : PartialTransferCase → Except CaseError CaseAssessment
```

It reports every `SimplifiedRoute` independently in `CaseAssessment.routes`,
including all direct-transfer bases and the four court routes.  A route status
is `qualifies` when all its checks are satisfied, `doesNotQualify reasons`
when a known failure prevents it, or `needsInformation facts` when no known
failure prevents it but more facts are required.  Known disqualification wins
over unknown facts; an unknown value is never converted to `false`.

`CaseAssessment.overall` is `simplifiedRoutesAvailable` if any route qualifies,
`unresolved` if none qualifies but at least one needs information, and
`formalProbateOrOtherProcedure` only when every simplified route is
disqualified.  Thus the fallback is not emitted for an unresolved case.

The following example is compile-checked in
`SimpleProbate/Examples/EligibilityAssessment.lean`:

```lean
example :
    (assessRoutes personalCase.toPartial).map (fun assessment =>
      assessment.routes.find? (fun report =>
        report.route == .personalPropertyAffidavit)) =
    .ok (some {
      route := .personalPropertyAffidavit
      status := .qualifies
    }) := by decide
```

### Migration from the removed partial API

`SimpleProbate.Partial` has been removed. Its public, executable-only model used
`Option` fields and duplicated eligibility logic; partial facts and route
decisions now live in the same exact model as the propositions and proofs.

| Previous API | Exact API | Migration |
| --- | --- | --- |
| `SimpleProbate.Partial` | `Decision`, `Estate`, `Case`, and `Eligibility` | Import the owning exact module instead of the removed aggregate module. |
| `Option`-valued `PartialAsset`, `PartialEstate`, and `PartialTransferCase` | `Knowledge`-valued partial types in `Estate` and `Case` | Replace `some x` with `.known x` and `none` with `.unknown`; completion relations now give those facts proof semantics. |
| `RouteStatus` | `DecisionStatus EligibilityFact EligibilityFailure` | Match on `qualifies`, `doesNotQualify`, or `needsInformation` with typed facts and failures. |
| String `FactPath` and `Disqualifier` | `EligibilityFact` and `EligibilityFailure` | Keep domain logic typed; `Api` alone projects facts and failures to stable wire strings. |
| `routeStatus` and `overallOf` helpers | exact `assessRoute` and `assessRoutes` | Use `assessRoutes` for the complete typed route table and overall result. |
| `Asset.grossValue` | `Asset.currentGrossValue` and `Asset.dateOfDeathValue` | Supply the current value for personal-property rules and the date-of-death value for real-property rules. |
| Positional `targetIndex` identity | deterministic `AssetId` and `TransferCase.targetId` | Assign stable asset IDs and select the target by ID in the Lean API; duplicate names are allowed. |
| `gross_value_cents` and `target_index` on JSON input | retained by the `Api` adapter | Existing wire clients remain compatible: the adapter generates deterministic IDs from asset positions, maps `target_index` to `targetId`, and uses `gross_value_cents` only as the fallback for an omitted or null explicit valuation field. |

`RouteEligible` now takes a `SimplifiedRoute`; callers that still need the old
`Route`-shaped predicate can use `LegacyRouteEligible`, with
`legacyRouteEligible_toRoute_iff` bridging non-fallback routes. The checked
`candidateRoutes` and `routeEligible` helpers now return `Except CaseError`
rather than `Except DateError`. The former one-way `candidateRoutes_sound`
contract is replaced by the membership equivalence `candidateRoutes_exact`.

### Valuation and errors

`PartialAsset` carries separate `currentGrossValue` and `dateOfDeathValue`
fields.  The personal-property affidavit valuation uses current gross value;
the small-real-property affidavit and primary-residence petition valuations
use date-of-death value.  The personal-property calculation aggregates all
qualifying employment compensation before applying its single statutory
exclusion, rather than applying the exclusion asset by asset.

Assessment returns typed `CaseError`s: `invalidDate`, `afterSnapshot`, or
`malformedCase issues`.  The last form reports structural problems such as
duplicate asset IDs, a missing target asset, or incompatible property facts.

### Dependent packet assessment

For court filings, use the dependent packet API:

```lean
assessPacket : (route : CourtRoute) → PartialProcedureContext →
  PartialTransferCase → PartialPacket route → Except CaseError ReadinessAssessment
```

`PartialPacket route` selects the packet structure appropriate to that
`CourtRoute`; `PartialProcedureContext` supplies facts shared by packet rules.
Each packet item is `present`, `absent`, or `unknown`.  `absent` is a known
missing requirement, while `unknown` is unresolved information; the API keeps
those outcomes distinct in its readiness assessment.

For the small-real-property packet, this model encodes the §13200(d) will
attachment rule as applicable only when `claimsUnderWill` is true and authority
is `.noProceeding`. Written personal-representative consent or
`.blockedByProceeding` does not trigger that attachment in the model.

### Proof contracts

For total cases, `assessRoute_ofTotal_qualifies_iff` and
`assessRoute_ofTotal_disqualified_iff` give positive and negative exactness
for each route; the disqualified theorem requires successful total-case
validation. `assessRoutes_ofTotal_fallback_iff` also requires successful
total-case validation and gives exact fallback semantics. For partial cases,
`assessRoute_qualifies_all_completions` proves that a qualifying route remains
eligible in every well-formed completion, while
`assessRoute_disqualified_no_completion` proves that a disqualified route has
no eligible well-formed completion. Packet contracts are
`assessPacket_ofTotal_ready_iff` (readiness iff for every `CourtRoute`) and
`assessPacket_ready_all_completions` (partial readiness sound when the context,
case, and route-indexed packet each satisfy their completion relation and the
total case is `WellFormed`). The four route-specific
`*Missing_empty_iff_ready` theorems connect total packet missing lists to
readiness.

## 2026 route limits

For deaths from April 1, 2025 through December 31, 2026:

- personal-property affidavit: $208,850;
- primary-residence petition: $750,000;
- small-value real-property affidavit: $69,625;
- employment-compensation exclusion: $20,875.

The spousal property petition has no value cap in this model.

## Source traceability

| Lean definition | Official source |
| --- | --- |
| `thresholdsFor`, `thresholdsForBand` | Probate Code §890 and Judicial Council form DE-300 |
| `Estate.personalAffidavitValue` | Probate Code §§13050 and 13100 |
| `PersonalPropertyAffidavitEligible` | Probate Code §§13100–13101 |
| `SmallValueRealPropertyAffidavitEligible` | Probate Code §13200 and form DE-305 |
| `PrimaryResidencePetitionEligible` | Probate Code §§13150–13154 and forms DE-310/DE-315 |
| `SpousalPropertyPetitionEligible` | Probate Code §§13500 and 13650–13656; forms DE-221/DE-226 |
| packet readiness predicates | California Courts Self-Help Guide plus the cited Probate Code sections |

The source-as-of date and full URLs are recorded in
`docs/superpowers/specs/2026-07-28-california-simple-transfer-design.md`.

## Interactive demo

`demo/` contains a web app that runs the same case through per-query Gemini
inference and through this formalization side by side — verdicts, per-route
status, latency, tokens, and cost. See [demo/README.md](demo/README.md) to run
it.
