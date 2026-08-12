import SimpleProbate.Router.Intake
import SimpleProbate.Router.Report

/-!
# Per-asset probate classification

Probate is triggered **per asset**, not per person. A decedent with a $3M
estate can have nothing to probate, and a decedent with one $8,000 bank
account can need a filing. So the first thing this engine does is walk the
asset list and decide, for each asset separately, whether it is part of the
probate estate.

The rules, in the order they are applied:

1. **Survivorship and trust title decide the question outright.** Joint
   tenancy with right of survivorship, tenancy by the entirety, and community
   property with right of survivorship pass to the survivor by operation of
   law at the instant of death; property already titled in a funded trust is
   owned by the trust, not by the decedent. None of these is affected by a
   beneficiary designation, so they are checked first.
2. **Otherwise the beneficiary designation controls**, and this is where the
   traps live:
   * `named_living` → non-probate; the contract pays the named person
     directly.
   * `named_predeceased` → **probate**. The designation lapses and, absent a
     surviving contingent beneficiary, the proceeds fall back into the estate.
     This is the single most commonly missed classification in practice — the
     family assumes "it has a beneficiary" and never opens the estate.
   * `estate` → probate. Naming the estate as beneficiary drags an otherwise
     non-probate contract into administration (and exposes it to creditors).
   * `none` on an account that normally carries a designation → probate, for
     the same reason.
   * `unsure` → unknown. Never guessed.
3. **Otherwise title decides.** `sole` → probate. `tenants_in_common` →
   the decedent's undivided fractional share is probate (the co-tenant's share
   is not, and there is no survivorship).
4. **Anything still undetermined is `unknown`** with the exact fact paths that
   would settle it. An unknown asset is never quietly treated as non-probate:
   it blocks the valuation caps downstream.

Citations are California-specific, so they are emitted only when the domicile
is California. For any other domicile the rule is still stated in plain
English in `reason`, but no citation is attached — a citation to the wrong
state's code is worse than none.
-/

namespace SimpleProbate
namespace Router

/-- Account types that normally carry a beneficiary designation, so that the
*absence* of one is itself a legal fact rather than a non-event. -/
def AssetKind.carriesDesignation : AssetKind → Bool
  | .retirement | .lifeInsurance | .bank | .brokerage => true
  | _ => false

/-- Designations on deposit and securities accounts are payable-on-death /
transfer-on-death registrations; on retirement plans and policies they are
contract beneficiary designations. Same outcome, different statute. -/
def AssetKind.designationIsPodTod : AssetKind → Bool
  | .bank | .brokerage => true
  | _ => false

/-- The raw output of a classification rule, before the value, the
`counts_toward` list and the citation gate are attached. -/
private structure Verdict' where
  classification : Classification
  basis : Option ClassificationBasis
  reason : String
  /-- Key into `citationFor`; `none` for conclusions that are not legal
  conclusions (i.e. `unknown`), which need no citation. -/
  citationKey : Option ClassificationBasis
  missing : List FactPath

/-- California authority for each basis. Every legal conclusion this module
reaches carries one of these. -/
private def citationFor : ClassificationBasis → Citation
  | .jtwrosSurvivorship =>
    ⟨"Cal. Civ. Code §683; Cal. Prob. Code §13050", none⟩
  | .communityPropertyRos =>
    ⟨"Cal. Civ. Code §682.1; Cal. Prob. Code §13050", none⟩
  | .trustFunded => ⟨"Cal. Prob. Code §15200 et seq.", none⟩
  | .beneficiaryDesignation => ⟨"Cal. Prob. Code §5000", none⟩
  | .podTod => ⟨"Cal. Prob. Code §§5000, 5302", none⟩
  | .soleNameNoDesignation => ⟨"Cal. Prob. Code §7000", none⟩
  | .beneficiaryPredeceasedFallsToEstate =>
    ⟨"Cal. Prob. Code §§5000, 7000", none⟩
  | .designationToEstate => ⟨"Cal. Prob. Code §7000", none⟩
  | .unknownTitle => ⟨"Cal. Prob. Code §13050", none⟩

/-- Florida authority for each basis. The classification rules themselves are
jurisdiction-general — survivorship, beneficiary designations and trusts carry
property past the estate everywhere — but the authority that says so is not,
and a California pin cite on a Florida asset is a defect, not a nicety.

Sources, retrieved 2026-08-12 from leg.state.fl.us:
Fla. Stat. §689.15 "Estates by survivorship" (survivorship must be expressly
provided for; estates by the entirety excepted) · §655.82 "Pay-on-death
accounts" (on the death of the last surviving party, sums on deposit belong to
the surviving beneficiaries) · §222.13(1) "Life insurance policies;
disposition of proceeds" (proceeds to a named beneficiary other than the
estate are not administered; naming the estate makes them "a part of the
insured's estate for all purposes … administered by the personal
representative") · §733.607(1) "Possession of estate" (the personal
representative takes possession of the decedent's property except the
protected homestead) · ch. 736 "Florida Trust Code". -/
private def floridaCitationFor : ClassificationBasis → Citation
  | .jtwrosSurvivorship => ⟨"Fla. Stat. §689.15", none⟩
  -- Florida is not a community-property state; if an intake reports the form
  -- anyway, what carries the asset is still the express survivorship right.
  | .communityPropertyRos => ⟨"Fla. Stat. §689.15", none⟩
  | .trustFunded => ⟨"Fla. Stat. ch. 736 (Florida Trust Code)", none⟩
  | .beneficiaryDesignation => ⟨"Fla. Stat. §222.13(1)", none⟩
  | .podTod => ⟨"Fla. Stat. §655.82", none⟩
  | .soleNameNoDesignation => ⟨"Fla. Stat. §733.607(1)", none⟩
  | .beneficiaryPredeceasedFallsToEstate =>
    ⟨"Fla. Stat. §§222.13(1), 733.607(1)", none⟩
  | .designationToEstate => ⟨"Fla. Stat. §222.13(1)", none⟩
  | .unknownTitle => ⟨"Fla. Stat. §733.607(1)", none⟩

/-- The citation table for a domicile, or `none` for a jurisdiction this build
does not model. A modelled jurisdiction must have one: a classification is a
legal conclusion and doctrine 4 admits no uncited conclusions. -/
private def citationTableFor : Option String → Option (ClassificationBasis → Citation)
  | some "CA" => some citationFor
  | some "FL" => some floridaCitationFor
  | _ => none

/-- Title forms that dispose of the asset without regard to any designation. -/
private def titleVerdict (a : IntakeAsset) : Option Verdict' :=
  match a.titleForm with
  | some .jtwros => some {
      classification := .nonProbate
      basis := some .jtwrosSurvivorship
      reason := "Held in joint tenancy with right of survivorship — the decedent's interest ends at death and the whole passes to the surviving joint tenant by operation of law, outside probate."
      citationKey := some .jtwrosSurvivorship
      missing := [] }
  | some .tenancyByEntirety => some {
      classification := .nonProbate
      basis := some .jtwrosSurvivorship
      reason := "Held as tenants by the entirety — the surviving spouse takes the whole by survivorship, outside probate. (California does not recognise this form; it appears on out-of-state property.)"
      citationKey := some .jtwrosSurvivorship
      missing := [] }
  | some .communityWithRos => some {
      classification := .nonProbate
      basis := some .communityPropertyRos
      reason := "Community property with right of survivorship — the whole passes to the surviving spouse at death without administration."
      citationKey := some .communityPropertyRos
      missing := [] }
  | some .trustFunded => some {
      classification := .nonProbate
      basis := some .trustFunded
      reason := "Titled in a funded trust — the trust, not the decedent, owned the asset, so it passes under the trust instrument rather than through probate."
      citationKey := some .trustFunded
      missing := [] }
  | some .custodial => some {
      classification := .nonProbate
      basis := none
      reason := "Held by the decedent as custodian for a minor — the property belongs to the minor, not to the decedent, and is not part of the estate. A successor custodian must be appointed."
      citationKey := none
      missing := []
      : Verdict' }
  | _ => none

/-- Title-only fallback once designations are known to be irrelevant. -/
private def soleOrCommonVerdict (index : Nat) (a : IntakeAsset) : Verdict' :=
  match a.titleForm with
  | some .sole => {
      classification := .probate
      basis := some .soleNameNoDesignation
      reason := "Held in the decedent's sole name with no survivorship feature and no beneficiary designation — it passes under the will or by intestacy and is part of the probate estate."
      citationKey := some .soleNameNoDesignation
      missing := [] }
  | some .tenantsInCommon => {
      classification := .probate
      basis := some .soleNameNoDesignation
      reason := "Held as tenants in common — there is no right of survivorship, so the decedent's undivided fractional share (and only that share) is part of the probate estate."
      citationKey := some .soleNameNoDesignation
      missing := [] }
  | _ => {
      classification := .unknown
      basis := some .unknownTitle
      reason := "How this asset is titled is not yet known, so whether it is part of the probate estate cannot be determined. It is neither counted nor excluded until the title form is supplied."
      citationKey := none
      missing := [assetPath index "title_form"] }

/-- The classification rule proper. -/
private def verdictFor (index : Nat) (a : IntakeAsset) : Verdict' :=
  match titleVerdict a with
  | some v => v
  | none =>
    -- Title is `sole`, `tenants_in_common`, or unknown: the designation, if
    -- there is one, controls.
    let titleFacts : List FactPath :=
      if a.titleForm.isNone then [assetPath index "title_form"] else []
    match a.beneficiaryDesignation with
    | some .namedLiving =>
      let podTod := a.kind.map AssetKind.designationIsPodTod == some true
      { classification := .nonProbate
        basis := some (if podTod then .podTod else .beneficiaryDesignation)
        reason :=
          if podTod then
            "A payable-on-death / transfer-on-death registration names a living beneficiary — the account passes to that person on proof of death, outside probate."
          else
            "A living beneficiary is named on the contract — the proceeds are paid directly to that person under the plan or policy, outside probate."
        citationKey := some (if podTod then .podTod else .beneficiaryDesignation)
        missing := [] }
    | some .namedPredeceased =>
      { classification := .probate
        basis := some .beneficiaryPredeceasedFallsToEstate
        reason := "The named beneficiary died before the decedent. The designation lapses, and unless a contingent beneficiary survives, the plan's or policy's default order pays the decedent's estate — so this asset falls back into the probate estate. Confirm whether a surviving contingent beneficiary is named before relying on this."
        citationKey := some .beneficiaryPredeceasedFallsToEstate
        missing := [] }
    | some .estate =>
      { classification := .probate
        basis := some .designationToEstate
        reason := "The decedent's estate is the named beneficiary. Naming the estate pulls an otherwise non-probate contract into administration, where it is reachable by the decedent's creditors."
        citationKey := some .designationToEstate
        missing := [] }
    | some BeneficiaryDesignation.none =>
      match a.kind with
      | some k =>
        if k.carriesDesignation then
          { classification := .probate
            basis := some .soleNameNoDesignation
            reason := "This account type normally carries a beneficiary designation and none is on file, so it is payable to the decedent's estate and is part of the probate estate."
            citationKey := some .soleNameNoDesignation
            missing := [] }
        else
          soleOrCommonVerdict index a
      | none => soleOrCommonVerdict index a
    | some .unsure =>
      { classification := .unknown
        basis := some .unknownTitle
        reason :=
          if titleFacts.isEmpty then
            "Whether a beneficiary is named on this asset is not yet known, and that fact decides whether it is part of the probate estate."
          else
            "Neither how this asset is titled nor whether a beneficiary is named on it is known yet, and either fact on its own could decide whether it is part of the probate estate."
        citationKey := none
        missing := titleFacts ++ [assetPath index "beneficiary_designation"] }
    | Option.none =>
      match a.kind with
      | some k =>
        if k.carriesDesignation then
          { classification := .unknown
            basis := some .unknownTitle
            reason :=
              if titleFacts.isEmpty then
                "This account type normally carries a beneficiary designation, and whether one is on file decides whether it is part of the probate estate."
              else
                "This account type normally carries a beneficiary designation. Neither that designation nor how the account is titled has been supplied, and either one could take it out of the probate estate — so it is counted neither in nor out."
            citationKey := none
            missing := titleFacts ++ [assetPath index "beneficiary_designation"] }
        else
          soleOrCommonVerdict index a
      | none =>
        { classification := .unknown
          basis := some .unknownTitle
          reason := "What kind of asset this is has not been supplied, so neither the title rule nor the beneficiary rule can be applied to it."
          citationKey := none
          missing := titleFacts ++ [assetPath index "kind"] }

/-! ## `counts_toward` — which route valuations include this asset

California measures the small-estate caps by the **gross** value of the
decedent's property (Cal. Prob. Code §13050 lists what is left out), which is
why an encumbrance never reduces the figure here. The §13100 subtotal counts
the decedent's California real *and* personal property, so a California
parcel counts toward the personal-property affidavit's cap even though the
affidavit itself cannot transfer it. -/

private def countsTowardFor
    (domicile : Option String) (a : IntakeAsset) (c : Classification) :
    List String :=
  if domicile != some "CA" then
    -- The California route valuations are only meaningful for a California
    -- estate. Florida is deliberately not listed here either: §735.201(2)
    -- measures the estate *less property exempt from creditors' claims*, and
    -- an asset whose exemption is unknown may or may not count — a two-sided
    -- bound that a flat "counts toward" list cannot express without
    -- overstating one side. `SimpleProbate.FL` carries that arithmetic, and
    -- the Florida route rows report the facts that separate the bounds.
    []
  else if c != .probate then
    []
  else
    match a.kind with
    | some .realProperty =>
      match a.situsState with
      | some "CA" =>
        ["ca_personal_property_affidavit", "ca_small_value_real_property_affidavit"] ++
          (if a.isPrimaryResidence == some true then ["ca_primary_residence_petition"] else [])
      | some _ => []          -- out-of-state realty is excluded from every CA cap
      | none => []            -- situs unknown; reported as a missing fact instead
    | some _ => ["ca_personal_property_affidavit"]
    | none => []

/-- Classify one asset. -/
def classifyAsset (domicile : Option String) (index : Nat) (a : IntakeAsset) :
    AssetClassification :=
  let v := verdictFor index a
  -- Real property needs a situs before it can be valued under any route, and
  -- before ancillary administration can be ruled in or out.
  let situsFacts : List FactPath :=
    if a.kind == some .realProperty && a.situsState.isNone then
      [assetPath index "situs_state"]
    else
      []
  { name := a.name
    classification := v.classification
    basis := v.basis
    reason := v.reason
    citation :=
      match citationTableFor domicile with
      | some table => v.citationKey.map table
      | none => none
    missingFacts := dedup (v.missing ++ situsFacts)
    countsToward := countsTowardFor domicile a v.classification
    valueCents := a.grossValueCents }

private def classifyAux (domicile : Option String) :
    Nat → List IntakeAsset → List AssetClassification
  | _, [] => []
  | index, a :: rest =>
    classifyAsset domicile index a :: classifyAux domicile (index + 1) rest

/-- The whole asset map, index-aligned with `case.assets`. -/
def assetMapOf (c : IntakeCase) : List AssetClassification :=
  classifyAux c.decedent.domicileState 0 c.assets

/-! ## The probate estate

The known subtotal is the sum of the gross values of the assets *known* to be
probate. It is honest about what it is not: any asset whose classification is
unknown, any probate asset whose value is unknown, and an unconfirmed
inventory all make the total `partial` and name the fact that would close the
gap. A `partial` total can still disqualify a capped route (a known subtotal
already over the cap can only grow) — that logic lives in
`SimpleProbate.Partial.capCheck` and is reused, not re-implemented. -/

private def probateAux :
    Nat → List AssetClassification → Money × List FactPath
  | _, [] => (0, [])
  | index, ac :: rest =>
    let (subtotal, missing) := probateAux (index + 1) rest
    let ownMissing := ac.missingFacts
    match ac.classification with
    | .probate =>
      match ac.valueCents with
      | some value => (subtotal + value, ownMissing ++ missing)
      | none =>
        (subtotal, ownMissing ++ [assetPath index "gross_value_cents"] ++ missing)
    | .unknown => (subtotal, ownMissing ++ missing)
    | .nonProbate => (subtotal, ownMissing ++ missing)

def probateEstateOf (c : IntakeCase) (m : List AssetClassification) :
    ProbateEstate :=
  let (subtotal, missing) := probateAux 0 m
  let inventoryFacts : List FactPath :=
    if c.inventoryComplete == some true then [] else ["inventory_complete"]
  let allMissing := dedup (missing ++ inventoryFacts)
  { knownSubtotalCents := subtotal
    status := if allMissing.isEmpty then .known else .partiallyKnown
    missingFacts := allMissing }

end Router
end SimpleProbate
