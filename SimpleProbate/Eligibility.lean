import SimpleProbate.Estate

namespace SimpleProbate

inductive SummaryAuthority
  | noProceeding
  | writtenPersonalRepresentativeConsent
  | blockedByProceeding
deriving BEq, DecidableEq, Repr

def SummaryAuthority.Permits : SummaryAuthority → Prop
  | .noProceeding => True
  | .writtenPersonalRepresentativeConsent => True
  | .blockedByProceeding => False

instance (authority : SummaryAuthority) : Decidable authority.Permits :=
  match authority with
  | .noProceeding => isTrue trivial
  | .writtenPersonalRepresentativeConsent => isTrue trivial
  | .blockedByProceeding => isFalse id

inductive SurvivorStatus
  | none
  | spouse
  | registeredDomesticPartner
deriving BEq, DecidableEq, Repr

structure TransferCase where
  deathDate : CivilDate
  estate : Estate
  target : Asset
  targetIsPartOfEstate : Bool
  authority : SummaryAuthority
  daysSinceDeath : Nat
  sixMonthsElapsed : Bool
  claimantIsSuccessor : Bool
  noSuperiorRight : Bool
  funeralLastIllnessAndUnsecuredDebtsPaid : Bool
  survivorStatus : SurvivorStatus
  propertyPassesToSurvivor : Bool
  propertyBelongsToSurvivor : Bool
deriving DecidableEq, Repr

def SupportedDeathDate (date : CivilDate) : Prop :=
  match classifyDeathDate date with
  | .ok _ => True
  | .error _ => False

instance (date : CivilDate) : Decidable (SupportedDeathDate date) := by
  unfold SupportedDeathDate
  cases classifyDeathDate date <;> infer_instance

def TransferCase.WellFormed (case : TransferCase) : Prop :=
  (case.targetIsPartOfEstate = true) ↔ case.target ∈ case.estate.assets

instance (case : TransferCase) : Decidable case.WellFormed := by
  unfold TransferCase.WellFormed
  infer_instance

inductive Route
  | directTransfer (basis : DirectTransferBasis)
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
  | formalProbateOrOtherProcedure
deriving BEq, DecidableEq, Repr

def DirectTransferEligible
    (case : TransferCase) (basis : DirectTransferBasis) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.WellFormed ∧
  case.target.directTransferBasis = some basis

def PersonalPropertyAffidavitEligible (case : TransferCase) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.WellFormed ∧
  case.target.kind = .personal ∧
  case.targetIsPartOfEstate = true ∧
  case.claimantIsSuccessor = true ∧
  case.noSuperiorRight = true ∧
  40 ≤ case.daysSinceDeath ∧
  case.authority.Permits ∧
  match case.estate.personalAffidavitValue case.deathDate,
      thresholdsFor case.deathDate with
  | .ok value, .ok thresholds =>
      value ≤ thresholds.personalPropertyAffidavit
  | _, _ => False

def SmallValueRealPropertyAffidavitEligible (case : TransferCase) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.WellFormed ∧
  case.target.kind = .californiaReal ∧
  case.target.treatment = .counted ∧
  case.targetIsPartOfEstate = true ∧
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

def PrimaryResidencePetitionEligible (case : TransferCase) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.WellFormed ∧
  case.target.kind = .californiaReal ∧
  case.target.treatment = .counted ∧
  case.target.isPrimaryResidence = true ∧
  case.targetIsPartOfEstate = true ∧
  case.claimantIsSuccessor = true ∧
  40 ≤ case.daysSinceDeath ∧
  case.authority.Permits ∧
  match thresholdsFor case.deathDate with
  | .ok thresholds =>
      case.estate.primaryResidenceValue ≤ thresholds.primaryResidencePetition
  | .error _ => False

def SpousalPropertyPetitionEligible (case : TransferCase) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.WellFormed ∧
  case.survivorStatus ≠ .none ∧
  (case.propertyPassesToSurvivor = true ∨
   case.propertyBelongsToSurvivor = true)

instance (case : TransferCase) (basis : DirectTransferBasis) :
    Decidable (DirectTransferEligible case basis) := by
  unfold DirectTransferEligible
  infer_instance

instance (case : TransferCase) :
    Decidable (PersonalPropertyAffidavitEligible case) := by
  unfold PersonalPropertyAffidavitEligible
  cases estateValue : case.estate.personalAffidavitValue case.deathDate with
  | error _ =>
      infer_instance
  | ok _ =>
      cases thresholdResult : thresholdsFor case.deathDate with
      | error _ =>
          infer_instance
      | ok _ =>
          infer_instance

instance (case : TransferCase) :
    Decidable (SmallValueRealPropertyAffidavitEligible case) := by
  unfold SmallValueRealPropertyAffidavitEligible
  cases thresholdResult : thresholdsFor case.deathDate with
  | error _ =>
      infer_instance
  | ok _ =>
      infer_instance

instance (case : TransferCase) :
    Decidable (PrimaryResidencePetitionEligible case) := by
  unfold PrimaryResidencePetitionEligible
  cases thresholdResult : thresholdsFor case.deathDate with
  | error _ =>
      infer_instance
  | ok _ =>
      infer_instance

instance (case : TransferCase) :
    Decidable (SpousalPropertyPetitionEligible case) := by
  unfold SpousalPropertyPetitionEligible
  infer_instance

def directTransferBases : List DirectTransferBasis := [
  .governmentBenefit,
  .namedBeneficiary,
  .revocableTrust,
  .jointTenancy,
  .transferOnDeath,
  .multiplePartyAccount,
  .spousePassage
]

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

def RouteEligible (case : TransferCase) : Route → Prop
  | .directTransfer basis => DirectTransferEligible case basis
  | .personalPropertyAffidavit => PersonalPropertyAffidavitEligible case
  | .smallValueRealPropertyAffidavit =>
      SmallValueRealPropertyAffidavitEligible case
  | .primaryResidencePetition => PrimaryResidencePetitionEligible case
  | .spousalPropertyPetition => SpousalPropertyPetitionEligible case
  | .formalProbateOrOtherProcedure => nonFallbackRoutes case = []

instance (case : TransferCase) (route : Route) :
    Decidable (RouteEligible case route) := by
  cases route <;>
    simp only [RouteEligible] <;>
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
  decide (RouteEligible case route)

def routeEligible
    (case : TransferCase) (route : Route) : Except DateError Bool :=
  match classifyDeathDate case.deathDate with
  | .ok _ => .ok (routeEligibleUnchecked case route)
  | .error error => .error error

private theorem candidateRoutesUnchecked_sound
    {case : TransferCase} {route : Route}
    (membership : route ∈ candidateRoutesUnchecked case) :
    RouteEligible case route := by
  unfold candidateRoutesUnchecked at membership
  split at membership
  next noRoutes =>
    have routeIsFallback : route = .formalProbateOrOtherProcedure := by
      simpa using membership
    subst route
    simpa [RouteEligible] using noRoutes
  next someRoute =>
    have eligibleCheck :
        routeEligibleNonFallback case route = true :=
      (List.mem_filter.mp membership).2
    cases route <;>
      simp_all only [routeEligibleNonFallback, RouteEligible,
        decide_eq_true_eq, Bool.false_eq_true]

theorem candidateRoutes_sound
    {case : TransferCase} {routes : List Route} {route : Route}
    (result : candidateRoutes case = .ok routes)
    (membership : route ∈ routes) :
    RouteEligible case route := by
  unfold candidateRoutes at result
  cases dateResult : classifyDeathDate case.deathDate with
  | error _ =>
      rw [dateResult] at result
      contradiction
  | ok _ =>
      rw [dateResult] at result
      injection result with routesEq
      subst routes
      exact candidateRoutesUnchecked_sound membership

end SimpleProbate
