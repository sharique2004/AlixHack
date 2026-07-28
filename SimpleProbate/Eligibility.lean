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

def DirectTransferEligible
    (case : TransferCase) (basis : DirectTransferBasis) : Prop :=
  match case.targetAsset? with
  | some target =>
      SupportedDeathDate case.deathDate ∧
      case.WellFormed ∧
      target.directTransferBasis = some basis
  | none => False

def PersonalPropertyAffidavitEligible (case : TransferCase) : Prop :=
  match case.targetAsset? with
  | some target =>
      SupportedDeathDate case.deathDate ∧
      case.WellFormed ∧
      target.kind = .personal ∧
      case.claimantIsSuccessor = true ∧
      case.noSuperiorRight = true ∧
      40 ≤ case.daysSinceDeath ∧
      case.authority.Permits ∧
      match case.estate.personalAffidavitValue case.deathDate,
          thresholdsFor case.deathDate with
      | .ok value, .ok thresholds =>
          value ≤ thresholds.personalPropertyAffidavit
      | _, _ => False
  | none => False

def SmallValueRealPropertyAffidavitEligible (case : TransferCase) : Prop :=
  match case.targetAsset? with
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
  match case.targetAsset? with
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
          case.estate.primaryResidenceValue ≤ thresholds.primaryResidencePetition
      | .error _ => False
  | none => False

def SpousalPropertyPetitionEligible (case : TransferCase) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.WellFormed ∧
  case.survivorStatus ≠ .none ∧
  (case.propertyPassesToSurvivor = true ∨
   case.propertyBelongsToSurvivor = true)

instance (case : TransferCase) (basis : DirectTransferBasis) :
    Decidable (DirectTransferEligible case basis) := by
  unfold DirectTransferEligible
  split <;> infer_instance

instance (case : TransferCase) :
    Decidable (PersonalPropertyAffidavitEligible case) := by
  unfold PersonalPropertyAffidavitEligible
  split
  · cases estateValue : case.estate.personalAffidavitValue case.deathDate with
    | error _ =>
        infer_instance
    | ok _ =>
        cases thresholdResult : thresholdsFor case.deathDate with
        | error _ =>
            infer_instance
        | ok _ =>
            infer_instance
  · infer_instance

instance (case : TransferCase) :
    Decidable (SmallValueRealPropertyAffidavitEligible case) := by
  unfold SmallValueRealPropertyAffidavitEligible
  split
  · cases thresholdResult : thresholdsFor case.deathDate with
    | error _ =>
        infer_instance
    | ok _ =>
        infer_instance
  · infer_instance

instance (case : TransferCase) :
    Decidable (PrimaryResidencePetitionEligible case) := by
  unfold PrimaryResidencePetitionEligible
  split
  · cases thresholdResult : thresholdsFor case.deathDate with
    | error _ =>
        infer_instance
    | ok _ =>
        infer_instance
  · infer_instance

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
  | .formalProbateOrOtherProcedure =>
      SupportedDeathDate case.deathDate ∧ nonFallbackRoutes case = []

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
    (supportedDate : SupportedDeathDate case.deathDate)
    (membership : route ∈ candidateRoutesUnchecked case) :
    RouteEligible case route := by
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
      have supportedDate : SupportedDeathDate case.deathDate := by
        simp [SupportedDeathDate, dateResult]
      injection result with routesEq
      subst routes
      exact candidateRoutesUnchecked_sound supportedDate membership

end SimpleProbate
