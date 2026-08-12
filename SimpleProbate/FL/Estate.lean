import SimpleProbate.FL.Thresholds

/-!
# Florida estate model

The facts Florida's small-estate routes actually turn on, named to match the
settlement contract's `IntakeCase` (`assets[i].title_form`,
`assets[i].situs_state`, …) so that the partial layer can blame the exact wire
field when something is unknown.

Two Florida-specific reductions of the contract's asset shape:

* **Real vs personal is the only kind distinction Florida needs.** Fla. Stat.
  §735.301 and §735.304 are confined to personal property; §735.201 is not.
* **"Subject to administration" is derived from `title_form` and
  `beneficiary_designation`**, not supplied. Tenancy by the entirety, joint
  tenancy with right of survivorship, funded trusts, custodial accounts, and a
  living named beneficiary all carry property past the estate.

Sources retrieved 2026-08-12: Fla. Stat. §§735.201, 735.301, 735.304, 732.402;
Fla. Const. art. X, §4(a)(1).
-/

namespace SimpleProbate.FL

/-- The only property distinction Florida's small-estate routes need. The
contract's richer `kind` enum collapses onto this; `"other"` does not settle
the question and stays unknown. -/
inductive AssetKind
  | realProperty
  | personal
deriving BEq, DecidableEq, Repr

/-- Decode the contract's `assets[i].kind`. `none` means the wire value does not
settle real vs personal, which the partial layer treats as unknown — never as
"personal". -/
def AssetKind.ofWireName : String → Option AssetKind
  | "real_property" => some .realProperty
  | "bank" | "brokerage" | "retirement" | "life_insurance" | "vehicle"
  | "personal" | "business" | "digital" | "employment_comp" => some .personal
  | _ => none

/-- The contract's `assets[i].title_form`. -/
inductive TitleForm
  | sole
  | jtwros
  | tenancyByEntirety
  | communityWithRos
  | tenantsInCommon
  | trustFunded
  | custodial
deriving BEq, DecidableEq, Repr

def TitleForm.ofWireName : String → Option TitleForm
  | "sole" => some .sole
  | "jtwros" => some .jtwros
  | "tenancy_by_entirety" => some .tenancyByEntirety
  | "community_with_ros" => some .communityWithRos
  | "tenants_in_common" => some .tenantsInCommon
  | "trust_funded" => some .trustFunded
  | "custodial" => some .custodial
  | _ => none

/-- Title forms that carry the asset to someone else at death by operation of
law or by trust, so the asset is not part of the estate subject to
administration. A tenant in common's undivided share *is* administered. -/
def TitleForm.passesOutsideAdministration : TitleForm → Bool
  | .jtwros | .tenancyByEntirety | .communityWithRos | .trustFunded
  | .custodial => true
  | .sole | .tenantsInCommon => false

/-- The contract's `assets[i].beneficiary_designation`. `noDesignation` is the
wire value `"none"`; it is spelled out to stay clear of `Option.none`. -/
inductive BeneficiaryDesignation
  | namedLiving
  | namedPredeceased
  | estate
  | noDesignation
  | unsure
deriving BEq, DecidableEq, Repr

def BeneficiaryDesignation.ofWireName : String → Option BeneficiaryDesignation
  | "named_living" => some .namedLiving
  | "named_predeceased" => some .namedPredeceased
  | "estate" => some .estate
  | "none" => some .noDesignation
  | "unsure" => some .unsure
  | _ => none

/-- Whether the designation alone settles that the asset passes outside
administration. `unsure` settles nothing. -/
def BeneficiaryDesignation.passesOutsideAdministration :
    BeneficiaryDesignation → Option Bool
  | .namedLiving => some true
  | .namedPredeceased | .estate | .noDesignation => some false
  | .unsure => none

/-- The contract's `decedent.will_status`. `noWill` is the wire value
`"none"`. -/
inductive WillStatus
  | validOriginal
  | copyOnly
  | holographic
  | noWill
  | unsure
deriving BEq, DecidableEq, Repr

def WillStatus.ofWireName : String → Option WillStatus
  | "valid_original" => some .validOriginal
  | "copy_only" => some .copyOnly
  | "holographic" => some .holographic
  | "none" => some .noWill
  | "unsure" => some .unsure
  | _ => none

/-- A fully known asset. Values are gross; Florida's §735.201 test speaks of the
value of the estate *less exempt property*, not less encumbrances, so this
module does not net liens. -/
structure Asset where
  name : String
  kind : AssetKind
  /-- Two-letter state code, as on the wire. Real property is administered where
  it sits; the Router supplies the domicile for personalty. -/
  situsState : String
  grossValue : Money
  titleForm : TitleForm
  beneficiaryDesignation : BeneficiaryDesignation
  isPrimaryResidence : Bool := false
  /-- Stated exemption from the claims of creditors under Fla. Stat. §732.402
  (household furnishings, motor vehicles, qualified tuition programs, certain
  death benefits). Protected homestead is *derived*, not stated. -/
  exemptFromCreditors : Bool := false
deriving DecidableEq, Repr

structure Estate where
  assets : List Asset
deriving DecidableEq, Repr

/-- Part of the estate subject to administration: nothing in the title form or
the beneficiary designation carries it elsewhere. -/
def Asset.subjectToAdministration (asset : Asset) : Bool :=
  !asset.titleForm.passesOutsideAdministration &&
    asset.beneficiaryDesignation.passesOutsideAdministration != some true

/-- Administered *in Florida*. Fla. Stat. §735.201(2) counts only "the entire
estate subject to administration in this state". -/
def Asset.inFloridaAdministration (asset : Asset) : Bool :=
  asset.situsState == "FL"

/-- Protected homestead — Fla. Const. art. X, §4(a)(1). Exempt from the claims
of creditors, so §735.201(2) subtracts it. This module treats Florida-situs real
property that was the decedent's primary residence as the homestead; the
constitutional acreage and ownership tests are outside the intake. -/
def Asset.protectedHomestead (asset : Asset) : Bool :=
  asset.kind == .realProperty && asset.isPrimaryResidence &&
    asset.situsState == "FL"

/-- Exempt from the claims of creditors: Fla. Stat. §732.402 exempt property or
Fla. Const. art. X, §4 homestead. -/
def Asset.exemptFromCreditorClaims (asset : Asset) : Bool :=
  asset.exemptFromCreditors || asset.protectedHomestead

/-- Per-asset contribution to the Fla. Stat. §735.201(2) valuation. -/
def Asset.summaryAdministrationValue (asset : Asset) : Money :=
  if asset.inFloridaAdministration && asset.subjectToAdministration &&
      !asset.exemptFromCreditorClaims then
    asset.grossValue
  else
    0

/-- Fla. Stat. §735.201(2): the value of the entire estate subject to
administration in this state, less the value of property exempt from the claims
of creditors. -/
def Estate.summaryAdministrationValue (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset => total + asset.summaryAdministrationValue) 0

/-- Per-asset contribution to the Fla. Stat. §735.301 / §735.304 valuation,
which reaches nonexempt *personal* property only. -/
def Asset.nonexemptPersonalValue (asset : Asset) : Money :=
  if asset.kind == .personal && asset.inFloridaAdministration &&
      asset.subjectToAdministration && !asset.exemptFromCreditorClaims then
    asset.grossValue
  else
    0

/-- Fla. Stat. §735.301(1) / §735.304: "nonexempt personal property". -/
def Estate.nonexemptPersonalPropertyValue (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset => total + asset.nonexemptPersonalValue) 0

/-- Real property the decedent actually left to be administered. Fla. Stat.
§735.301(1) and §735.304 are available only to an estate "leaving only personal
property", and this is not restricted to Florida-situs land: out-of-state real
property is still real property the decedent left. Real property that passes by
survivorship or through a funded trust is not left to be administered. -/
def Asset.isAdministrableRealProperty (asset : Asset) : Bool :=
  asset.kind == .realProperty && asset.subjectToAdministration

def Estate.containsRealProperty (estate : Estate) : Bool :=
  estate.assets.any Asset.isAdministrableRealProperty

/-- The two expense figures Fla. Stat. §735.301(1) and §735.304 measure
nonexempt personalty against. -/
structure Expenses where
  /-- Funeral, interment, and grave-marker expenses. Only the *preferred*
  portion counts, so this is capped at `preferredFuneralExpenseCap`. -/
  funeralExpenses : Money
  /-- Reasonable and necessary medical and hospital expenses of the last 60 days
  of the last illness. -/
  lastIllnessMedicalExpenses : Money
deriving DecidableEq, Repr

/-- "The sum of the amount of preferred funeral expenses and reasonable and
necessary medical and hospital expenses of the last 60 days of the last
illness" — Fla. Stat. §735.301(1), with the funeral component limited to the
preferred class by Fla. Stat. §733.707(1)(b). -/
def Expenses.allowance (expenses : Expenses) : Money :=
  min expenses.funeralExpenses preferredFuneralExpenseCap +
    expenses.lastIllnessMedicalExpenses

/-! ## Model checks -/

-- A funeral bill above the preferred class does not enlarge the allowance.
example : Expenses.allowance ⟨Money.dollars 11_000, Money.dollars 3_000⟩ =
    Money.dollars 9_000 := by decide

-- Tenancy by the entirety and a living beneficiary both leave the estate.
example : TitleForm.passesOutsideAdministration .tenancyByEntirety = true := by
  decide
example : TitleForm.passesOutsideAdministration .tenantsInCommon = false := by
  decide
example :
    BeneficiaryDesignation.passesOutsideAdministration .namedPredeceased =
      some false := by decide

end SimpleProbate.FL
