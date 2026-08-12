import SimpleProbate.FL.Bands
import SimpleProbate.FL.Thresholds
import SimpleProbate.FL.Estate
import SimpleProbate.FL.Eligibility
import SimpleProbate.FL.Partial
import SimpleProbate.FL.Examples

/-!
# Florida module — public entry point

Import `SimpleProbate.FL.Assess` to get the whole Florida module. The Router
calls, in `SimpleProbate.FL`:

* `assessRoutes : PartialCase → Except CaseError Assessment` — the partial
  layer, and the only function the Router needs for a verdict.
* `routeStatus`, `verdictOf`, `unresolvedFactsOf` — accessors over that result.
* `RouteId.wireName`, `.label`, `.forms`, `.citations` — wire vocabulary.
* `AssetKind.ofWireName`, `TitleForm.ofWireName`,
  `BeneficiaryDesignation.ofWireName`, `WillStatus.ofWireName` — decoders from
  the contract's enum strings. Each returns `none` for a value that does not
  settle the question, which the partial layer treats as unknown.
* `thresholdsFor`, `classifyDeathDate`, `preferredFuneralExpenseCap` — the
  banded figures, if the Router wants to show them.
* `Case`, `candidateRoutes`, and the `*Eligible` predicates — the total layer
  the partial layer is measured against.

## Routes

| wire id | statute |
|---|---|
| `fl_disposition_without_administration` | Fla. Stat. §735.301, §735.304 |
| `fl_summary_administration` | Fla. Stat. §735.201 |
| `fl_formal_administration` | Fla. Stat. ch. 733 (fallback only) |

## Doctrine

Unknown is never false; a known violation beats an unknown; nothing beyond the
2026-12-31 source snapshot; every conclusion carries a citation; money is
integer cents throughout.

## Sources, all retrieved 2026-08-12

* Fla. Stat. §735.201 — summary administration (flsenate.gov)
* Fla. Stat. §735.301 — disposition without administration (flsenate.gov)
* Fla. Stat. §735.304 — disposition without administration of intestate
  property in small estates (flsenate.gov)
* Fla. Stat. §733.707(1)(b) — order of payment; preferred funeral expenses
  capped at $6,000 in the aggregate
* Fla. Stat. §732.402 — exempt property
* Fla. Const. art. X, §4(a)(1) — homestead exemption from creditors' claims
* CS/HB 1337 (2026) — signed 2026-04-29, effective 2026-07-01; raised the
  §735.201(2) ceiling from $75,000 to $150,000 and the §735.304 figure from
  $10,000 to $20,000
-/
