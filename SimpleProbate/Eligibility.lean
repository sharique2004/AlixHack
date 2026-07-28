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

def TransferCase.target? (case : TransferCase) : Option Asset :=
  case.estate.findAsset? case.targetId

private def TransferCase.Valid (case : TransferCase) : Prop :=
  validatePartialCase case.toPartial = .ok ()

private instance (case : TransferCase) : Decidable case.Valid := by
  unfold TransferCase.Valid
  infer_instance

def DirectTransferEligible
    (case : TransferCase) (basis : DirectTransferBasis) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.Valid ∧
  ∃ target, case.target? = some target ∧
    target.directTransferBasis = some basis

def PersonalPropertyAffidavitEligible (case : TransferCase) : Prop :=
  match case.target? with
  | some target =>
      SupportedDeathDate case.deathDate ∧
      case.Valid ∧
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
      case.Valid ∧
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
      case.Valid ∧
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
  case.Valid ∧
  case.target? ≠ none ∧
  case.survivorStatus ≠ .none ∧
  (case.propertyPassesToSurvivor = true ∨
   case.propertyBelongsToSurvivor = true)

instance (case : TransferCase) (basis : DirectTransferBasis) :
    Decidable (DirectTransferEligible case basis) := by
  unfold DirectTransferEligible TransferCase.Valid TransferCase.target?
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

def LegacyRouteEligible (case : TransferCase) : Route → Prop
  | .directTransfer basis => DirectTransferEligible case basis
  | .personalPropertyAffidavit => PersonalPropertyAffidavitEligible case
  | .smallValueRealPropertyAffidavit =>
      SmallValueRealPropertyAffidavitEligible case
  | .primaryResidencePetition =>
      PrimaryResidencePetitionEligible case
  | .spousalPropertyPetition => SpousalPropertyPetitionEligible case
  | .formalProbateOrOtherProcedure =>
      SupportedDeathDate case.deathDate ∧ nonFallbackRoutes case = []

instance (case : TransferCase) (route : Route) :
    Decidable (LegacyRouteEligible case route) := by
  cases route <;>
    simp only [LegacyRouteEligible] <;>
    infer_instance

private def candidateRoutesUnchecked (case : TransferCase) : List Route :=
  if nonFallbackRoutes case = [] then
    [.formalProbateOrOtherProcedure]
  else
    nonFallbackRoutes case

def candidateRoutes (case : TransferCase) : Except DateError (List Route) :=
  match classifyDeathDate case.deathDate with
  | .ok _ => .ok (candidateRoutesUnchecked case)
  | .error error => .error error

private def routeEligibleUnchecked (case : TransferCase) (route : Route) : Bool :=
  decide (LegacyRouteEligible case route)

def routeEligible
    (case : TransferCase) (route : Route) : Except DateError Bool :=
  match classifyDeathDate case.deathDate with
  | .ok _ => .ok (routeEligibleUnchecked case route)
  | .error error => .error error

private theorem candidateRoutesUnchecked_sound
    {case : TransferCase} {route : Route}
    (supportedDate : SupportedDeathDate case.deathDate)
    (membership : route ∈ candidateRoutesUnchecked case) :
    LegacyRouteEligible case route := by
  unfold candidateRoutesUnchecked at membership
  split at membership
  next noRoutes =>
    have routeIsFallback : route = .formalProbateOrOtherProcedure := by
      simpa using membership
    subst route
    exact ⟨supportedDate, noRoutes⟩
  next someRoute =>
    have eligibleCheck :
        routeEligibleNonFallback case route = true :=
      (List.mem_filter.mp membership).2
    cases route <;>
      simp_all only [routeEligibleNonFallback, LegacyRouteEligible,
        decide_eq_true_eq, Bool.false_eq_true]

theorem candidateRoutes_sound
    {case : TransferCase} {routes : List Route} {route : Route}
    (result : candidateRoutes case = .ok routes)
    (membership : route ∈ routes) :
    LegacyRouteEligible case route := by
  unfold candidateRoutes at result
  cases dateResult : classifyDeathDate case.deathDate with
  | error _ =>
      rw [dateResult] at result
      contradiction
  | ok _ =>
      rw [dateResult] at result
      have supportedDate : SupportedDeathDate case.deathDate := by
        simp [SupportedDeathDate, dateResult]
      injection result with routesEq
      subst routes
      exact candidateRoutesUnchecked_sound supportedDate membership

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
  | .error .invalidDate =>
      .ok [.unknown .deathDate, .unknown .targetAsset]
  | .error .afterSnapshot =>
      .ok [.unknown .deathDate, .unknown .targetAsset]
  | .error (.malformedCase _) =>
      .ok [.unknown .deathDate, .unknown .targetAsset]
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

private theorem eligibilityChecks_always_ok
    (case : PartialTransferCase) (route : SimplifiedRoute) :
    ∃ checks, eligibilityChecks case route = .ok checks := by
  unfold eligibilityChecks
  cases validation : validatePartialCase case with
  | error error => cases error <;> simp
  | ok unitValue =>
      cases unitValue
      simp

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

theorem eligibilityChecks_ofTotal_all_satisfied_iff
    (case : TransferCase) (route : SimplifiedRoute) :
    (∀ checks,
      eligibilityChecks case.toPartial route = .ok checks →
      (∀ check ∈ checks, check = .satisfied)) ↔
    RouteEligible case route := by
  cases validation : validatePartialCase case.toPartial with
  | error error =>
      have notValid : ¬case.Valid := by
        simp [TransferCase.Valid, validation]
      simp only [eligibilityChecks, validation]
      cases targetResult : case.target? <;>
        cases error <;> cases route <;>
        simp [RouteEligible, DirectTransferEligible,
          PersonalPropertyAffidavitEligible,
          SmallValueRealPropertyAffidavitEligible,
          PrimaryResidencePetitionEligible,
          SpousalPropertyPetitionEligible,
          notValid, targetResult]
  | ok unitValue =>
      cases unitValue
      have caseValid : case.Valid := by
        exact validation
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
          caseValid, TransferCase.target?,
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
  obtain ⟨checks, checksResult⟩ :=
    eligibilityChecks_always_ok case.toPartial route
  cases validation : validatePartialCase case.toPartial with
  | error error =>
      constructor
      · intro impossible
        simp [assessRoute, validation] at impossible
      · intro allSatisfied
        have bad := allSatisfied
          ([
            .unknown .deathDate,
            .unknown .targetAsset
          ] : List (CheckResult EligibilityFact EligibilityFailure))
          (by cases error <;>
            simp [eligibilityChecks, validation])
          (.unknown .deathDate)
          (by simp)
        contradiction
  | ok unitValue =>
      cases unitValue
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
    eligibilityChecks_always_ok case.toPartial route
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

end SimpleProbate
