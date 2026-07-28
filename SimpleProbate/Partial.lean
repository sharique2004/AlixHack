import SimpleProbate.Eligibility

/-!
# Partial-information layer

Evaluates the route eligibility predicates from `SimpleProbate.Eligibility`
over partially known (`Option`-valued) facts. Unknown is never treated as
false: a route is disqualified only by a known violation, and within one
route known violations take precedence over unknowns, which take precedence
over satisfaction.

Valuation under partial information mirrors the CODE of the baseline
valuation functions (`Asset.personalAffidavitValue` with its per-asset
employment-compensation exclusion, `Asset.countedCaliforniaRealValue`,
`Asset.countedPrimaryResidenceValue`): if every needed asset fact is known
the value is computed exactly as the baseline computes it; a known subtotal
already above a cap is a violation even when other assets have unknown
values; otherwise a value-dependent check with any needed unknown fact
(including `estate.inventory_complete` not known to be true) is unknown.

This module deliberately does not import `Lean.Data.Json`; the JSON bridge
lives in `SimpleProbate.Api`.

-- TODO(proof-contract): deferred theorems from the approved spec
-- (docs/superpowers/specs/2026-07-28-exact-partial-probate-api-design.md).
-- Omitted (not stubbed) in this executable-scope pass:
--   * total route exactness: for every well-formed total case, the report is
--       `qualifies` ↔ `RouteEligible` and `doesNotQualify` ↔ `¬ RouteEligible`;
--   * fallback exactness: overall `formalProbateOrOtherProcedure` ↔ every
--       simplified route is conclusively ineligible;
--   * partial-input soundness via `Completes partial total`:
--       `qualifies` → every compatible well-formed completion satisfies the
--       route predicate; `doesNotQualify` → no compatible well-formed
--       completion satisfies it;
--   * `needsInformation` lists exactly the unresolved atomic checks after
--       known violations are excluded by the aggregation precedence;
--   * nonempty-list invariants on the `doesNotQualify` / `needsInformation`
--       constructors.
-/

namespace SimpleProbate

/-- JSON path into the wire-format `CaseInput` naming a fact whose value is
unknown, e.g. `"death_date"` or `"estate.assets[1].gross_value_cents"`. -/
abbrev FactPath := String

/-- A stable, machine-readable reason why a route is known not to qualify. -/
structure Disqualifier where
  id : String
  text : String
deriving BEq, DecidableEq, Repr

/-- Result of evaluating one atomic conjunct of a route's eligibility
predicate against partially known facts. -/
inductive AtomicResult
  | satisfied
  | violated (reason : Disqualifier)
  | unknown (facts : List FactPath)
deriving BEq, DecidableEq, Repr

/-- Public per-route status. Aggregation precedence: known violations beat
unknowns; unknowns beat satisfaction; unknown is never treated as false. -/
inductive RouteStatus
  | qualifies
  | doesNotQualify (reasons : List Disqualifier)
  | needsInformation (facts : List FactPath)
deriving BEq, DecidableEq, Repr

/-- The stable ids of the disqualifiers of a `doesNotQualify` status
(empty for the other statuses). -/
def RouteStatus.disqualifierIds : RouteStatus → List String
  | .doesNotQualify reasons => reasons.map (·.id)
  | _ => []

/-- The missing facts of a `needsInformation` status (empty otherwise). -/
def RouteStatus.missingFacts : RouteStatus → List FactPath
  | .needsInformation facts => facts
  | _ => []

/-- Route identifiers as reported on the wire. `directTransfer` is a single
row; when it qualifies the report's `detail` names the basis. -/
inductive RouteId
  | directTransfer
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
  | formalProbateOrOtherProcedure
deriving BEq, DecidableEq, Repr

def RouteId.wireName : RouteId → String
  | .directTransfer => "direct_transfer"
  | .personalPropertyAffidavit => "personal_property_affidavit"
  | .smallValueRealPropertyAffidavit => "small_value_real_property_affidavit"
  | .primaryResidencePetition => "primary_residence_petition"
  | .spousalPropertyPetition => "spousal_property_petition"
  | .formalProbateOrOtherProcedure => "formal_probate_or_other_procedure"

def RouteId.forms : RouteId → List String
  | .directTransfer => []
  | .personalPropertyAffidavit => []
  | .smallValueRealPropertyAffidavit => ["DE-305"]
  | .primaryResidencePetition => ["DE-310", "DE-315"]
  | .spousalPropertyPetition => ["DE-221", "DE-226"]
  | .formalProbateOrOtherProcedure => ["DE-111"]

def DirectTransferBasis.wireName : DirectTransferBasis → String
  | .governmentBenefit => "government_benefit"
  | .namedBeneficiary => "named_beneficiary"
  | .revocableTrust => "revocable_trust"
  | .jointTenancy => "joint_tenancy"
  | .transferOnDeath => "transfer_on_death"
  | .multiplePartyAccount => "multiple_party_account"
  | .spousePassage => "spouse_passage"

/-- One row of the assessment: a route, its status, and a one-line detail
(non-empty only when the route qualifies). -/
structure RouteReport where
  route : RouteId
  status : RouteStatus
  detail : String
deriving BEq, DecidableEq, Repr

inductive OverallOutcome
  | simplifiedRoutesAvailable
  | unresolved
  | formalProbateOrOtherProcedure
deriving BEq, DecidableEq, Repr

def OverallOutcome.wireName : OverallOutcome → String
  | .simplifiedRoutesAvailable => "simplified_routes_available"
  | .unresolved => "unresolved"
  | .formalProbateOrOtherProcedure => "formal_probate_or_other_procedure"

/-- All six route reports (stable order) plus the overall outcome. -/
structure CaseAssessment where
  routes : List RouteReport
  overall : OverallOutcome
deriving BEq, DecidableEq, Repr

/-- Structural case errors. These are not legal conclusions. -/
inductive CaseError
  | invalidDate
  | afterSnapshot
  | malformedCase (detail : String)
deriving BEq, DecidableEq, Repr

/-- Partially known asset, mirroring `Asset` with `Option`-valued fields.
`none` means unknown, never false/zero. -/
structure PartialAsset where
  name : String
  kind : Option PropertyKind := none
  grossValue : Option Money := none
  encumbrances : Option Money := none
  treatment : Option ValuationTreatment := none
  includedInPrimaryResidencePetition : Option Bool := none
  isPrimaryResidence : Option Bool := none
deriving DecidableEq, Repr

/-- Partially known estate. If `inventoryComplete` is not KNOWN true, capped
routes can be disqualified by a known-over-cap subtotal but can never
qualify. -/
structure PartialEstate where
  inventoryComplete : Option Bool := none
  assets : List PartialAsset
deriving DecidableEq, Repr

/-- Partially known transfer case, mirroring `TransferCase`. The target is
`estate.assets[targetIndex]`; the demo restriction fixes
`targetIsPartOfEstate := true`, which discharges `TransferCase.WellFormed`
structurally. -/
structure PartialTransferCase where
  deathDate : Option CivilDate := none
  daysSinceDeath : Option Nat := none
  sixMonthsElapsed : Option Bool := none
  claimantIsSuccessor : Option Bool := none
  noSuperiorRight : Option Bool := none
  funeralLastIllnessAndUnsecuredDebtsPaid : Option Bool := none
  authority : Option SummaryAuthority := none
  survivorStatus : Option SurvivorStatus := none
  propertyPassesToSurvivor : Option Bool := none
  propertyBelongsToSurvivor : Option Bool := none
  estate : PartialEstate
  targetIndex : Nat
deriving DecidableEq, Repr

-- `$1,234.56`-style rendering of integer cents.
namespace Money

private def groupRev : List Char → Nat → List Char
  | [], _ => []
  | c :: rest, i =>
    if i != 0 && i % 3 == 0 then
      ',' :: c :: groupRev rest (i + 1)
    else
      c :: groupRev rest (i + 1)

def formatUSD (amount : Money) : String :=
  let dollars := amount / 100
  let cents := amount % 100
  let grouped := String.ofList ((groupRev (toString dollars).toList.reverse 0).reverse)
  let centsStr := (if cents < 10 then "0" else "") ++ toString cents
  "$" ++ grouped ++ "." ++ centsStr

end Money

/-- First-occurrence-preserving deduplication. -/
private def dedupAux [BEq α] (seen : List α) : List α → List α
  | [] => []
  | x :: xs =>
    if seen.contains x then
      dedupAux seen xs
    else
      x :: dedupAux (x :: seen) xs

private def dedup [BEq α] (xs : List α) : List α := dedupAux [] xs

/-- Aggregate a route's atomic check results with the contract precedence:
violations beat unknowns beat satisfied. -/
def aggregate (checks : List AtomicResult) : RouteStatus :=
  let reasons := dedup <| checks.filterMap fun
    | .violated reason => some reason
    | _ => none
  if !reasons.isEmpty then
    .doesNotQualify reasons
  else
    let facts := dedup <| checks.foldl
      (fun acc check =>
        match check with
        | .unknown fs => acc ++ fs
        | _ => acc)
      []
    if !facts.isEmpty then
      .needsInformation facts
    else
      .qualifies

/-- JSON path for a field of asset `index`. -/
def assetFact (index : Nat) (field : String) : FactPath :=
  s!"estate.assets[{index}].{field}"

private def dq (id text : String) : Disqualifier := ⟨id, text⟩

/-- Check that an `Option Bool` fact is known true. -/
private def requiredTrue
    (value : Option Bool) (path : FactPath) (whenFalse : Disqualifier) :
    AtomicResult :=
  match value with
  | none => .unknown [path]
  | some true => .satisfied
  | some false => .violated whenFalse

/-- Partial evaluation of a per-asset valuation contribution: either a fully
known amount or the (lazy frontier of) unknown facts blocking it. -/
inductive PartialValue
  | known (value : Money)
  | needs (facts : List FactPath)
deriving BEq, DecidableEq, Repr

/-- The basis, if any, that a known treatment supplies for a direct transfer.
Reuses the baseline `Asset.directTransferBasis`, which depends only on the
treatment. -/
def treatmentBasis (treatment : ValuationTreatment) : Option DirectTransferBasis :=
  Asset.directTransferBasis
    { name := "", kind := .personal, grossValue := 0, treatment := treatment }

/-- Partial mirror of `Asset.personalAffidavitValue`. The per-asset
employment-compensation exclusion mirrors the baseline CODE (applied once per
asset), not the spec's future aggregate correction. -/
def PartialAsset.personalAffidavitContribution
    (thresholds : Thresholds) (index : Nat) (asset : PartialAsset) :
    PartialValue :=
  -- Exclusion condition of the baseline:
  --   kind == .outsideCaliforniaReal || includedInPrimaryResidencePetition
  let excluded : Option Bool :=
    match asset.kind, asset.includedInPrimaryResidencePetition with
    | some .outsideCaliforniaReal, _ => some true
    | _, some true => some true
    | some _, some false => some false
    | _, _ => none
  match excluded with
  | some true => .known 0
  | some false =>
    match asset.treatment with
    | none => .needs [assetFact index "treatment"]
    | some .counted =>
      match asset.grossValue with
      | none => .needs [assetFact index "gross_value_cents"]
      | some value => .known value
    | some .employmentCompensation =>
      match asset.grossValue with
      | none => .needs [assetFact index "gross_value_cents"]
      | some value =>
        .known (value - min value thresholds.employmentCompensationExclusion)
    | some _ => .known 0
  | none =>
    -- Exclusion condition unresolved; a known non-contributing treatment
    -- still settles the contribution at zero.
    match asset.treatment with
    | some .counted | some .employmentCompensation | none =>
      .needs <|
        (if asset.kind.isNone then [assetFact index "kind"] else []) ++
        (if asset.includedInPrimaryResidencePetition.isNone then
          [assetFact index "included_in_primary_residence_petition"]
        else [])
    | some _ => .known 0

/-- Gross value gated by boolean conditions that must all be known true
(mirrors the `if … then grossValue else 0` shape of the baseline). -/
private def gatedGross
    (index : Nat) (conditions : List (Option Bool × FactPath))
    (gross : Option Money) : PartialValue :=
  if conditions.any (fun c => c.1 == some false) then
    .known 0
  else
    let missing := conditions.filterMap fun c =>
      if c.1.isNone then some c.2 else none
    if missing.isEmpty then
      match gross with
      | some value => .known value
      | none => .needs [assetFact index "gross_value_cents"]
    else
      .needs missing

/-- Partial mirror of `Asset.countedCaliforniaRealValue`. -/
def PartialAsset.smallValueRealContribution
    (index : Nat) (asset : PartialAsset) : PartialValue :=
  gatedGross index
    [ (asset.kind.map (· == .californiaReal), assetFact index "kind"),
      (asset.treatment.map (· == .counted), assetFact index "treatment") ]
    asset.grossValue

/-- Partial mirror of `Asset.countedPrimaryResidenceValue`. -/
def PartialAsset.primaryResidenceContribution
    (index : Nat) (asset : PartialAsset) : PartialValue :=
  gatedGross index
    [ (asset.kind.map (· == .californiaReal), assetFact index "kind"),
      (asset.treatment.map (· == .counted), assetFact index "treatment"),
      (asset.isPrimaryResidence, assetFact index "is_primary_residence") ]
    asset.grossValue

/-- Known subtotal over the fully known assets plus the unknown facts of the
remaining ones. -/
structure PartialSubtotal where
  knownSubtotal : Money
  missing : List FactPath
deriving Repr

private def subtotalAux
    (per : Nat → PartialAsset → PartialValue) :
    Nat → List PartialAsset → PartialSubtotal
  | _, [] => { knownSubtotal := 0, missing := [] }
  | i, asset :: rest =>
    let s := subtotalAux per (i + 1) rest
    match per i asset with
    | .known value => { s with knownSubtotal := s.knownSubtotal + value }
    | .needs facts => { s with missing := facts ++ s.missing }

def PartialEstate.subtotalWith
    (estate : PartialEstate) (per : Nat → PartialAsset → PartialValue) :
    PartialSubtotal :=
  subtotalAux per 0 estate.assets

/-- The estate-valuation conjunct of a capped route under partial
information: a known subtotal already above the cap is `violated` even with
unknowns elsewhere; otherwise any needed unknown fact (including
`estate.inventory_complete` not known true) makes the check `unknown`.
Returns the check result and the qualifying detail line. -/
private def capCheck
    (thresholds? : Option Thresholds) (cap : Thresholds → Money)
    (inventoryComplete : Option Bool)
    (subtotalOf : Thresholds → PartialSubtotal)
    (overLimitId valueLabel : String) : AtomicResult × String :=
  match thresholds? with
  | none => (.unknown ["death_date"], "")
  | some thresholds =>
    let subtotal := subtotalOf thresholds
    if subtotal.knownSubtotal > cap thresholds then
      (.violated (dq overLimitId
        s!"Known {valueLabel} {Money.formatUSD subtotal.knownSubtotal} exceeds the {Money.formatUSD (cap thresholds)} limit"),
       "")
    else
      let inventoryFacts :=
        if inventoryComplete == some true then [] else ["estate.inventory_complete"]
      let missing := subtotal.missing ++ inventoryFacts
      if missing.isEmpty then
        (.satisfied,
         s!"Qualifying {valueLabel} {Money.formatUSD subtotal.knownSubtotal} ≤ {Money.formatUSD (cap thresholds)} limit")
      else
        (.unknown missing, "")

private def buildReport
    (route : RouteId) (checks : List AtomicResult) (qualifyingDetail : String) :
    RouteReport :=
  let status := aggregate checks
  { route := route
    status := status
    detail := if status == .qualifies then qualifyingDetail else "" }

/-- Assess all six routes of a partial case. Structural problems (invalid or
post-snapshot death date, out-of-range target index, duplicate asset names)
are typed errors, never legal conclusions. -/
def assessRoutes (c : PartialTransferCase) : Except CaseError CaseAssessment := do
  -- Structural validation: a KNOWN death date must be valid and supported.
  match c.deathDate with
  | some date =>
    match classifyDeathDate date with
    | .error .invalidDate => throw CaseError.invalidDate
    | .error .afterSnapshot => throw CaseError.afterSnapshot
    | .ok _ => pure ()
  | none => pure ()
  -- Structural validation: the target must be one of the listed assets.
  let some target := c.estate.assets[c.targetIndex]?
    | throw (CaseError.malformedCase
        s!"target_index {c.targetIndex} is out of range for estate.assets (length {c.estate.assets.length})")
  -- Structural validation: asset names identify assets, so must be unique.
  let names := c.estate.assets.map (·.name)
  if (dedup names).length != names.length then
    throw (CaseError.malformedCase "asset names must be unique within estate.assets")
  let thresholds? : Option Thresholds :=
    c.deathDate.bind fun date => (thresholdsFor date).toOption
  -- Conjuncts shared by several routes.
  -- `SupportedDeathDate`: validity was established above, so a known date
  -- satisfies it and an unknown date leaves it unknown.
  let supportedDate : AtomicResult :=
    if c.deathDate.isSome then .satisfied else .unknown ["death_date"]
  -- `TransferCase.WellFormed` and `targetIsPartOfEstate = true` are
  -- discharged structurally: the target IS estate.assets[target_index]
  -- (demo restriction `targetIsPartOfEstate := true`).
  let wellFormed : AtomicResult := .satisfied
  let partOfEstate : AtomicResult := .satisfied
  let claimant := requiredTrue c.claimantIsSuccessor "claimant_is_successor"
    (dq "claimant_not_successor"
      "The claimant is not the decedent's successor in interest")
  let noSuperior := requiredTrue c.noSuperiorRight "no_superior_right"
    (dq "superior_right_exists"
      "Someone else has a superior right to the property")
  let waitingPeriod : AtomicResult :=
    match c.daysSinceDeath with
    | none => .unknown ["days_since_death"]
    | some days =>
      if 40 ≤ days then .satisfied
      else .violated (dq "waiting_period_not_met"
        "Fewer than 40 days have passed since death")
  let authorityPermits : AtomicResult :=
    match c.authority with
    | none => .unknown ["authority"]
    | some .blockedByProceeding =>
      .violated (dq "blocked_by_pending_proceeding"
        "A pending probate proceeding blocks summary transfer")
    | some _ => .satisfied
  -- Route: direct_transfer — conjuncts of `DirectTransferEligible`.
  let (basisCheck, basisDetail) :=
    match target.treatment with
    | none =>
      (AtomicResult.unknown [assetFact c.targetIndex "treatment"], "")
    | some treatment =>
      match treatmentBasis treatment with
      | some basis =>
        (AtomicResult.satisfied, s!"Direct transfer basis: {basis.wireName}")
      | none =>
        (AtomicResult.violated (dq "no_direct_transfer_basis"
          "The target asset's valuation treatment provides no direct transfer basis"),
         "")
  let directReport := buildReport .directTransfer
    [supportedDate, wellFormed, basisCheck] basisDetail
  -- Route: personal_property_affidavit — conjuncts of
  -- `PersonalPropertyAffidavitEligible`.
  let targetPersonal : AtomicResult :=
    match target.kind with
    | none => .unknown [assetFact c.targetIndex "kind"]
    | some .personal => .satisfied
    | some _ =>
      .violated (dq "target_not_personal_property"
        "The target asset is not personal property")
  let (personalValueCheck, personalDetail) :=
    capCheck thresholds? (·.personalPropertyAffidavit) c.estate.inventoryComplete
      (fun thresholds =>
        c.estate.subtotalWith
          (PartialAsset.personalAffidavitContribution thresholds))
      "value_over_limit" "personal-property value"
  let personalReport := buildReport .personalPropertyAffidavit
    [supportedDate, wellFormed, targetPersonal, partOfEstate, claimant,
     noSuperior, waitingPeriod, authorityPermits, personalValueCheck]
    personalDetail
  -- Route: small_value_real_property_affidavit — conjuncts of
  -- `SmallValueRealPropertyAffidavitEligible`.
  let targetCaliforniaReal : AtomicResult :=
    match target.kind with
    | none => .unknown [assetFact c.targetIndex "kind"]
    | some .californiaReal => .satisfied
    | some _ =>
      .violated (dq "target_not_california_real_property"
        "The target asset is not California real property")
  let targetCounted : AtomicResult :=
    match target.treatment with
    | none => .unknown [assetFact c.targetIndex "treatment"]
    | some .counted => .satisfied
    | some _ =>
      .violated (dq "target_not_counted"
        "The target asset's valuation treatment is not counted")
  let sixMonths := requiredTrue c.sixMonthsElapsed "six_months_elapsed"
    (dq "six_month_period_not_met" "Six months have not elapsed since death")
  let debtsPaid := requiredTrue c.funeralLastIllnessAndUnsecuredDebtsPaid
    "funeral_last_illness_and_unsecured_debts_paid"
    (dq "debts_not_paid"
      "Funeral, last-illness, and unsecured debts are not all paid")
  let (smallValueCheck, smallValueDetail) :=
    capCheck thresholds? (·.smallValueRealPropertyAffidavit)
      c.estate.inventoryComplete
      (fun _ => c.estate.subtotalWith PartialAsset.smallValueRealContribution)
      "value_over_limit" "counted California real-property value"
  let smallValueReport := buildReport .smallValueRealPropertyAffidavit
    [supportedDate, wellFormed, targetCaliforniaReal, targetCounted,
     partOfEstate, claimant, noSuperior, sixMonths, authorityPermits,
     debtsPaid, smallValueCheck]
    smallValueDetail
  -- Route: primary_residence_petition — conjuncts of
  -- `PrimaryResidencePetitionEligible`.
  let targetPrimaryResidence := requiredTrue target.isPrimaryResidence
    (assetFact c.targetIndex "is_primary_residence")
    (dq "target_not_primary_residence"
      "The target asset is not the decedent's primary residence")
  let (primaryValueCheck, primaryValueDetail) :=
    capCheck thresholds? (·.primaryResidencePetition) c.estate.inventoryComplete
      (fun _ => c.estate.subtotalWith PartialAsset.primaryResidenceContribution)
      "value_over_limit" "primary-residence value"
  let primaryReport := buildReport .primaryResidencePetition
    [supportedDate, wellFormed, targetCaliforniaReal, targetCounted,
     targetPrimaryResidence, partOfEstate, claimant, waitingPeriod,
     authorityPermits, primaryValueCheck]
    primaryValueDetail
  -- Route: spousal_property_petition — conjuncts of
  -- `SpousalPropertyPetitionEligible`.
  let survivorExists : AtomicResult :=
    match c.survivorStatus with
    | none => .unknown ["survivor_status"]
    | some SurvivorStatus.none =>
      .violated (dq "no_surviving_spouse_or_partner"
        "There is no surviving spouse or registered domestic partner")
    | some _ => .satisfied
  let passesOrBelongs : AtomicResult :=
    match c.propertyPassesToSurvivor, c.propertyBelongsToSurvivor with
    | some true, _ => .satisfied
    | _, some true => .satisfied
    | some false, some false =>
      .violated (dq "property_not_community_or_survivor"
        "The property neither passes to nor belongs to the surviving spouse or partner")
    | passes, belongs =>
      .unknown <|
        (if passes.isNone then ["property_passes_to_survivor"] else []) ++
        (if belongs.isNone then ["property_belongs_to_survivor"] else [])
  let spousalReport := buildReport .spousalPropertyPetition
    [supportedDate, wellFormed, survivorExists, passesOrBelongs]
    "Property passes to or belongs to the surviving spouse or registered domestic partner"
  -- Fallback row + overall outcome (contract precedence: any qualifying
  -- simplified route → available; else any needs-information → unresolved;
  -- else fallback).
  let simplified :=
    [directReport, personalReport, smallValueReport, primaryReport,
     spousalReport]
  let anyQualifies := simplified.any fun report => report.status == .qualifies
  let unresolvedFacts := dedup <| simplified.foldl
    (fun acc report =>
      match report.status with
      | .needsInformation facts => acc ++ facts
      | _ => acc)
    []
  let fallbackReport : RouteReport :=
    if anyQualifies then
      { route := .formalProbateOrOtherProcedure
        status := .doesNotQualify
          [dq "simplified_route_available"
            "At least one simplified route qualifies"]
        detail := "" }
    else if unresolvedFacts.isEmpty then
      { route := .formalProbateOrOtherProcedure
        status := .qualifies
        detail := "No simplified route qualifies; formal probate or another procedure is required" }
    else
      { route := .formalProbateOrOtherProcedure
        status := .needsInformation unresolvedFacts
        detail := "" }
  let overall : OverallOutcome :=
    if anyQualifies then .simplifiedRoutesAvailable
    else if unresolvedFacts.isEmpty then .formalProbateOrOtherProcedure
    else .unresolved
  pure { routes := simplified ++ [fallbackReport], overall := overall }

/-- Status of one route in an assessment result (`none` on case error or if
the route row is absent). -/
def routeStatus
    (result : Except CaseError CaseAssessment) (route : RouteId) :
    Option RouteStatus :=
  match result with
  | .error _ => none
  | .ok assessment =>
    (assessment.routes.find? fun report => report.route == route).map (·.status)

/-- Overall outcome of an assessment result (`none` on case error). -/
def overallOf : Except CaseError CaseAssessment → Option OverallOutcome
  | .error _ => none
  | .ok assessment => some assessment.overall

/-! ## Compile-time regression examples -/

namespace PartialExamples

/-- Fully known asset: counted personal property exactly at the
2025-band personal-property cap. -/
def knownPersonalAsset : PartialAsset := {
  name := "account"
  kind := some .personal
  grossValue := some (Money.dollars 208_850)
  encumbrances := some 0
  treatment := some .counted
  includedInPrimaryResidencePetition := some false
  isPrimaryResidence := some false
}

/-- Fully known eligible personal-property-affidavit case (mirrors the
baseline `base2026Case`). -/
def knownEligibleCase : PartialTransferCase := {
  deathDate := some ⟨2026, 1, 1⟩
  daysSinceDeath := some 40
  sixMonthsElapsed := some false
  claimantIsSuccessor := some true
  noSuperiorRight := some true
  funeralLastIllnessAndUnsecuredDebtsPaid := some true
  authority := some .noProceeding
  survivorStatus := some SurvivorStatus.none
  propertyPassesToSurvivor := some false
  propertyBelongsToSurvivor := some false
  estate := { inventoryComplete := some true, assets := [knownPersonalAsset] }
  targetIndex := 0
}

/-- The corresponding total baseline case. -/
def totalPersonalAsset : Asset := {
  name := "account"
  kind := .personal
  grossValue := Money.dollars 208_850
  encumbrances := 0
  treatment := .counted
}

def totalEligibleCase : TransferCase := {
  deathDate := ⟨2026, 1, 1⟩
  estate := { assets := [totalPersonalAsset] }
  target := totalPersonalAsset
  targetIsPartOfEstate := true
  authority := .noProceeding
  daysSinceDeath := 40
  sixMonthsElapsed := false
  claimantIsSuccessor := true
  noSuperiorRight := true
  funeralLastIllnessAndUnsecuredDebtsPaid := true
  survivorStatus := .none
  propertyPassesToSurvivor := false
  propertyBelongsToSurvivor := false
}

-- Fully known eligible case ⇒ the personal-property affidavit qualifies.
example :
    routeStatus (assessRoutes knownEligibleCase) .personalPropertyAffidavit =
      some .qualifies := by decide

example :
    overallOf (assessRoutes knownEligibleCase) =
      some .simplifiedRoutesAvailable := by decide

-- Unknown counted value ⇒ needs_information naming exactly that fact.
def unknownValueCase : PartialTransferCase := {
  knownEligibleCase with
  estate := {
    inventoryComplete := some true
    assets := [{ knownPersonalAsset with grossValue := none }]
  }
}

example :
    routeStatus (assessRoutes unknownValueCase) .personalPropertyAffidavit =
      some (.needsInformation ["estate.assets[0].gross_value_cents"]) := by
  decide

example :
    overallOf (assessRoutes unknownValueCase) = some .unresolved := by decide

-- Known subtotal over the cap ⇒ does_not_qualify even though another value
-- (and the inventory) is unknown: violations beat unknowns.
def overCapWithUnknownsCase : PartialTransferCase := {
  knownEligibleCase with
  estate := {
    inventoryComplete := none
    assets := [
      { knownPersonalAsset with
        grossValue := some (Money.dollars 208_850 + 100) },
      { knownPersonalAsset with name := "second account", grossValue := none }
    ]
  }
}

example :
    (routeStatus (assessRoutes overCapWithUnknownsCase)
        .personalPropertyAffidavit).map (·.disqualifierIds) =
      some ["value_over_limit"] := by decide

example :
    overallOf (assessRoutes overCapWithUnknownsCase) =
      some .formalProbateOrOtherProcedure := by decide

-- Inventory not confirmed ⇒ capped routes cannot qualify even with all
-- values known and under the cap.
def inventoryUnknownCase : PartialTransferCase := {
  knownEligibleCase with
  estate := { inventoryComplete := none, assets := [knownPersonalAsset] }
}

example :
    routeStatus (assessRoutes inventoryUnknownCase) .personalPropertyAffidavit =
      some (.needsInformation ["estate.inventory_complete"]) := by decide

-- Structural errors are typed errors, not verdicts.
example :
    assessRoutes { knownEligibleCase with deathDate := some ⟨2027, 3, 1⟩ } =
      .error .afterSnapshot := by decide

example :
    assessRoutes { knownEligibleCase with deathDate := some ⟨2026, 2, 29⟩ } =
      .error .invalidDate := by decide

example :
    assessRoutes { knownEligibleCase with targetIndex := 1 } =
      .error (.malformedCase
        "target_index 1 is out of range for estate.assets (length 1)") := by
  decide

/-! Total-case agreement with the baseline `RouteEligible` predicates on
three concrete cases. -/

-- Agreement 1: fully known eligible case.
example :
    (routeStatus (assessRoutes knownEligibleCase) .personalPropertyAffidavit =
        some .qualifies) ↔
      PersonalPropertyAffidavitEligible totalEligibleCase := by decide

-- Agreement 2: waiting period not met (20 days) — both engines reject.
def tooSoonPartialCase : PartialTransferCase :=
  { knownEligibleCase with daysSinceDeath := some 20 }

def tooSoonTotalCase : TransferCase :=
  { totalEligibleCase with daysSinceDeath := 20 }

example :
    (routeStatus (assessRoutes tooSoonPartialCase) .personalPropertyAffidavit =
        some .qualifies) ↔
      PersonalPropertyAffidavitEligible tooSoonTotalCase := by decide

example :
    (routeStatus (assessRoutes tooSoonPartialCase)
        .personalPropertyAffidavit).map (·.disqualifierIds) =
      some ["waiting_period_not_met"] := by decide

-- Agreement 3: spousal-property petition with a surviving spouse.
def spousalPartialCase : PartialTransferCase := {
  knownEligibleCase with
  survivorStatus := some .spouse
  propertyPassesToSurvivor := some true
}

def spousalTotalCase : TransferCase := {
  totalEligibleCase with
  survivorStatus := .spouse
  propertyPassesToSurvivor := true
}

example :
    (routeStatus (assessRoutes spousalPartialCase) .spousalPropertyPetition =
        some .qualifies) ↔
      SpousalPropertyPetitionEligible spousalTotalCase := by decide

example :
    overallOf (assessRoutes spousalPartialCase) =
      some .simplifiedRoutesAvailable := by decide

end PartialExamples

end SimpleProbate
