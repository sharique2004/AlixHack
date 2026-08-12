import SimpleProbate.Api

/-!
# Intake model

Lean mirror of `IntakeCase` (CONTRACT-SETTLEMENT.md §2) and its tolerant JSON
decoder.

Every field except `as_of_date` and each asset's `name` is `Option`-valued:
an absent key and an explicit `null` both mean *unknown*, never `false` and
never zero. Structural problems — a non-integer or negative money value, a
string where an object belongs, an enum value outside the contract's list —
are `malformed_case` errors, never legal conclusions.

Decoding reuses `SimpleProbate.Api`'s helpers (`optField`, `asNat`, `asBool`,
`asString`) so that the two wire formats cannot drift apart in their treatment
of `null`.
-/

namespace SimpleProbate
namespace Router

open Lean (Json)

/-! ## Enumerations (contract §2) -/

inductive MannerOfDeath
  | natural | accident | suicide | homicide | pending | undetermined
deriving BEq, DecidableEq, Repr

inductive WillStatus
  | validOriginal | copyOnly | holographic | none | unsure
deriving BEq, DecidableEq, Repr

inductive MaritalStatus
  | married | single | widowed | divorced
deriving BEq, DecidableEq, Repr

inductive AssetKind
  | realProperty | bank | brokerage | retirement | lifeInsurance | vehicle
  | personal | business | digital | employmentComp | other
deriving BEq, DecidableEq, Repr

inductive TitleForm
  | sole | jtwros | tenancyByEntirety | communityWithRos | tenantsInCommon
  | trustFunded | custodial
deriving BEq, DecidableEq, Repr

inductive BeneficiaryDesignation
  | namedLiving | namedPredeceased | estate | none | unsure
deriving BEq, DecidableEq, Repr

inductive DebtKind
  | mortgage | creditCard | medical | tax | loan | funeral | other
deriving BEq, DecidableEq, Repr

inductive Relationship
  | spouse | child | parent | sibling | other
deriving BEq, DecidableEq, Repr

/-! ### Additive extension (contract §2.1)

The three modules behind this endpoint ask for facts the frozen §2 request did
not carry: Florida's routes turn on whether the will directs administration,
on whether an administration is already pending, on which assets are exempt
from creditors' claims, and on the funeral and last-illness expenses; the two
federal items turn on tax facts and on Social Security entitlement.

Every one of them is optional and defaults to unknown, so a §2 request decodes
exactly as it did before and simply receives `needs_information` on the rows
that need them. They are documented as §2.1 of `CONTRACT-SETTLEMENT.md`. -/

/-- `decedent.refund_claimant` — who is claiming the decedent's income-tax
refund. IRS Form 1310 instructions. -/
inductive RefundClaimant
  | survivingSpouseJointReturn | courtAppointedRepresentative | otherClaimant
deriving BEq, DecidableEq, Repr

/-- `decedent.final_return_kind` — whether the final return is an original or
an amended one. The court-certificate exception reaches only an original. -/
inductive FinalReturnKind
  | original | amended
deriving BEq, DecidableEq, Repr

/-! ## Fact paths

Every unknown reported anywhere in the response is a JSON path into the
`IntakeCase` the caller sent, so the product's UI can turn it directly into
the next question. These constructors are the only place those paths are
built. -/

def decedentPath (field : String) : FactPath := s!"decedent.{field}"
def assetPath (index : Nat) (field : String) : FactPath := s!"assets[{index}].{field}"
def heirPath (index : Nat) (field : String) : FactPath := s!"heirs[{index}].{field}"

/-! ## Structures -/

structure IntakeDecedent where
  deathDate : Option CivilDate := none
  domicileState : Option String := none
  maritalStatus : Option MaritalStatus := none
  survivingSpouse : Option Bool := none
  mannerOfDeath : Option MannerOfDeath := none
  deathCertificateFinal : Option Bool := none
  willStatus : Option WillStatus := none
  employmentRelatedDeath : Option Bool := none
  thirdPartyFaultSuspected : Option Bool := none
  relatedDeathWithin120h : Option Bool := none
  receivedMedicaidLtc : Option Bool := none
  veteran : Option Bool := none
  pendingLitigation : Option Bool := none
  -- §2.1 — Florida
  /-- `decedent.will_directs_administration` — Fla. Stat. §735.201(1). -/
  willDirectsAdministration : Option Bool := none
  /-- `decedent.administration_pending` — Fla. Stat. §735.304. -/
  administrationPending : Option Bool := none
  -- §2.1 — federal
  /-- `decedent.federal_refund_due`. -/
  federalRefundDue : Option Bool := none
  /-- `decedent.refund_claimant`. -/
  refundClaimant : Option RefundClaimant := none
  /-- `decedent.final_return_kind`. -/
  finalReturnKind : Option FinalReturnKind := none
  /-- `decedent.court_certificate_attached`. -/
  courtCertificateAttached : Option Bool := none
  /-- `decedent.ssa_insured_at_death` — fully *or* currently insured;
  42 U.S.C. §402(i) opens on the disjunction. -/
  ssaInsuredAtDeath : Option Bool := none
deriving DecidableEq, Repr

structure IntakeAsset where
  name : String
  kind : Option AssetKind := none
  situsState : Option String := none
  grossValueCents : Option Money := none
  encumbranceCents : Option Money := none
  titleForm : Option TitleForm := none
  beneficiaryDesignation : Option BeneficiaryDesignation := none
  isPrimaryResidence : Option Bool := none
  /-- §2.1 `assets[i].exempt_from_creditors` — stated exemption under
  Fla. Stat. §732.402. Protected homestead is derived, not stated. -/
  exemptFromCreditors : Option Bool := none
deriving DecidableEq, Repr

structure IntakeDebt where
  kind : Option DebtKind := none
  amountCents : Option Money := none
  securedByAsset : Option String := none
deriving DecidableEq, Repr

structure IntakeHeir where
  relationship : Option Relationship := none
  name : Option String := none
  age : Option Nat := none
  receivesMeansTestedBenefits : Option Bool := none
  isSuspectInDeath : Option Bool := none
  disclaimed : Option Bool := none
  -- §2.1 — Social Security lump-sum death payment, 42 U.S.C. §402(i)
  /-- `heirs[i].lived_in_same_household_at_death`. -/
  livedInSameHouseholdAtDeath : Option Bool := none
  /-- `heirs[i].entitled_to_spouse_benefits_month_of_death`. -/
  entitledToSpouseBenefitsMonthOfDeath : Option Bool := none
  /-- `heirs[i].entitled_to_child_benefits_month_of_death` — entitlement to
  child's insurance benefits under §402(d), which does not track the probate
  relationship label. Never inferred from `relationship`. -/
  entitledToChildBenefitsMonthOfDeath : Option Bool := none
deriving DecidableEq, Repr

/-- §2.1 `expenses` — Fla. Stat. §735.301's allowance is measured against
these two figures, so an absent one leaves the allowance unknown rather than
zero. Money is integer cents. -/
structure IntakeExpenses where
  preferredFuneralCents : Option Money := none
  lastIllnessMedicalCents : Option Money := none
deriving DecidableEq, Repr

structure IntakeCase where
  asOfDate : CivilDate
  decedent : IntakeDecedent := {}
  assets : List IntakeAsset := []
  debts : List IntakeDebt := []
  heirs : List IntakeHeir := []
  conflictSignals : Option Bool := none
  inventoryComplete : Option Bool := none
  /-- §2.1 `heirs_complete` — "is this list of people complete?". Gates every
  negative conclusion about who may claim, exactly as `inventory_complete`
  gates the valuation caps. -/
  heirsComplete : Option Bool := none
  /-- §2.1 `expenses`. -/
  expenses : IntakeExpenses := {}
deriving DecidableEq, Repr

/-! ## Enum parsing

An unrecognised enum string is a structural error (`malformed_case`); it is
never silently downgraded to "unknown", because a client that sends
`"title_form": "jtwros "` deserves to hear about it rather than to receive an
assessment built on a fact that was quietly dropped. -/

def parseMannerOfDeath (path s : String) : Except String MannerOfDeath :=
  match s with
  | "natural" => .ok .natural
  | "accident" => .ok .accident
  | "suicide" => .ok .suicide
  | "homicide" => .ok .homicide
  | "pending" => .ok .pending
  | "undetermined" => .ok .undetermined
  | _ => .error s!"{path}: unknown manner of death '{s}'"

def parseWillStatus (path s : String) : Except String WillStatus :=
  match s with
  | "valid_original" => .ok .validOriginal
  | "copy_only" => .ok .copyOnly
  | "holographic" => .ok .holographic
  | "none" => .ok WillStatus.none
  | "unsure" => .ok .unsure
  | _ => .error s!"{path}: unknown will status '{s}'"

def parseMaritalStatus (path s : String) : Except String MaritalStatus :=
  match s with
  | "married" => .ok .married
  | "single" => .ok .single
  | "widowed" => .ok .widowed
  | "divorced" => .ok .divorced
  | _ => .error s!"{path}: unknown marital status '{s}'"

def parseAssetKind (path s : String) : Except String AssetKind :=
  match s with
  | "real_property" => .ok .realProperty
  | "bank" => .ok .bank
  | "brokerage" => .ok .brokerage
  | "retirement" => .ok .retirement
  | "life_insurance" => .ok .lifeInsurance
  | "vehicle" => .ok .vehicle
  | "personal" => .ok .personal
  | "business" => .ok .business
  | "digital" => .ok .digital
  | "employment_comp" => .ok .employmentComp
  | "other" => .ok .other
  | _ => .error s!"{path}: unknown asset kind '{s}'"

def parseTitleForm (path s : String) : Except String TitleForm :=
  match s with
  | "sole" => .ok .sole
  | "jtwros" => .ok .jtwros
  | "tenancy_by_entirety" => .ok .tenancyByEntirety
  | "community_with_ros" => .ok .communityWithRos
  | "tenants_in_common" => .ok .tenantsInCommon
  | "trust_funded" => .ok .trustFunded
  | "custodial" => .ok .custodial
  | _ => .error s!"{path}: unknown title form '{s}'"

def parseBeneficiaryDesignation (path s : String) :
    Except String BeneficiaryDesignation :=
  match s with
  | "named_living" => .ok .namedLiving
  | "named_predeceased" => .ok .namedPredeceased
  | "estate" => .ok .estate
  | "none" => .ok BeneficiaryDesignation.none
  | "unsure" => .ok .unsure
  | _ => .error s!"{path}: unknown beneficiary designation '{s}'"

def parseDebtKind (path s : String) : Except String DebtKind :=
  match s with
  | "mortgage" => .ok .mortgage
  | "credit_card" => .ok .creditCard
  | "medical" => .ok .medical
  | "tax" => .ok .tax
  | "loan" => .ok .loan
  | "funeral" => .ok .funeral
  | "other" => .ok .other
  | _ => .error s!"{path}: unknown debt kind '{s}'"

def parseRefundClaimant (path s : String) : Except String RefundClaimant :=
  match s with
  | "surviving_spouse_joint_return" => .ok .survivingSpouseJointReturn
  | "court_appointed_representative" => .ok .courtAppointedRepresentative
  | "other" => .ok .otherClaimant
  | _ => .error s!"{path}: unknown refund claimant '{s}'"

def parseFinalReturnKind (path s : String) : Except String FinalReturnKind :=
  match s with
  | "original" => .ok .original
  | "amended" => .ok .amended
  | _ => .error s!"{path}: unknown final return kind '{s}'"

def parseRelationship (path s : String) : Except String Relationship :=
  match s with
  | "spouse" => .ok .spouse
  | "child" => .ok .child
  | "parent" => .ok .parent
  | "sibling" => .ok .sibling
  | "other" => .ok .other
  | _ => .error s!"{path}: unknown relationship '{s}'"

/-! ## Decoding -/

/-- Optional string-encoded enum field: absent ≡ null ≡ unknown, unrecognised
value ≡ structural error. -/
private def optEnumField {α : Type} (j : Json) (path key : String)
    (parse : String → String → Except String α) : Except String (Option α) :=
  match Api.optField j key with
  | none => .ok none
  | some value => do
    let s ← Api.asString s!"{path}{key}" value
    (parse s!"{path}{key}" s).map some

private def optStringField (j : Json) (path key : String) :
    Except String (Option String) :=
  match Api.optField j key with
  | none => .ok none
  | some value => (Api.asString s!"{path}{key}" value).map some

def decodeCivilDate (path : String) (j : Json) : Except String CivilDate := do
  let .obj _ := j | throw s!"{path} must be an object with year, month and day"
  let year ← match Api.optField j "year" with
    | some v => Api.asNat s!"{path}.year" v
    | none => throw s!"{path}.year is required"
  let month ← match Api.optField j "month" with
    | some v => Api.asNat s!"{path}.month" v
    | none => throw s!"{path}.month is required"
  let day ← match Api.optField j "day" with
    | some v => Api.asNat s!"{path}.day" v
    | none => throw s!"{path}.day is required"
  pure ⟨year, month, day⟩

def decodeDecedent (j : Json) : Except String IntakeDecedent := do
  let .obj _ := j | throw "decedent must be an object or null"
  let path := "decedent."
  let deathDate ← match Api.optField j "death_date" with
    | none => pure none
    | some v => (decodeCivilDate "decedent.death_date" v).map some
  pure {
    deathDate := deathDate
    domicileState := ← optStringField j path "domicile_state"
    maritalStatus := ← optEnumField j path "marital_status" parseMaritalStatus
    survivingSpouse := ← Api.optBoolField j path "surviving_spouse"
    mannerOfDeath := ← optEnumField j path "manner_of_death" parseMannerOfDeath
    deathCertificateFinal := ← Api.optBoolField j path "death_certificate_final"
    willStatus := ← optEnumField j path "will_status" parseWillStatus
    employmentRelatedDeath := ← Api.optBoolField j path "employment_related_death"
    thirdPartyFaultSuspected := ← Api.optBoolField j path "third_party_fault_suspected"
    relatedDeathWithin120h := ← Api.optBoolField j path "related_death_within_120h"
    receivedMedicaidLtc := ← Api.optBoolField j path "received_medicaid_ltc"
    veteran := ← Api.optBoolField j path "veteran"
    pendingLitigation := ← Api.optBoolField j path "pending_litigation"
    willDirectsAdministration :=
      ← Api.optBoolField j path "will_directs_administration"
    administrationPending := ← Api.optBoolField j path "administration_pending"
    federalRefundDue := ← Api.optBoolField j path "federal_refund_due"
    refundClaimant := ← optEnumField j path "refund_claimant" parseRefundClaimant
    finalReturnKind :=
      ← optEnumField j path "final_return_kind" parseFinalReturnKind
    courtCertificateAttached :=
      ← Api.optBoolField j path "court_certificate_attached"
    ssaInsuredAtDeath := ← Api.optBoolField j path "ssa_insured_at_death"
  }

def decodeIntakeAsset (index : Nat) (j : Json) : Except String IntakeAsset := do
  let path := s!"assets[{index}]."
  let .obj _ := j | throw s!"assets[{index}] must be an object"
  let name ← match Api.optField j "name" with
    | some v => Api.asString s!"{path}name" v
    | none => throw s!"{path}name is required"
  pure {
    name := name
    kind := ← optEnumField j path "kind" parseAssetKind
    situsState := ← optStringField j path "situs_state"
    grossValueCents := ← Api.optNatField j path "gross_value_cents"
    encumbranceCents := ← Api.optNatField j path "encumbrance_cents"
    titleForm := ← optEnumField j path "title_form" parseTitleForm
    beneficiaryDesignation :=
      ← optEnumField j path "beneficiary_designation" parseBeneficiaryDesignation
    isPrimaryResidence := ← Api.optBoolField j path "is_primary_residence"
    exemptFromCreditors := ← Api.optBoolField j path "exempt_from_creditors"
  }

def decodeIntakeDebt (index : Nat) (j : Json) : Except String IntakeDebt := do
  let path := s!"debts[{index}]."
  let .obj _ := j | throw s!"debts[{index}] must be an object"
  pure {
    kind := ← optEnumField j path "kind" parseDebtKind
    amountCents := ← Api.optNatField j path "amount_cents"
    securedByAsset := ← optStringField j path "secured_by_asset"
  }

def decodeIntakeHeir (index : Nat) (j : Json) : Except String IntakeHeir := do
  let path := s!"heirs[{index}]."
  let .obj _ := j | throw s!"heirs[{index}] must be an object"
  pure {
    relationship := ← optEnumField j path "relationship" parseRelationship
    name := ← optStringField j path "name"
    age := ← Api.optNatField j path "age"
    receivesMeansTestedBenefits :=
      ← Api.optBoolField j path "receives_means_tested_benefits"
    isSuspectInDeath := ← Api.optBoolField j path "is_suspect_in_death"
    disclaimed := ← Api.optBoolField j path "disclaimed"
    livedInSameHouseholdAtDeath :=
      ← Api.optBoolField j path "lived_in_same_household_at_death"
    entitledToSpouseBenefitsMonthOfDeath :=
      ← Api.optBoolField j path "entitled_to_spouse_benefits_month_of_death"
    entitledToChildBenefitsMonthOfDeath :=
      ← Api.optBoolField j path "entitled_to_child_benefits_month_of_death"
  }

def decodeIntakeExpenses (j : Json) : Except String IntakeExpenses := do
  let .obj _ := j | throw "expenses must be an object or null"
  pure {
    preferredFuneralCents :=
      ← Api.optNatField j "expenses." "preferred_funeral_cents"
    lastIllnessMedicalCents :=
      ← Api.optNatField j "expenses." "last_illness_medical_cents"
  }

private def decodeIndexed {α : Type} (decode : Nat → Json → Except String α) :
    Nat → List Json → Except String (List α)
  | _, [] => .ok []
  | index, item :: rest => do
    let head ← decode index item
    let tail ← decodeIndexed decode (index + 1) rest
    pure (head :: tail)

private def decodeArrayField {α : Type} (j : Json) (key : String)
    (decode : Nat → Json → Except String α) : Except String (List α) :=
  match Api.optField j key with
  | none => .ok []
  | some value =>
    match value.getArr? with
    | .ok array => decodeIndexed decode 0 array.toList
    | .error _ => .error s!"{key} must be an array or null"

/-- Tolerant decode of a wire `IntakeCase`. -/
def decodeIntakeCase (j : Json) : Except String IntakeCase := do
  let .obj _ := j | throw "case must be a JSON object"
  let asOfDate ← match Api.optField j "as_of_date" with
    | some v => decodeCivilDate "as_of_date" v
    | none => throw "as_of_date is required"
  let decedent ← match Api.optField j "decedent" with
    | none => pure ({} : IntakeDecedent)
    | some v => decodeDecedent v
  pure {
    asOfDate := asOfDate
    decedent := decedent
    assets := ← decodeArrayField j "assets" decodeIntakeAsset
    debts := ← decodeArrayField j "debts" decodeIntakeDebt
    heirs := ← decodeArrayField j "heirs" decodeIntakeHeir
    conflictSignals := ← Api.optBoolField j "" "conflict_signals"
    inventoryComplete := ← Api.optBoolField j "" "inventory_complete"
    heirsComplete := ← Api.optBoolField j "" "heirs_complete"
    expenses := ← match Api.optField j "expenses" with
      | none => pure ({} : IntakeExpenses)
      | some v => decodeIntakeExpenses v
  }

instance : Lean.FromJson IntakeCase := ⟨decodeIntakeCase⟩

end Router
end SimpleProbate
