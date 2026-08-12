import SimpleProbate.Router.Classify
import SimpleProbate.Router.Dates

/-!
# California jurisdiction assembly

This module does not re-decide California law. The eligibility predicates, the
threshold bands, the unknown-vs-violation precedence and the valuation caps
already exist and are proved out in `SimpleProbate.Eligibility` and
`SimpleProbate.Partial`; what happens here is *adaptation*: an `IntakeCase`
is projected onto a `PartialTransferCase`, `assessRoutes` is called, and its
output is mapped onto the contract's `RouteReport` shape with the stable
`ca_*` ids.

Two rules govern the projection.

**Unknown in, unknown out.** Where the intake cannot supply a fact the CA
engine needs, the field is left `none`. It is never set to `false` to make a
route resolve, and never set to `true` to make one qualify.

**Every fact path is a path into the intake.** The engine names facts in its
own vocabulary (`days_since_death`, `estate.assets[2].treatment`). Those names
mean nothing to a caller holding an `IntakeCase`, so every engine fact is
translated through `factMap` into the intake path (or paths) that would
actually answer it. `estate.assets[i].treatment`, for instance, translates to
whichever of `title_form` / `beneficiary_designation` / `kind` the
classifier is actually waiting on for that asset.

Three facts are *derived* from the intake rather than asked for, and the
derivations are stated here so a reviewer can disagree with them in one place:

* `authority` (no pending probate proceeding blocks summary transfer) — taken
  as satisfied only when `decedent.pending_litigation` is known `false`. Known
  `true` does not block the route, because litigation is not necessarily a
  probate proceeding; it leaves the fact unknown.
* `claimant_is_successor` — taken as satisfied when the intake lists at least
  one heir who has not disclaimed. The §13101 affidavit is executed by the
  decedent's successor in interest, and the heir list is the caller's own
  statement of who that is.
* `no_superior_right` — taken as satisfied only when the caller has listed
  heirs *and* has answered `conflict_signals: false`.

`included_in_primary_residence_petition` is set to `false` for every asset:
no §13151 petition is assumed to be pending. That is the conservative
direction — it keeps assets inside the §13100 subtotal rather than excusing
them from it.
-/

namespace SimpleProbate
namespace Router

/-! ## Route metadata (contract §4) -/

structure RouteMeta where
  id : String
  label : String
  forms : List String
  citations : List Citation

def caDirectTransfer : RouteMeta :=
  { id := "ca_direct_transfer"
    label := "Transfers that need no court at all"
    forms := []
    citations := [⟨"Cal. Prob. Code §§5000, 5302, 13050", none⟩] }

def caPersonalPropertyAffidavit : RouteMeta :=
  { id := "ca_personal_property_affidavit"
    label := "Affidavit for collection of personal property"
    forms := ["DE-300"]
    citations := [⟨"Cal. Prob. Code §§13100–13101", none⟩] }

def caSmallValueRealPropertyAffidavit : RouteMeta :=
  { id := "ca_small_value_real_property_affidavit"
    label := "Affidavit re real property of small value"
    forms := ["DE-305"]
    citations := [⟨"Cal. Prob. Code §§13200–13210", none⟩] }

def caPrimaryResidencePetition : RouteMeta :=
  { id := "ca_primary_residence_petition"
    label := "Petition to determine succession to real property"
    forms := ["DE-310", "DE-315"]
    citations := [⟨"Cal. Prob. Code §§13150–13154", none⟩] }

def caSpousalPropertyPetition : RouteMeta :=
  { id := "ca_spousal_property_petition"
    label := "Spousal or domestic partner property petition"
    forms := ["DE-221", "DE-226"]
    citations := [⟨"Cal. Prob. Code §§13500, 13650", none⟩] }

def caFormalProbate : RouteMeta :=
  { id := "ca_formal_probate_or_other"
    label := "Formal probate administration"
    forms := ["DE-111"]
    citations := [⟨"Cal. Prob. Code §8000", none⟩] }

/-! ## Projection onto the CA engine -/

/-- A `PartialTransferCase` together with the translation from the engine's
fact vocabulary back to intake paths. -/
structure CaAdapter where
  partialCase : PartialTransferCase
  factMap : List (FactPath × List FactPath)

/-- Translate one engine fact path into intake paths. An entry mapping to the
empty list means "this fact is supplied by the adapter and can never be
missing"; an unmapped fact passes through unchanged (there are none, but the
function is total). -/
def mapFact (m : List (FactPath × List FactPath)) (fact : FactPath) :
    List FactPath :=
  match m.lookup fact with
  | some paths => paths
  | none => [fact]

def mapFacts (m : List (FactPath × List FactPath)) (facts : List FactPath) :
    List FactPath :=
  dedup (concatMap (mapFact m) facts)

/-- The valuation treatment implied by a classification. Probate assets are
`counted` (employment compensation gets its own treatment so the §13050(a)
salary exclusion applies); non-probate assets get the treatment matching the
basis, which is what makes them contribute zero to every cap. -/
def treatmentFor (kind : Option AssetKind) (ac : AssetClassification) :
    Option ValuationTreatment :=
  match ac.classification with
  | .unknown => none
  | .probate =>
    if kind == some .employmentComp then
      some .employmentCompensation
    else
      some .counted
  | .nonProbate =>
    match ac.basis with
    | some .jtwrosSurvivorship => some .jointTenancy
    | some .communityPropertyRos => some .spousePassage
    | some .trustFunded => some .revocableTrust
    | some .beneficiaryDesignation => some .directBeneficiary
    | some .podTod => some .transferOnDeath
    -- Custodial property (basis `none`): excluded from the estate and not a
    -- transfer *from* the decedent, so it contributes nothing and supplies no
    -- direct-transfer basis.
    | _ => some .terminableAtDeath

private def adaptAssets :
    Nat → List IntakeAsset → List AssetClassification →
      List PartialAsset × List (FactPath × List FactPath)
  | _, [], _ => ([], [])
  | _, _, [] => ([], [])
  | i, a :: as, ac :: acs =>
    let (restAssets, restMap) := adaptAssets (i + 1) as acs
    let (kind, kindFacts) : Option PropertyKind × List FactPath :=
      match a.kind with
      | some .realProperty =>
        match a.situsState with
        | some "CA" => (some .californiaReal, [])
        | some _ => (some .outsideCaliforniaReal, [])
        | none => (none, [assetPath i "situs_state"])
      | some _ => (some .personal, [])
      | none => (none, [assetPath i "kind"])
    let partialAsset : PartialAsset := {
      name := a.name
      kind := kind
      grossValue := a.grossValueCents
      encumbrances := a.encumbranceCents
      treatment := treatmentFor a.kind ac
      includedInPrimaryResidencePetition := some false
      isPrimaryResidence := a.isPrimaryResidence
    }
    let entries : List (FactPath × List FactPath) := [
      (assetFact i "kind", kindFacts),
      (assetFact i "treatment", ac.missingFacts),
      (assetFact i "gross_value_cents", [assetPath i "gross_value_cents"]),
      (assetFact i "is_primary_residence", [assetPath i "is_primary_residence"]),
      (assetFact i "included_in_primary_residence_petition", [])
    ]
    (partialAsset :: restAssets, entries ++ restMap)

/-- Build the CA engine's view of the case. `targetIndex` is set per call by
`assessTarget`. -/
def adapt (c : IntakeCase) (m : List AssetClassification) : CaAdapter :=
  let (assets, assetMap) := adaptAssets 0 c.assets m
  let takingHeirs := c.heirs.filter fun h => h.disclaimed != some true
  let hasTakingHeir := !takingHeirs.isEmpty
  let hasTakingSpouse := takingHeirs.any fun h => h.relationship == some .spouse
  let spouseSurvives := c.decedent.survivingSpouse == some true
  let survivorStatus : Option SurvivorStatus :=
    match c.decedent.survivingSpouse with
    | some true => some .spouse
    | some false => some SurvivorStatus.none
    | none =>
      match c.decedent.maritalStatus with
      | some .single | some .divorced | some .widowed => some SurvivorStatus.none
      | _ => none
  let noSurvivor := survivorStatus == some SurvivorStatus.none
  let hasSpousalTitledAsset := c.assets.any fun a =>
    a.titleForm == some .communityWithRos || a.titleForm == some .tenancyByEntirety
  let partialCase : PartialTransferCase := {
    deathDate := c.decedent.deathDate
    daysSinceDeath :=
      match c.decedent.deathDate with
      | some d => if d.atMost c.asOfDate then some (daysBetween d c.asOfDate) else none
      | none => none
    sixMonthsElapsed :=
      match c.decedent.deathDate with
      | some d => some ((addMonths d 6).atMost c.asOfDate)
      | none => none
    claimantIsSuccessor := if hasTakingHeir then some true else none
    noSuperiorRight :=
      if hasTakingHeir && c.conflictSignals == some false then some true else none
    -- Whether funeral, last-illness and unsecured debts are paid is not a
    -- fact the intake captures; the debt list does not establish payment.
    funeralLastIllnessAndUnsecuredDebtsPaid := none
    authority :=
      if c.decedent.pendingLitigation == some false then some .noProceeding else none
    survivorStatus := survivorStatus
    propertyPassesToSurvivor :=
      if spouseSurvives && hasTakingSpouse then some true
      else if noSurvivor then some false
      else none
    propertyBelongsToSurvivor :=
      if spouseSurvives && hasSpousalTitledAsset then some true
      else if noSurvivor then some false
      else none
    estate := { inventoryComplete := c.inventoryComplete, assets := assets }
    targetIndex := 0
  }
  let caseFacts : List (FactPath × List FactPath) := [
    ("death_date", [decedentPath "death_date"]),
    ("days_since_death", [decedentPath "death_date"]),
    ("six_months_elapsed", [decedentPath "death_date"]),
    ("claimant_is_successor", ["heirs"]),
    ("no_superior_right", ["conflict_signals"]),
    ("funeral_last_illness_and_unsecured_debts_paid", ["debts"]),
    ("authority", [decedentPath "pending_litigation"]),
    ("survivor_status", [decedentPath "surviving_spouse"]),
    ("property_passes_to_survivor", ["heirs"]),
    ("property_belongs_to_survivor", ["heirs"]),
    ("estate.inventory_complete", ["inventory_complete"])
  ]
  { partialCase := partialCase, factMap := caseFacts ++ assetMap }

/-! ## Row construction -/

private def reasonOf (d : Disqualifier) : Reason := ⟨d.id, d.text⟩

def rowOf (rm : RouteMeta) (m : List (FactPath × List FactPath))
    (status : SimpleProbate.RouteStatus) : RouteRow :=
  let (rowStatus, reasons, missing) :=
    match status with
    | .qualifies => (RowStatus.qualifies, ([] : List Reason), ([] : List FactPath))
    | .doesNotQualify rs => (RowStatus.doesNotQualify, rs.map reasonOf, [])
    | .needsInformation facts => (RowStatus.needsInformation, [], mapFacts m facts)
  { route := rm.id
    label := rm.label
    status := rowStatus
    reasons := reasons
    missingFacts := missing
    forms := rm.forms
    citations := rm.citations }

/-- A route the engine could not be asked about at all, because the intake
lists no assets. -/
private def noAssetsRow (rm : RouteMeta) : RouteRow :=
  { route := rm.id
    label := rm.label
    status := .needsInformation
    reasons := []
    missingFacts := ["assets"]
    forms := rm.forms
    citations := rm.citations }

/-! ## Target selection

`assessRoutes` reports on one target asset. The contract's rows are
case-level, so each row is asked of the asset that row is actually about: the
personal-property affidavit of a probate personal-property asset, the two
real-property routes of the California parcel, the direct-transfer row of an
asset that actually passes outside probate. Where no such asset exists the
first asset is used, and the engine's own violation ("the target asset is not
personal property") is the correct answer for the case. -/

private def indexedFind
    (p : Nat → IntakeAsset → AssetClassification → Bool) :
    Nat → List IntakeAsset → List AssetClassification → Option Nat
  | _, [], _ => none
  | _, _, [] => none
  | i, a :: as, ac :: acs =>
    if p i a ac then some i else indexedFind p (i + 1) as acs

private def pick (c : IntakeCase) (m : List AssetClassification)
    (ps : List (Nat → IntakeAsset → AssetClassification → Bool)) : Nat :=
  match ps with
  | [] => 0
  | p :: rest =>
    match indexedFind p 0 c.assets m with
    | some i => i
    | none => pick c m rest

/-- Assess the CA routes for the case and return the six contract rows. -/
def californiaRoutes (c : IntakeCase) (m : List AssetClassification) :
    Except CaseError (List RouteRow) := do
  let adapter := adapt c m
  let fm := adapter.factMap
  let assessAt (index : Nat) : Except CaseError CaseAssessment :=
    assessRoutes { adapter.partialCase with targetIndex := index }
  let isPersonal := fun (_ : Nat) (a : IntakeAsset) (_ : AssetClassification) =>
    a.kind != some AssetKind.realProperty && a.kind.isSome
  let personalIndex := pick c m [
    fun i a ac => isPersonal i a ac && ac.classification == .probate,
    isPersonal ]
  let realIndex := pick c m [
    fun _ a _ => a.kind == some .realProperty && a.situsState == some "CA",
    fun _ a _ => a.kind == some .realProperty ]
  let directIndex := pick c m [
    fun _ _ ac => ac.classification == .nonProbate,
    fun _ _ ac => ac.classification == .unknown ]
  let personalAssessment ← assessAt personalIndex
  let realAssessment ← assessAt realIndex
  let directAssessment ← assessAt directIndex
  let statusOf (assessment : CaseAssessment) (route : RouteId) :
      SimpleProbate.RouteStatus :=
    match assessment.routes.find? fun r => r.route == route with
    | some r => r.status
    -- Unreachable: `assessRoutes` always emits all six rows.
    | none => .needsInformation []
  let directRow :=
    rowOf caDirectTransfer fm (statusOf directAssessment .directTransfer)
  let personalRow :=
    rowOf caPersonalPropertyAffidavit fm
      (statusOf personalAssessment .personalPropertyAffidavit)
  let smallValueRow :=
    rowOf caSmallValueRealPropertyAffidavit fm
      (statusOf realAssessment .smallValueRealPropertyAffidavit)
  let residenceRow :=
    rowOf caPrimaryResidencePetition fm
      (statusOf realAssessment .primaryResidencePetition)
  let spousalRow :=
    rowOf caSpousalPropertyPetition fm
      (statusOf personalAssessment .spousalPropertyPetition)
  -- The fallback row is recomputed over the five contract rows rather than
  -- lifted from any one engine call, because each of those rows was asked of
  -- a different target.
  let simplified := [directRow, personalRow, smallValueRow, residenceRow, spousalRow]
  let anyQualifies := simplified.any fun r => r.status == .qualifies
  let openFacts := dedup (concatMap (fun (r : RouteRow) => r.missingFacts) simplified)
  let fallbackRow : RouteRow :=
    { route := caFormalProbate.id
      label := caFormalProbate.label
      status :=
        if anyQualifies then .doesNotQualify
        else if openFacts.isEmpty then .qualifies
        else .needsInformation
      reasons :=
        if anyQualifies then
          [⟨"simplified_route_available",
            "At least one simplified transfer route qualifies on the known facts, so full administration is not required for that property."⟩]
        else []
      missingFacts := if anyQualifies then [] else openFacts
      forms := caFormalProbate.forms
      citations := caFormalProbate.citations }
  pure (simplified ++ [fallbackRow])

/-- The fallback rows: "formal probate or another procedure" in California,
"formal administration" in Florida. They qualify precisely when no simplified
route does, so they must not be read as a qualifying route — see `verdictOf`. -/
def isFallbackRoute (route : String) : Bool :=
  route == caFormalProbate.id || route == "fl_formal_administration"

/-- Jurisdiction verdict, shared by every jurisdiction in a response so that
two of them are never graded on different curves.

`ELIGIBLE` is reserved for cases with nothing left to ask: a route that
qualifies while another route is still waiting on a fact leaves the case
`INCOMPLETE_INFO`, because the missing fact may yet change the picture.

The fallback row is excluded from the qualifying test. It qualifies exactly
when nothing simpler does, so counting it would report `ELIGIBLE` on the one
case that means the opposite — "you are going to need full administration".
That is also the older `CheckResult` contract's rule: `SimpleProbate.Partial`
computes `overall` over the five simplified routes and `Api.verdictFor` maps
its `formal_probate_or_other_procedure` to `OTHER_FORM_REQUIRED`. -/
def verdictOf (rows : List RouteRow) : Verdict :=
  if rows.any fun r => r.status == .needsInformation then
    .incompleteInfo
  else if rows.any fun r => r.status == .qualifies && !isFallbackRoute r.route then
    .eligible
  else
    .otherFormRequired

def californiaJurisdiction (c : IntakeCase) (m : List AssetClassification) :
    Except CaseError JurisdictionReport := do
  let rows ←
    if c.assets.isEmpty then
      pure [noAssetsRow caDirectTransfer, noAssetsRow caPersonalPropertyAffidavit,
            noAssetsRow caSmallValueRealPropertyAffidavit,
            noAssetsRow caPrimaryResidencePetition,
            noAssetsRow caSpousalPropertyPetition, noAssetsRow caFormalProbate]
    else
      californiaRoutes c m
  pure { code := "CA", role := .domicile, verdict := verdictOf rows, routes := rows }

/-! ## Ancillary jurisdictions

Real property is administered where it sits. A parcel outside the domicile
state therefore needs its own proceeding in that state, no matter how the
domicile state's routes come out. -/

private def ancillaryStatesAux (domicile : String) :
    List IntakeAsset → List String
  | [] => []
  | a :: rest =>
    let tail := ancillaryStatesAux domicile rest
    match a.kind, a.situsState with
    | some .realProperty, some s => if s != domicile then s :: tail else tail
    | _, _ => tail

/-- Distinct out-of-domicile situs states of real property, in intake order. -/
def ancillaryStates (c : IntakeCase) : List String :=
  match c.decedent.domicileState with
  | some domicile => dedup (ancillaryStatesAux domicile c.assets)
  | none => []

/-- One `role: "ancillary"` entry per out-of-domicile situs state.

SEAM(jurisdiction): these entries carry no routes today. When
`SimpleProbate.FL` lands, route them the same way the domicile entry is
routed — `| "FL" => FL.jurisdiction c m .ancillary` — and give California
ancillary entries `californiaRoutes` with `role := .ancillary`, since
§§13200/13150 turn on where the parcel is, not on where the decedent lived.
The `ancillary_probate_required` flag carries the explanation and the citation
in the meantime. -/
def ancillaryJurisdictions (c : IntakeCase) : List JurisdictionReport :=
  (ancillaryStates c).map fun code =>
    { code := code, role := .ancillary, verdict := .otherFormRequired, routes := [] }

end Router
end SimpleProbate
