import Lean.Data.Json
import SimpleProbate.Eligibility

/-!
# Exact probate JSON adapter

This module is a wire adapter only. It decodes JSON into the exact
`PartialTransferCase`, delegates every eligibility decision to `assessRoutes`,
and projects the eleven exact route reports to the demo's stable six-row
format.
-/

namespace SimpleProbate
namespace Api

open Lean (Json)

private def knowledgeOfOption : Option α → Knowledge α
  | none => .unknown
  | some value => .known value

/-- Object field lookup where an absent key and explicit `null` both mean
unknown. -/
def optField (json : Json) (key : String) : Option Json :=
  match json.getObjVal? key with
  | .ok Json.null => none
  | .ok value => some value
  | .error _ => none

def asBool (path : String) (json : Json) : Except String Bool :=
  match json with
  | .bool value => .ok value
  | _ => .error s!"{path} must be a boolean or null"

def asNat (path : String) (json : Json) : Except String Nat :=
  match json with
  | .num number =>
      if number.exponent == 0 then
        if number.mantissa < 0 then
          .error s!"{path} must be a non-negative integer"
        else
          .ok number.mantissa.toNat
      else
        .error s!"{path} must be an integer"
  | _ => .error s!"{path} must be an integer or null"

def asString (path : String) (json : Json) : Except String String :=
  match json with
  | .str value => .ok value
  | _ => .error s!"{path} must be a string or null"

def optBoolField
    (json : Json) (path key : String) : Except String (Option Bool) :=
  match optField json key with
  | none => .ok none
  | some value => (asBool s!"{path}{key}" value).map some

def optNatField
    (json : Json) (path key : String) : Except String (Option Nat) :=
  match optField json key with
  | none => .ok none
  | some value => (asNat s!"{path}{key}" value).map some

def parseKind (path value : String) : Except String PropertyKind :=
  match value with
  | "personal" => .ok .personal
  | "california_real" => .ok .californiaReal
  | "outside_california_real" => .ok .outsideCaliforniaReal
  | _ => .error s!"{path}: unknown property kind '{value}'"

def parseTreatment
    (path value : String) : Except String ValuationTreatment :=
  match value with
  | "counted" => .ok .counted
  | "joint_tenancy" => .ok .jointTenancy
  | "terminable_at_death" => .ok .terminableAtDeath
  | "revocable_trust" => .ok .revocableTrust
  | "spouse_passage" => .ok .spousePassage
  | "multiple_party_survivor" => .ok .multiplePartySurvivor
  | "registered_vehicle" => .ok .registeredVehicle
  | "vessel" => .ok .vessel
  | "registered_home" => .ok .registeredHome
  | "direct_beneficiary" => .ok .directBeneficiary
  | "transfer_on_death" => .ok .transferOnDeath
  | "government_benefit" => .ok .governmentBenefit
  | "military_compensation" => .ok .militaryCompensation
  | "employment_compensation" => .ok .employmentCompensation
  | _ => .error s!"{path}: unknown valuation treatment '{value}'"

def parseAuthority
    (path value : String) : Except String SummaryAuthority :=
  match value with
  | "no_proceeding" => .ok .noProceeding
  | "written_personal_representative_consent" =>
      .ok .writtenPersonalRepresentativeConsent
  | "blocked_by_proceeding" => .ok .blockedByProceeding
  | _ => .error s!"{path}: unknown authority '{value}'"

def parseSurvivorStatus
    (path value : String) : Except String SurvivorStatus :=
  match value with
  | "none" => .ok SurvivorStatus.none
  | "spouse" => .ok .spouse
  | "registered_domestic_partner" => .ok .registeredDomesticPartner
  | _ => .error s!"{path}: unknown survivor status '{value}'"

def decodeDeathDate (json : Json) : Except String CivilDate := do
  let .obj _ := json | throw "death_date must be an object or null"
  let year ← match optField json "year" with
    | some value => asNat "death_date.year" value
    | none => throw "death_date.year is required"
  let month ← match optField json "month" with
    | some value => asNat "death_date.month" value
    | none => throw "death_date.month is required"
  let day ← match optField json "day" with
    | some value => asNat "death_date.day" value
    | none => throw "death_date.day is required"
  pure ⟨year, month, day⟩

def decodeAsset (index : Nat) (json : Json) : Except String PartialAsset := do
  let path := s!"estate.assets[{index}]."
  let .obj _ := json | throw s!"estate.assets[{index}] must be an object"
  let name ← match optField json "name" with
    | some value => asString s!"{path}name" value
    | none => throw s!"{path}name is required"
  let kind ← match optField json "kind" with
    | none => pure none
    | some value => do
        let text ← asString s!"{path}kind" value
        (parseKind s!"{path}kind" text).map some
  let legacyGrossValueField ← optNatField json path "gross_value_cents"
  let currentGrossValueField ←
    optNatField json path "current_gross_value_cents"
  let dateOfDeathValueField ←
    optNatField json path "date_of_death_value_cents"
  let currentValue :=
    match currentGrossValueField with
    | some value => some value
    | none => legacyGrossValueField
  let dateOfDeathValue :=
    match dateOfDeathValueField with
    | some value => some value
    | none => legacyGrossValueField
  let encumbrances ← optNatField json path "encumbrances_cents"
  let treatment ← match optField json "treatment" with
    | none => pure none
    | some value => do
        let text ← asString s!"{path}treatment" value
        (parseTreatment s!"{path}treatment" text).map some
  let includedInPrimaryResidencePetition ←
    optBoolField json path "included_in_primary_residence_petition"
  let isPrimaryResidence ←
    optBoolField json path "is_primary_residence"
  pure {
    id := ⟨index⟩
    name
    kind := knowledgeOfOption kind
    currentGrossValue := knowledgeOfOption currentValue
    dateOfDeathValue := knowledgeOfOption dateOfDeathValue
    encumbrances := knowledgeOfOption encumbrances
    treatment := knowledgeOfOption treatment
    includedInPrimaryResidencePetition :=
      knowledgeOfOption includedInPrimaryResidencePetition
    isPrimaryResidence := knowledgeOfOption isPrimaryResidence
  }

private def decodeAssetList
    (assets : List Json) : Except String (List PartialAsset) :=
  let rec go (index : Nat) : List Json → Except String (List PartialAsset)
    | [] => .ok []
    | asset :: rest => do
        let decoded ← decodeAsset index asset
        let tail ← go (index + 1) rest
        pure (decoded :: tail)
  go 0 assets

/-- Decode the demo input directly into the exact partial case. -/
def decodeCase (json : Json) : Except String PartialTransferCase := do
  let .obj _ := json | throw "case must be a JSON object"
  let deathDate ← match optField json "death_date" with
    | none => pure none
    | some value => (decodeDeathDate value).map some
  let daysSinceDeath ← optNatField json "" "days_since_death"
  let sixMonthsElapsed ← optBoolField json "" "six_months_elapsed"
  let claimantIsSuccessor ←
    optBoolField json "" "claimant_is_successor"
  let noSuperiorRight ← optBoolField json "" "no_superior_right"
  let funeralLastIllnessAndUnsecuredDebtsPaid ←
    optBoolField json "" "funeral_last_illness_and_unsecured_debts_paid"
  let authority ← match optField json "authority" with
    | none => pure none
    | some value => do
        let text ← asString "authority" value
        (parseAuthority "authority" text).map some
  let survivorStatus ← match optField json "survivor_status" with
    | none => pure none
    | some value => do
        let text ← asString "survivor_status" value
        (parseSurvivorStatus "survivor_status" text).map some
  let propertyPassesToSurvivor ←
    optBoolField json "" "property_passes_to_survivor"
  let propertyBelongsToSurvivor ←
    optBoolField json "" "property_belongs_to_survivor"
  let estateJson ← match optField json "estate" with
    | some value => pure value
    | none => throw "estate is required"
  let .obj _ := estateJson | throw "estate must be a JSON object"
  let inventoryComplete ←
    optBoolField estateJson "estate." "inventory_complete"
  let assetsJson ← match optField estateJson "assets" with
    | some value =>
        match value.getArr? with
        | .ok array => pure array.toList
        | .error _ => throw "estate.assets must be an array"
    | none => throw "estate.assets is required"
  let assets ← decodeAssetList assetsJson
  let targetIndex ← match optField json "target_index" with
    | some value => asNat "target_index" value
    | none => throw "target_index is required"
  if targetIndex < assets.length then
    pure {
      deathDate := knowledgeOfOption deathDate
      estate := {
        assets
        inventoryComplete := knowledgeOfOption inventoryComplete
      }
      targetId := .known ⟨targetIndex⟩
      authority := knowledgeOfOption authority
      daysSinceDeath := knowledgeOfOption daysSinceDeath
      sixMonthsElapsed := knowledgeOfOption sixMonthsElapsed
      claimantIsSuccessor := knowledgeOfOption claimantIsSuccessor
      noSuperiorRight := knowledgeOfOption noSuperiorRight
      funeralLastIllnessAndUnsecuredDebtsPaid :=
        knowledgeOfOption funeralLastIllnessAndUnsecuredDebtsPaid
      survivorStatus := knowledgeOfOption survivorStatus
      propertyPassesToSurvivor :=
        knowledgeOfOption propertyPassesToSurvivor
      propertyBelongsToSurvivor :=
        knowledgeOfOption propertyBelongsToSurvivor
    }
  else
    throw s!"target_index {targetIndex} is out of range for estate.assets (length {assets.length})"

instance : Lean.FromJson PartialTransferCase := ⟨decodeCase⟩

inductive WireRouteId
  | directTransfer
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
  | formalProbateOrOtherProcedure
deriving BEq, DecidableEq, Repr

structure WireReason where
  id : String
  text : String
deriving BEq, DecidableEq, Repr

inductive WireRouteStatus
  | qualifies
  | doesNotQualify (reasons : List WireReason)
  | needsInformation (facts : List String)
deriving BEq, DecidableEq, Repr

structure WireRouteReport where
  route : WireRouteId
  status : WireRouteStatus
  detail : String
  forms : List String
deriving BEq, DecidableEq, Repr

def WireRouteId.wireName : WireRouteId → String
  | .directTransfer => "direct_transfer"
  | .personalPropertyAffidavit => "personal_property_affidavit"
  | .smallValueRealPropertyAffidavit =>
      "small_value_real_property_affidavit"
  | .primaryResidencePetition => "primary_residence_petition"
  | .spousalPropertyPetition => "spousal_property_petition"
  | .formalProbateOrOtherProcedure =>
      "formal_probate_or_other_procedure"

def WireRouteId.forms : WireRouteId → List String
  | .directTransfer => []
  | .personalPropertyAffidavit => []
  | .smallValueRealPropertyAffidavit => ["DE-305"]
  | .primaryResidencePetition => ["DE-310", "DE-315"]
  | .spousalPropertyPetition => ["DE-221", "DE-226"]
  | .formalProbateOrOtherProcedure => ["DE-111"]

def directTransferBasisWireName : DirectTransferBasis → String
  | .governmentBenefit => "government_benefit"
  | .namedBeneficiary => "named_beneficiary"
  | .revocableTrust => "revocable_trust"
  | .jointTenancy => "joint_tenancy"
  | .transferOnDeath => "transfer_on_death"
  | .multiplePartyAccount => "multiple_party_account"
  | .spousePassage => "spouse_passage"

private def assetPath (id : AssetId) (field : String) : String :=
  s!"estate.assets[{id.value}].{field}"

def factPath : EligibilityFact → String
  | .deathDate => "death_date"
  | .targetAsset => "target_index"
  | .inventoryComplete => "estate.inventory_complete"
  | .assetField id .kind => assetPath id "kind"
  | .assetField id .currentGrossValue =>
      assetPath id "current_gross_value_cents"
  | .assetField id .dateOfDeathValue =>
      assetPath id "date_of_death_value_cents"
  | .assetField id .treatment => assetPath id "treatment"
  | .assetField id .primaryResidence =>
      assetPath id "is_primary_residence"
  | .assetField id .primaryPetitionInclusion =>
      assetPath id "included_in_primary_residence_petition"
  | .authority => "authority"
  | .daysSinceDeath => "days_since_death"
  | .sixMonthsElapsed => "six_months_elapsed"
  | .claimantIsSuccessor => "claimant_is_successor"
  | .noSuperiorRight => "no_superior_right"
  | .debtsPaid =>
      "funeral_last_illness_and_unsecured_debts_paid"
  | .survivorStatus => "survivor_status"
  | .propertyPassesToSurvivor => "property_passes_to_survivor"
  | .propertyBelongsToSurvivor => "property_belongs_to_survivor"

private def wireReason (id text : String) : WireReason := ⟨id, text⟩

def failureReason : EligibilityFailure → WireReason
  | .directTransferBasisAbsent _ =>
      wireReason "no_direct_transfer_basis"
        "The target asset has no qualifying direct-transfer basis"
  | .targetNotPersonalProperty =>
      wireReason "target_not_personal_property"
        "The target asset is not personal property"
  | .targetNotCaliforniaRealProperty =>
      wireReason "target_not_california_real_property"
        "The target asset is not California real property"
  | .targetNotCounted =>
      wireReason "target_not_counted"
        "The target asset's valuation treatment is not counted"
  | .targetNotPrimaryResidence =>
      wireReason "target_not_primary_residence"
        "The target asset is not the decedent's primary residence"
  | .claimantNotSuccessor =>
      wireReason "claimant_not_successor"
        "The claimant is not the decedent's successor in interest"
  | .superiorRightExists =>
      wireReason "superior_right_exists"
        "Someone else has a superior right to the property"
  | .fortyDaysNotElapsed =>
      wireReason "waiting_period_not_met"
        "Fewer than 40 days have passed since death"
  | .sixMonthsNotElapsed =>
      wireReason "six_month_period_not_met"
        "Six months have not elapsed since death"
  | .blockedByProceeding =>
      wireReason "blocked_by_pending_proceeding"
        "A pending probate proceeding blocks summary transfer"
  | .requiredDebtsUnpaid =>
      wireReason "debts_not_paid"
        "Funeral, last-illness, and unsecured debts are not all paid"
  | .personalPropertyValueOverCap value cap =>
      wireReason "value_over_limit"
        s!"Personal-property value {value} cents exceeds the {cap}-cent cap"
  | .smallRealPropertyValueOverCap value cap =>
      wireReason "value_over_limit"
        s!"Counted California real-property value {value} cents exceeds the {cap}-cent cap"
  | .primaryResidenceValueOverCap value cap =>
      wireReason "value_over_limit"
        s!"Primary-residence value {value} cents exceeds the {cap}-cent cap"
  | .noSurvivingSpouseOrPartner =>
      wireReason "no_surviving_spouse_or_partner"
        "There is no surviving spouse or registered domestic partner"
  | .propertyNeitherPassesNorBelongsToSurvivor =>
      wireReason "property_not_community_or_survivor"
        "The property neither passes to nor belongs to the surviving spouse or partner"

def structuralIssueDetail : StructuralIssue → String
  | .duplicateAssetId id => s!"duplicate asset id {id.value}"
  | .missingTargetAsset id => s!"missing target asset id {id.value}"
  | .primaryResidenceNotCaliforniaReal id =>
      s!"asset {id.value} is marked as the primary residence but is not California real property"
  | .petitionAssetNotCaliforniaReal id =>
      s!"asset {id.value} is included in a primary-residence petition but is not California real property"
  | .petitionAssetNotPrimaryResidence id =>
      s!"asset {id.value} is included in a primary-residence petition but is not marked as the primary residence"

private def mappedStatus
    (status : DecisionStatus EligibilityFact EligibilityFailure) :
    WireRouteStatus :=
  match status with
  | .qualifies => .qualifies
  | .doesNotQualify reasons =>
      .doesNotQualify (reasons.map failureReason)
  | .needsInformation facts =>
      .needsInformation (facts.map factPath)

private def qualifyingDetail : WireRouteId → String
  | .personalPropertyAffidavit =>
      "The personal-property affidavit requirements are satisfied"
  | .smallValueRealPropertyAffidavit =>
      "The small-value real-property affidavit requirements are satisfied"
  | .primaryResidencePetition =>
      "The primary-residence petition requirements are satisfied"
  | .spousalPropertyPetition =>
      "The spousal-property petition requirements are satisfied"
  | _ => ""

def courtReport (report : RouteReport) : Option WireRouteReport :=
  let route? : Option WireRouteId :=
    match report.route with
    | .directTransfer _ => none
    | .personalPropertyAffidavit => some .personalPropertyAffidavit
    | .smallValueRealPropertyAffidavit =>
        some .smallValueRealPropertyAffidavit
    | .primaryResidencePetition => some .primaryResidencePetition
    | .spousalPropertyPetition => some .spousalPropertyPetition
  route?.map fun route =>
    let status := mappedStatus report.status
    {
      route
      status
      detail :=
        match status with
        | .qualifies => qualifyingDetail route
        | _ => ""
      forms := route.forms
    }

private def directBasis? (report : RouteReport) : Option DirectTransferBasis :=
  match report.route with
  | .directTransfer basis => some basis
  | _ => none

private def directFacts
    (reports : List RouteReport) : List String :=
  reports.flatMap fun report =>
    match directBasis? report, report.status with
    | some _, .needsInformation facts => facts.map factPath
    | _, _ => []

def directReport (reports : List RouteReport) : WireRouteReport :=
  let qualifyingBases := reports.filterMap fun report =>
    match directBasis? report, report.status with
    | some basis, .qualifies => some basis
    | _, _ => none
  let status :=
    match qualifyingBases with
    | _ :: _ => WireRouteStatus.qualifies
    | [] =>
        match dedupStable (directFacts reports) with
        | fact :: facts => .needsInformation (fact :: facts)
        | [] => .doesNotQualify [
            wireReason "no_direct_transfer_basis"
              "The target asset has no qualifying direct-transfer basis"
          ]
  {
    route := .directTransfer
    status
    detail :=
      match status with
      | .qualifies =>
          String.intercalate ", "
            (qualifyingBases.map directTransferBasisWireName)
      | _ => ""
    forms := []
  }

private def fallbackFacts (assessment : CaseAssessment) : List String :=
  dedupStable <| assessment.routes.flatMap fun report =>
    match report.status with
    | .needsInformation facts => facts.map factPath
    | _ => []

def fallbackReport (assessment : CaseAssessment) : WireRouteReport :=
  let status :=
    match assessment.overall with
    | .formalProbateOrOtherProcedure => WireRouteStatus.qualifies
    | .unresolved =>
        .needsInformation (fallbackFacts assessment)
    | .simplifiedRoutesAvailable =>
        .doesNotQualify [
          wireReason "simplified_route_available"
            "At least one simplified transfer route qualifies"
        ]
  {
    route := .formalProbateOrOtherProcedure
    status
    detail :=
      match status with
      | .qualifies =>
          "No simplified route qualifies; formal probate or another procedure is required"
      | _ => ""
    forms := WireRouteId.formalProbateOrOtherProcedure.forms
  }

private def missingCourtReport (route : WireRouteId) : WireRouteReport := {
  route
  status := .needsInformation []
  detail := ""
  forms := route.forms
}

private def selectCourtReport
    (reports : List WireRouteReport) (route : WireRouteId) :
    WireRouteReport :=
  match reports.find? (fun report => report.route == route) with
  | some report => report
  | none => missingCourtReport route

/-- Project an assessment returned by `assessRoutes` to the stable six-row wire
contract. `assessRoutes_routes_exact` guarantees that such an assessment has
every simplified route exactly once, so `missingCourtReport` is unreachable on
the public execution path. It remains a total-function fallback for callers
that manually fabricate a `CaseAssessment` without that invariant. -/
def projectAssessment
    (assessment : CaseAssessment) : List WireRouteReport :=
  let courts := assessment.routes.filterMap courtReport
  [
    directReport assessment.routes,
    selectCourtReport courts .personalPropertyAffidavit,
    selectCourtReport courts .smallValueRealPropertyAffidavit,
    selectCourtReport courts .primaryResidencePetition,
    selectCourtReport courts .spousalPropertyPetition,
    fallbackReport assessment
  ]

def wireReasonJson (reason : WireReason) : Json :=
  Json.mkObj [
    ("id", Json.str reason.id),
    ("text", Json.str reason.text)
  ]

def wireRouteReportJson (report : WireRouteReport) : Json :=
  let (status, reasons, missingFacts) :=
    match report.status with
    | .qualifies =>
        ("qualifies", ([] : List WireReason), ([] : List String))
    | .doesNotQualify reasons =>
        ("does_not_qualify", reasons, [])
    | .needsInformation facts =>
        ("needs_information", [], facts)
  Json.mkObj [
    ("route", Json.str report.route.wireName),
    ("status", Json.str status),
    ("reasons", Json.arr (reasons.map wireReasonJson).toArray),
    ("missing_facts", Json.arr (missingFacts.map Json.str).toArray),
    ("detail", Json.str report.detail),
    ("forms", Json.arr (report.forms.map Json.str).toArray)
  ]

instance : Lean.ToJson WireRouteReport := ⟨wireRouteReportJson⟩

def overallOutcomeWireName : OverallOutcome → String
  | .simplifiedRoutesAvailable => "simplified_routes_available"
  | .unresolved => "unresolved"
  | .formalProbateOrOtherProcedure =>
      "formal_probate_or_other_procedure"

def verdictFor : OverallOutcome → String
  | .simplifiedRoutesAvailable => "ELIGIBLE"
  | .unresolved => "INCOMPLETE_INFO"
  | .formalProbateOrOtherProcedure => "OTHER_FORM_REQUIRED"

def summaryFor (assessment : CaseAssessment) : String :=
  match assessment.overall with
  | .simplifiedRoutesAvailable =>
      "At least one simplified route qualifies on the supplied facts."
  | .unresolved =>
      "No route qualifies on the known facts and at least one route still needs information."
  | .formalProbateOrOtherProcedure =>
      "Every simplified route is conclusively disqualified; formal probate or another procedure is required."

def assessmentResultJson (assessment : CaseAssessment) : Json :=
  Json.mkObj [
    ("verdict", Json.str (verdictFor assessment.overall)),
    ("error", Json.null),
    ("overall", Json.str (overallOutcomeWireName assessment.overall)),
    ("routes",
      Json.arr ((projectAssessment assessment).map wireRouteReportJson).toArray),
    ("reasoning", Json.str (summaryFor assessment)),
    ("engine", Json.str "lean4"),
    ("latency_ms", Json.num ⟨(0 : Int), 0⟩)
  ]

instance : Lean.ToJson CaseAssessment := ⟨assessmentResultJson⟩

def errorResultJson (errorType detail : String) : Json :=
  Json.mkObj [
    ("verdict", Json.null),
    ("error", Json.mkObj [
      ("type", Json.str errorType),
      ("detail", Json.str detail)
    ]),
    ("overall", Json.null),
    ("routes", Json.arr #[]),
    ("reasoning", Json.str detail),
    ("engine", Json.str "lean4"),
    ("latency_ms", Json.num ⟨(0 : Int), 0⟩)
  ]

def caseErrorJson : CaseError → Json
  | .invalidDate =>
      errorResultJson "invalid_date"
        "The supplied death date is not a valid civil date"
  | .afterSnapshot =>
      errorResultJson "after_snapshot"
        "The death date is after 2026-12-31, the model's supported snapshot end"
  | .malformedCase issues =>
      errorResultJson "malformed_case"
        (String.intercalate "; " (issues.map structuralIssueDetail))

def resultJson : Except CaseError CaseAssessment → Json
  | .ok assessment => assessmentResultJson assessment
  | .error caseError => caseErrorJson caseError

/-- Raw stdin text to a deterministic response JSON document. -/
def run (input : String) : Json :=
  match Json.parse input with
  | .error parseError =>
      errorResultJson "malformed_case"
        s!"Input was not valid JSON: {parseError}"
  | .ok json =>
      match decodeCase json with
      | .error decodeError =>
          errorResultJson "malformed_case" decodeError
      | .ok partialCase =>
          resultJson (assessRoutes partialCase)

end Api
end SimpleProbate
