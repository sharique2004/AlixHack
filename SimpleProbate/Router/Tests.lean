import SimpleProbate.Router.Encode

/-!
# Compile-time regressions

Every example in this file is checked by the kernel on every build. They are
`example`s rather than a test binary for the same reason the rest of the
repository is: a rule that can be broken without the build going red is not a
rule.

Coverage: each classification rule including all four beneficiary traps,
`counts_toward`, the probate-estate total, unknown propagation into the cap
test (an unknown title must *block* the cap test, not default it either way),
the insolvency and slayer flags, deadline computation, structural errors, and
the contract §6 canonical fixture end to end.
-/

namespace SimpleProbate
namespace Router
namespace Tests

open Lean (Json)

/-! ## Per-asset classification

Each example is one asset put through `classifyAsset` in a California case. -/

private def classify (a : IntakeAsset) : AssetClassification :=
  classifyAsset (some "CA") 0 a

private def bankAccount : IntakeAsset :=
  { name := "account", kind := some .bank, situsState := some "CA",
    grossValueCents := some 500000 }

private def retirementAccount : IntakeAsset :=
  { name := "401(k)", kind := some .retirement, situsState := some "CA",
    grossValueCents := some 31000000 }

private def parcel : IntakeAsset :=
  { name := "12 Oak St", kind := some .realProperty, situsState := some "CA",
    grossValueCents := some 62000000 }

-- Survivorship and trust forms are non-probate whatever else is true of them.
example :
    (classify { bankAccount with titleForm := some .jtwros }).classification =
      .nonProbate := by decide

example :
    (classify { bankAccount with titleForm := some .jtwros }).basis =
      some .jtwrosSurvivorship := by decide

example :
    (classify { parcel with titleForm := some .tenancyByEntirety }).classification =
      .nonProbate := by decide

example :
    (classify { parcel with titleForm := some .communityWithRos }).basis =
      some .communityPropertyRos := by decide

example :
    (classify { parcel with titleForm := some .trustFunded }).basis =
      some .trustFunded := by decide

-- Survivorship title beats a designation naming the estate: the asset never
-- reaches the estate for the designation to operate on.
example :
    (classify { bankAccount with
      titleForm := some .jtwros
      beneficiaryDesignation := some .estate }).classification =
      .nonProbate := by decide

-- A living named beneficiary takes outside probate. On a deposit or
-- securities account the basis is the POD/TOD registration; on a plan or
-- policy it is the contract designation.
example :
    (classify { bankAccount with
      titleForm := some .sole
      beneficiaryDesignation := some .namedLiving }).basis = some .podTod := by
  decide

example :
    (classify { retirementAccount with
      titleForm := some .sole
      beneficiaryDesignation := some .namedLiving }).basis =
      some .beneficiaryDesignation := by decide

-- TRAP 1 — the beneficiary predeceased the decedent. The designation lapses
-- and the asset falls back into the probate estate.
example :
    (classify { retirementAccount with
      titleForm := some .sole
      beneficiaryDesignation := some .namedPredeceased }).classification =
      .probate := by decide

example :
    (classify { retirementAccount with
      titleForm := some .sole
      beneficiaryDesignation := some .namedPredeceased }).basis =
      some .beneficiaryPredeceasedFallsToEstate := by decide

-- TRAP 2 — the estate is the named beneficiary.
example :
    (classify { retirementAccount with
      titleForm := some .sole
      beneficiaryDesignation := some .estate }).basis =
      some .designationToEstate := by decide

example :
    (classify { retirementAccount with
      beneficiaryDesignation := some .estate }).classification = .probate := by
  decide

-- TRAP 3 — no designation on an account type that normally carries one. The
-- account is payable to the estate, even though its title form is unknown.
example :
    (classify { bankAccount with
      beneficiaryDesignation := some BeneficiaryDesignation.none }).classification =
      .probate := by decide

example :
    (classify { bankAccount with
      beneficiaryDesignation := some BeneficiaryDesignation.none }).basis =
      some .soleNameNoDesignation := by decide

-- Sole title with no designation is the ordinary probate asset. A vehicle
-- does not normally carry a designation, so its absence settles nothing on
-- its own and title decides.
example :
    (classify { name := "car", kind := some .vehicle, situsState := some "CA",
                grossValueCents := some 1800000,
                titleForm := some .sole }).classification = .probate := by decide

-- Tenants in common: no survivorship, so the decedent's fractional share is
-- probate.
example :
    (classify { parcel with titleForm := some .tenantsInCommon }).classification =
      .probate := by decide

-- Custodial property belongs to the minor, not to the decedent.
example :
    (classify { bankAccount with titleForm := some .custodial }).classification =
      .nonProbate := by decide

-- TRAP 4 — nothing is guessed. An unknown title, an unknown designation on an
-- account that needs one, and "unsure" all produce `unknown` plus the exact
-- paths that would settle it.
example :
    (classify bankAccount).classification = .unknown := by decide

example :
    (classify bankAccount).missingFacts =
      ["assets[0].title_form", "assets[0].beneficiary_designation"] := by decide

example :
    (classify { retirementAccount with
      titleForm := some .sole
      beneficiaryDesignation := some .unsure }).missingFacts =
      ["assets[0].beneficiary_designation"] := by decide

example :
    (classify { parcel with titleForm := Option.none }).missingFacts =
      ["assets[0].title_form"] := by decide

example :
    (classify { name := "mystery", grossValueCents := some 100 }).missingFacts =
      ["assets[0].title_form", "assets[0].kind"] := by decide

-- Real property with an unknown situs cannot be valued under any route.
example :
    (classify { name := "land", kind := some .realProperty,
                titleForm := some .sole }).missingFacts =
      ["assets[0].situs_state"] := by decide

-- Every legal conclusion carries a citation; `unknown` is not a conclusion
-- and carries none.
example : (classify { bankAccount with titleForm := some .jtwros }).citation.isSome = true := by
  decide

example : (classify bankAccount).citation.isNone = true := by decide

-- Citations are California-specific, so they are withheld for other domiciles
-- while the plain-English rule still applies.
example :
    (classifyAsset (some "TX") 0 { bankAccount with titleForm := some .jtwros }).citation.isNone =
      true := by decide

example :
    (classifyAsset (some "TX") 0 { bankAccount with titleForm := some .jtwros }).classification =
      .nonProbate := by decide

/-! ## `counts_toward`

A California parcel counts toward the §13100 cap (which measures the
decedent's California real *and* personal property) as well as the two real
property routes. Out-of-state realty counts toward nothing, and a non-probate
asset counts toward nothing at all. -/

example :
    (classify { parcel with titleForm := some .sole, isPrimaryResidence := some true }).countsToward =
      ["ca_personal_property_affidavit", "ca_small_value_real_property_affidavit",
       "ca_primary_residence_petition"] := by decide

example :
    (classify { parcel with titleForm := some .sole, situsState := some "OR" }).countsToward =
      [] := by decide

example :
    (classify { bankAccount with titleForm := some .jtwros }).countsToward = [] := by
  decide

example :
    (classify { bankAccount with
      beneficiaryDesignation := some BeneficiaryDesignation.none }).countsToward =
      ["ca_personal_property_affidavit"] := by decide

/-! ## The canonical fixture — CONTRACT-SETTLEMENT.md §6

CA domicile, died 2026-03-04 (natural), married, valid original will.
Home $620k JTWROS; Schwab brokerage $141k sole with no TOD; 401(k) $310k with
the surviving spouse named; car $18k sole; savings of unknown title. -/

def fixtureHome : IntakeAsset :=
  { name := "Primary residence — 12 Oak St"
    kind := some .realProperty, situsState := some "CA"
    grossValueCents := some 62000000, encumbranceCents := some 41000000
    titleForm := some .jtwros, isPrimaryResidence := some true }

def fixtureBrokerage : IntakeAsset :=
  { name := "Schwab brokerage"
    kind := some .brokerage, situsState := some "CA"
    grossValueCents := some 14100000
    titleForm := some .sole
    beneficiaryDesignation := some BeneficiaryDesignation.none }

def fixtureRetirement : IntakeAsset :=
  { name := "401(k)"
    kind := some .retirement, situsState := some "CA"
    grossValueCents := some 31000000
    titleForm := some .sole
    beneficiaryDesignation := some .namedLiving }

def fixtureCar : IntakeAsset :=
  { name := "2019 Toyota Camry"
    kind := some .vehicle, situsState := some "CA"
    grossValueCents := some 1800000
    titleForm := some .sole }

/-- The savings account whose title form the caller has not supplied. -/
def fixtureSavings : IntakeAsset :=
  { name := "Savings account"
    kind := some .bank, situsState := some "CA"
    grossValueCents := some 950000 }

def fixtureCase : IntakeCase := {
  asOfDate := ⟨2026, 8, 12⟩
  decedent := {
    deathDate := some ⟨2026, 3, 4⟩
    domicileState := some "CA"
    maritalStatus := some .married
    survivingSpouse := some true
    mannerOfDeath := some .natural
    deathCertificateFinal := some true
    willStatus := some .validOriginal
    employmentRelatedDeath := some false
    thirdPartyFaultSuspected := some false
    relatedDeathWithin120h := some false
    receivedMedicaidLtc := some false
    veteran := some false
    pendingLitigation := some false
    -- §2.1. CONTRACT §6 states the federal outcome but not the facts behind
    -- it; the engine assumes neither, so the fixture supplies them: the
    -- spouse files an original joint return, and the decedent died insured.
    refundClaimant := some .survivingSpouseJointReturn
    finalReturnKind := some .original
    ssaInsuredAtDeath := some true
  }
  assets := [fixtureHome, fixtureBrokerage, fixtureRetirement, fixtureCar, fixtureSavings]
  debts := [
    { kind := some .mortgage, amountCents := some 41000000
      securedByAsset := some "Primary residence — 12 Oak St" }
  ]
  heirs := [
    { relationship := some .spouse, name := some "Surviving spouse", age := some 61
      receivesMeansTestedBenefits := some false, isSuspectInDeath := some false
      disclaimed := some false
      livedInSameHouseholdAtDeath := some true
      entitledToSpouseBenefitsMonthOfDeath := some false
      entitledToChildBenefitsMonthOfDeath := some false }
  ]
  conflictSignals := some false
  inventoryComplete := Option.none
  heirsComplete := some true
}

private def fixture : Option SettlementAssessment := (assess fixtureCase).toOption

private def classificationNamed (name : String) : Option Classification :=
  fixture.bind fun a => (findAsset a.assetMap name).map (·.classification)

-- Home → non-probate by survivorship; 401(k) → non-probate by designation.
example : classificationNamed "Primary residence — 12 Oak St" = some .nonProbate := by
  decide

example : classificationNamed "401(k)" = some .nonProbate := by decide

-- Brokerage and car → probate.
example : classificationNamed "Schwab brokerage" = some .probate := by decide

example : classificationNamed "2019 Toyota Camry" = some .probate := by decide

-- Savings → unknown, and it is the thing blocking the cap test.
example : classificationNamed "Savings account" = some .unknown := by decide

-- $159,000 known probate subtotal, reported as partial.
example :
    fixture.map (·.probateEstate.knownSubtotalCents) = some 15900000 := by decide

example : fixture.map (·.probateEstate.status) = some .partiallyKnown := by decide

-- California verdict INCOMPLETE_INFO.
example :
    fixture.bind (fun a => (jurisdictionOf a "CA").map (·.verdict)) =
      some .incompleteInfo := by decide

-- Personal-property affidavit needs information, and names exactly the facts
-- that would resolve it.
example :
    fixture.bind (fun a => routeStatusOf a "CA" "ca_personal_property_affidavit") =
      some .needsInformation := by decide

example :
    fixture.bind (fun a => routeMissingOf a "CA" "ca_personal_property_affidavit") =
      some ["assets[4].title_form", "assets[4].beneficiary_designation",
            "inventory_complete"] := by decide

-- Spousal property petition qualifies for the community share.
example :
    fixture.bind (fun a => routeStatusOf a "CA" "ca_spousal_property_petition") =
      some .qualifies := by decide

-- Nothing rises to critical on these facts.
example : fixture.map (fun a => a.flags.any fun f => f.severity == .critical) = some false := by
  decide

-- Final Form 1040 due 2027-04-15, computed.
example :
    fixture.bind (fun a => deadlineDateOf a "final_form_1040") = some ⟨2027, 4, 15⟩ := by
  decide

example :
    fixture.bind (fun a => deadlineStatusOf a "final_form_1040") = some .computed := by
  decide

-- The creditor window has no date because letters have not issued. A date
-- here would be an invented one.
example :
    fixture.bind (fun a => deadlineStatusOf a "ca_creditor_claim_window") =
      some .awaitingEvent := by decide

example :
    fixture.bind (fun a => deadlineDateOf a "ca_creditor_claim_window") = Option.none := by
  decide

-- `unresolved_facts` is the deduplicated union of every unknown in the
-- response — this list is what the product asks its next question from.
example :
    fixture.map (·.unresolvedFacts) =
      some ["assets[4].title_form", "assets[4].beneficiary_designation",
            "inventory_complete"] := by decide

/-! ## Unknown propagation

An unknown title blocks the cap test rather than defaulting it. Supplying the
one missing fact — and confirming the inventory — is what lets the same case
qualify. -/

private def completedCase : IntakeCase :=
  { fixtureCase with
    assets := [
      fixtureHome, fixtureBrokerage, fixtureRetirement, fixtureCar,
      { fixtureSavings with
        titleForm := some .sole
        beneficiaryDesignation := some BeneficiaryDesignation.none }
    ]
    inventoryComplete := some true }

example :
    (assess completedCase).toOption.bind
      (fun a => routeStatusOf a "CA" "ca_personal_property_affidavit") =
      some .qualifies := by decide

example :
    (assess completedCase).toOption.map (·.probateEstate.status) = some .known := by
  decide

example :
    (assess completedCase).toOption.map (·.probateEstate.knownSubtotalCents) =
      some 16850000 := by decide

example :
    (assess completedCase).toOption.map (·.unresolvedFacts) = some [] := by decide

-- Known violation still beats unknown: a subtotal already over the cap
-- disqualifies the route even though another asset is unclassified.
private def overCapCase : IntakeCase :=
  { fixtureCase with
    assets := [
      { fixtureBrokerage with grossValueCents := some 30000000 },
      fixtureSavings
    ]
    debts := [] }

example :
    (assess overCapCase).toOption.bind
      (fun a => routeStatusOf a "CA" "ca_personal_property_affidavit") =
      some .doesNotQualify := by decide

/-! ## Flags -/

private def flagsOfCase (c : IntakeCase) : List String :=
  match (assess c).toOption with
  | some a => flagIds a
  | none => ["<error>"]

private def severityOfCase (c : IntakeCase) (id : String) : Option Severity :=
  (assess c).toOption.bind fun a => flagSeverityOf a id

-- Slayer rule: homicide fires it, and so does a suspect heir.
example :
    (flagsOfCase { fixtureCase with
      decedent := { fixtureCase.decedent with mannerOfDeath := some .homicide } }).contains
      "slayer_rule_screen" = true := by decide

example :
    severityOfCase
      { fixtureCase with
        decedent := { fixtureCase.decedent with mannerOfDeath := some .homicide } }
      "slayer_rule_screen" = some .critical := by decide

example :
    (flagsOfCase { fixtureCase with
      heirs := [{ relationship := some .child, isSuspectInDeath := some true }] }).contains
      "slayer_rule_screen" = true := by decide

-- An unknown manner of death is not a slayer screen. `critical` never fires
-- on an unknown.
example :
    (flagsOfCase { fixtureCase with
      decedent := { fixtureCase.decedent with mannerOfDeath := Option.none } }).contains
      "slayer_rule_screen" = false := by decide

example : flagsOfCase fixtureCase = [] := by decide

-- Insolvency. With a complete inventory and debts above the probate estate
-- the finding is critical; with the inventory still open the same arithmetic
-- is only a warning, because further assets may yet close the gap.
private def insolventCase : IntakeCase :=
  { completedCase with
    debts := [
      { kind := some .medical, amountCents := some 20000000 },
      { kind := some .creditCard, amountCents := some 500000 }
    ] }

example : (flagsOfCase insolventCase).contains "insolvent_estate" = true := by decide

example : severityOfCase insolventCase "insolvent_estate" = some .critical := by decide

example :
    severityOfCase { insolventCase with inventoryComplete := Option.none }
      "insolvent_estate" = some .warning := by decide

-- A mortgage secured by an asset that passes outside probate is not a debt of
-- the probate estate, and must not manufacture insolvency.
example : (flagsOfCase completedCase).contains "insolvent_estate" = false := by decide

-- Ancillary probate: a parcel outside the domicile state.
private def ancillaryCase : IntakeCase :=
  { fixtureCase with
    assets := fixtureCase.assets ++
      [{ name := "Cabin", kind := some .realProperty, situsState := some "OR",
         grossValueCents := some 25000000, titleForm := some .sole }] }

example : (flagsOfCase ancillaryCase).contains "ancillary_probate_required" = true := by
  decide

example :
    (assess ancillaryCase).toOption.bind (fun a => (jurisdictionOf a "OR").map (·.role)) =
      some .ancillary := by decide

-- Other referral screens fire on the facts that trigger them.
example :
    (flagsOfCase { fixtureCase with
      decedent := { fixtureCase.decedent with willStatus := some .copyOnly } }).contains
      "will_copy_only" = true := by decide

example :
    (flagsOfCase { fixtureCase with
      heirs := [{ relationship := some .child, age := some 9 }] }).contains
      "minor_beneficiary" = true := by decide

example :
    severityOfCase
      { fixtureCase with
        heirs := [{ relationship := some .child, receivesMeansTestedBenefits := some true }] }
      "special_needs_beneficiary" = some .critical := by decide

example :
    (flagsOfCase { fixtureCase with
      decedent := { fixtureCase.decedent with thirdPartyFaultSuspected := some true } }).contains
      "wrongful_death_vs_survival_claim" = true := by decide

example :
    (flagsOfCase { fixtureCase with
      decedent := { fixtureCase.decedent with relatedDeathWithin120h := some true } }).contains
      "simultaneous_death_120h" = true := by decide

example :
    (flagsOfCase { fixtureCase with
      decedent := { fixtureCase.decedent with deathCertificateFinal := some false } }).contains
      "pending_death_certificate" = true := by decide

/-! ## Structural errors are never legal conclusions -/

private def errorCode (c : IntakeCase) : Option String :=
  match assess c with
  | .error e => some e.code
  | .ok _ => none

example :
    errorCode { fixtureCase with
      decedent := { fixtureCase.decedent with deathDate := some ⟨2027, 1, 2⟩ } } =
      some "after_snapshot" := by decide

example :
    assess { fixtureCase with
      decedent := { fixtureCase.decedent with deathDate := some ⟨2027, 1, 2⟩ } } =
      .error ⟨"after_snapshot",
        "death_date 2027-01-02 is after the source snapshot (2026-12-31)."⟩ := by
  decide

example :
    errorCode { fixtureCase with
      decedent := { fixtureCase.decedent with deathDate := some ⟨2026, 2, 29⟩ } } =
      some "invalid_date" := by decide

-- A death after the as-of date is a malformed case, not a verdict.
example :
    errorCode { fixtureCase with asOfDate := ⟨2026, 1, 1⟩ } = some "malformed_case" := by
  decide

-- Asset names identify assets, so they must be unique.
example :
    errorCode { fixtureCase with
      assets := [fixtureBrokerage, fixtureBrokerage] } =
      some "malformed_case" := by decide

/-! ## The federal array

The two federal rows come from `SimpleProbate.Fed` through
`SimpleProbate.Router.Federal`. These examples pin the join, not the federal
rules themselves — those carry their own 92 regressions and their soundness
proofs over all 2 592 partial-fact/completion pairs. -/

private def federalStatuses (c : IntakeCase) : List (String × FederalStatus) :=
  match assess c with
  | .ok a => a.federal.map fun f => (f.item, f.status)
  | .error _ => []

-- CONTRACT §6: Form 1310 not required (surviving spouse filing an original
-- joint return); lump-sum death payment payable to the surviving spouse, $255.
example :
    federalStatuses fixtureCase =
      [("irs_form_1310", .notRequired),
       ("ssa_lump_sum_death_payment", .payable)] := by decide

example :
    fixture.bind (fun a =>
      (a.federal.find? fun f => f.item == "ssa_lump_sum_death_payment").map
        (fun f => (f.payee, f.amountCents))) =
      some (some "surviving_spouse", some 25500) := by decide

-- Doctrine 1 across the seam: strip the federal facts and both rows ask for
-- them by name rather than concluding anything.
private def noFederalFactsCase : IntakeCase :=
  { fixtureCase with
    decedent := { fixtureCase.decedent with
      refundClaimant := Option.none
      finalReturnKind := Option.none
      ssaInsuredAtDeath := Option.none } }

example :
    federalStatuses noFederalFactsCase =
      [("irs_form_1310", .needsInformation),
       ("ssa_lump_sum_death_payment", .needsInformation)] := by decide

-- …and those questions reach `unresolved_facts`, which is where the product
-- reads its next question from.
example :
    (assess noFederalFactsCase).toOption.map (fun a =>
      a.unresolvedFacts.contains "decedent.ssa_insured_at_death") = some true := by
  decide

/-! ## Florida — the date-of-death band

Two cases identical apart from `decedent.death_date`. The estate is $120,000
of Florida personalty; Fla. Stat. §735.201(2) capped summary administration at
$75,000 for deaths before 2026-07-01 and at $150,000 on or after (CS/HB 1337,
signed 2026-04-29). Nothing else changes, and the answer changes completely.

The car's `exempt_from_creditors` is deliberately left unknown, so this pair
also pins the two-sided bound: the June case is disqualified on the *lower*
bound (the two accounts alone exceed $75,000) and the July case qualifies on
the *upper* bound ($120,000 ≤ $150,000), so the unknown exemption never has to
be resolved in either direction. -/

private def flChecking : IntakeAsset :=
  { name := "Truist checking account", kind := some .bank, situsState := some "FL"
    grossValueCents := some 4500000, encumbranceCents := some 0
    titleForm := some .sole, beneficiaryDesignation := some BeneficiaryDesignation.none
    isPrimaryResidence := some false, exemptFromCreditors := some false }

private def flBrokerage : IntakeAsset :=
  { name := "Vanguard brokerage account", kind := some .brokerage
    situsState := some "FL", grossValueCents := some 6000000
    encumbranceCents := some 0, titleForm := some .sole
    beneficiaryDesignation := some BeneficiaryDesignation.none
    isPrimaryResidence := some false, exemptFromCreditors := some false }

private def flCar : IntakeAsset :=
  { name := "2021 Honda CR-V", kind := some .vehicle, situsState := some "FL"
    grossValueCents := some 1500000, encumbranceCents := some 0
    titleForm := some .sole, beneficiaryDesignation := some BeneficiaryDesignation.none
    isPrimaryResidence := some false }

private def flCase (deathDate : CivilDate) : IntakeCase := {
  asOfDate := ⟨2026, 8, 12⟩
  decedent := {
    deathDate := some deathDate
    domicileState := some "FL"
    maritalStatus := some .widowed
    survivingSpouse := some false
    mannerOfDeath := some .natural
    deathCertificateFinal := some true
    willStatus := some .validOriginal
    employmentRelatedDeath := some false
    thirdPartyFaultSuspected := some false
    relatedDeathWithin120h := some false
    receivedMedicaidLtc := some false
    veteran := some false
    pendingLitigation := some false
    willDirectsAdministration := some false
    administrationPending := some false
    federalRefundDue := some true
    refundClaimant := some .otherClaimant
    finalReturnKind := some .original
    ssaInsuredAtDeath := some true
  }
  assets := [flChecking, flBrokerage, flCar]
  heirs := [
    { relationship := some .child, name := some "Alicia Navarro", age := some 41
      disclaimed := some false, livedInSameHouseholdAtDeath := some false
      entitledToSpouseBenefitsMonthOfDeath := some false
      entitledToChildBenefitsMonthOfDeath := some false }
  ]
  conflictSignals := some false
  inventoryComplete := some true
  heirsComplete := some true
  expenses := { preferredFuneralCents := some 950000
                lastIllnessMedicalCents := some 240000 }
}

private def flJune := flCase ⟨2026, 6, 30⟩
private def flJuly := flCase ⟨2026, 7, 1⟩

-- The cases differ in exactly one field.
example : flJuly = { flJune with
    decedent := { flJune.decedent with deathDate := some ⟨2026, 7, 1⟩ } } := by decide

private def flStatus (c : IntakeCase) (route : String) : Option RowStatus :=
  (assess c).toOption.bind fun a => routeStatusOf a "FL" route

private def flVerdict (c : IntakeCase) : Option Verdict :=
  (assess c).toOption.bind fun a => (jurisdictionOf a "FL").map (·.verdict)

-- 2026-06-30: $105,000 of known non-exempt personalty already exceeds the
-- $75,000 band, and the decedent has not been dead two years.
example : flStatus flJune "fl_summary_administration" = some .doesNotQualify := by
  decide

example : flStatus flJune "fl_formal_administration" = some .qualifies := by decide

example : flVerdict flJune = some .otherFormRequired := by decide

-- 2026-07-01: the whole $120,000 sits under the $150,000 band.
example : flStatus flJuly "fl_summary_administration" = some .qualifies := by decide

example : flStatus flJuly "fl_formal_administration" = some .doesNotQualify := by
  decide

example : flVerdict flJuly = some .eligible := by decide

-- Neither case is left with an open question — the contrast is a legal
-- conclusion on both sides, not one verdict and one shrug.
example : (assess flJune).toOption.map (·.unresolvedFacts) = some [] := by decide

example : (assess flJuly).toOption.map (·.unresolvedFacts) = some [] := by decide

-- The jurisdiction is reported as the domicile, with Florida's route ids.
example :
    (assess flJuly).toOption.bind (fun a => (jurisdictionOf a "FL").map fun j =>
      (j.role, j.routes.map (·.route))) =
      some (.domicile,
        ["fl_disposition_without_administration", "fl_summary_administration",
         "fl_formal_administration"]) := by decide

-- Florida real property owned by a California decedent produces an ancillary
-- Florida entry with real routes, because §735.201 turns on where the
-- property sits, not on where the decedent lived.
private def flCondo : IntakeAsset :=
  { name := "Sarasota condo", kind := some .realProperty, situsState := some "FL"
    grossValueCents := some 22000000, titleForm := some .sole
    beneficiaryDesignation := some BeneficiaryDesignation.none
    isPrimaryResidence := some false, exemptFromCreditors := some false }

private def caWithFloridaCondo : IntakeCase :=
  { fixtureCase with
    assets := fixtureCase.assets ++ [flCondo]
    decedent := { fixtureCase.decedent with
      willDirectsAdministration := some false
      administrationPending := some false } }

example :
    (assess caWithFloridaCondo).toOption.bind (fun a =>
      (jurisdictionOf a "FL").map fun j => (j.role, j.routes.length)) =
      some (.ancillary, 3) := by decide

-- $220,000 of Florida real property is over both bands, so no simplified
-- Florida route is available for it whichever side of 2026-07-01 the death
-- falls on.
example :
    (assess caWithFloridaCondo).toOption.bind (fun a =>
      routeStatusOf a "FL" "fl_summary_administration") =
      some .doesNotQualify := by decide

-- The domicile entry is still California's, and it is still first.
example :
    (assess caWithFloridaCondo).toOption.map (fun a =>
      a.jurisdictions.map fun j => (j.code, j.role)) =
      some [("CA", .domicile), ("FL", .ancillary)] := by decide

/-! ## The fallback route is not a qualifying route

`ELIGIBLE` must never be the answer when the only route that qualifies is full
administration. This is the older `CheckResult` contract's rule too:
`SimpleProbate.Partial` computes `overall` over the five simplified routes and
`Api.verdictFor` maps `formal_probate_or_other_procedure` to
`OTHER_FORM_REQUIRED`. -/

example :
    verdictOf [{ route := "fl_summary_administration", label := "", status := .doesNotQualify,
                 reasons := [], missingFacts := [], forms := [], citations := [] },
               { route := "fl_formal_administration", label := "", status := .qualifies,
                 reasons := [], missingFacts := [], forms := [], citations := [] }] =
      .otherFormRequired := by decide

example :
    verdictOf [{ route := "ca_personal_property_affidavit", label := "", status := .qualifies,
                 reasons := [], missingFacts := [], forms := [], citations := [] },
               { route := "ca_formal_probate_or_other", label := "", status := .doesNotQualify,
                 reasons := [], missingFacts := [], forms := [], citations := [] }] =
      .eligible := by decide

/-! ## Decoding: absent ≡ null ≡ unknown, unknown enum ≡ malformed -/

private def dateJson : Json :=
  Json.mkObj [("year", Json.num 2026), ("month", Json.num 8), ("day", Json.num 12)]

private def caseJson (assetFields : List (String × Json)) : Json :=
  Json.mkObj [
    ("as_of_date", dateJson),
    ("assets", Json.arr #[Json.mkObj (("name", Json.str "a") :: assetFields)])
  ]

private def decodedTitle (assetFields : List (String × Json)) :
    Except String (Option TitleForm) :=
  (decodeIntakeCase (caseJson assetFields)).map fun c =>
    match c.assets with
    | a :: _ => a.titleForm
    | [] => Option.none

-- An explicit null and an absent key decode identically, and neither becomes
-- a value.
example : decodedTitle [("title_form", Json.null)] = .ok Option.none := by decide

example : decodedTitle [] = .ok Option.none := by decide

example : decodedTitle [("title_form", Json.str "jtwros")] = .ok (some .jtwros) := by
  decide

-- An unrecognised enum value is a structural error, not an unknown.
example : (decodedTitle [("title_form", Json.str "joint")]).toOption = Option.none := by
  decide

end Tests
end Router
end SimpleProbate
