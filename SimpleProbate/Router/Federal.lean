import SimpleProbate.Router.Report
import SimpleProbate.Router.Intake
import SimpleProbate.Fed.Assessment

/-!
# Federal adapter

`SimpleProbate.Fed` owns the two federal items and their wire vocabulary but
deliberately writes no JSON and knows nothing about `IntakeCase`. This module
is the join: it reads the federal facts out of the intake, calls
`Fed.federalReports`, and projects the result onto the Router's `FederalReport`
row.

Nothing is inferred on the way across. In particular the Social Security
ladder's third rung turns on entitlement to child's insurance benefits under
§402(d), which does not track the probate relationship label — an adult child
is usually not entitled and a step-grandchild may be — so
`heirs[i].entitled_to_child_benefits_month_of_death` is passed through exactly
as supplied and never derived from `heirs[i].relationship`. An intake that
leaves it unknown gets `needs_information` naming that path, which is the
question the product should ask.
-/

namespace SimpleProbate
namespace Router

/-! ## Intake → federal facts -/

/-- The probate relationship label, as the Social Security ladder reads it.
Only `spouse` carries statutory weight; rung (3) does not consult this field
at all. -/
private def ssaRelationship : Relationship → Fed.Ssa.Relationship
  | .spouse => .spouse
  | .child => .child
  | .parent | .sibling | .other => .otherRelation

/-- `heirs[]` → the ladder's claimants. The index is the position in the
contract's `heirs[]` array, because it is what the emitted fact paths are
built from; the list is never filtered. -/
private def claimantsOf : Nat → List IntakeHeir → List Fed.Ssa.Claimant
  | _, [] => []
  | index, h :: rest =>
    { index := index
      relationship := h.relationship.map ssaRelationship
      livedInSameHouseholdAtDeath := h.livedInSameHouseholdAtDeath
      entitledToSpouseBenefitsMonthOfDeath := h.entitledToSpouseBenefitsMonthOfDeath
      entitledToChildBenefitsMonthOfDeath := h.entitledToChildBenefitsMonthOfDeath } ::
    claimantsOf (index + 1) rest

private def refundClaimantOf : RefundClaimant → Fed.Form1310.Claimant
  | .survivingSpouseJointReturn => .survivingSpouseJointReturn
  | .courtAppointedRepresentative => .courtAppointedRepresentative
  | .otherClaimant => .otherClaimant

private def returnKindOf : FinalReturnKind → Fed.Form1310.ReturnKind
  | .original => .original
  | .amended => .amended

def federalCaseOf (c : IntakeCase) : Fed.FederalCase :=
  { asOfDate := c.asOfDate
    deathDate := c.decedent.deathDate
    refundDue := c.decedent.federalRefundDue
    refundClaimant := c.decedent.refundClaimant.map refundClaimantOf
    finalReturnKind := c.decedent.finalReturnKind.map returnKindOf
    courtCertificateAttached := c.decedent.courtCertificateAttached
    insuredAtDeath := c.decedent.ssaInsuredAtDeath
    survivingSpouse := c.decedent.survivingSpouse
    heirsComplete := c.heirsComplete
    claimants := claimantsOf 0 c.heirs }

/-! ## Federal row → wire row -/

private def statusOf : Fed.FederalStatus → FederalStatus
  | .required => .required
  | .notRequired => .notRequired
  | .needsInformation => .needsInformation
  | .payable => .payable
  | .notPayable => .notPayable

private def rowOf (r : Fed.FederalReport) : FederalReport :=
  { item := r.item.wireName
    label := r.label
    status := statusOf r.status
    payee := r.payee.map (·.wireName)
    amountCents := r.amountCents
    reasons := r.reasons.map fun d => ⟨d.id, d.text⟩
    missingFacts := r.missingFacts
    citations := r.citations.map fun c => ⟨c.label, c.url⟩ }

/-- The `federal[]` array for a case: Form 1310 first, then the lump-sum death
payment. A structural problem is a typed error, never two verdicts — the
Router pre-empts every one of them in `validate`, so this is a total fallback
rather than a live path. -/
def federalRowsOf (c : IntakeCase) : Except CaseError (List FederalReport) :=
  (Fed.federalReports (federalCaseOf c)).map fun rows => rows.map rowOf

end Router
end SimpleProbate
