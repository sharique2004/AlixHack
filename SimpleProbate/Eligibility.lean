import SimpleProbate.Case

namespace SimpleProbate

def SummaryAuthority.Permits : SummaryAuthority → Prop
  | .noProceeding => True
  | .writtenPersonalRepresentativeConsent => True
  | .blockedByProceeding => False

instance (authority : SummaryAuthority) : Decidable authority.Permits :=
  match authority with
  | .noProceeding => isTrue trivial
  | .writtenPersonalRepresentativeConsent => isTrue trivial
  | .blockedByProceeding => isFalse id

def SupportedDeathDate (date : CivilDate) : Prop :=
  match classifyDeathDate date with
  | .ok _ => True
  | .error _ => False

instance (date : CivilDate) : Decidable (SupportedDeathDate date) := by
  unfold SupportedDeathDate
  cases classifyDeathDate date <;> infer_instance

inductive Route
  | directTransfer (basis : DirectTransferBasis)
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
  | formalProbateOrOtherProcedure
deriving BEq, DecidableEq, Repr

inductive SimplifiedRoute
  | directTransfer (basis : DirectTransferBasis)
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

def SimplifiedRoute.toRoute : SimplifiedRoute → Route
  | .directTransfer basis => .directTransfer basis
  | .personalPropertyAffidavit => .personalPropertyAffidavit
  | .smallValueRealPropertyAffidavit =>
      .smallValueRealPropertyAffidavit
  | .primaryResidencePetition => .primaryResidencePetition
  | .spousalPropertyPetition => .spousalPropertyPetition

def Route.toSimplified? : Route → Option SimplifiedRoute
  | .directTransfer basis => some (.directTransfer basis)
  | .personalPropertyAffidavit => some .personalPropertyAffidavit
  | .smallValueRealPropertyAffidavit =>
      some .smallValueRealPropertyAffidavit
  | .primaryResidencePetition => some .primaryResidencePetition
  | .spousalPropertyPetition => some .spousalPropertyPetition
  | .formalProbateOrOtherProcedure => none

instance : Coe SimplifiedRoute Route := ⟨SimplifiedRoute.toRoute⟩

inductive EligibilityFact
  | deathDate
  | targetAsset
  | inventoryComplete
  | assetField (id : AssetId) (field : AssetField)
  | authority
  | daysSinceDeath
  | sixMonthsElapsed
  | claimantIsSuccessor
  | noSuperiorRight
  | debtsPaid
  | survivorStatus
  | propertyPassesToSurvivor
  | propertyBelongsToSurvivor
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive EligibilityFailure
  | directTransferBasisAbsent (basis : DirectTransferBasis)
  | targetNotPersonalProperty
  | targetNotCaliforniaRealProperty
  | targetNotCounted
  | targetNotPrimaryResidence
  | claimantNotSuccessor
  | superiorRightExists
  | fortyDaysNotElapsed
  | sixMonthsNotElapsed
  | blockedByProceeding
  | requiredDebtsUnpaid
  | personalPropertyValueOverCap (value cap : Money)
  | smallRealPropertyValueOverCap (value cap : Money)
  | primaryResidenceValueOverCap (value cap : Money)
  | noSurvivingSpouseOrPartner
  | propertyNeitherPassesNorBelongsToSurvivor
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure RouteReport where
  route : SimplifiedRoute
  status : DecisionStatus EligibilityFact EligibilityFailure
deriving DecidableEq, Repr

inductive OverallOutcome
  | simplifiedRoutesAvailable
  | unresolved
  | formalProbateOrOtherProcedure
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure CaseAssessment where
  routes : List RouteReport
  overall : OverallOutcome
deriving DecidableEq, Repr

def directTransferBases : List DirectTransferBasis := [
  .governmentBenefit,
  .namedBeneficiary,
  .revocableTrust,
  .jointTenancy,
  .transferOnDeath,
  .multiplePartyAccount,
  .spousePassage
]

def simplifiedRoutes : List SimplifiedRoute :=
  directTransferBases.map SimplifiedRoute.directTransfer ++ [
    .personalPropertyAffidavit,
    .smallValueRealPropertyAffidavit,
    .primaryResidencePetition,
    .spousalPropertyPetition
  ]

theorem simplifiedRoutes_nodup : simplifiedRoutes.Nodup := by
  decide

def overallOutcome (reports : List RouteReport) : OverallOutcome :=
  if reports.any (fun report =>
      match report.status with
      | .qualifies => true
      | _ => false) then
    .simplifiedRoutesAvailable
  else if reports.any (fun report =>
      match report.status with
      | .needsInformation _ => true
      | _ => false) then
    .unresolved
  else
    .formalProbateOrOtherProcedure

def TransferCase.target? (case : TransferCase) : Option Asset :=
  case.estate.findAsset? case.targetId

def DirectTransferEligible
    (case : TransferCase) (basis : DirectTransferBasis) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.WellFormed ∧
  ∃ target, case.target? = some target ∧
    target.directTransferBasis = some basis

def PersonalPropertyAffidavitEligible (case : TransferCase) : Prop :=
  match case.target? with
  | some target =>
      SupportedDeathDate case.deathDate ∧
      case.WellFormed ∧
      target.kind = .personal ∧
      case.claimantIsSuccessor = true ∧
      case.noSuperiorRight = true ∧
      40 ≤ case.daysSinceDeath ∧
      case.authority.Permits ∧
      match thresholdsFor case.deathDate with
      | .ok thresholds =>
          case.estate.personalAffidavitValueWith thresholds ≤
            thresholds.personalPropertyAffidavit
      | .error _ => False
  | none => False

def SmallValueRealPropertyAffidavitEligible (case : TransferCase) : Prop :=
  match case.target? with
  | some target =>
      SupportedDeathDate case.deathDate ∧
      case.WellFormed ∧
      target.kind = .californiaReal ∧
      target.treatment = .counted ∧
      case.claimantIsSuccessor = true ∧
      case.noSuperiorRight = true ∧
      case.sixMonthsElapsed = true ∧
      case.authority.Permits ∧
      case.funeralLastIllnessAndUnsecuredDebtsPaid = true ∧
      match thresholdsFor case.deathDate with
      | .ok thresholds =>
          case.estate.smallValueRealPropertyValue ≤
            thresholds.smallValueRealPropertyAffidavit
      | .error _ => False
  | none => False

def PrimaryResidencePetitionEligible (case : TransferCase) : Prop :=
  match case.target? with
  | some target =>
      SupportedDeathDate case.deathDate ∧
      case.WellFormed ∧
      target.kind = .californiaReal ∧
      target.treatment = .counted ∧
      target.isPrimaryResidence = true ∧
      case.claimantIsSuccessor = true ∧
      40 ≤ case.daysSinceDeath ∧
      case.authority.Permits ∧
      match thresholdsFor case.deathDate with
      | .ok thresholds =>
          case.estate.primaryResidenceValue ≤
            thresholds.primaryResidencePetition
      | .error _ => False
  | none => False

def SpousalPropertyPetitionEligible (case : TransferCase) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.WellFormed ∧
  case.target? ≠ none ∧
  case.survivorStatus ≠ .none ∧
  (case.propertyPassesToSurvivor = true ∨
   case.propertyBelongsToSurvivor = true)

instance (case : TransferCase) (basis : DirectTransferBasis) :
    Decidable (DirectTransferEligible case basis) := by
  unfold DirectTransferEligible TransferCase.target?
  infer_instance

instance (case : TransferCase) :
    Decidable (PersonalPropertyAffidavitEligible case) := by
  unfold PersonalPropertyAffidavitEligible
  split
  · cases thresholdResult : thresholdsFor case.deathDate <;>
      infer_instance
  · infer_instance

instance (case : TransferCase) :
    Decidable (SmallValueRealPropertyAffidavitEligible case) := by
  unfold SmallValueRealPropertyAffidavitEligible
  split
  · cases thresholdResult : thresholdsFor case.deathDate <;>
      infer_instance
  · infer_instance

instance (case : TransferCase) :
    Decidable (PrimaryResidencePetitionEligible case) := by
  unfold PrimaryResidencePetitionEligible
  split
  · cases thresholdResult : thresholdsFor case.deathDate <;>
      infer_instance
  · infer_instance

instance (case : TransferCase) :
    Decidable (SpousalPropertyPetitionEligible case) := by
  unfold SpousalPropertyPetitionEligible
  infer_instance

theorem validatePartialCase_toPartial_ok_iff_supported
    (case : TransferCase) :
    validatePartialCase case.toPartial = .ok () ↔
      SupportedDeathDate case.deathDate ∧ case.WellFormed := by
  rw [validatePartialCase_toPartial_ok_iff]
  cases dateResult : classifyDeathDate case.deathDate <;>
    simp [SupportedDeathDate, dateResult]

private def routeEligibleNonFallback (case : TransferCase) : Route → Bool
  | .directTransfer basis => decide (DirectTransferEligible case basis)
  | .personalPropertyAffidavit =>
      decide (PersonalPropertyAffidavitEligible case)
  | .smallValueRealPropertyAffidavit =>
      decide (SmallValueRealPropertyAffidavitEligible case)
  | .primaryResidencePetition =>
      decide (PrimaryResidencePetitionEligible case)
  | .spousalPropertyPetition =>
      decide (SpousalPropertyPetitionEligible case)
  | .formalProbateOrOtherProcedure => false

private def nonFallbackRoutes (case : TransferCase) : List Route :=
  (directTransferBases.map Route.directTransfer ++
    ([.personalPropertyAffidavit,
      .smallValueRealPropertyAffidavit,
      .primaryResidencePetition,
      .spousalPropertyPetition] : List Route)
  ).filter (routeEligibleNonFallback case)

/--
Declarative eligibility for the stable, non-fallback route API.

Legacy callers using `Route` should use `LegacyRouteEligible`; for every
`SimplifiedRoute`, `legacyRouteEligible_toRoute_iff` proves the two
declarative views coincide.
-/
def RouteEligible (case : TransferCase) : SimplifiedRoute → Prop
  | .directTransfer basis => DirectTransferEligible case basis
  | .personalPropertyAffidavit => PersonalPropertyAffidavitEligible case
  | .smallValueRealPropertyAffidavit =>
      SmallValueRealPropertyAffidavitEligible case
  | .primaryResidencePetition =>
      PrimaryResidencePetitionEligible case
  | .spousalPropertyPetition => SpousalPropertyPetitionEligible case

instance (case : TransferCase) (route : SimplifiedRoute) :
    Decidable (RouteEligible case route) := by
  cases route <;>
    simp only [RouteEligible] <;>
    infer_instance

private theorem RouteEligible.supportedAndWellFormed
    {case : TransferCase} {route : SimplifiedRoute}
    (eligible : RouteEligible case route) :
    SupportedDeathDate case.deathDate ∧ case.WellFormed := by
  cases route with
  | directTransfer basis =>
      exact ⟨eligible.1, eligible.2.1⟩
  | personalPropertyAffidavit =>
      cases targetResult : case.target? with
      | none =>
          simp [RouteEligible, PersonalPropertyAffidavitEligible,
            targetResult] at eligible
      | some target =>
          simp only [RouteEligible, PersonalPropertyAffidavitEligible,
            targetResult] at eligible
          exact ⟨eligible.1, eligible.2.1⟩
  | smallValueRealPropertyAffidavit =>
      cases targetResult : case.target? with
      | none =>
          simp [RouteEligible, SmallValueRealPropertyAffidavitEligible,
            targetResult] at eligible
      | some target =>
          simp only [RouteEligible,
            SmallValueRealPropertyAffidavitEligible,
            targetResult] at eligible
          exact ⟨eligible.1, eligible.2.1⟩
  | primaryResidencePetition =>
      cases targetResult : case.target? with
      | none =>
          simp [RouteEligible, PrimaryResidencePetitionEligible,
            targetResult] at eligible
      | some target =>
          simp only [RouteEligible, PrimaryResidencePetitionEligible,
            targetResult] at eligible
          exact ⟨eligible.1, eligible.2.1⟩
  | spousalPropertyPetition =>
      exact ⟨eligible.1, eligible.2.1⟩

private theorem RouteEligible.targetExists
    {case : TransferCase} {route : SimplifiedRoute}
    (eligible : RouteEligible case route) :
    ∃ target, case.target? = some target := by
  cases route with
  | directTransfer basis =>
      exact ⟨eligible.2.2.choose, eligible.2.2.choose_spec.1⟩
  | personalPropertyAffidavit =>
      cases targetResult : case.target? with
      | none =>
          simp [RouteEligible, PersonalPropertyAffidavitEligible,
            targetResult] at eligible
      | some target => exact ⟨target, rfl⟩
  | smallValueRealPropertyAffidavit =>
      cases targetResult : case.target? with
      | none =>
          simp [RouteEligible, SmallValueRealPropertyAffidavitEligible,
            targetResult] at eligible
      | some target => exact ⟨target, rfl⟩
  | primaryResidencePetition =>
      cases targetResult : case.target? with
      | none =>
          simp [RouteEligible, PrimaryResidencePetitionEligible,
            targetResult] at eligible
      | some target => exact ⟨target, rfl⟩
  | spousalPropertyPetition =>
      cases targetResult : case.target? with
      | none =>
          exact (eligible.2.2.1 targetResult).elim
      | some target => exact ⟨target, rfl⟩

def LegacyRouteEligible (case : TransferCase) : Route → Prop
  | .directTransfer basis => DirectTransferEligible case basis
  | .personalPropertyAffidavit => PersonalPropertyAffidavitEligible case
  | .smallValueRealPropertyAffidavit =>
      SmallValueRealPropertyAffidavitEligible case
  | .primaryResidencePetition =>
      PrimaryResidencePetitionEligible case
  | .spousalPropertyPetition => SpousalPropertyPetitionEligible case
  | .formalProbateOrOtherProcedure =>
      SupportedDeathDate case.deathDate ∧
      case.WellFormed ∧
      nonFallbackRoutes case = []

instance (case : TransferCase) (route : Route) :
    Decidable (LegacyRouteEligible case route) := by
  cases route <;>
    simp only [LegacyRouteEligible] <;>
    infer_instance

theorem legacyRouteEligible_toRoute_iff
    (case : TransferCase) (route : SimplifiedRoute) :
    LegacyRouteEligible case route.toRoute ↔ RouteEligible case route := by
  cases route <;> rfl

def checkKnowledge
    (fact : EligibilityFact) (failure : EligibilityFailure)
    (predicate : α → Bool) :
    Knowledge α → CheckResult EligibilityFact EligibilityFailure
  | .unknown => .unknown fact
  | .known value =>
      if predicate value then .satisfied else .violated failure

@[simp] private theorem checkKnowledge_ofTotal
    (fact : EligibilityFact) (failure : EligibilityFailure)
    (predicate : α → Bool) (value : α) :
    checkKnowledge fact failure predicate (.known value) =
        (.satisfied : CheckResult EligibilityFact EligibilityFailure) ↔
      predicate value = true := by
  simp [checkKnowledge]

@[simp] private theorem unknown_ne_checkKnowledge_ofTotal
    (queried fact : EligibilityFact) (failure : EligibilityFailure)
    (predicate : α → Bool) (value : α) :
    ¬(.unknown queried :
        CheckResult EligibilityFact EligibilityFailure) =
      checkKnowledge fact failure predicate (.known value) := by
  by_cases result : predicate value = true <;>
    simp [checkKnowledge, result]

def checkAuthority :
    Knowledge SummaryAuthority →
      CheckResult EligibilityFact EligibilityFailure
  | .unknown => .unknown .authority
  | .known .blockedByProceeding => .violated .blockedByProceeding
  | .known _ => .satisfied

@[simp] private theorem checkAuthority_ofTotal
    (authority : SummaryAuthority) :
    checkAuthority (.known authority) = .satisfied ↔
      authority.Permits := by
  cases authority <;> simp [checkAuthority, SummaryAuthority.Permits]

@[simp] private theorem unknown_ne_checkAuthority_ofTotal
    (fact : EligibilityFact) (authority : SummaryAuthority) :
    ¬(.unknown fact :
        CheckResult EligibilityFact EligibilityFailure) =
      checkAuthority (.known authority) := by
  cases authority <;> simp [checkAuthority]

private def deathDateCheck :
    Knowledge CivilDate →
      CheckResult EligibilityFact EligibilityFailure
  | .unknown => .unknown .deathDate
  | .known date =>
      match classifyDeathDate date with
      | .ok _ => .satisfied
      | .error _ => .violated .blockedByProceeding

@[simp] private theorem unknown_ne_deathDateCheck_ofTotal
    (fact : EligibilityFact) (date : CivilDate) :
    ¬(.unknown fact :
        CheckResult EligibilityFact EligibilityFailure) =
      deathDateCheck (.known date) := by
  cases result : classifyDeathDate date <;>
    simp [deathDateCheck, result]

private def targetResolution
    (case : PartialTransferCase) :
    CheckResult EligibilityFact EligibilityFailure × Option PartialAsset :=
  match case.targetId with
  | .unknown => (.unknown .targetAsset, none)
  | .known id =>
      match case.estate.findAsset? id with
      | some target => (.satisfied, some target)
      | none =>
          match case.estate.inventoryComplete with
          | .known true => (.violated .targetNotCounted, none)
          | _ => (.unknown .targetAsset, none)

private def ValuationTreatment.directTransferBasis :
    ValuationTreatment → Option DirectTransferBasis
  | .governmentBenefit => some .governmentBenefit
  | .directBeneficiary => some .namedBeneficiary
  | .revocableTrust => some .revocableTrust
  | .jointTenancy => some .jointTenancy
  | .transferOnDeath => some .transferOnDeath
  | .multiplePartySurvivor => some .multiplePartyAccount
  | .spousePassage => some .spousePassage
  | _ => none

private def directTransferChecks
    (basis : DirectTransferBasis) :
    Option PartialAsset →
      List (CheckResult EligibilityFact EligibilityFailure)
  | none => []
  | some target => [
      checkKnowledge (.assetField target.id .treatment)
        (.directTransferBasisAbsent basis)
        (fun treatment => treatment.directTransferBasis == some basis)
        target.treatment
    ]

private def valuationChecks
    (valuation : PartialValuation) (cap : Money)
    (overCap : Money → Money → EligibilityFailure) :
    List (CheckResult EligibilityFact EligibilityFailure) :=
  if cap < valuation.lowerBound then
    [.violated (overCap valuation.lowerBound cap)]
  else
    match valuation.exactValue with
    | some value =>
        if value ≤ cap then [.satisfied]
        else [.violated (overCap value cap)]
    | none =>
        valuation.missingFields.map
          (fun (id, field) => .unknown (.assetField id field)) ++
        if valuation.needsCompleteInventory then
          [.unknown .inventoryComplete]
        else
          []

@[simp] private theorem valuationChecks_exact_all_satisfied
    (value cap : Money)
    (overCap : Money → Money → EligibilityFailure) :
    (∀ check ∈ valuationChecks {
        lowerBound := value
        exactValue := some value
        missingFields := []
        needsCompleteInventory := false
      } cap overCap,
      check = (.satisfied :
        CheckResult EligibilityFact EligibilityFailure)) ↔
      value ≤ cap := by
  by_cases withinCap : value ≤ cap
  · have notOver : ¬cap < value := Nat.not_lt.mpr withinCap
    simp [valuationChecks, withinCap, notOver]
  · have over : cap < value := Nat.lt_of_not_ge withinCap
    simp [valuationChecks, withinCap, over]

@[simp] private theorem valuationChecks_exact_no_unknown
    (value cap : Money)
    (overCap : Money → Money → EligibilityFailure)
    (fact : EligibilityFact) :
    (.unknown fact :
        CheckResult EligibilityFact EligibilityFailure) ∉
      valuationChecks {
        lowerBound := value
        exactValue := some value
        missingFields := []
        needsCompleteInventory := false
      } cap overCap := by
  by_cases over : cap < value <;>
    by_cases withinCap : value ≤ cap <;>
    simp [valuationChecks, over, withinCap]

private def datedValuationChecks
    (date : Knowledge CivilDate)
    (valuationFor : Thresholds → PartialValuation)
    (capFor : Thresholds → Money)
    (overCap : Money → Money → EligibilityFailure) :
    List (CheckResult EligibilityFact EligibilityFailure) :=
  match date with
  | .unknown => [.unknown .deathDate]
  | .known date =>
      match thresholdsFor date with
      | .error _ => [.violated .blockedByProceeding]
      | .ok thresholds =>
          valuationChecks (valuationFor thresholds) (capFor thresholds) overCap

private def personalChecks
    (case : PartialTransferCase) (target : Option PartialAsset) :
    List (CheckResult EligibilityFact EligibilityFailure) :=
  let targetChecks :=
    match target with
    | none => []
    | some asset => [
        checkKnowledge (.assetField asset.id .kind)
          .targetNotPersonalProperty
          (fun kind => kind == .personal) asset.kind
      ]
  targetChecks ++ [
    checkKnowledge .claimantIsSuccessor .claimantNotSuccessor
      id case.claimantIsSuccessor,
    checkKnowledge .noSuperiorRight .superiorRightExists
      id case.noSuperiorRight,
    checkKnowledge .daysSinceDeath .fortyDaysNotElapsed
      (fun days => 40 ≤ days) case.daysSinceDeath,
    checkAuthority case.authority
  ] ++
  datedValuationChecks case.deathDate
    case.estate.personalAffidavitValuation
    (·.personalPropertyAffidavit)
    EligibilityFailure.personalPropertyValueOverCap

private def smallRealChecks
    (case : PartialTransferCase) (target : Option PartialAsset) :
    List (CheckResult EligibilityFact EligibilityFailure) :=
  let targetChecks :=
    match target with
    | none => []
    | some asset => [
        checkKnowledge (.assetField asset.id .kind)
          .targetNotCaliforniaRealProperty
          (fun kind => kind == .californiaReal) asset.kind,
        checkKnowledge (.assetField asset.id .treatment)
          .targetNotCounted
          (fun treatment => treatment == .counted) asset.treatment
      ]
  targetChecks ++ [
    checkKnowledge .claimantIsSuccessor .claimantNotSuccessor
      id case.claimantIsSuccessor,
    checkKnowledge .noSuperiorRight .superiorRightExists
      id case.noSuperiorRight,
    checkKnowledge .sixMonthsElapsed .sixMonthsNotElapsed
      id case.sixMonthsElapsed,
    checkAuthority case.authority,
    checkKnowledge .debtsPaid .requiredDebtsUnpaid
      id case.funeralLastIllnessAndUnsecuredDebtsPaid
  ] ++
  datedValuationChecks case.deathDate
    (fun _ => case.estate.smallRealPropertyValuation)
    (·.smallValueRealPropertyAffidavit)
    EligibilityFailure.smallRealPropertyValueOverCap

private def primaryResidenceChecks
    (case : PartialTransferCase) (target : Option PartialAsset) :
    List (CheckResult EligibilityFact EligibilityFailure) :=
  let targetChecks :=
    match target with
    | none => []
    | some asset => [
        checkKnowledge (.assetField asset.id .kind)
          .targetNotCaliforniaRealProperty
          (fun kind => kind == .californiaReal) asset.kind,
        checkKnowledge (.assetField asset.id .treatment)
          .targetNotCounted
          (fun treatment => treatment == .counted) asset.treatment,
        checkKnowledge (.assetField asset.id .primaryResidence)
          .targetNotPrimaryResidence id asset.isPrimaryResidence
      ]
  targetChecks ++ [
    checkKnowledge .claimantIsSuccessor .claimantNotSuccessor
      id case.claimantIsSuccessor,
    checkKnowledge .daysSinceDeath .fortyDaysNotElapsed
      (fun days => 40 ≤ days) case.daysSinceDeath,
    checkAuthority case.authority
  ] ++
  datedValuationChecks case.deathDate
    (fun _ => case.estate.primaryResidenceValuation)
    (·.primaryResidencePetition)
    EligibilityFailure.primaryResidenceValueOverCap

private def survivorPropertyChecks
    (passes belongs : Knowledge Bool) :
    List (CheckResult EligibilityFact EligibilityFailure) :=
  match passes, belongs with
  | .known true, _ | _, .known true => [.satisfied]
  | .known false, .known false =>
      [.violated .propertyNeitherPassesNorBelongsToSurvivor]
  | .unknown, .unknown => [
      .unknown .propertyPassesToSurvivor,
      .unknown .propertyBelongsToSurvivor
    ]
  | .unknown, .known false => [.unknown .propertyPassesToSurvivor]
  | .known false, .unknown => [.unknown .propertyBelongsToSurvivor]

@[simp] private theorem survivorPropertyChecks_ofTotal_all_satisfied
    (passes belongs : Bool) :
    (∀ check ∈ survivorPropertyChecks (.known passes) (.known belongs),
      check = (.satisfied :
        CheckResult EligibilityFact EligibilityFailure)) ↔
      passes = true ∨ belongs = true := by
  cases passes <;> cases belongs <;>
    simp [survivorPropertyChecks]

@[simp] private theorem survivorPropertyChecks_ofTotal_no_unknown
    (passes belongs : Bool) (fact : EligibilityFact) :
    (.unknown fact :
        CheckResult EligibilityFact EligibilityFailure) ∉
      survivorPropertyChecks (.known passes) (.known belongs) := by
  cases passes <;> cases belongs <;>
    simp [survivorPropertyChecks]

@[simp] private theorem survivorStatusCheck_ofTotal
    (status : SurvivorStatus) :
    checkKnowledge .survivorStatus .noSurvivingSpouseOrPartner
        (fun current =>
          match current with
          | .none => false
          | _ => true) (.known status) =
      (.satisfied : CheckResult EligibilityFact EligibilityFailure) ↔
      status ≠ .none := by
  cases status <;> simp [checkKnowledge]

@[simp] private theorem survivorStatusBool_iff
    (status : SurvivorStatus) :
    (match status with
      | .none => false
      | _ => true) = true ↔
      status ≠ .none := by
  cases status <;> simp

private def spousalChecks
    (case : PartialTransferCase) :
    List (CheckResult EligibilityFact EligibilityFailure) := [
    checkKnowledge .survivorStatus .noSurvivingSpouseOrPartner
      (fun status =>
        match status with
        | .none => false
        | _ => true) case.survivorStatus
  ] ++ survivorPropertyChecks
    case.propertyPassesToSurvivor case.propertyBelongsToSurvivor

def eligibilityChecks
    (case : PartialTransferCase) (route : SimplifiedRoute) :
    Except CaseError
      (List (CheckResult EligibilityFact EligibilityFailure)) :=
  match validatePartialCase case with
  | .error error => .error error
  | .ok _ =>
      let resolved := targetResolution case
      let baseChecks := [deathDateCheck case.deathDate, resolved.1]
      .ok <| baseChecks ++
        match route with
        | .directTransfer basis => directTransferChecks basis resolved.2
        | .personalPropertyAffidavit => personalChecks case resolved.2
        | .smallValueRealPropertyAffidavit =>
            smallRealChecks case resolved.2
        | .primaryResidencePetition =>
            primaryResidenceChecks case resolved.2
        | .spousalPropertyPetition => spousalChecks case

private theorem eligibilityChecks_ok_of_validate
    (case : PartialTransferCase) (route : SimplifiedRoute) :
    validatePartialCase case = .ok () →
      ∃ checks, eligibilityChecks case route = .ok checks := by
  intro valid
  simp [eligibilityChecks, valid]

def assessRoute
    (case : PartialTransferCase) (route : SimplifiedRoute) :
    Except CaseError
      (DecisionStatus EligibilityFact EligibilityFailure) :=
  match validatePartialCase case with
  | .error error => .error error
  | .ok _ =>
      match eligibilityChecks case route with
      | .error error => .error error
      | .ok checks => .ok (aggregateChecks checks)

private def assessRouteReport
    (case : PartialTransferCase) (route : SimplifiedRoute) :
    Except CaseError RouteReport := do
  let status ← assessRoute case route
  pure { route := route, status := status }

private def qualifyingRoutes (reports : List RouteReport) : List Route :=
  reports.filterMap fun report =>
    match report.status with
    | .qualifies => some report.route.toRoute
    | _ => none

def assessRoutes
    (case : PartialTransferCase) :
    Except CaseError CaseAssessment := do
  validatePartialCase case
  let reports ← simplifiedRoutes.mapM (assessRouteReport case)
  pure { routes := reports, overall := overallOutcome reports }

def candidateRoutes
    (case : TransferCase) : Except CaseError (List Route) := do
  let assessment ← assessRoutes case.toPartial
  let qualifying := qualifyingRoutes assessment.routes
  if qualifying = [] then
    pure [.formalProbateOrOtherProcedure]
  else
    pure qualifying

def routeEligible
    (case : TransferCase) (route : Route) : Except CaseError Bool := do
  match route.toSimplified? with
  | some simplified =>
      let status ← assessRoute case.toPartial simplified
      pure <| match status with
        | .qualifies => true
        | _ => false
  | none =>
      let assessment ← assessRoutes case.toPartial
      pure <| assessment.overall == .formalProbateOrOtherProcedure

theorem mem_assessRoute_needsInformation_iff
    {case : PartialTransferCase} {route : SimplifiedRoute}
    {facts : List EligibilityFact}
    (result :
      assessRoute case route = .ok (.needsInformation facts))
    (fact : EligibilityFact) :
    fact ∈ facts ↔
      ∃ checks,
        eligibilityChecks case route = .ok checks ∧
        .unknown fact ∈ checks := by
  cases valid : validatePartialCase case with
  | error error =>
      simp [assessRoute, valid] at result
  | ok unitValue =>
      cases unitValue
      cases checksResult : eligibilityChecks case route with
      | error error =>
          simp [assessRoute, valid, checksResult] at result
      | ok checks =>
          have aggregateResult :
              aggregateChecks checks = .needsInformation facts := by
            simpa [assessRoute, valid, checksResult] using result
          rw [mem_requiredFact_of_aggregate aggregateResult fact]
          constructor
          · intro member
            exact ⟨checks, rfl, member⟩
          · rintro ⟨otherChecks, otherResult, member⟩
            injection otherResult with checksEq
            subst otherChecks
            exact member

private theorem checkKnowledge_satisfied_sound
    {knowledge : Knowledge α} {value : α}
    (completion : knowledge.Completes value)
    {fact : EligibilityFact} {failure : EligibilityFailure}
    {predicate : α → Bool}
    (satisfied :
      checkKnowledge fact failure predicate knowledge = .satisfied) :
    predicate value = true := by
  cases knowledge with
  | unknown => simp [checkKnowledge] at satisfied
  | known expected =>
      simp [Knowledge.Completes] at completion
      subst value
      simpa [checkKnowledge] using satisfied

private theorem checkKnowledge_violated_unsound
    {knowledge : Knowledge α} {value : α}
    (completion : knowledge.Completes value)
    {fact : EligibilityFact} {failure : EligibilityFailure}
    {predicate : α → Bool}
    (holds : predicate value = true) :
    checkKnowledge fact failure predicate knowledge ≠ .violated failure := by
  cases knowledge with
  | unknown => simp [checkKnowledge]
  | known expected =>
      simp [Knowledge.Completes] at completion
      subst value
      simp [checkKnowledge, holds]

private theorem checkKnowledge_no_violation
    {knowledge : Knowledge α} {value : α}
    (completion : knowledge.Completes value)
    {fact : EligibilityFact} {failure reason : EligibilityFailure}
    {predicate : α → Bool}
    (holds : predicate value = true) :
    checkKnowledge fact failure predicate knowledge ≠ .violated reason := by
  cases knowledge with
  | unknown => simp [checkKnowledge]
  | known expected =>
      simp [Knowledge.Completes] at completion
      subst value
      simp [checkKnowledge, holds]

private theorem checkAuthority_satisfied_sound
    {knowledge : Knowledge SummaryAuthority} {value : SummaryAuthority}
    (completion : knowledge.Completes value)
    (satisfied : checkAuthority knowledge = .satisfied) :
    value.Permits := by
  cases knowledge with
  | unknown => simp [checkAuthority] at satisfied
  | known expected =>
      simp [Knowledge.Completes] at completion
      subst value
      cases expected <;> simp [checkAuthority, SummaryAuthority.Permits] at satisfied ⊢

private theorem checkAuthority_no_violation
    {knowledge : Knowledge SummaryAuthority} {value : SummaryAuthority}
    (completion : knowledge.Completes value)
    (permits : value.Permits) (reason : EligibilityFailure) :
    checkAuthority knowledge ≠ .violated reason := by
  cases knowledge with
  | unknown => simp [checkAuthority]
  | known expected =>
      simp [Knowledge.Completes] at completion
      subst value
      cases expected <;>
        simp [checkAuthority, SummaryAuthority.Permits] at permits ⊢

private theorem valuationChecks_all_satisfied_exact
    (valuation : PartialValuation) (cap : Money)
    (overCap : Money → Money → EligibilityFailure)
    (coherent :
      valuation.exactValue = none →
        valuation.missingFields ≠ [] ∨
        valuation.needsCompleteInventory = true)
    (allSatisfied :
      ∀ check ∈ valuationChecks valuation cap overCap,
        check = (.satisfied :
          CheckResult EligibilityFact EligibilityFailure)) :
    ∃ value,
      valuation.exactValue = some value ∧ value ≤ cap := by
  rcases valuation with ⟨lowerBound, exactValue, missingFields, needsInventory⟩
  by_cases lowerOver : cap < lowerBound
  · have violated := allSatisfied
      (.violated (overCap lowerBound cap)) (by
        simp [valuationChecks, lowerOver])
    contradiction
  · cases exactValue with
    | some value =>
        by_cases withinCap : value ≤ cap
        · exact ⟨value, rfl, withinCap⟩
        · have valueOver : cap < value := Nat.lt_of_not_ge withinCap
          have violated := allSatisfied
            (.violated (overCap value cap)) (by
              simp [valuationChecks, lowerOver, withinCap])
          contradiction
    | none =>
        have unknownPresent : missingFields ≠ [] ∨ needsInventory = true :=
          coherent rfl
        rcases unknownPresent with missing | inventory
        · cases missingFields with
          | nil => contradiction
          | cons entry rest =>
              have unknown := allSatisfied
                (.unknown (.assetField entry.1 entry.2)) (by
                  simp [valuationChecks, lowerOver])
              contradiction
        · have unknown := allSatisfied (.unknown .inventoryComplete) (by
            simp [valuationChecks, lowerOver, inventory])
          contradiction

private theorem mem_violated_valuationChecks
    {valuation : PartialValuation} {cap : Money}
    {overCap : Money → Money → EligibilityFailure}
    {reason : EligibilityFailure}
    (member :
      (.violated reason :
        CheckResult EligibilityFact EligibilityFailure) ∈
        valuationChecks valuation cap overCap) :
    cap < valuation.lowerBound ∨
      ∃ value,
        valuation.exactValue = some value ∧ cap < value := by
  rcases valuation with ⟨lowerBound, exactValue, missingFields, needsInventory⟩
  by_cases lowerOver : cap < lowerBound
  · exact Or.inl lowerOver
  · right
    cases exactValue with
    | none => simp [valuationChecks, lowerOver] at member
    | some value =>
        by_cases withinCap : value ≤ cap
        · simp [valuationChecks, lowerOver, withinCap] at member
        · exact ⟨value, rfl, Nat.lt_of_not_ge withinCap⟩

private theorem valuationChecks_no_violation_of_completion
    {valuation : PartialValuation} {cap totalValue : Money}
    {overCap : Money → Money → EligibilityFailure}
    (lowerSound : valuation.lowerBound ≤ totalValue)
    (exactSound :
      ∀ value, valuation.exactValue = some value →
        totalValue = value)
    (withinCap : totalValue ≤ cap)
    (reason : EligibilityFailure) :
    (.violated reason :
      CheckResult EligibilityFact EligibilityFailure) ∉
      valuationChecks valuation cap overCap := by
  intro member
  rcases mem_violated_valuationChecks member with lowerOver | exactOver
  · exact (Nat.not_lt_of_ge (Nat.le_trans lowerSound withinCap)) lowerOver
  · obtain ⟨value, exactValue, valueOver⟩ := exactOver
    have totalEq := exactSound value exactValue
    rw [totalEq] at withinCap
    exact (Nat.not_lt_of_ge withinCap) valueOver

private theorem datedValuationChecks_no_violation
    {dateKnowledge : Knowledge CivilDate} {totalDate : CivilDate}
    (dateCompletion : dateKnowledge.Completes totalDate)
    {valuationFor : Thresholds → PartialValuation}
    {capFor : Thresholds → Money}
    {overCap : Money → Money → EligibilityFailure}
    {thresholds : Thresholds} {reason : EligibilityFailure}
    (thresholdResult : thresholdsFor totalDate = .ok thresholds)
    (valuationNo :
      (.violated reason :
        CheckResult EligibilityFact EligibilityFailure) ∉
        valuationChecks (valuationFor thresholds)
          (capFor thresholds) overCap) :
    (.violated reason :
      CheckResult EligibilityFact EligibilityFailure) ∉
      datedValuationChecks dateKnowledge valuationFor capFor overCap := by
  cases dateKnowledge with
  | unknown => simp [datedValuationChecks]
  | known date =>
      simp [Knowledge.Completes] at dateCompletion
      subst totalDate
      simp [datedValuationChecks, thresholdResult, valuationNo]

private theorem findAsset_eq_some_of_mem
    {estate : Estate} {asset : Asset} {id : AssetId}
    (unique : (estate.assets.map (·.id)).Nodup)
    (member : asset ∈ estate.assets)
    (sameId : asset.id = id) :
    estate.findAsset? id = some asset := by
  cases estate with
  | mk assets =>
      unfold Estate.findAsset?
      induction assets with
      | nil => simp at member
      | cons head tail ih =>
          simp only [List.map_cons, List.nodup_cons] at unique
          simp only [List.mem_cons] at member
          rcases member with rfl | member
          · simp [sameId]
          · have headDifferent : head.id ≠ id := by
              intro equal
              apply unique.1
              simp only [List.mem_map]
              exact ⟨asset, member, sameId.trans equal.symm⟩
            simpa [headDifferent] using ih unique.2 member

private theorem targetResolution_satisfied_sound
    {partialCase : PartialTransferCase} {total : TransferCase}
    (completion : partialCase.Completes total)
    (wellFormed : total.WellFormed)
    (satisfied : (targetResolution partialCase).1 = .satisfied) :
    ∃ partialAsset totalAsset,
      (targetResolution partialCase).2 = some partialAsset ∧
      total.target? = some totalAsset ∧
      partialAsset.Completes totalAsset := by
  cases targetKnown : partialCase.targetId with
  | unknown => simp [targetResolution, targetKnown] at satisfied
  | known id =>
      cases found : partialCase.estate.findAsset? id with
      | none =>
          cases inventory : partialCase.estate.inventoryComplete with
          | unknown =>
              simp [targetResolution, targetKnown, found, inventory] at satisfied
          | known complete =>
              cases complete <;>
                simp [targetResolution, targetKnown, found, inventory] at satisfied
      | some partialAsset =>
          have partialMember : partialAsset ∈ partialCase.estate.assets :=
            List.mem_of_find?_eq_some found
          have partialId : partialAsset.id = id := by
            have predicate :=
              List.find?_some found
            simpa using predicate
          obtain ⟨totalAsset, totalMember, assetCompletion⟩ :=
            completion.2.1.1 partialAsset partialMember
          have targetId : id = total.targetId := by
            have targetCompletion := completion.2.2.1
            simpa [targetKnown, Knowledge.Completes] using targetCompletion
          have totalFound :
              total.target? = some totalAsset := by
            apply findAsset_eq_some_of_mem wellFormed.1 totalMember
            exact assetCompletion.1.symm.trans (partialId.trans targetId)
          exact ⟨partialAsset, totalAsset,
            by simp [targetResolution, targetKnown, found],
            totalFound, assetCompletion⟩

private theorem targetResolution_no_violation
    {partialCase : PartialTransferCase} {total : TransferCase}
    {totalAsset : Asset}
    (completion : partialCase.Completes total)
    (wellFormed : total.WellFormed)
    (totalFound : total.target? = some totalAsset) :
    (∀ reason,
      (targetResolution partialCase).1 ≠ .violated reason) ∧
    ∀ partialAsset,
      (targetResolution partialCase).2 = some partialAsset →
        partialAsset.Completes totalAsset := by
  have totalMember : totalAsset ∈ total.estate.assets :=
    List.mem_of_find?_eq_some totalFound
  have totalAssetId : totalAsset.id = total.targetId := by
    have predicate := List.find?_some totalFound
    simpa using predicate
  cases targetKnown : partialCase.targetId with
  | unknown =>
      constructor
      · intro reason
        simp [targetResolution, targetKnown]
      · intro partialAsset resolved
        simp [targetResolution, targetKnown] at resolved
  | known id =>
      have targetId : id = total.targetId := by
        simpa [targetKnown, Knowledge.Completes] using completion.2.2.1
      cases found : partialCase.estate.findAsset? id with
      | some partialAsset =>
          have partialMember : partialAsset ∈ partialCase.estate.assets :=
            List.mem_of_find?_eq_some found
          obtain ⟨completed, completedMember, assetCompletion⟩ :=
            completion.2.1.1 partialAsset partialMember
          have partialId : partialAsset.id = id := by
            simpa using List.find?_some found
          have completedFound :
              total.target? = some completed := by
            apply findAsset_eq_some_of_mem wellFormed.1 completedMember
            exact assetCompletion.1.symm.trans
              (partialId.trans targetId)
          rw [totalFound] at completedFound
          injection completedFound with completedEq
          subst completed
          constructor
          · intro reason
            simp [targetResolution, targetKnown, found]
          · intro candidate resolved
            simp [targetResolution, targetKnown, found] at resolved
            subst candidate
            exact assetCompletion
      | none =>
          cases inventory : partialCase.estate.inventoryComplete with
          | unknown =>
              constructor
              · intro reason
                simp [targetResolution, targetKnown, found, inventory]
              · intro partialAsset resolved
                simp [targetResolution, targetKnown, found, inventory] at resolved
          | known complete =>
              cases complete with
              | false =>
                  constructor
                  · intro reason
                    simp [targetResolution, targetKnown, found, inventory]
                  · intro partialAsset resolved
                    simp [targetResolution, targetKnown, found, inventory] at resolved
              | true =>
                  have sameIds : partialCase.estate.sameAssetIds total.estate := by
                    simpa [PartialEstate.Completes, inventory] using
                      completion.2.1.2
                  have totalIdMember :
                      id ∈ total.estate.assets.map (·.id) := by
                    simp only [List.mem_map]
                    exact ⟨totalAsset, totalMember,
                      totalAssetId.trans targetId.symm⟩
                  have partialIdMember :
                      id ∈ partialCase.estate.assets.map (·.id) :=
                    (sameIds id).mpr totalIdMember
                  obtain ⟨partialAsset, partialMember, partialId⟩ :=
                    List.mem_map.mp partialIdMember
                  have notFound :=
                    (List.find?_eq_none.mp found) partialAsset partialMember
                  have predicate :
                      (partialAsset.id == id) = true := by
                    simp [partialId]
                  exact (notFound predicate).elim

private theorem deathDateCheck_satisfied_sound
    {partialCase : PartialTransferCase} {total : TransferCase}
    (completion : partialCase.Completes total)
    (satisfied : deathDateCheck partialCase.deathDate = .satisfied) :
    SupportedDeathDate total.deathDate := by
  cases dateKnown : partialCase.deathDate with
  | unknown => simp [deathDateCheck, dateKnown] at satisfied
  | known date =>
      have dateEq : date = total.deathDate := by
        simpa [dateKnown, Knowledge.Completes] using completion.1
      subst date
      cases classified : classifyDeathDate total.deathDate <;>
        simp [deathDateCheck, dateKnown, classified,
          SupportedDeathDate] at satisfied ⊢

private theorem deathDateCheck_satisfied_known
    {partialCase : PartialTransferCase} {total : TransferCase}
    (completion : partialCase.Completes total)
    (satisfied : deathDateCheck partialCase.deathDate = .satisfied) :
    partialCase.deathDate = .known total.deathDate := by
  cases dateKnown : partialCase.deathDate with
  | unknown => simp [deathDateCheck, dateKnown] at satisfied
  | known date =>
      have dateEq : date = total.deathDate := by
        simpa [dateKnown, Knowledge.Completes] using completion.1
      simp [dateEq]

private theorem deathDateCheck_no_violation
    {partialCase : PartialTransferCase} {total : TransferCase}
    (completion : partialCase.Completes total)
    (supported : SupportedDeathDate total.deathDate)
    (reason : EligibilityFailure) :
    deathDateCheck partialCase.deathDate ≠ .violated reason := by
  cases dateKnown : partialCase.deathDate with
  | unknown => simp [deathDateCheck]
  | known date =>
      have dateEq : date = total.deathDate := by
        simpa [dateKnown, Knowledge.Completes] using completion.1
      subst date
      cases classified : classifyDeathDate total.deathDate <;>
        simp [deathDateCheck, classified,
          SupportedDeathDate] at supported ⊢

private theorem survivorPropertyChecks_satisfied_sound
    {passesKnowledge belongsKnowledge : Knowledge Bool}
    {passes belongs : Bool}
    (passesCompletion : passesKnowledge.Completes passes)
    (belongsCompletion : belongsKnowledge.Completes belongs)
    (allSatisfied :
      ∀ check ∈ survivorPropertyChecks passesKnowledge belongsKnowledge,
        check = (.satisfied :
          CheckResult EligibilityFact EligibilityFailure)) :
    passes = true ∨ belongs = true := by
  cases passesKnowledge <;> cases belongsKnowledge <;>
    cases passes <;> cases belongs <;>
    simp_all [Knowledge.Completes, survivorPropertyChecks]

private theorem survivorPropertyChecks_no_violation
    {passesKnowledge belongsKnowledge : Knowledge Bool}
    {passes belongs : Bool}
    (passesCompletion : passesKnowledge.Completes passes)
    (belongsCompletion : belongsKnowledge.Completes belongs)
    (holds : passes = true ∨ belongs = true)
    (reason : EligibilityFailure) :
    (.violated reason :
      CheckResult EligibilityFact EligibilityFailure) ∉
      survivorPropertyChecks passesKnowledge belongsKnowledge := by
  cases passesKnowledge <;> cases belongsKnowledge <;>
    cases passes <;> cases belongs <;>
    simp_all [Knowledge.Completes, survivorPropertyChecks]

private theorem find?_map_of_pointwise
    (transform : α → β) (partialPredicate : β → Bool)
    (totalPredicate : α → Bool)
    (samePredicate :
      ∀ value, partialPredicate (transform value) = totalPredicate value)
    (values : List α) :
    (values.map transform).find? partialPredicate =
      (values.find? totalPredicate).map transform := by
  induction values with
  | nil => rfl
  | cons head tail ih =>
      simp only [List.map_cons, List.find?_cons]
      rw [samePredicate]
      cases totalPredicate head <;> simp [ih]

@[simp] private theorem findAsset_ofTotal
    (estate : Estate) (id : AssetId) :
    (PartialEstate.ofTotal estate).findAsset? id =
      (estate.findAsset? id).map PartialAsset.ofTotal := by
  cases estate with
  | mk assets =>
      exact find?_map_of_pointwise
        PartialAsset.ofTotal
        (fun asset => asset.id == id)
        (fun asset => asset.id == id)
        (by intro asset; rfl)
        assets

@[simp] private theorem inventoryComplete_ofTotal
    (estate : Estate) :
    (PartialEstate.ofTotal estate).inventoryComplete = .known true := rfl

@[simp] private theorem directTransferBasis_ofTreatment
    (asset : Asset) :
    asset.treatment.directTransferBasis = asset.directTransferBasis := by
  cases asset with
  | mk id name kind current death encumbrances treatment included primary =>
      cases treatment <;> rfl

theorem assessRoute_qualifies_all_completions
    {partialCase : PartialTransferCase} {route : SimplifiedRoute}
    (qualified : assessRoute partialCase route = .ok .qualifies) :
    ∀ total, partialCase.Completes total →
      TransferCase.WellFormed total →
      RouteEligible total route := by
  intro total completion wellFormed
  cases valid : validatePartialCase partialCase with
  | error error =>
      simp [assessRoute, valid] at qualified
  | ok unitValue =>
      cases unitValue
      obtain ⟨checks, checksResult⟩ :=
        eligibilityChecks_ok_of_validate partialCase route valid
      have aggregateResult : aggregateChecks checks = .qualifies := by
        simpa [assessRoute, valid, checksResult] using qualified
      have allSatisfied :
          ∀ check ∈ checks,
            check = (.satisfied :
              CheckResult EligibilityFact EligibilityFailure) :=
        (aggregateChecks_qualifies_iff checks).mp aggregateResult
      simp only [eligibilityChecks, valid] at checksResult
      injection checksResult with checksEq
      subst checks
      have deathSatisfied :
          deathDateCheck partialCase.deathDate = .satisfied :=
        allSatisfied _ (by simp)
      have targetSatisfied :
          (targetResolution partialCase).1 = .satisfied :=
        allSatisfied _ (by simp)
      have supported :=
        deathDateCheck_satisfied_sound completion deathSatisfied
      have deathKnown :=
        deathDateCheck_satisfied_known completion deathSatisfied
      obtain ⟨partialAsset, totalAsset, resolved, totalTarget,
          assetCompletion⟩ :=
        targetResolution_satisfied_sound completion wellFormed targetSatisfied
      have partialUnique :=
        validatePartialCase_ok_nodup valid
      rcases completion with
        ⟨dateCompletion, estateCompletion, targetCompletion,
          authorityCompletion, daysCompletion, sixMonthsCompletion,
          successorCompletion, superiorCompletion, debtsCompletion,
          survivorCompletion, passesCompletion, belongsCompletion⟩
      cases route with
      | directTransfer basis =>
          have treatmentSatisfied :
              checkKnowledge
                  (.assetField partialAsset.id .treatment)
                  (.directTransferBasisAbsent basis)
                  (fun treatment =>
                    treatment.directTransferBasis == some basis)
                  partialAsset.treatment =
                .satisfied :=
            allSatisfied _ (by
              simp [directTransferChecks, resolved])
          have basisCheck :=
            checkKnowledge_satisfied_sound
              assetCompletion.2.2.2.2.2.2.1
              treatmentSatisfied
          have basisEq :
              totalAsset.treatment.directTransferBasis = some basis := by
            simpa using basisCheck
          exact ⟨supported, wellFormed, totalAsset, totalTarget,
            by simpa [directTransferBasis_ofTreatment] using basisEq⟩
      | personalPropertyAffidavit =>
          have kindSatisfied :
              checkKnowledge
                  (.assetField partialAsset.id .kind)
                  .targetNotPersonalProperty
                  (fun kind => kind == .personal)
                  partialAsset.kind =
                .satisfied :=
            allSatisfied _ (by simp [personalChecks, resolved])
          have successorSatisfied :
              checkKnowledge .claimantIsSuccessor .claimantNotSuccessor
                  id partialCase.claimantIsSuccessor =
                .satisfied :=
            allSatisfied _ (by simp [personalChecks, resolved])
          have superiorSatisfied :
              checkKnowledge .noSuperiorRight .superiorRightExists
                  id partialCase.noSuperiorRight =
                .satisfied :=
            allSatisfied _ (by simp [personalChecks, resolved])
          have daysSatisfied :
              checkKnowledge .daysSinceDeath .fortyDaysNotElapsed
                  (fun days => 40 ≤ days) partialCase.daysSinceDeath =
                .satisfied :=
            allSatisfied _ (by simp [personalChecks, resolved])
          have authoritySatisfied :
              checkAuthority partialCase.authority = .satisfied :=
            allSatisfied _ (by simp [personalChecks, resolved])
          have targetKind :
              totalAsset.kind = .personal := by
            have checked :=
              checkKnowledge_satisfied_sound
                assetCompletion.2.2.1 kindSatisfied
            simpa using checked
          have successor :
              total.claimantIsSuccessor = true :=
            checkKnowledge_satisfied_sound
              successorCompletion successorSatisfied
          have noSuperior :
              total.noSuperiorRight = true :=
            checkKnowledge_satisfied_sound
              superiorCompletion superiorSatisfied
          have days : 40 ≤ total.daysSinceDeath := by
            have checked :=
              checkKnowledge_satisfied_sound daysCompletion daysSatisfied
            simpa using checked
          have authority :=
            checkAuthority_satisfied_sound
              authorityCompletion authoritySatisfied
          rw [deathKnown] at dateCompletion
          have dateEq : total.deathDate = total.deathDate := rfl
          cases thresholdResult : thresholdsFor total.deathDate with
          | error error =>
              have violated := allSatisfied
                (.violated .blockedByProceeding) (by
                  simp [personalChecks, resolved,
                    datedValuationChecks, deathKnown, thresholdResult])
              contradiction
          | ok thresholds =>
              have valuationAll :
                  ∀ check ∈ valuationChecks
                      (partialCase.estate.personalAffidavitValuation thresholds)
                      thresholds.personalPropertyAffidavit
                      EligibilityFailure.personalPropertyValueOverCap,
                    check = (.satisfied :
                      CheckResult EligibilityFact EligibilityFailure) := by
                intro check member
                apply allSatisfied check
                simp [personalChecks, resolved,
                  datedValuationChecks, deathKnown, thresholdResult,
                  member]
              obtain ⟨value, exactValue, withinCap⟩ :=
                valuationChecks_all_satisfied_exact
                  (partialCase.estate.personalAffidavitValuation thresholds)
                  thresholds.personalPropertyAffidavit
                  EligibilityFailure.personalPropertyValueOverCap
                  (personalValuation_coherent partialCase.estate thresholds)
                  valuationAll
              have totalValue :=
                personalValuation_exact_eq estateCompletion partialUnique
                  wellFormed.1 thresholds exactValue
              simp only [RouteEligible,
                PersonalPropertyAffidavitEligible, totalTarget]
              exact ⟨supported, wellFormed, targetKind, successor,
                noSuperior, days, authority,
                by simpa [thresholdResult, totalValue] using withinCap⟩
      | smallValueRealPropertyAffidavit =>
          have kindSatisfied :
              checkKnowledge
                  (.assetField partialAsset.id .kind)
                  .targetNotCaliforniaRealProperty
                  (fun kind => kind == .californiaReal)
                  partialAsset.kind =
                .satisfied :=
            allSatisfied _ (by simp [smallRealChecks, resolved])
          have treatmentSatisfied :
              checkKnowledge
                  (.assetField partialAsset.id .treatment)
                  .targetNotCounted
                  (fun treatment => treatment == .counted)
                  partialAsset.treatment =
                .satisfied :=
            allSatisfied _ (by simp [smallRealChecks, resolved])
          have successorSatisfied :
              checkKnowledge .claimantIsSuccessor .claimantNotSuccessor
                  id partialCase.claimantIsSuccessor =
                .satisfied :=
            allSatisfied _ (by simp [smallRealChecks, resolved])
          have superiorSatisfied :
              checkKnowledge .noSuperiorRight .superiorRightExists
                  id partialCase.noSuperiorRight =
                .satisfied :=
            allSatisfied _ (by simp [smallRealChecks, resolved])
          have monthsSatisfied :
              checkKnowledge .sixMonthsElapsed .sixMonthsNotElapsed
                  id partialCase.sixMonthsElapsed =
                .satisfied :=
            allSatisfied _ (by simp [smallRealChecks, resolved])
          have authoritySatisfied :
              checkAuthority partialCase.authority = .satisfied :=
            allSatisfied _ (by simp [smallRealChecks, resolved])
          have debtsSatisfied :
              checkKnowledge .debtsPaid .requiredDebtsUnpaid
                  id partialCase.funeralLastIllnessAndUnsecuredDebtsPaid =
                .satisfied :=
            allSatisfied _ (by simp [smallRealChecks, resolved])
          have targetKind :
              totalAsset.kind = .californiaReal := by
            have checked := checkKnowledge_satisfied_sound
              assetCompletion.2.2.1 kindSatisfied
            simpa using checked
          have targetTreatment :
              totalAsset.treatment = .counted := by
            have checked := checkKnowledge_satisfied_sound
              assetCompletion.2.2.2.2.2.2.1 treatmentSatisfied
            simpa using checked
          have successor :
              total.claimantIsSuccessor = true :=
            checkKnowledge_satisfied_sound
              successorCompletion successorSatisfied
          have noSuperior :
              total.noSuperiorRight = true :=
            checkKnowledge_satisfied_sound
              superiorCompletion superiorSatisfied
          have sixMonths :
              total.sixMonthsElapsed = true :=
            checkKnowledge_satisfied_sound
              sixMonthsCompletion monthsSatisfied
          have authority := checkAuthority_satisfied_sound
            authorityCompletion authoritySatisfied
          have debts :
              total.funeralLastIllnessAndUnsecuredDebtsPaid = true :=
            checkKnowledge_satisfied_sound
              debtsCompletion debtsSatisfied
          cases thresholdResult : thresholdsFor total.deathDate with
          | error error =>
              have violated := allSatisfied
                (.violated .blockedByProceeding) (by
                  simp [smallRealChecks, resolved,
                    datedValuationChecks, deathKnown, thresholdResult])
              contradiction
          | ok thresholds =>
              have valuationAll :
                  ∀ check ∈ valuationChecks
                      partialCase.estate.smallRealPropertyValuation
                      thresholds.smallValueRealPropertyAffidavit
                      EligibilityFailure.smallRealPropertyValueOverCap,
                    check = (.satisfied :
                      CheckResult EligibilityFact EligibilityFailure) := by
                intro check member
                apply allSatisfied check
                simp [smallRealChecks, resolved,
                  datedValuationChecks, deathKnown, thresholdResult,
                  member]
              obtain ⟨value, exactValue, withinCap⟩ :=
                valuationChecks_all_satisfied_exact
                  partialCase.estate.smallRealPropertyValuation
                  thresholds.smallValueRealPropertyAffidavit
                  EligibilityFailure.smallRealPropertyValueOverCap
                  (smallRealValuation_coherent partialCase.estate)
                  valuationAll
              have totalValue :=
                smallRealValuation_exact_eq estateCompletion partialUnique
                  wellFormed.1 exactValue
              simp only [RouteEligible,
                SmallValueRealPropertyAffidavitEligible, totalTarget]
              exact ⟨supported, wellFormed, targetKind, targetTreatment,
                successor, noSuperior, sixMonths, authority, debts,
                by simpa [thresholdResult, totalValue] using withinCap⟩
      | primaryResidencePetition =>
          have kindSatisfied :
              checkKnowledge
                  (.assetField partialAsset.id .kind)
                  .targetNotCaliforniaRealProperty
                  (fun kind => kind == .californiaReal)
                  partialAsset.kind =
                .satisfied :=
            allSatisfied _ (by simp [primaryResidenceChecks, resolved])
          have treatmentSatisfied :
              checkKnowledge
                  (.assetField partialAsset.id .treatment)
                  .targetNotCounted
                  (fun treatment => treatment == .counted)
                  partialAsset.treatment =
                .satisfied :=
            allSatisfied _ (by simp [primaryResidenceChecks, resolved])
          have residenceSatisfied :
              checkKnowledge
                  (.assetField partialAsset.id .primaryResidence)
                  .targetNotPrimaryResidence id partialAsset.isPrimaryResidence =
                .satisfied :=
            allSatisfied _ (by simp [primaryResidenceChecks, resolved])
          have successorSatisfied :
              checkKnowledge .claimantIsSuccessor .claimantNotSuccessor
                  id partialCase.claimantIsSuccessor =
                .satisfied :=
            allSatisfied _ (by simp [primaryResidenceChecks, resolved])
          have daysSatisfied :
              checkKnowledge .daysSinceDeath .fortyDaysNotElapsed
                  (fun days => 40 ≤ days) partialCase.daysSinceDeath =
                .satisfied :=
            allSatisfied _ (by simp [primaryResidenceChecks, resolved])
          have authoritySatisfied :
              checkAuthority partialCase.authority = .satisfied :=
            allSatisfied _ (by simp [primaryResidenceChecks, resolved])
          have targetKind :
              totalAsset.kind = .californiaReal := by
            have checked := checkKnowledge_satisfied_sound
              assetCompletion.2.2.1 kindSatisfied
            simpa using checked
          have targetTreatment :
              totalAsset.treatment = .counted := by
            have checked := checkKnowledge_satisfied_sound
              assetCompletion.2.2.2.2.2.2.1 treatmentSatisfied
            simpa using checked
          have targetResidence :
              totalAsset.isPrimaryResidence = true :=
            checkKnowledge_satisfied_sound
              assetCompletion.2.2.2.2.2.2.2.2
              residenceSatisfied
          have successor :
              total.claimantIsSuccessor = true :=
            checkKnowledge_satisfied_sound
              successorCompletion successorSatisfied
          have days : 40 ≤ total.daysSinceDeath := by
            have checked := checkKnowledge_satisfied_sound
              daysCompletion daysSatisfied
            simpa using checked
          have authority := checkAuthority_satisfied_sound
            authorityCompletion authoritySatisfied
          cases thresholdResult : thresholdsFor total.deathDate with
          | error error =>
              have violated := allSatisfied
                (.violated .blockedByProceeding) (by
                  simp [primaryResidenceChecks, resolved,
                    datedValuationChecks, deathKnown, thresholdResult])
              contradiction
          | ok thresholds =>
              have valuationAll :
                  ∀ check ∈ valuationChecks
                      partialCase.estate.primaryResidenceValuation
                      thresholds.primaryResidencePetition
                      EligibilityFailure.primaryResidenceValueOverCap,
                    check = (.satisfied :
                      CheckResult EligibilityFact EligibilityFailure) := by
                intro check member
                apply allSatisfied check
                simp [primaryResidenceChecks, resolved,
                  datedValuationChecks, deathKnown, thresholdResult,
                  member]
              obtain ⟨value, exactValue, withinCap⟩ :=
                valuationChecks_all_satisfied_exact
                  partialCase.estate.primaryResidenceValuation
                  thresholds.primaryResidencePetition
                  EligibilityFailure.primaryResidenceValueOverCap
                  (primaryResidenceValuation_coherent partialCase.estate)
                  valuationAll
              have totalValue :=
                primaryResidenceValuation_exact_eq estateCompletion partialUnique
                  wellFormed.1 exactValue
              simp only [RouteEligible,
                PrimaryResidencePetitionEligible, totalTarget]
              exact ⟨supported, wellFormed, targetKind, targetTreatment,
                targetResidence, successor, days, authority,
                by simpa [thresholdResult, totalValue] using withinCap⟩
      | spousalPropertyPetition =>
          have survivorSatisfied :
              checkKnowledge .survivorStatus .noSurvivingSpouseOrPartner
                  (fun status =>
                    match status with
                    | .none => false
                    | _ => true) partialCase.survivorStatus =
                .satisfied :=
            allSatisfied _ (by simp [spousalChecks])
          have propertyAll :
              ∀ check ∈ survivorPropertyChecks
                  partialCase.propertyPassesToSurvivor
                  partialCase.propertyBelongsToSurvivor,
                check = (.satisfied :
                  CheckResult EligibilityFact EligibilityFailure) := by
            intro check member
            apply allSatisfied check
            simp [spousalChecks, member]
          have survivorCheck :=
            checkKnowledge_satisfied_sound
              survivorCompletion survivorSatisfied
          have survivor : total.survivorStatus ≠ .none := by
            cases status : total.survivorStatus with
            | none => simp [status] at survivorCheck
            | spouse => simp
            | registeredDomesticPartner => simp
          have property :=
            survivorPropertyChecks_satisfied_sound
              passesCompletion belongsCompletion propertyAll
          simp only [RouteEligible, SpousalPropertyPetitionEligible]
          exact ⟨supported, wellFormed,
            by simp [totalTarget], survivor, property⟩

theorem assessRoute_disqualified_no_completion
    {partialCase : PartialTransferCase} {route : SimplifiedRoute}
    {reasons : List EligibilityFailure}
    (disqualified :
      assessRoute partialCase route =
        .ok (.doesNotQualify reasons)) :
    ∀ total, partialCase.Completes total →
      TransferCase.WellFormed total →
      ¬ RouteEligible total route := by
  intro total completion wellFormed eligible
  cases valid : validatePartialCase partialCase with
  | error error =>
      simp [assessRoute, valid] at disqualified
  | ok unitValue =>
      cases unitValue
      obtain ⟨checks, checksResult⟩ :=
        eligibilityChecks_ok_of_validate partialCase route valid
      have aggregateResult :
          aggregateChecks checks = .doesNotQualify reasons := by
        simpa [assessRoute, valid, checksResult] using disqualified
      have reasonsNonempty :=
        aggregateChecks_disqualified_nonempty aggregateResult
      cases reasons with
      | nil => exact reasonsNonempty rfl
      | cons reason rest =>
          have violation :
              (.violated reason :
                CheckResult EligibilityFact EligibilityFailure) ∈ checks :=
            (mem_disqualifier_of_aggregate aggregateResult reason).mp (by simp)
          simp only [eligibilityChecks, valid] at checksResult
          injection checksResult with checksEq
          subst checks
          have supported := eligible.supportedAndWellFormed.1
          have partialUnique := validatePartialCase_ok_nodup valid
          obtain ⟨totalAsset, totalTarget⟩ := eligible.targetExists
          have targetSound :=
            targetResolution_no_violation completion wellFormed totalTarget
          have deathNe :
              (.violated reason :
                CheckResult EligibilityFact EligibilityFailure) ≠
                deathDateCheck partialCase.deathDate :=
            Ne.symm (deathDateCheck_no_violation completion supported reason)
          have targetNe :
              (.violated reason :
                CheckResult EligibilityFact EligibilityFailure) ≠
                (targetResolution partialCase).1 :=
            Ne.symm (targetSound.1 reason)
          rcases completion with
            ⟨dateCompletion, estateCompletion, targetCompletion,
              authorityCompletion, daysCompletion, sixMonthsCompletion,
              successorCompletion, superiorCompletion, debtsCompletion,
              survivorCompletion, passesCompletion, belongsCompletion⟩
          cases resolvedTarget :
              (targetResolution partialCase).2 with
          | none =>
              cases route with
              | directTransfer basis =>
                  simp [directTransferChecks, resolvedTarget,
                    deathNe, targetNe] at violation
              | personalPropertyAffidavit =>
                  simp only [RouteEligible,
                    PersonalPropertyAffidavitEligible, totalTarget] at eligible
                  rcases eligible with
                    ⟨_, _, _, successor, noSuperior, days,
                      authority, capEligible⟩
                  have successorNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .claimantIsSuccessor)
                      (failure := .claimantNotSuccessor)
                      (predicate := id) (reason := reason)
                      successorCompletion successor
                  have superiorNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .noSuperiorRight)
                      (failure := .superiorRightExists)
                      (predicate := id) (reason := reason)
                      superiorCompletion noSuperior
                  have daysNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .daysSinceDeath)
                      (failure := .fortyDaysNotElapsed)
                      (predicate := fun current : Nat => 40 ≤ current)
                      (reason := reason) daysCompletion (by simpa using days)
                  have authorityNe :=
                    Ne.symm <| checkAuthority_no_violation
                      authorityCompletion authority reason
                  cases thresholdResult :
                      thresholdsFor total.deathDate with
                  | error error =>
                      simp [thresholdResult] at capEligible
                  | ok thresholds =>
                      simp [thresholdResult] at capEligible
                      have valuationNo :=
                        valuationChecks_no_violation_of_completion
                          (overCap :=
                            EligibilityFailure.personalPropertyValueOverCap)
                          (personalValuation_lowerBound_le estateCompletion
                            partialUnique thresholds)
                          (fun value exactValue =>
                            personalValuation_exact_eq estateCompletion
                              partialUnique wellFormed.1 thresholds exactValue)
                          capEligible reason
                      have datedNo :=
                        datedValuationChecks_no_violation
                          (valuationFor :=
                            partialCase.estate.personalAffidavitValuation)
                          (capFor := (·.personalPropertyAffidavit))
                          (overCap :=
                            EligibilityFailure.personalPropertyValueOverCap)
                          dateCompletion
                          thresholdResult valuationNo
                      simp [personalChecks, resolvedTarget,
                        deathNe, targetNe, successorNe, superiorNe,
                        daysNe, authorityNe, datedNo] at violation
              | smallValueRealPropertyAffidavit =>
                  simp only [RouteEligible,
                    SmallValueRealPropertyAffidavitEligible,
                    totalTarget] at eligible
                  rcases eligible with
                    ⟨_, _, _, _, successor, noSuperior, sixMonths,
                      authority, debts, capEligible⟩
                  have successorNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .claimantIsSuccessor)
                      (failure := .claimantNotSuccessor)
                      (predicate := id) (reason := reason)
                      successorCompletion successor
                  have superiorNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .noSuperiorRight)
                      (failure := .superiorRightExists)
                      (predicate := id) (reason := reason)
                      superiorCompletion noSuperior
                  have monthsNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .sixMonthsElapsed)
                      (failure := .sixMonthsNotElapsed)
                      (predicate := id) (reason := reason)
                      sixMonthsCompletion sixMonths
                  have authorityNe :=
                    Ne.symm <| checkAuthority_no_violation
                      authorityCompletion authority reason
                  have debtsNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .debtsPaid)
                      (failure := .requiredDebtsUnpaid)
                      (predicate := id) (reason := reason)
                      debtsCompletion debts
                  cases thresholdResult :
                      thresholdsFor total.deathDate with
                  | error error =>
                      simp [thresholdResult] at capEligible
                  | ok thresholds =>
                      simp [thresholdResult] at capEligible
                      have valuationNo :=
                        valuationChecks_no_violation_of_completion
                          (overCap :=
                            EligibilityFailure.smallRealPropertyValueOverCap)
                          (smallRealValuation_lowerBound_le estateCompletion
                            partialUnique)
                          (fun value exactValue =>
                            smallRealValuation_exact_eq estateCompletion
                              partialUnique wellFormed.1 exactValue)
                          capEligible reason
                      have datedNo :=
                        datedValuationChecks_no_violation
                          (valuationFor := fun _ =>
                            partialCase.estate.smallRealPropertyValuation)
                          (capFor := (·.smallValueRealPropertyAffidavit))
                          (overCap :=
                            EligibilityFailure.smallRealPropertyValueOverCap)
                          dateCompletion
                          thresholdResult valuationNo
                      simp [smallRealChecks, resolvedTarget,
                        deathNe, targetNe, successorNe, superiorNe,
                        monthsNe, authorityNe, debtsNe, datedNo] at violation
              | primaryResidencePetition =>
                  simp only [RouteEligible,
                    PrimaryResidencePetitionEligible, totalTarget] at eligible
                  rcases eligible with
                    ⟨_, _, _, _, _, successor, days, authority,
                      capEligible⟩
                  have successorNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .claimantIsSuccessor)
                      (failure := .claimantNotSuccessor)
                      (predicate := id) (reason := reason)
                      successorCompletion successor
                  have daysNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .daysSinceDeath)
                      (failure := .fortyDaysNotElapsed)
                      (predicate := fun current : Nat => 40 ≤ current)
                      (reason := reason) daysCompletion (by simpa using days)
                  have authorityNe :=
                    Ne.symm <| checkAuthority_no_violation
                      authorityCompletion authority reason
                  cases thresholdResult :
                      thresholdsFor total.deathDate with
                  | error error =>
                      simp [thresholdResult] at capEligible
                  | ok thresholds =>
                      simp [thresholdResult] at capEligible
                      have valuationNo :=
                        valuationChecks_no_violation_of_completion
                          (overCap :=
                            EligibilityFailure.primaryResidenceValueOverCap)
                          (primaryResidenceValuation_lowerBound_le
                            estateCompletion partialUnique)
                          (fun value exactValue =>
                            primaryResidenceValuation_exact_eq
                              estateCompletion partialUnique wellFormed.1
                              exactValue)
                          capEligible reason
                      have datedNo :=
                        datedValuationChecks_no_violation
                          (valuationFor := fun _ =>
                            partialCase.estate.primaryResidenceValuation)
                          (capFor := (·.primaryResidencePetition))
                          (overCap :=
                            EligibilityFailure.primaryResidenceValueOverCap)
                          dateCompletion
                          thresholdResult valuationNo
                      simp [primaryResidenceChecks, resolvedTarget,
                        deathNe, targetNe, successorNe, daysNe,
                        authorityNe, datedNo] at violation
              | spousalPropertyPetition =>
                  rcases eligible with
                    ⟨_, _, _, survivor, property⟩
                  have survivorHolds :
                      (match total.survivorStatus with
                        | .none => false
                        | _ => true) = true := by
                    cases status : total.survivorStatus with
                    | none => exact (survivor status).elim
                    | spouse => rfl
                    | registeredDomesticPartner => rfl
                  have survivorNe :=
                    Ne.symm <| checkKnowledge_no_violation
                      (fact := .survivorStatus)
                      (failure := .noSurvivingSpouseOrPartner)
                      (predicate := fun status : SurvivorStatus =>
                        match status with
                        | .none => false
                        | _ => true)
                      (reason := reason) survivorCompletion survivorHolds
                  have propertyNo :=
                    survivorPropertyChecks_no_violation
                      passesCompletion belongsCompletion property reason
                  simp [spousalChecks, deathNe, targetNe,
                    survivorNe, propertyNo] at violation
          | some partialAsset =>
              have assetCompletion :=
                targetSound.2 partialAsset resolvedTarget
              cases route with
              | directTransfer basis =>
                  obtain ⟨eligibleTarget, eligibleFound, basisEq⟩ :=
                    eligible.2.2
                  rw [totalTarget] at eligibleFound
                  injection eligibleFound with eligibleTargetEq
                  subst eligibleTarget
                  have basisHolds :
                      (totalAsset.treatment.directTransferBasis ==
                        some basis) = true := by
                    simp [directTransferBasis_ofTreatment, basisEq]
                  have treatmentNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge
                          (.assetField partialAsset.id .treatment)
                          (.directTransferBasisAbsent basis)
                          (fun treatment =>
                            treatment.directTransferBasis == some basis)
                          partialAsset.treatment :=
                    Ne.symm <| checkKnowledge_no_violation
                      assetCompletion.2.2.2.2.2.2.1 basisHolds
                  simp [directTransferChecks, resolvedTarget,
                    deathNe, targetNe, treatmentNe] at violation
              | personalPropertyAffidavit =>
                  simp only [RouteEligible,
                    PersonalPropertyAffidavitEligible, totalTarget] at eligible
                  rcases eligible with
                    ⟨_, _, targetKind, successor, noSuperior, days,
                      authority, capEligible⟩
                  have kindNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge
                          (.assetField partialAsset.id .kind)
                          .targetNotPersonalProperty
                          (fun kind => kind == .personal)
                          partialAsset.kind :=
                    Ne.symm <| checkKnowledge_no_violation
                      assetCompletion.2.2.1 (by simp [targetKind])
                  have successorNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .claimantIsSuccessor
                          .claimantNotSuccessor id
                          partialCase.claimantIsSuccessor :=
                    Ne.symm <| checkKnowledge_no_violation
                      successorCompletion successor
                  have superiorNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .noSuperiorRight
                          .superiorRightExists id
                          partialCase.noSuperiorRight :=
                    Ne.symm <| checkKnowledge_no_violation
                      superiorCompletion noSuperior
                  have daysNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .daysSinceDeath
                          .fortyDaysNotElapsed
                          (fun current => 40 ≤ current)
                          partialCase.daysSinceDeath :=
                    Ne.symm <| checkKnowledge_no_violation
                      daysCompletion (by simpa using days)
                  have authorityNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkAuthority partialCase.authority :=
                    Ne.symm <| checkAuthority_no_violation
                      authorityCompletion authority reason
                  cases thresholdResult :
                      thresholdsFor total.deathDate with
                  | error error =>
                      simp [thresholdResult] at capEligible
                  | ok thresholds =>
                      simp [thresholdResult] at capEligible
                      have lowerSound :=
                        personalValuation_lowerBound_le estateCompletion
                          partialUnique thresholds
                      have valuationNo :=
                        valuationChecks_no_violation_of_completion
                          (overCap :=
                            EligibilityFailure.personalPropertyValueOverCap)
                          lowerSound
                          (fun value exactValue =>
                            personalValuation_exact_eq estateCompletion
                              partialUnique wellFormed.1 thresholds exactValue)
                          capEligible reason
                      have datedNo :=
                        datedValuationChecks_no_violation
                          (valuationFor :=
                            partialCase.estate.personalAffidavitValuation)
                          (capFor := (·.personalPropertyAffidavit))
                          (overCap :=
                            EligibilityFailure.personalPropertyValueOverCap)
                          dateCompletion
                          thresholdResult valuationNo
                      simp [personalChecks, resolvedTarget,
                        deathNe, targetNe, kindNe, successorNe,
                        superiorNe, daysNe, authorityNe, datedNo] at violation
              | smallValueRealPropertyAffidavit =>
                  simp only [RouteEligible,
                    SmallValueRealPropertyAffidavitEligible,
                    totalTarget] at eligible
                  rcases eligible with
                    ⟨_, _, targetKind, targetTreatment, successor,
                      noSuperior, sixMonths, authority, debts, capEligible⟩
                  have kindNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge
                          (.assetField partialAsset.id .kind)
                          .targetNotCaliforniaRealProperty
                          (fun kind => kind == .californiaReal)
                          partialAsset.kind :=
                    Ne.symm <| checkKnowledge_no_violation
                      assetCompletion.2.2.1 (by simp [targetKind])
                  have treatmentNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge
                          (.assetField partialAsset.id .treatment)
                          .targetNotCounted
                          (fun treatment => treatment == .counted)
                          partialAsset.treatment :=
                    Ne.symm <| checkKnowledge_no_violation
                      assetCompletion.2.2.2.2.2.2.1
                      (by simp [targetTreatment])
                  have successorNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .claimantIsSuccessor
                          .claimantNotSuccessor id
                          partialCase.claimantIsSuccessor :=
                    Ne.symm <| checkKnowledge_no_violation
                      successorCompletion successor
                  have superiorNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .noSuperiorRight
                          .superiorRightExists id
                          partialCase.noSuperiorRight :=
                    Ne.symm <| checkKnowledge_no_violation
                      superiorCompletion noSuperior
                  have monthsNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .sixMonthsElapsed
                          .sixMonthsNotElapsed id
                          partialCase.sixMonthsElapsed :=
                    Ne.symm <| checkKnowledge_no_violation
                      sixMonthsCompletion sixMonths
                  have authorityNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkAuthority partialCase.authority :=
                    Ne.symm <| checkAuthority_no_violation
                      authorityCompletion authority reason
                  have debtsNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .debtsPaid .requiredDebtsUnpaid
                          id partialCase.funeralLastIllnessAndUnsecuredDebtsPaid :=
                    Ne.symm <| checkKnowledge_no_violation
                      debtsCompletion debts
                  cases thresholdResult :
                      thresholdsFor total.deathDate with
                  | error error =>
                      simp [thresholdResult] at capEligible
                  | ok thresholds =>
                      simp [thresholdResult] at capEligible
                      have lowerSound :=
                        smallRealValuation_lowerBound_le estateCompletion
                          partialUnique
                      have valuationNo :=
                        valuationChecks_no_violation_of_completion
                          (overCap :=
                            EligibilityFailure.smallRealPropertyValueOverCap)
                          lowerSound
                          (fun value exactValue =>
                            smallRealValuation_exact_eq estateCompletion
                              partialUnique wellFormed.1 exactValue)
                          capEligible reason
                      have datedNo :=
                        datedValuationChecks_no_violation
                          (valuationFor := fun _ =>
                            partialCase.estate.smallRealPropertyValuation)
                          (capFor := (·.smallValueRealPropertyAffidavit))
                          (overCap :=
                            EligibilityFailure.smallRealPropertyValueOverCap)
                          dateCompletion
                          thresholdResult valuationNo
                      simp [smallRealChecks, resolvedTarget,
                        deathNe, targetNe, kindNe, treatmentNe,
                        successorNe, superiorNe, monthsNe, authorityNe,
                        debtsNe, datedNo] at violation
              | primaryResidencePetition =>
                  simp only [RouteEligible,
                    PrimaryResidencePetitionEligible, totalTarget] at eligible
                  rcases eligible with
                    ⟨_, _, targetKind, targetTreatment, targetResidence,
                      successor, days, authority, capEligible⟩
                  have kindNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge
                          (.assetField partialAsset.id .kind)
                          .targetNotCaliforniaRealProperty
                          (fun kind => kind == .californiaReal)
                          partialAsset.kind :=
                    Ne.symm <| checkKnowledge_no_violation
                      assetCompletion.2.2.1 (by simp [targetKind])
                  have treatmentNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge
                          (.assetField partialAsset.id .treatment)
                          .targetNotCounted
                          (fun treatment => treatment == .counted)
                          partialAsset.treatment :=
                    Ne.symm <| checkKnowledge_no_violation
                      assetCompletion.2.2.2.2.2.2.1
                      (by simp [targetTreatment])
                  have residenceNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge
                          (.assetField partialAsset.id .primaryResidence)
                          .targetNotPrimaryResidence id
                          partialAsset.isPrimaryResidence :=
                    Ne.symm <| checkKnowledge_no_violation
                      assetCompletion.2.2.2.2.2.2.2.2 targetResidence
                  have successorNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .claimantIsSuccessor
                          .claimantNotSuccessor id
                          partialCase.claimantIsSuccessor :=
                    Ne.symm <| checkKnowledge_no_violation
                      successorCompletion successor
                  have daysNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .daysSinceDeath
                          .fortyDaysNotElapsed
                          (fun current => 40 ≤ current)
                          partialCase.daysSinceDeath :=
                    Ne.symm <| checkKnowledge_no_violation
                      daysCompletion (by simpa using days)
                  have authorityNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkAuthority partialCase.authority :=
                    Ne.symm <| checkAuthority_no_violation
                      authorityCompletion authority reason
                  cases thresholdResult :
                      thresholdsFor total.deathDate with
                  | error error =>
                      simp [thresholdResult] at capEligible
                  | ok thresholds =>
                      simp [thresholdResult] at capEligible
                      have lowerSound :=
                        primaryResidenceValuation_lowerBound_le
                          estateCompletion partialUnique
                      have valuationNo :=
                        valuationChecks_no_violation_of_completion
                          (overCap :=
                            EligibilityFailure.primaryResidenceValueOverCap)
                          lowerSound
                          (fun value exactValue =>
                            primaryResidenceValuation_exact_eq
                              estateCompletion partialUnique wellFormed.1
                              exactValue)
                          capEligible reason
                      have datedNo :=
                        datedValuationChecks_no_violation
                          (valuationFor := fun _ =>
                            partialCase.estate.primaryResidenceValuation)
                          (capFor := (·.primaryResidencePetition))
                          (overCap :=
                            EligibilityFailure.primaryResidenceValueOverCap)
                          dateCompletion
                          thresholdResult valuationNo
                      simp [primaryResidenceChecks, resolvedTarget,
                        deathNe, targetNe, kindNe, treatmentNe,
                        residenceNe, successorNe, daysNe, authorityNe,
                        datedNo] at violation
              | spousalPropertyPetition =>
                  rcases eligible with
                    ⟨_, _, _, survivor, property⟩
                  have survivorHolds :
                      (match total.survivorStatus with
                        | .none => false
                        | _ => true) = true := by
                    cases status : total.survivorStatus with
                    | none => exact (survivor status).elim
                    | spouse => rfl
                    | registeredDomesticPartner => rfl
                  have survivorNe :
                      (.violated reason :
                        CheckResult EligibilityFact EligibilityFailure) ≠
                        checkKnowledge .survivorStatus
                          .noSurvivingSpouseOrPartner
                          (fun status =>
                            match status with
                            | .none => false
                            | _ => true)
                          partialCase.survivorStatus :=
                    Ne.symm <| checkKnowledge_no_violation
                      survivorCompletion survivorHolds
                  have propertyNo :=
                    survivorPropertyChecks_no_violation
                      passesCompletion belongsCompletion property reason
                  simp [spousalChecks, deathNe, targetNe,
                    survivorNe, propertyNo] at violation

theorem eligibilityChecks_ofTotal_all_satisfied_iff
    (case : TransferCase) (route : SimplifiedRoute) :
    (∃ checks,
      eligibilityChecks case.toPartial route = .ok checks ∧
      ∀ check ∈ checks, check = .satisfied) ↔
    RouteEligible case route := by
  cases validation : validatePartialCase case.toPartial with
  | error error =>
      have invalid :
          ¬(SupportedDeathDate case.deathDate ∧ case.WellFormed) := by
        intro valid
        have ok :=
          (validatePartialCase_toPartial_ok_iff_supported case).mpr valid
        rw [validation] at ok
        contradiction
      constructor
      · rintro ⟨checks, checksResult, allSatisfied⟩
        simp [eligibilityChecks, validation] at checksResult
      · intro eligible
        exfalso
        exact invalid eligible.supportedAndWellFormed
  | ok unitValue =>
      cases unitValue
      have wellFormed : case.WellFormed :=
        ((validatePartialCase_toPartial_ok_iff_supported case).mp
          validation).2
      simp only [eligibilityChecks, validation]
      cases route <;>
        cases dateResult : classifyDeathDate case.deathDate <;>
        cases targetResult : case.target? <;>
        simp [TransferCase.target?] at targetResult <;>
        simp [RouteEligible, DirectTransferEligible,
          PersonalPropertyAffidavitEligible,
          SmallValueRealPropertyAffidavitEligible,
          PrimaryResidencePetitionEligible,
          SpousalPropertyPetitionEligible,
          wellFormed, TransferCase.target?,
          TransferCase.toPartial,
          targetResolution, deathDateCheck, directTransferChecks,
          personalChecks, smallRealChecks, primaryResidenceChecks,
          spousalChecks,
          datedValuationChecks,
          ValuationTreatment.directTransferBasis,
          PartialAsset.ofTotal, Asset.directTransferBasis,
          SummaryAuthority.Permits, SupportedDeathDate, thresholdsFor,
          Except.map,
          personalValuation_ofTotal_exact,
          smallRealPropertyValuation_ofTotal_exact,
          primaryResidenceValuation_ofTotal_exact,
          dateResult, targetResult] <;>
        try rfl <;>
        cases case.authority <;>
        simp [checkAuthority, SummaryAuthority.Permits, Except.map] <;>
        cases case.survivorStatus <;>
        simp

theorem assessRoute_ofTotal_qualifies_iff
    (case : TransferCase) (route : SimplifiedRoute) :
    assessRoute case.toPartial route = .ok .qualifies ↔
      RouteEligible case route := by
  rw [← eligibilityChecks_ofTotal_all_satisfied_iff]
  cases validation : validatePartialCase case.toPartial with
  | error error =>
      simp [assessRoute, eligibilityChecks, validation]
  | ok unitValue =>
      cases unitValue
      obtain ⟨checks, checksResult⟩ :=
        eligibilityChecks_ok_of_validate case.toPartial route validation
      simp [assessRoute, validation, checksResult,
        aggregateChecks_qualifies_iff]

private theorem eligibilityChecks_ofTotal_no_unknown
    (case : TransferCase) (route : SimplifiedRoute)
    (valid : validatePartialCase case.toPartial = .ok ())
    {checks : List (CheckResult EligibilityFact EligibilityFailure)}
    (result : eligibilityChecks case.toPartial route = .ok checks) :
    ∀ fact, .unknown fact ∉ checks := by
  simp only [eligibilityChecks, valid] at result
  injection result with checksEq
  subst checks
  cases route <;>
    cases targetResult : case.target? <;>
    simp [TransferCase.target?] at targetResult <;>
    cases thresholdResult : thresholdsFor case.deathDate <;>
    simp [TransferCase.toPartial,
      targetResolution,
      directTransferChecks, personalChecks, smallRealChecks,
      primaryResidenceChecks, spousalChecks,
      datedValuationChecks,
      ValuationTreatment.directTransferBasis,
      PartialAsset.ofTotal,
      personalValuation_ofTotal_exact,
      smallRealPropertyValuation_ofTotal_exact,
      primaryResidenceValuation_ofTotal_exact,
      targetResult, thresholdResult]

theorem assessRoute_ofTotal_needsInformation_false
    (case : TransferCase) (route : SimplifiedRoute) (facts : List EligibilityFact) :
    assessRoute case.toPartial route ≠ .ok (.needsInformation facts) := by
  intro result
  cases valid : validatePartialCase case.toPartial with
  | error error =>
      simp [assessRoute, valid] at result
  | ok unitValue =>
      cases unitValue
      cases checksResult :
          eligibilityChecks case.toPartial route with
      | error error =>
          simp [assessRoute, valid, checksResult] at result
      | ok checks =>
          have aggregateResult :
              aggregateChecks checks = .needsInformation facts := by
            simpa [assessRoute, valid, checksResult] using result
          have nonempty : facts ≠ [] :=
            aggregateChecks_information_nonempty aggregateResult
          cases facts with
          | nil => exact nonempty rfl
          | cons fact rest =>
              have unknownMember : (.unknown fact :
                  CheckResult EligibilityFact EligibilityFailure) ∈ checks :=
                (mem_requiredFact_of_aggregate aggregateResult fact).mp (by simp)
              exact
                (eligibilityChecks_ofTotal_no_unknown case route valid
                  checksResult fact) unknownMember

theorem assessRoute_ofTotal_disqualified_iff
    (case : TransferCase) (route : SimplifiedRoute)
    (valid : validatePartialCase case.toPartial = .ok ()) :
    (∃ reasons,
      assessRoute case.toPartial route =
        .ok (.doesNotQualify reasons)) ↔
      ¬ RouteEligible case route := by
  rw [← assessRoute_ofTotal_qualifies_iff]
  obtain ⟨checks, checksResult⟩ :=
    eligibilityChecks_ok_of_validate case.toPartial route valid
  cases result : assessRoute case.toPartial route with
  | error error =>
      simp [assessRoute, valid, checksResult] at result
  | ok status =>
      cases status with
      | qualifies => simp
      | doesNotQualify reasons => simp
      | needsInformation facts =>
          exact
            (assessRoute_ofTotal_needsInformation_false case route facts
              result).elim

private theorem assessRouteReport_ok_sound
    {case : PartialTransferCase} {route : SimplifiedRoute}
    {report : RouteReport}
    (result : assessRouteReport case route = .ok report) :
    report.route = route ∧
      assessRoute case route = .ok report.status := by
  unfold assessRouteReport at result
  cases routeResult : assessRoute case route with
  | error error =>
      rw [routeResult] at result
      change (Except.error error : Except CaseError RouteReport) =
        .ok report at result
      contradiction
  | ok status =>
      rw [routeResult] at result
      change
        Except.ok ({ route := route, status := status } : RouteReport) =
          .ok report at result
      injection result with reportEq
      subst report
      exact ⟨rfl, rfl⟩

private theorem mapM_routeReports_exact
    {case : PartialTransferCase}
    {routes : List SimplifiedRoute} {reports : List RouteReport}
    (result :
      routes.mapM (assessRouteReport case) =
        .ok reports) :
    ∀ route,
      route ∈ routes ↔
      ∃ report ∈ reports,
        report.route = route ∧
        assessRoute case route = .ok report.status := by
  induction routes generalizing reports with
  | nil =>
      simp only [List.mapM_nil, pure, Except.pure] at result
      injection result with reportsEq
      subst reports
      simp
  | cons head tail ih =>
      cases headResult : assessRouteReport case head with
      | error error =>
          rw [List.mapM_cons, headResult] at result
          change (Except.error error : Except CaseError (List RouteReport)) =
            .ok reports at result
          contradiction
      | ok status =>
          cases tailResult :
              tail.mapM (assessRouteReport case) with
          | error error =>
              rw [List.mapM_cons, headResult, tailResult] at result
              change
                (Except.error error : Except CaseError (List RouteReport)) =
                  .ok reports at result
              contradiction
          | ok tailReports =>
              simp [List.mapM_cons, headResult, tailResult] at result
              injection result with reportsEq
              subst reports
              have headExact :
                  status.route = head ∧
                  assessRoute case head = .ok status.status := by
                exact assessRouteReport_ok_sound headResult
              intro route
              constructor
              · intro member
                rcases List.mem_cons.mp member with routeEq | tailMember
                · exact ⟨status, by simp,
                    headExact.1.trans (Eq.symm routeEq),
                    by simpa [routeEq] using headExact.2⟩
                · obtain ⟨report, reportMember, reportRoute, reportResult⟩ :=
                    (ih tailResult route).mp tailMember
                  exact ⟨report, by simp [reportMember],
                    reportRoute, reportResult⟩
              · rintro ⟨report, reportMember, reportRoute, reportResult⟩
                simp only [List.mem_cons] at reportMember
                rcases reportMember with reportEq | tailMember
                · subst report
                  exact List.mem_cons.mpr <| Or.inl <|
                    reportRoute.symm.trans headExact.1
                · right
                  exact (ih tailResult route).mpr
                    ⟨report, tailMember, reportRoute, reportResult⟩

private theorem mapM_routeReports_routes
    {case : PartialTransferCase}
    {routes : List SimplifiedRoute} {reports : List RouteReport}
    (result :
      routes.mapM (assessRouteReport case) = .ok reports) :
    reports.map (·.route) = routes := by
  induction routes generalizing reports with
  | nil =>
      simp only [List.mapM_nil, pure, Except.pure] at result
      injection result with reportsEq
      subst reports
      rfl
  | cons head tail ih =>
      cases headResult : assessRouteReport case head with
      | error error =>
          rw [List.mapM_cons, headResult] at result
          change (Except.error error : Except CaseError (List RouteReport)) =
            .ok reports at result
          contradiction
      | ok headReport =>
          cases tailResult :
              tail.mapM (assessRouteReport case) with
          | error error =>
              rw [List.mapM_cons, headResult, tailResult] at result
              change
                (Except.error error : Except CaseError (List RouteReport)) =
                  .ok reports at result
              contradiction
          | ok tailReports =>
              simp [List.mapM_cons, headResult, tailResult] at result
              injection result with reportsEq
              subst reports
              have headRoute :=
                (assessRouteReport_ok_sound headResult).1
              simp [headRoute, ih tailResult]

private theorem mapM_routeReports_members
    {case : PartialTransferCase}
    {routes : List SimplifiedRoute} {reports : List RouteReport}
    (result :
      routes.mapM (assessRouteReport case) = .ok reports) :
    ∀ report ∈ reports,
      report.route ∈ routes ∧
      assessRoute case report.route = .ok report.status := by
  induction routes generalizing reports with
  | nil =>
      simp only [List.mapM_nil, pure, Except.pure] at result
      injection result with reportsEq
      subst reports
      simp
  | cons head tail ih =>
      cases headResult : assessRouteReport case head with
      | error error =>
          rw [List.mapM_cons, headResult] at result
          change (Except.error error : Except CaseError (List RouteReport)) =
            .ok reports at result
          contradiction
      | ok headReport =>
          cases tailResult :
              tail.mapM (assessRouteReport case) with
          | error error =>
              rw [List.mapM_cons, headResult, tailResult] at result
              change
                (Except.error error : Except CaseError (List RouteReport)) =
                  .ok reports at result
              contradiction
          | ok tailReports =>
              simp [List.mapM_cons, headResult, tailResult] at result
              injection result with reportsEq
              subst reports
              intro report member
              rcases List.mem_cons.mp member with reportEq | tailMember
              · subst report
                have exact := assessRouteReport_ok_sound headResult
                exact ⟨List.mem_cons.mpr (Or.inl exact.1),
                  by simpa [exact.1] using exact.2⟩
              · obtain ⟨routeMember, routeResult⟩ :=
                  ih tailResult report tailMember
                exact ⟨List.mem_cons.mpr (Or.inr routeMember), routeResult⟩

private theorem mem_qualifyingRoutes_iff
    {reports : List RouteReport} {route : Route} :
    route ∈ qualifyingRoutes reports ↔
      ∃ report ∈ reports,
        report.route.toRoute = route ∧
        report.status = .qualifies := by
  unfold qualifyingRoutes
  rw [List.mem_filterMap]
  constructor
  · rintro ⟨report, reportMember, mapped⟩
    cases status : report.status with
    | qualifies =>
        simp [status] at mapped
        exact ⟨report, reportMember, mapped, status⟩
    | doesNotQualify reasons =>
        simp [status] at mapped
    | needsInformation facts =>
        simp [status] at mapped
  · rintro ⟨report, reportMember, reportRoute, status⟩
    exact ⟨report, reportMember, by simp [status, reportRoute]⟩

private theorem qualifyingRoutes_exact_of_mapM
    {case : TransferCase} {reports : List RouteReport}
    (result :
      simplifiedRoutes.mapM (assessRouteReport case.toPartial) =
        .ok reports) :
    ∀ route,
      route ∈ qualifyingRoutes reports ↔
      ∃ simplified ∈ simplifiedRoutes,
        simplified.toRoute = route ∧
        RouteEligible case simplified := by
  intro route
  rw [mem_qualifyingRoutes_iff]
  constructor
  · rintro ⟨report, reportMember, reportRoute, status⟩
    obtain ⟨routeMember, routeResult⟩ :=
      mapM_routeReports_members result report reportMember
    rw [status] at routeResult
    exact ⟨report.route, routeMember, reportRoute,
      (assessRoute_ofTotal_qualifies_iff case report.route).mp routeResult⟩
  · rintro ⟨simplified, routeMember, routeEq, eligible⟩
    obtain ⟨report, reportMember, reportRoute, routeResult⟩ :=
      (mapM_routeReports_exact result simplified).mp routeMember
    have qualifies :=
      (assessRoute_ofTotal_qualifies_iff case simplified).mpr eligible
    rw [qualifies] at routeResult
    injection routeResult with statusEq
    exact ⟨report, reportMember,
      by simpa [reportRoute] using routeEq,
      statusEq.symm⟩

private theorem mem_qualifyingRoutes_toRoute_iff
    {case : TransferCase} {reports : List RouteReport}
    (result :
      simplifiedRoutes.mapM (assessRouteReport case.toPartial) =
        .ok reports)
    (simplified : SimplifiedRoute) :
    simplified.toRoute ∈ qualifyingRoutes reports ↔
      RouteEligible case simplified := by
  rw [qualifyingRoutes_exact_of_mapM result]
  constructor
  · rintro ⟨other, _, routeEq, eligible⟩
    have simplifiedEq : other = simplified := by
      cases other <;> cases simplified <;>
        simp [SimplifiedRoute.toRoute] at routeEq ⊢ <;>
        assumption
    simpa [simplifiedEq] using eligible
  · intro eligible
    exact ⟨simplified,
      by
        cases simplified with
        | directTransfer basis =>
            cases basis <;> simp [simplifiedRoutes, directTransferBases]
        | personalPropertyAffidavit =>
            simp [simplifiedRoutes]
        | smallValueRealPropertyAffidavit =>
            simp [simplifiedRoutes]
        | primaryResidencePetition =>
            simp [simplifiedRoutes]
        | spousalPropertyPetition =>
            simp [simplifiedRoutes],
      rfl, eligible⟩

private theorem qualifyingRoutes_nil_iff
    {case : TransferCase} {reports : List RouteReport}
    (result :
      simplifiedRoutes.mapM (assessRouteReport case.toPartial) =
        .ok reports) :
    qualifyingRoutes reports = [] ↔
      ∀ simplified ∈ simplifiedRoutes,
        ¬ RouteEligible case simplified := by
  constructor
  · intro empty simplified routeMember eligible
    have member :=
      (qualifyingRoutes_exact_of_mapM result
        simplified.toRoute).mpr
        ⟨simplified, routeMember, rfl, eligible⟩
    rw [empty] at member
    contradiction
  · intro allIneligible
    cases routesResult : qualifyingRoutes reports with
    | nil => rfl
    | cons route rest =>
        have member : route ∈ qualifyingRoutes reports := by
          rw [routesResult]
          exact List.Mem.head _
        obtain ⟨simplified, routeMember, _, eligible⟩ :=
          (qualifyingRoutes_exact_of_mapM result route).mp member
        exact (allIneligible simplified routeMember eligible).elim

private theorem mem_simplifiedRoutes (route : SimplifiedRoute) :
    route ∈ simplifiedRoutes := by
  cases route with
  | directTransfer basis =>
      cases basis <;> simp [simplifiedRoutes, directTransferBases]
  | personalPropertyAffidavit =>
      simp [simplifiedRoutes]
  | smallValueRealPropertyAffidavit =>
      simp [simplifiedRoutes]
  | primaryResidencePetition =>
      simp [simplifiedRoutes]
  | spousalPropertyPetition =>
      simp [simplifiedRoutes]

private theorem overallOutcome_fallback_iff
    (reports : List RouteReport) :
    overallOutcome reports = .formalProbateOrOtherProcedure ↔
      ∀ report ∈ reports,
        ∃ reasons, report.status = .doesNotQualify reasons := by
  constructor
  · intro fallback
    have qualifiesFalse :
        reports.any (fun report =>
          match report.status with
          | .qualifies => true
          | _ => false) = false := by
      cases qualifiesResult :
          reports.any (fun report =>
            match report.status with
            | .qualifies => true
            | _ => false) with
      | false => rfl
      | true => simp [overallOutcome, qualifiesResult] at fallback
    have needsFalse :
        reports.any (fun report =>
          match report.status with
          | .needsInformation _ => true
          | _ => false) = false := by
      cases needsResult :
          reports.any (fun report =>
            match report.status with
            | .needsInformation _ => true
            | _ => false) with
      | false => rfl
      | true =>
          simp [overallOutcome, qualifiesFalse, needsResult] at fallback
    intro report member
    have notQualifies :=
      (List.any_eq_false.mp qualifiesFalse) report member
    have notNeeds :=
      (List.any_eq_false.mp needsFalse) report member
    cases statusResult : report.status with
    | qualifies => simp [statusResult] at notQualifies
    | doesNotQualify reasons => exact ⟨reasons, rfl⟩
    | needsInformation facts => simp [statusResult] at notNeeds
  · intro allDisqualified
    have qualifiesFalse :
        reports.any (fun report =>
          match report.status with
          | .qualifies => true
          | _ => false) = false :=
      List.any_eq_false.mpr fun report member => by
        obtain ⟨reasons, status⟩ := allDisqualified report member
        simp [status]
    have needsFalse :
        reports.any (fun report =>
          match report.status with
          | .needsInformation _ => true
          | _ => false) = false :=
      List.any_eq_false.mpr fun report member => by
        obtain ⟨reasons, status⟩ := allDisqualified report member
        simp [status]
    simp [overallOutcome, qualifiesFalse, needsFalse]

private theorem assessRouteReport_ok_of_validate
    {case : PartialTransferCase}
    (valid : validatePartialCase case = .ok ())
    (route : SimplifiedRoute) :
    ∃ report, assessRouteReport case route = .ok report := by
  obtain ⟨checks, checksResult⟩ :=
    eligibilityChecks_ok_of_validate case route valid
  refine ⟨{
    route := route
    status := aggregateChecks checks
  }, ?_⟩
  simp [assessRouteReport, assessRoute, valid, checksResult]
  rfl

private theorem mapM_routeReports_ok_of_validate
    {case : PartialTransferCase}
    (valid : validatePartialCase case = .ok ())
    (routes : List SimplifiedRoute) :
    ∃ reports,
      routes.mapM (assessRouteReport case) = .ok reports := by
  induction routes with
  | nil => exact ⟨[], rfl⟩
  | cons head tail ih =>
      obtain ⟨headReport, headResult⟩ :=
        assessRouteReport_ok_of_validate valid head
      obtain ⟨tailReports, tailResult⟩ := ih
      exact ⟨headReport :: tailReports, by
        rw [List.mapM_cons, headResult, tailResult]
        rfl⟩

private theorem assessRoutes_ok_of_validate
    {case : PartialTransferCase}
    (valid : validatePartialCase case = .ok ()) :
    ∃ assessment, assessRoutes case = .ok assessment := by
  obtain ⟨reports, reportsResult⟩ :=
    mapM_routeReports_ok_of_validate valid simplifiedRoutes
  exact ⟨{
    routes := reports
    overall := overallOutcome reports
  }, by
    simp [assessRoutes, valid, reportsResult]
    rfl⟩

theorem assessRoutes_routes_exact
    {case : PartialTransferCase} {assessment : CaseAssessment}
    (result : assessRoutes case = .ok assessment) :
    assessment.routes.map (·.route) = simplifiedRoutes := by
  cases valid : validatePartialCase case with
  | error error =>
      unfold assessRoutes at result
      rw [valid] at result
      change (Except.error error : Except CaseError CaseAssessment) =
        .ok assessment at result
      contradiction
  | ok unitValue =>
      cases unitValue
      obtain ⟨reports, reportsResult⟩ :=
        mapM_routeReports_ok_of_validate valid simplifiedRoutes
      unfold assessRoutes at result
      rw [valid, reportsResult] at result
      change
        Except.ok {
          routes := reports
          overall := overallOutcome reports
        } = .ok assessment at result
      injection result with assessmentEq
      subst assessment
      exact mapM_routeReports_routes reportsResult

theorem assessRoutes_routes_nodup
    {case : PartialTransferCase} {assessment : CaseAssessment}
    (result : assessRoutes case = .ok assessment) :
    (assessment.routes.map (·.route)).Nodup := by
  rw [assessRoutes_routes_exact result]
  exact simplifiedRoutes_nodup

theorem assessRoutes_fallback_all_completions_ineligible
    {partialCase : PartialTransferCase} {assessment : CaseAssessment}
    (result : assessRoutes partialCase = .ok assessment)
    (fallback :
      assessment.overall = .formalProbateOrOtherProcedure) :
    ∀ total, partialCase.Completes total →
      TransferCase.WellFormed total →
      ∀ route ∈ simplifiedRoutes, ¬ RouteEligible total route := by
  cases valid : validatePartialCase partialCase with
  | error error =>
      unfold assessRoutes at result
      rw [valid] at result
      change (Except.error error : Except CaseError CaseAssessment) =
        .ok assessment at result
      contradiction
  | ok unitValue =>
      cases unitValue
      obtain ⟨reports, reportsResult⟩ :=
        mapM_routeReports_ok_of_validate valid simplifiedRoutes
      have assessmentEq :
          assessment = {
            routes := reports
            overall := overallOutcome reports
          } := by
        unfold assessRoutes at result
        rw [valid, reportsResult] at result
        change
          Except.ok {
            routes := reports
            overall := overallOutcome reports
          } = .ok assessment at result
        injection result with resultEq
        exact resultEq.symm
      subst assessment
      have allDisqualified :=
        (overallOutcome_fallback_iff reports).mp fallback
      intro total completion wellFormed route routeMember
      have routeOrder :=
        mapM_routeReports_routes reportsResult
      have reportRouteMember :
          route ∈ reports.map (·.route) := by
        rw [routeOrder]
        exact routeMember
      obtain ⟨report, reportMember, reportRoute⟩ :=
        List.mem_map.mp reportRouteMember
      subst route
      have routeResult :=
        (mapM_routeReports_members reportsResult
          report reportMember).2
      obtain ⟨reasons, status⟩ :=
        allDisqualified report reportMember
      rw [status] at routeResult
      exact assessRoute_disqualified_no_completion routeResult
        total completion wellFormed

theorem assessRoutes_ofTotal_fallback_iff
    (case : TransferCase)
    (valid : validatePartialCase case.toPartial = .ok ()) :
    (∃ assessment,
      assessRoutes case.toPartial = .ok assessment ∧
      assessment.overall = .formalProbateOrOtherProcedure) ↔
    ∀ route ∈ simplifiedRoutes, ¬ RouteEligible case route := by
  constructor
  · rintro ⟨assessment, result, fallback⟩
    have wellFormed :=
      ((validatePartialCase_toPartial_ok_iff_supported case).mp valid).2
    exact assessRoutes_fallback_all_completions_ineligible
      result fallback case (toPartial_completes case) wellFormed
  · intro allIneligible
    obtain ⟨reports, reportsResult⟩ :=
      mapM_routeReports_ok_of_validate valid simplifiedRoutes
    refine ⟨{
      routes := reports
      overall := overallOutcome reports
    }, ?_, ?_⟩
    · unfold assessRoutes
      rw [valid, reportsResult]
      rfl
    · apply (overallOutcome_fallback_iff reports).mpr
      intro report reportMember
      obtain ⟨routeMember, routeResult⟩ :=
        mapM_routeReports_members reportsResult report reportMember
      obtain ⟨reasons, disqualified⟩ :=
        (assessRoute_ofTotal_disqualified_iff
          case report.route valid).mpr
          (allIneligible report.route routeMember)
      rw [routeResult] at disqualified
      injection disqualified with statusEq
      exact ⟨reasons, statusEq⟩

theorem candidateRoutes_exact
    {case : TransferCase} {routes : List Route}
    (result : candidateRoutes case = .ok routes) :
    ∀ route,
      route ∈ routes ↔
      match route.toSimplified? with
      | some simplified => RouteEligible case simplified
      | none =>
          ∀ simplified ∈ simplifiedRoutes,
            ¬ RouteEligible case simplified := by
  cases valid : validatePartialCase case.toPartial with
  | error error =>
      unfold candidateRoutes assessRoutes at result
      rw [valid] at result
      change (Except.error error : Except CaseError (List Route)) =
        .ok routes at result
      contradiction
  | ok unitValue =>
      cases unitValue
      obtain ⟨reports, reportsResult⟩ :=
        mapM_routeReports_ok_of_validate valid simplifiedRoutes
      unfold candidateRoutes assessRoutes at result
      rw [valid, reportsResult] at result
      change
        (if qualifyingRoutes reports = [] then
          Except.ok [.formalProbateOrOtherProcedure]
        else
          Except.ok (qualifyingRoutes reports)) =
        .ok routes at result
      by_cases empty : qualifyingRoutes reports = []
      · simp [empty] at result
        subst routes
        have allIneligible :=
          (qualifyingRoutes_nil_iff reportsResult).mp empty
        intro route
        cases route with
        | directTransfer basis =>
            have ineligible :=
              allIneligible (.directTransfer basis)
                (mem_simplifiedRoutes (.directTransfer basis))
            simp [Route.toSimplified?, ineligible]
        | personalPropertyAffidavit =>
            have ineligible :=
              allIneligible .personalPropertyAffidavit
                (mem_simplifiedRoutes .personalPropertyAffidavit)
            simp [Route.toSimplified?, ineligible]
        | smallValueRealPropertyAffidavit =>
            have ineligible :=
              allIneligible .smallValueRealPropertyAffidavit
                (mem_simplifiedRoutes .smallValueRealPropertyAffidavit)
            simp [Route.toSimplified?, ineligible]
        | primaryResidencePetition =>
            have ineligible :=
              allIneligible .primaryResidencePetition
                (mem_simplifiedRoutes .primaryResidencePetition)
            simp [Route.toSimplified?, ineligible]
        | spousalPropertyPetition =>
            have ineligible :=
              allIneligible .spousalPropertyPetition
                (mem_simplifiedRoutes .spousalPropertyPetition)
            simp [Route.toSimplified?, ineligible]
        | formalProbateOrOtherProcedure =>
            simpa [Route.toSimplified?] using allIneligible
      · simp [empty] at result
        subst routes
        have notAllIneligible :
            ¬ ∀ simplified ∈ simplifiedRoutes,
              ¬ RouteEligible case simplified := by
          intro allIneligible
          exact empty
            ((qualifyingRoutes_nil_iff reportsResult).mpr allIneligible)
        have fallbackNotMember :
            .formalProbateOrOtherProcedure ∉
              qualifyingRoutes reports := by
          intro member
          obtain ⟨simplified, _, routeEq, _⟩ :=
            (qualifyingRoutes_exact_of_mapM reportsResult
              .formalProbateOrOtherProcedure).mp member
          cases simplified <;>
            simp [SimplifiedRoute.toRoute] at routeEq
        intro route
        cases route with
        | directTransfer basis =>
            simpa [Route.toSimplified?, SimplifiedRoute.toRoute] using
              mem_qualifyingRoutes_toRoute_iff reportsResult
                (.directTransfer basis)
        | personalPropertyAffidavit =>
            simpa [Route.toSimplified?, SimplifiedRoute.toRoute] using
              mem_qualifyingRoutes_toRoute_iff reportsResult
                .personalPropertyAffidavit
        | smallValueRealPropertyAffidavit =>
            simpa [Route.toSimplified?, SimplifiedRoute.toRoute] using
              mem_qualifyingRoutes_toRoute_iff reportsResult
                .smallValueRealPropertyAffidavit
        | primaryResidencePetition =>
            simpa [Route.toSimplified?, SimplifiedRoute.toRoute] using
              mem_qualifyingRoutes_toRoute_iff reportsResult
                .primaryResidencePetition
        | spousalPropertyPetition =>
            simpa [Route.toSimplified?, SimplifiedRoute.toRoute] using
              mem_qualifyingRoutes_toRoute_iff reportsResult
                .spousalPropertyPetition
        | formalProbateOrOtherProcedure =>
            simp [Route.toSimplified?, fallbackNotMember,
              notAllIneligible]

end SimpleProbate
