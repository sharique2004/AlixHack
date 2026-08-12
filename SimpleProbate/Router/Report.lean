import SimpleProbate.Partial

/-!
# Response model

Lean mirror of `SettlementAssessment` (CONTRACT-SETTLEMENT.md §3). Every
constructor here carries the contract's stable wire spelling in a `wireName`
function, so the JSON encoder in `SimpleProbate.Router.Encode` never writes a
literal enum string of its own.

Naming: the contract's `RouteReport` is `RouteRow` here, because
`SimpleProbate.RouteReport` (the CA engine's per-route record) already exists
and the two are different shapes. `RouteRow` is the wire shape; the engine's
`RouteStatus` is projected onto `RowStatus` + `reasons` + `missingFacts`.
-/

namespace SimpleProbate
namespace Router

/-- First-occurrence-preserving deduplication; every list of fact paths on the
wire goes through this, so `unresolved_facts` is order-stable. -/
private def dedupAux [BEq α] (seen : List α) : List α → List α
  | [] => []
  | x :: xs => if seen.contains x then dedupAux seen xs else x :: dedupAux (x :: seen) xs

def dedup [BEq α] (xs : List α) : List α := dedupAux [] xs

/-- `List.flatMap` under a stable name (its signature has moved between core
versions). -/
def concatMap {α β : Type} (f : α → List β) : List α → List β
  | [] => []
  | x :: xs => f x ++ concatMap f xs

structure Citation where
  label : String
  url : Option String := none
deriving BEq, DecidableEq, Repr

structure Reason where
  id : String
  text : String
deriving BEq, DecidableEq, Repr

/-! ## Asset map -/

inductive Classification
  | probate | nonProbate | unknown
deriving BEq, DecidableEq, Repr

def Classification.wireName : Classification → String
  | .probate => "probate"
  | .nonProbate => "non_probate"
  | .unknown => "unknown"

inductive ClassificationBasis
  | jtwrosSurvivorship
  | communityPropertyRos
  | beneficiaryDesignation
  | podTod
  | trustFunded
  | soleNameNoDesignation
  | beneficiaryPredeceasedFallsToEstate
  | designationToEstate
  | unknownTitle
deriving BEq, DecidableEq, Repr

def ClassificationBasis.wireName : ClassificationBasis → String
  | .jtwrosSurvivorship => "jtwros_survivorship"
  | .communityPropertyRos => "community_property_ros"
  | .beneficiaryDesignation => "beneficiary_designation"
  | .podTod => "pod_tod"
  | .trustFunded => "trust_funded"
  | .soleNameNoDesignation => "sole_name_no_designation"
  | .beneficiaryPredeceasedFallsToEstate => "beneficiary_predeceased_falls_to_estate"
  | .designationToEstate => "designation_to_estate"
  | .unknownTitle => "unknown_title"

structure AssetClassification where
  name : String
  classification : Classification
  basis : Option ClassificationBasis
  reason : String
  citation : Option Citation
  missingFacts : List FactPath
  countsToward : List String
  valueCents : Option Money
deriving DecidableEq, Repr

inductive EstateStatus
  | known
  /-- The contract's `"partial"`; spelled out here because `partial` is a Lean
  keyword. -/
  | partiallyKnown
deriving BEq, DecidableEq, Repr

def EstateStatus.wireName : EstateStatus → String
  | .known => "known"
  | .partiallyKnown => "partial"

structure ProbateEstate where
  knownSubtotalCents : Money
  status : EstateStatus
  missingFacts : List FactPath
deriving DecidableEq, Repr

/-! ## Jurisdictions -/

inductive RowStatus
  | qualifies | doesNotQualify | needsInformation
deriving BEq, DecidableEq, Repr

def RowStatus.wireName : RowStatus → String
  | .qualifies => "qualifies"
  | .doesNotQualify => "does_not_qualify"
  | .needsInformation => "needs_information"

/-- The contract's `RouteReport`. -/
structure RouteRow where
  route : String
  label : String
  status : RowStatus
  reasons : List Reason
  missingFacts : List FactPath
  forms : List String
  citations : List Citation
deriving DecidableEq, Repr

inductive Verdict
  | eligible | incompleteInfo | otherFormRequired
deriving BEq, DecidableEq, Repr

def Verdict.wireName : Verdict → String
  | .eligible => "ELIGIBLE"
  | .incompleteInfo => "INCOMPLETE_INFO"
  | .otherFormRequired => "OTHER_FORM_REQUIRED"

inductive JurisdictionRole
  | domicile | ancillary
deriving BEq, DecidableEq, Repr

def JurisdictionRole.wireName : JurisdictionRole → String
  | .domicile => "domicile"
  | .ancillary => "ancillary"

structure JurisdictionReport where
  code : String
  role : JurisdictionRole
  verdict : Verdict
  routes : List RouteRow
deriving DecidableEq, Repr

/-! ## Federal -/

inductive FederalStatus
  | required | notRequired | needsInformation | payable | notPayable
deriving BEq, DecidableEq, Repr

def FederalStatus.wireName : FederalStatus → String
  | .required => "required"
  | .notRequired => "not_required"
  | .needsInformation => "needs_information"
  | .payable => "payable"
  | .notPayable => "not_payable"

structure FederalReport where
  item : String
  label : String
  status : FederalStatus
  payee : Option String := none
  amountCents : Option Money := none
  reasons : List Reason := []
  missingFacts : List FactPath := []
  citations : List Citation := []
deriving DecidableEq, Repr

/-! ## Flags, deadlines, actions -/

inductive Severity
  | critical | warning | info
deriving BEq, DecidableEq, Repr

def Severity.wireName : Severity → String
  | .critical => "critical"
  | .warning => "warning"
  | .info => "info"

structure Flag where
  id : String
  severity : Severity
  title : String
  detail : String
  citation : Option Citation
  triggeredBy : List FactPath
  action : String
deriving DecidableEq, Repr

inductive DeadlineStatus
  | computed | awaitingEvent | needsInformation
deriving BEq, DecidableEq, Repr

def DeadlineStatus.wireName : DeadlineStatus → String
  | .computed => "computed"
  | .awaitingEvent => "awaiting_event"
  | .needsInformation => "needs_information"

structure Deadline where
  id : String
  label : String
  status : DeadlineStatus
  date : Option CivilDate
  relativeTo : String
  offsetDays : Option Nat
  citation : Option Citation
deriving DecidableEq, Repr

structure NextAction where
  id : String
  label : String
  blockedBy : List FactPath
deriving DecidableEq, Repr

/-! ## The assessment -/

structure Snapshot where
  sourceAsOf : String
  supportedDeathDatesThrough : String
deriving DecidableEq, Repr

structure SettlementAssessment where
  engine : String := "lean4"
  snapshot : Snapshot
  assetMap : List AssetClassification
  probateEstate : ProbateEstate
  jurisdictions : List JurisdictionReport
  federal : List FederalReport
  flags : List Flag
  deadlines : List Deadline
  nextActions : List NextAction
  unresolvedFacts : List FactPath
  notes : List String
deriving DecidableEq, Repr

/-- The contract's error envelope. Structural only — never a legal conclusion. -/
structure RouterError where
  code : String
  detail : String
deriving DecidableEq, Repr

/-! ## Projections used by the regression examples and by the assembler -/

def findAsset (m : List AssetClassification) (name : String) :
    Option AssetClassification :=
  m.find? fun a => a.name == name

def findRoute (j : JurisdictionReport) (route : String) : Option RouteRow :=
  j.routes.find? fun r => r.route == route

def jurisdictionOf (a : SettlementAssessment) (code : String) :
    Option JurisdictionReport :=
  a.jurisdictions.find? fun j => j.code == code

def routeStatusOf (a : SettlementAssessment) (code route : String) :
    Option RowStatus :=
  (jurisdictionOf a code).bind fun j => (findRoute j route).map (·.status)

def routeMissingOf (a : SettlementAssessment) (code route : String) :
    Option (List FactPath) :=
  (jurisdictionOf a code).bind fun j => (findRoute j route).map (·.missingFacts)

def flagIds (a : SettlementAssessment) : List String := a.flags.map (·.id)

def flagSeverityOf (a : SettlementAssessment) (id : String) : Option Severity :=
  (a.flags.find? fun f => f.id == id).map (·.severity)

def deadlineDateOf (a : SettlementAssessment) (id : String) : Option CivilDate :=
  (a.deadlines.find? fun d => d.id == id).bind (·.date)

def deadlineStatusOf (a : SettlementAssessment) (id : String) :
    Option DeadlineStatus :=
  (a.deadlines.find? fun d => d.id == id).map (·.status)

def nextActionIds (a : SettlementAssessment) : List String :=
  a.nextActions.map (·.id)

end Router
end SimpleProbate
