# California Simple Transfer — Lean 4

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

Invalid dates and death dates after December 31, 2026 return an explicit
`DateError`; the model does not infer rules beyond its supported death-date
horizon. Its source-as-of date is July 28, 2026.

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
- `Eligibility`: states and decides candidate transfer routes.
- `Procedure`: checks route-specific packets and exposes ordered workflows.
- `Examples`: compile-checked boundary scenarios and regression theorems.

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
| `Asset.personalAffidavitValue` | Probate Code §§13050 and 13100 |
| `PersonalPropertyAffidavitEligible` | Probate Code §§13100–13101 |
| `SmallValueRealPropertyAffidavitEligible` | Probate Code §13200 and form DE-305 |
| `PrimaryResidencePetitionEligible` | Probate Code §§13150–13154 and forms DE-310/DE-315 |
| `SpousalPropertyPetitionEligible` | Probate Code §§13500 and 13650–13656; forms DE-221/DE-226 |
| packet readiness predicates | California Courts Self-Help Guide plus the cited Probate Code sections |

The source-as-of date and full URLs are recorded in
`docs/superpowers/specs/2026-07-28-california-simple-transfer-design.md`.
