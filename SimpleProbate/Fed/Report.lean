import SimpleProbate.Fed.Days

/-!
# The `FederalReport` row

A Lean mirror of the `federal[]` element of `SettlementAssessment`
(CONTRACT-SETTLEMENT.md §3). This module owns the shape and the wire names;
it deliberately does not import `Lean.Data.Json` — encoding belongs to the
Router agent, exactly as `SimpleProbate.Partial` leaves encoding to
`SimpleProbate.Api`.

Reasons reuse `SimpleProbate.Disqualifier` (`{id, text}`), which is already
the contract's reason shape, and missing facts reuse `FactPath`.
-/

namespace SimpleProbate
namespace Fed

/-- A legal authority. Every conclusion in this module carries at least one.
`url` is `none` rather than a guessed link; the contract's own examples
carry `"url": null`. -/
structure Citation where
  label : String
  url : Option String := none
deriving BEq, DecidableEq, Repr

/-- The two federal items assessed here. -/
inductive FederalItem
  | irsForm1310
  | ssaLumpSumDeathPayment
deriving BEq, DecidableEq, Repr

def FederalItem.wireName : FederalItem → String
  | .irsForm1310 => "irs_form_1310"
  | .ssaLumpSumDeathPayment => "ssa_lump_sum_death_payment"

def FederalItem.label : FederalItem → String
  | .irsForm1310 => "IRS Form 1310 — refund claim for a deceased taxpayer"
  | .ssaLumpSumDeathPayment => "Social Security lump-sum death payment"

/-- Wire status. `required`/`notRequired` are the Form 1310 verdicts,
`payable`/`notPayable` the SSA verdicts, `needsInformation` belongs to both.
Which statuses an item can take is pinned by `FederalReport.statusInRange`. -/
inductive FederalStatus
  | required
  | notRequired
  | needsInformation
  | payable
  | notPayable
deriving BEq, DecidableEq, Repr

def FederalStatus.wireName : FederalStatus → String
  | .required => "required"
  | .notRequired => "not_required"
  | .needsInformation => "needs_information"
  | .payable => "payable"
  | .notPayable => "not_payable"

/-- Who receives a payment. `estate` exists because the contract enumerates
it; 42 U.S.C. §402(i) names only a widow(er) and entitled children, so this
module never emits it — see `Ssa.payee_ne_estate`. -/
inductive FederalPayee
  | survivingSpouse
  | child
  | estate
  | nobody
deriving BEq, DecidableEq, Repr

def FederalPayee.wireName : FederalPayee → String
  | .survivingSpouse => "surviving_spouse"
  | .child => "child"
  | .estate => "estate"
  | .nobody => "none"

/-- One `federal[]` row. `payee` and `amountCents` are `none` for every item
but the SSA lump-sum payment, per the contract. -/
structure FederalReport where
  item : FederalItem
  label : String
  status : FederalStatus
  payee : Option FederalPayee := none
  amountCents : Option Money := none
  reasons : List Disqualifier := []
  missingFacts : List FactPath := []
  citations : List Citation := []
deriving BEq, DecidableEq, Repr

/-- The statuses each item is allowed to take. Form 1310 is a filing
requirement, so it is never `payable`; the lump-sum payment is a benefit, so
it is never `required`. -/
def FederalReport.statusInRange (report : FederalReport) : Bool :=
  match report.item, report.status with
  | .irsForm1310, .required
  | .irsForm1310, .notRequired
  | .irsForm1310, .needsInformation
  | .ssaLumpSumDeathPayment, .payable
  | .ssaLumpSumDeathPayment, .notPayable
  | .ssaLumpSumDeathPayment, .needsInformation => true
  | _, _ => false

/-- Doctrine 4: no legal conclusion without a citation, and doctrine 1:
`needs_information` must name the facts it is waiting on. -/
def FederalReport.wellFormed (report : FederalReport) : Bool :=
  report.statusInRange &&
  !report.citations.isEmpty &&
  (report.status != .needsInformation || !report.missingFacts.isEmpty) &&
  (report.status == .needsInformation || report.missingFacts.isEmpty)

/-- Convenience for building a reason. -/
def reason (id text : String) : Disqualifier := ⟨id, text⟩

end Fed
end SimpleProbate
