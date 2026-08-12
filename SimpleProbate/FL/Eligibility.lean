import SimpleProbate.FL.Estate

/-!
# Florida route eligibility over fully known facts

Prop-valued predicates, one conjunct per statutory element, with hand-written
`Decidable` instances. The partial layer in `SimpleProbate.FL.Partial` mirrors
these predicate-by-predicate; this file is what it is measured against.

Sources retrieved 2026-08-12:
* Fla. Stat. §735.201 — "Summary administration may be had in the
  administration of either a resident or nonresident decedent's estate, when it
  appears: (1) In a testate estate, the decedent's will does not direct
  administration as required by chapter 733. (2) The value of the entire estate
  subject to administration in this state, less the value of property exempt
  from the claims of creditors, does not exceed $75,000 or that the decedent has
  been dead for more than 2 years."
* Fla. Stat. §735.301(1) — "No administration shall be required or formal
  proceedings instituted upon the estate of a decedent leaving only personal
  property exempt under the provisions of s. 732.402, personal property exempt
  from the claims of creditors under the State Constitution, and nonexempt
  personal property the value of which does not exceed the sum of the amount of
  preferred funeral expenses and reasonable and necessary medical and hospital
  expenses of the last 60 days of the last illness."
* Fla. Stat. §735.304 — the intestate small-estate variant: decedent died
  intestate, has been dead more than 1 year, no administration is pending in
  this state, and nonexempt personalty does not exceed the sum of the §735.304
  figure and the same expense allowance.
* Fla. Stat. ch. 733 — formal administration.
* CS/HB 1337 (2026), eff. 2026-07-01 — the banded figures.
-/

namespace SimpleProbate.FL

/-- Everything a Florida route turns on, fully known. -/
structure Case where
  deathDate : CivilDate
  /-- The contract's required `as_of_date`; the §735.201(2) two-year branch and
  the §735.304 one-year condition are measured against it. -/
  asOfDate : CivilDate
  estate : Estate
  expenses : Expenses
  willStatus : WillStatus
  /-- Fla. Stat. §735.201(1): whether the will directs administration as
  required by chapter 733. -/
  willDirectsAdministration : Bool
  /-- Fla. Stat. §735.304: whether an administration of this estate is pending
  in Florida. -/
  administrationPending : Bool
deriving DecidableEq, Repr

/-- Within the Florida source snapshot and a real calendar date. -/
def SupportedDeathDate (date : CivilDate) : Prop :=
  match classifyDeathDate date with
  | .ok _ => True
  | .error _ => False

instance (date : CivilDate) : Decidable (SupportedDeathDate date) := by
  unfold SupportedDeathDate
  cases classifyDeathDate date <;> infer_instance

/-! ## Fla. Stat. §735.201 — summary administration -/

/-- §735.201(1). A will can only direct administration if there is a will, so an
intestate estate satisfies this element outright. -/
def WillPermitsSummaryAdministration (case : Case) : Prop :=
  case.willStatus = .noWill ∨ case.willDirectsAdministration = false

instance (case : Case) : Decidable (WillPermitsSummaryAdministration case) := by
  unfold WillPermitsSummaryAdministration
  infer_instance

/-- §735.201(2), first branch: the value of the entire estate subject to
administration in Florida, less property exempt from the claims of creditors,
does not exceed the date-of-death-banded ceiling. -/
def SummaryValueUnderCap (case : Case) : Prop :=
  match thresholdsFor case.deathDate with
  | .ok thresholds =>
      case.estate.summaryAdministrationValue ≤ thresholds.summaryAdministration
  | .error _ => False

instance (case : Case) : Decidable (SummaryValueUnderCap case) := by
  unfold SummaryValueUnderCap
  cases thresholdResult : thresholdsFor case.deathDate with
  | error _ => infer_instance
  | ok _ => infer_instance

/-- §735.201(2), second branch: "the decedent has been dead for more than 2
years". This branch qualifies regardless of value. -/
def DeadMoreThanTwoYears (case : Case) : Prop :=
  deadMoreThanYears case.deathDate case.asOfDate 2 = true

instance (case : Case) : Decidable (DeadMoreThanTwoYears case) := by
  unfold DeadMoreThanTwoYears
  infer_instance

def SummaryAdministrationEligible (case : Case) : Prop :=
  SupportedDeathDate case.deathDate ∧
  WillPermitsSummaryAdministration case ∧
  (SummaryValueUnderCap case ∨ DeadMoreThanTwoYears case)

instance (case : Case) : Decidable (SummaryAdministrationEligible case) := by
  unfold SummaryAdministrationEligible
  infer_instance

/-! ## Fla. Stat. §§735.301, 735.304 — disposition without administration -/

/-- §735.301(1) and §735.304 both reach only an estate "leaving only personal
property". -/
def NoRealPropertyToAdminister (case : Case) : Prop :=
  case.estate.containsRealProperty = false

instance (case : Case) : Decidable (NoRealPropertyToAdminister case) := by
  unfold NoRealPropertyToAdminister
  infer_instance

/-- §735.301(1): nonexempt personal property does not exceed the sum of the
preferred funeral expenses and the reasonable and necessary medical and hospital
expenses of the last 60 days of the last illness. -/
def Disposition301Eligible (case : Case) : Prop :=
  SupportedDeathDate case.deathDate ∧
  NoRealPropertyToAdminister case ∧
  case.estate.nonexemptPersonalPropertyValue ≤ case.expenses.allowance

instance (case : Case) : Decidable (Disposition301Eligible case) := by
  unfold Disposition301Eligible
  infer_instance

/-- §735.304: the intestate small-estate variant. The fixed figure is banded by
date of death ($10,000 before 2026-07-01, $20,000 on or after — CS/HB 1337). -/
def Disposition304Eligible (case : Case) : Prop :=
  SupportedDeathDate case.deathDate ∧
  case.willStatus = .noWill ∧
  deadMoreThanYears case.deathDate case.asOfDate 1 = true ∧
  case.administrationPending = false ∧
  NoRealPropertyToAdminister case ∧
  (match thresholdsFor case.deathDate with
   | .ok thresholds =>
       case.estate.nonexemptPersonalPropertyValue ≤
         thresholds.intestateSmallEstateDisposition + case.expenses.allowance
   | .error _ => False)

instance (case : Case) : Decidable (Disposition304Eligible case) := by
  unfold Disposition304Eligible
  cases thresholdResult : thresholdsFor case.deathDate with
  | error _ => infer_instance
  | ok _ => infer_instance

/-- The wire route `fl_disposition_without_administration` covers both
statutory bases. -/
def DispositionWithoutAdministrationEligible (case : Case) : Prop :=
  Disposition301Eligible case ∨ Disposition304Eligible case

instance (case : Case) :
    Decidable (DispositionWithoutAdministrationEligible case) := by
  unfold DispositionWithoutAdministrationEligible
  infer_instance

/-! ## Fla. Stat. ch. 733 — formal administration (the fallback) -/

/-- Never a positive recommendation: formal administration is what is left when
no simplified route is available. Exactly analogous to California's
`formalProbateOrOtherProcedure`. -/
def FormalAdministrationEligible (case : Case) : Prop :=
  SupportedDeathDate case.deathDate ∧
  ¬ DispositionWithoutAdministrationEligible case ∧
  ¬ SummaryAdministrationEligible case

instance (case : Case) : Decidable (FormalAdministrationEligible case) := by
  unfold FormalAdministrationEligible
  infer_instance

/-! ## Route finding -/

inductive Route
  | dispositionWithoutAdministration
  | summaryAdministration
  | formalAdministration
deriving BEq, DecidableEq, Repr

def RouteEligible (case : Case) : Route → Prop
  | .dispositionWithoutAdministration =>
      DispositionWithoutAdministrationEligible case
  | .summaryAdministration => SummaryAdministrationEligible case
  | .formalAdministration => FormalAdministrationEligible case

instance (case : Case) (route : Route) : Decidable (RouteEligible case route) := by
  cases route <;> simp only [RouteEligible] <;> infer_instance

/-- Stable evaluation order: the simplified routes first, then the fallback. -/
def allRoutes : List Route :=
  [.dispositionWithoutAdministration, .summaryAdministration,
   .formalAdministration]

private def candidateRoutesUnchecked (case : Case) : List Route :=
  allRoutes.filter (fun route => decide (RouteEligible case route))

/-- Every route the case qualifies for, or a typed date error. The fallback row
appears exactly when no simplified route qualifies, which is what
`FormalAdministrationEligible` says. -/
def candidateRoutes (case : Case) : Except DateError (List Route) :=
  match classifyDeathDate case.deathDate with
  | .ok _ => .ok (candidateRoutesUnchecked case)
  | .error error => .error error

theorem candidateRoutes_sound
    {case : Case} {routes : List Route} {route : Route}
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
      have eligibleCheck : decide (RouteEligible case route) = true :=
        (List.mem_filter.mp membership).2
      exact of_decide_eq_true eligibleCheck

end SimpleProbate.FL
