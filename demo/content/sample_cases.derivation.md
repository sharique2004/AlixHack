# sample_cases.json — exact-engine execution notes

The expected top-level verdicts below were recorded by running every fixture
through `lake exe probate-api`. The adapter decodes the wire case into typed
exact facts and failures, and `Api.lean` projects its eleven exact route
reports to the six demo rows. The explanatory notes summarize that executed
result; they are not a second rule evaluator. Aggregation is a known failure
before an unknown fact before satisfaction; overall, any qualifying route wins,
then unresolved information, then the formal-procedure fallback.
Route abbreviations: DT direct_transfer, PPA personal_property_affidavit, SV
small_value_real_property_affidavit, PR primary_residence_petition, SP spousal_property_petition,
FP formal_probate_or_other_procedure. Caps in cents: PPA band1 16,625,000 / band2 18,450,000 /
band3 20,885,000; SV band3 6,962,500; PR band3 75,000,000. All cases: valid target_index ⇒
WellFormed holds (targetIsPartOfEstate := true).

Notable code facts used: `Estate.personalAffidavitValue` counts `counted` assets of ANY kind except
outside-CA real and included-in-petition; treatments other than counted/employment_compensation
contribute 0. `smallValueRealPropertyValue` sums counted CA-real only. `primaryResidenceValue` sums
counted CA-real primary-residence only. PR route has no no_superior_right conjunct; SP has no cap
and no wait; DT looks only at the TARGET's treatment.

The adapter preserves legacy-only fixtures but reports exact missing value facts
as `estate.assets[n].current_gross_value_cents` for current-value questions
and `estate.assets[n].date_of_death_value_cents` for date-at-death questions.

## 1. eligible-personal-affidavit → ELIGIBLE
- DT: target treatment counted ⇒ no basis ⇒ does_not_qualify.
- PPA: kind personal ✓, successor ✓, no_superior ✓, 444 ≥ 40 ✓, no_proceeding permits ✓,
  inventory known-true ✓, current value 5,200,000+3,000,000 = 8,200,000 ≤ 20,885,000 (band3) ⇒ **qualifies**.
- SV: target kind personal ≠ california_real ⇒ does_not_qualify.
- PR: target kind personal / not primary residence ⇒ does_not_qualify.
- SP: survivor_status none ⇒ does_not_qualify.
- FP: a simplified route qualifies ⇒ does_not_qualify.

## 2. eligible-direct-transfer → ELIGIBLE
- DT: target treatment joint_tenancy ⇒ basis joint_tenancy; date 2026-07-03 supported ⇒ **qualifies**
  (no wait, no cap — 25 days is irrelevant).
- PPA: target kind california_real ⇒ does_not_qualify (also 25 < 40).
- SV: target treatment joint_tenancy ≠ counted ⇒ does_not_qualify (also six_months false, debts unpaid).
- PR: treatment ≠ counted, not primary residence ⇒ does_not_qualify.
- SP: survivor none ⇒ does_not_qualify.
- FP: DT qualifies ⇒ does_not_qualify.
- Encumbrance 20,000,000 on the condo never affects anything (gross-value model).

## 3. eligible-multiple-routes → ELIGIBLE
- DT: target (savings) counted ⇒ does_not_qualify.
- PPA: kind personal ✓, 342 ≥ 40 ✓, successor/no_superior ✓, permits ✓, inventory ✓; value:
  spouse_passage asset contributes 0 ⇒ 6,500,000 ≤ 20,885,000 ⇒ **qualifies**.
- SV: target kind personal ⇒ does_not_qualify.
- PR: target kind personal ⇒ does_not_qualify.
- SP: survivor spouse ∧ property_passes_to_survivor ⇒ **qualifies**.
- FP: does_not_qualify. Two routes qualify simultaneously (nonexclusive routes).

## 4. needs-info-unknown-value → INCOMPLETE_INFO
- DT: target (Vanguard, counted) ⇒ does_not_qualify.
- PPA: all non-value conjuncts satisfied; assets[0] is counted with its current value unknown ⇒ total
  unknown; known subtotal 3,000,000 not over cap ⇒ **needs_information**
  (estate.assets[0].current_gross_value_cents).
- SV/PR: target kind personal ⇒ does_not_qualify (known violation beats the unknown value).
- SP: survivor none ⇒ does_not_qualify.
- FP: PPA unresolved, none qualifies ⇒ needs_information (fallback suppressed).

## 5. needs-info-unknown-death-date → INCOMPLETE_INFO
- death_date null = unknown, NOT an error (errors are only for known bad dates).
- DT: target counted ⇒ no basis, a known violation ⇒ does_not_qualify (beats unknown date).
- PPA: every other conjunct satisfied; SupportedDeathDate + threshold band unknown ⇒
  **needs_information** (death_date).
- SV: target kind personal ⇒ does_not_qualify.
- PR: target kind personal ⇒ does_not_qualify.
- SP: survivor none ⇒ does_not_qualify.
- FP: PPA unresolved ⇒ needs_information.

## 6. needs-info-inventory-not-confirmed → INCOMPLETE_INFO
- DT: target counted ⇒ does_not_qualify.
- PPA: known subtotal 9,000,000+800,000 = 9,800,000 ≤ 20,885,000, but inventory_complete null ⇒
  cannot QUALIFY (total could grow), not over cap ⇒ **needs_information** (estate.inventory_complete).
- SV/PR: target kind personal ⇒ does_not_qualify. SP: survivor none ⇒ does_not_qualify.
- FP: needs_information.

## 7. over-cap-despite-unknowns → OTHER_FORM_REQUIRED
- DT: target counted ⇒ does_not_qualify.
- PPA: known counted subtotal 15,000,000+9,000,000 = 24,000,000 > 20,885,000 (band3) ⇒ violated even
  though assets[2].current_gross_value_cents is unknown ⇒ **does_not_qualify** (violation beats unknown).
- SV: target kind personal ⇒ does_not_qualify. PR: same. SP: survivor none ⇒ does_not_qualify.
- FP: all five simplified routes conclusively does_not_qualify ⇒ **qualifies** ⇒ OTHER_FORM_REQUIRED.

## 8. too-soon-20-days → OTHER_FORM_REQUIRED
- DT: target counted ⇒ does_not_qualify.
- PPA: 20 < 40 ⇒ **does_not_qualify** (waiting_period_not_met); value 1,000,000 fine but irrelevant.
- SV: target kind personal ⇒ does_not_qualify (also six_months false, debts unpaid — all known).
- PR: target kind personal ⇒ does_not_qualify. SP: survivor none ⇒ does_not_qualify.
- FP: qualifies ⇒ OTHER_FORM_REQUIRED. All facts known, so nothing is unresolved.

## 9. eligible-primary-residence → ELIGIBLE
- DT: target counted ⇒ does_not_qualify.
- PPA: target kind california_real ⇒ does_not_qualify. (House is
  included_in_primary_residence_petition ⇒ contributes 0 to PPA value anyway; checking 2,000,000.)
- SV: target is counted CA-real ✓ but smallValueRealPropertyValue = 60,000,000 > 6,962,500 ⇒
  does_not_qualify.
- PR: kind CA-real ✓, counted ✓, is_primary_residence ✓, successor ✓, 408 ≥ 40 ✓, permits ✓,
  inventory ✓, primaryResidenceValue 60,000,000 ≤ 75,000,000 (band3, AB 2016) ⇒ **qualifies**.
  (Encumbrance 25,000,000 ignored; no superior-right conjunct on this route.)
- SP: survivor none ⇒ does_not_qualify. FP: does_not_qualify.

## 10. eligible-small-value-real-property → ELIGIBLE
- DT: target counted ⇒ does_not_qualify.
- PPA: target kind california_real ⇒ does_not_qualify. (Estate PPA value would be
  5,500,000+4,000,000 — counted CA-real counts — but the target-kind violation decides.)
- SV: kind CA-real ✓, counted ✓, successor ✓, no_superior ✓, six_months_elapsed ✓, permits ✓,
  debts paid ✓, inventory ✓, smallValueRealPropertyValue = 5,500,000 ≤ 6,962,500 (band3) ⇒
  **qualifies** (savings account is not CA-real, contributes 0).
- PR: is_primary_residence false ⇒ does_not_qualify.
- SP: survivor none ⇒ does_not_qualify. FP: does_not_qualify.

## 11. pre-2022-death-over-old-cap → OTHER_FORM_REQUIRED
- Death 2021-10-01 < 2022-04-01 ⇒ band beforeApr2022, PPA cap 16,625,000.
- DT: target counted ⇒ does_not_qualify.
- PPA: value 17,500,000 > 16,625,000 ⇒ **does_not_qualify** (would pass today's 20,885,000 cap —
  the band matters).
- SV/PR: target kind personal ⇒ does_not_qualify. SP: survivor none ⇒ does_not_qualify.
- FP: qualifies ⇒ OTHER_FORM_REQUIRED.

## 12. error-after-snapshot → ERROR
- classifyDeathDate ⟨2027,3,1⟩: valid but after snapshotEnd ⟨2026,12,31⟩ ⇒ DateError.afterSnapshot.
- Case error `after_snapshot`: top-level error object, verdict null. NOT one of the three verdicts;
  no route table is produced.
