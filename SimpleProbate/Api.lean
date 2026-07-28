import Lean.Data.Json
import SimpleProbate.Partial

/-!
# JSON bridge

Codecs between the v2 wire schemas (`CaseInput` / `CheckResult`) and the
partial-information layer in `SimpleProbate.Partial`.

Decoding is tolerant: an absent key or an explicit `null` means "unknown",
never false. Non-integer or negative money values, unknown enum strings, and
other structural problems produce `malformed_case` errors.
-/

namespace SimpleProbate
namespace Api

open Lean (Json)

/-- Object field lookup where an absent key and an explicit `null` are both
"unknown". -/
def optField (j : Json) (key : String) : Option Json :=
  match j.getObjVal? key with
  | .ok Json.null => none
  | .ok value => some value
  | .error _ => none

def asBool (path : String) (j : Json) : Except String Bool :=
  match j with
  | .bool b => .ok b
  | _ => .error s!"{path} must be a boolean or null"

def asNat (path : String) (j : Json) : Except String Nat :=
  match j with
  | .num n =>
    if n.exponent == 0 then
      if n.mantissa < 0 then
        .error s!"{path} must be a non-negative integer"
      else
        .ok n.mantissa.toNat
    else
      .error s!"{path} must be an integer"
  | _ => .error s!"{path} must be an integer or null"

def asString (path : String) (j : Json) : Except String String :=
  match j with
  | .str s => .ok s
  | _ => .error s!"{path} must be a string or null"

def optBoolField (j : Json) (path key : String) : Except String (Option Bool) :=
  match optField j key with
  | none => .ok none
  | some value => (asBool s!"{path}{key}" value).map some

def optNatField (j : Json) (path key : String) : Except String (Option Nat) :=
  match optField j key with
  | none => .ok none
  | some value => (asNat s!"{path}{key}" value).map some

def parseKind (path s : String) : Except String PropertyKind :=
  match s with
  | "personal" => .ok .personal
  | "california_real" => .ok .californiaReal
  | "outside_california_real" => .ok .outsideCaliforniaReal
  | _ => .error s!"{path}: unknown property kind '{s}'"

def parseTreatment (path s : String) : Except String ValuationTreatment :=
  match s with
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
  | _ => .error s!"{path}: unknown valuation treatment '{s}'"

def parseAuthority (path s : String) : Except String SummaryAuthority :=
  match s with
  | "no_proceeding" => .ok .noProceeding
  | "written_personal_representative_consent" =>
    .ok .writtenPersonalRepresentativeConsent
  | "blocked_by_proceeding" => .ok .blockedByProceeding
  | _ => .error s!"{path}: unknown authority '{s}'"

def parseSurvivorStatus (path s : String) : Except String SurvivorStatus :=
  match s with
  | "none" => .ok SurvivorStatus.none
  | "spouse" => .ok .spouse
  | "registered_domestic_partner" => .ok .registeredDomesticPartner
  | _ => .error s!"{path}: unknown survivor status '{s}'"

def decodeDeathDate (j : Json) : Except String CivilDate := do
  let .obj _ := j | throw "death_date must be an object or null"
  let year ← match optField j "year" with
    | some v => asNat "death_date.year" v
    | none => throw "death_date.year is required"
  let month ← match optField j "month" with
    | some v => asNat "death_date.month" v
    | none => throw "death_date.month is required"
  let day ← match optField j "day" with
    | some v => asNat "death_date.day" v
    | none => throw "death_date.day is required"
  pure ⟨year, month, day⟩

def decodeAsset (index : Nat) (j : Json) : Except String PartialAsset := do
  let path := s!"estate.assets[{index}]."
  let .obj _ := j | throw s!"estate.assets[{index}] must be an object"
  let name ← match optField j "name" with
    | some v => asString s!"{path}name" v
    | none => throw s!"{path}name is required"
  let kind ← match optField j "kind" with
    | none => pure none
    | some v => do
      let s ← asString s!"{path}kind" v
      (parseKind s!"{path}kind" s).map some
  let grossValue ← optNatField j path "gross_value_cents"
  let encumbrances ← optNatField j path "encumbrances_cents"
  let treatment ← match optField j "treatment" with
    | none => pure none
    | some v => do
      let s ← asString s!"{path}treatment" v
      (parseTreatment s!"{path}treatment" s).map some
  let includedInPrimaryResidencePetition ←
    optBoolField j path "included_in_primary_residence_petition"
  let isPrimaryResidence ← optBoolField j path "is_primary_residence"
  pure {
    name := name
    kind := kind
    grossValue := grossValue
    encumbrances := encumbrances
    treatment := treatment
    includedInPrimaryResidencePetition := includedInPrimaryResidencePetition
    isPrimaryResidence := isPrimaryResidence
  }

private def decodeAssetList (assets : List Json) : Except String (List PartialAsset) :=
  let rec go (index : Nat) : List Json → Except String (List PartialAsset)
    | [] => .ok []
    | asset :: rest => do
      let decoded ← decodeAsset index asset
      let tail ← go (index + 1) rest
      pure (decoded :: tail)
  go 0 assets

/-- Tolerant decode of the wire-format `CaseInput` (absent key = null =
unknown). -/
def decodeCase (j : Json) : Except String PartialTransferCase := do
  let .obj _ := j | throw "case must be a JSON object"
  let deathDate ← match optField j "death_date" with
    | none => pure none
    | some v => (decodeDeathDate v).map some
  let daysSinceDeath ← optNatField j "" "days_since_death"
  let sixMonthsElapsed ← optBoolField j "" "six_months_elapsed"
  let claimantIsSuccessor ← optBoolField j "" "claimant_is_successor"
  let noSuperiorRight ← optBoolField j "" "no_superior_right"
  let funeralLastIllnessAndUnsecuredDebtsPaid ←
    optBoolField j "" "funeral_last_illness_and_unsecured_debts_paid"
  let authority ← match optField j "authority" with
    | none => pure none
    | some v => do
      let s ← asString "authority" v
      (parseAuthority "authority" s).map some
  let survivorStatus ← match optField j "survivor_status" with
    | none => pure none
    | some v => do
      let s ← asString "survivor_status" v
      (parseSurvivorStatus "survivor_status" s).map some
  let propertyPassesToSurvivor ← optBoolField j "" "property_passes_to_survivor"
  let propertyBelongsToSurvivor ← optBoolField j "" "property_belongs_to_survivor"
  let estateJson ← match optField j "estate" with
    | some v => pure v
    | none => throw "estate is required"
  let .obj _ := estateJson | throw "estate must be a JSON object"
  let inventoryComplete ← optBoolField estateJson "estate." "inventory_complete"
  let assetsJson ← match optField estateJson "assets" with
    | some v =>
      match v.getArr? with
      | .ok array => pure array.toList
      | .error _ => throw "estate.assets must be an array"
    | none => throw "estate.assets is required"
  let assets ← decodeAssetList assetsJson
  let targetIndex ← match optField j "target_index" with
    | some v => asNat "target_index" v
    | none => throw "target_index is required"
  pure {
    deathDate := deathDate
    daysSinceDeath := daysSinceDeath
    sixMonthsElapsed := sixMonthsElapsed
    claimantIsSuccessor := claimantIsSuccessor
    noSuperiorRight := noSuperiorRight
    funeralLastIllnessAndUnsecuredDebtsPaid := funeralLastIllnessAndUnsecuredDebtsPaid
    authority := authority
    survivorStatus := survivorStatus
    propertyPassesToSurvivor := propertyPassesToSurvivor
    propertyBelongsToSurvivor := propertyBelongsToSurvivor
    estate := { inventoryComplete := inventoryComplete, assets := assets }
    targetIndex := targetIndex
  }

instance : Lean.FromJson PartialTransferCase := ⟨decodeCase⟩

/-! ## Encoding the `CheckResult` -/

def disqualifierJson (d : Disqualifier) : Json :=
  Json.mkObj [("id", Json.str d.id), ("text", Json.str d.text)]

def routeReportJson (report : RouteReport) : Json :=
  let (status, reasons, missingFacts) :=
    match report.status with
    | .qualifies => ("qualifies", ([] : List Disqualifier), ([] : List FactPath))
    | .doesNotQualify reasons => ("does_not_qualify", reasons, [])
    | .needsInformation facts => ("needs_information", [], facts)
  Json.mkObj [
    ("route", Json.str report.route.wireName),
    ("status", Json.str status),
    ("reasons", Json.arr (reasons.map disqualifierJson).toArray),
    ("missing_facts", Json.arr (missingFacts.map Json.str).toArray),
    ("detail", Json.str report.detail),
    ("forms", Json.arr (report.route.forms.map Json.str).toArray)
  ]

instance : Lean.ToJson RouteReport := ⟨routeReportJson⟩

def verdictFor : OverallOutcome → String
  | .simplifiedRoutesAvailable => "ELIGIBLE"
  | .unresolved => "INCOMPLETE_INFO"
  | .formalProbateOrOtherProcedure => "OTHER_FORM_REQUIRED"

/-- One-sentence deterministic summary for the `reasoning` field. -/
def summaryFor (assessment : CaseAssessment) : String :=
  match assessment.overall with
  | .simplifiedRoutesAvailable =>
    let qualifying := (assessment.routes.filter fun report =>
      report.status == .qualifies &&
        report.route != .formalProbateOrOtherProcedure).map (·.route.wireName)
    s!"At least one simplified route qualifies on the supplied facts: {String.intercalate ", " qualifying}."
  | .unresolved =>
    "No route qualifies on the known facts and at least one route still needs information."
  | .formalProbateOrOtherProcedure =>
    "Every simplified route is conclusively disqualified; formal probate or another procedure is required."

/-- Successful assessment as a wire `CheckResult`. `latency_ms` is 0 here;
the backend overwrites it. -/
def assessmentResultJson (assessment : CaseAssessment) : Json :=
  Json.mkObj [
    ("verdict", Json.str (verdictFor assessment.overall)),
    ("error", Json.null),
    ("overall", Json.str assessment.overall.wireName),
    ("routes", Json.arr (assessment.routes.map routeReportJson).toArray),
    ("reasoning", Json.str (summaryFor assessment)),
    ("engine", Json.str "lean4"),
    ("latency_ms", Json.num ⟨(0 : Int), 0⟩)
  ]

instance : Lean.ToJson CaseAssessment := ⟨assessmentResultJson⟩

/-- Error state as a wire `CheckResult` (`verdict` and `overall` are null). -/
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
  | .malformedCase detail => errorResultJson "malformed_case" detail

def resultJson : Except CaseError CaseAssessment → Json
  | .ok assessment => assessmentResultJson assessment
  | .error caseError => caseErrorJson caseError

/-- Full pipeline: raw stdin text → wire `CheckResult` JSON. Unparseable
input and case errors both produce error results, never a crash. -/
def run (input : String) : Json :=
  match Json.parse input with
  | .error parseError =>
    errorResultJson "malformed_case" s!"Input was not valid JSON: {parseError}"
  | .ok j =>
    match decodeCase j with
    | .error decodeError => errorResultJson "malformed_case" decodeError
    | .ok partialCase => resultJson (assessRoutes partialCase)

end Api
end SimpleProbate
