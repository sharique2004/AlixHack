import SimpleProbate.Fed.Form1310
import SimpleProbate.Fed.SsaLumpSum

/-!
# The federal layer, assembled

One entry point for the Router: `federalReports` takes the federal facts of
an `IntakeCase` and returns the `federal[]` array of `SettlementAssessment`
in stable order — Form 1310 first, then the lump-sum death payment — or a
typed `CaseError` if the case is structurally broken.

Both items are federal, so neither depends on the domicile state and both
rows appear for every case, in every jurisdiction.
-/

namespace SimpleProbate
namespace Fed

/-- The federal facts of an `IntakeCase`.

`asOfDate` and `deathDate` are the contract's `as_of_date` and
`decedent.death_date`; `survivingSpouse` is `decedent.surviving_spouse`.
The remaining fields are the additions the two federal items need, listed
with their fact paths in `Form1310` and `Ssa`. Every one of them defaults to
unknown: a router that supplies nothing gets `needs_information` on both
rows, never a verdict. -/
structure FederalCase where
  /-- `as_of_date` — required by the contract. -/
  asOfDate : CivilDate
  /-- `decedent.death_date`. -/
  deathDate : Option CivilDate := none
  -- IRS Form 1310
  /-- `decedent.federal_refund_due`. -/
  refundDue : Option Bool := none
  /-- `decedent.refund_claimant`. -/
  refundClaimant : Option Form1310.Claimant := none
  /-- `decedent.final_return_kind`. -/
  finalReturnKind : Option Form1310.ReturnKind := none
  /-- `decedent.court_certificate_attached`. -/
  courtCertificateAttached : Option Bool := none
  -- SSA lump-sum death payment
  /-- `decedent.ssa_insured_at_death` — fully *or* currently insured. -/
  insuredAtDeath : Option Bool := none
  /-- `decedent.surviving_spouse`. -/
  survivingSpouse : Option Bool := none
  /-- `heirs_complete` — gates every negative conclusion about who may claim,
  exactly as `inventory_complete` gates the valuation caps. -/
  heirsComplete : Option Bool := none
  /-- `heirs[]`, carrying the three Social Security facts. -/
  claimants : List Ssa.Claimant := []
deriving BEq, DecidableEq, Repr

def FederalCase.form1310Facts (c : FederalCase) : Form1310.Facts :=
  { refundDue := c.refundDue
    claimant := c.refundClaimant
    returnKind := c.finalReturnKind
    courtCertificateAttached := c.courtCertificateAttached }

def FederalCase.ssaFacts (c : FederalCase) : Ssa.Facts :=
  { asOfDate := c.asOfDate
    deathDate := c.deathDate
    insuredAtDeath := c.insuredAtDeath
    survivingSpouse := c.survivingSpouse
    heirsComplete := c.heirsComplete
    claimants := c.claimants }

/-- The `federal[]` array, in stable order. Structural problems — an invalid
as-of date, an invalid or post-snapshot date of death, an as-of date before
the death — are typed errors, never legal conclusions. -/
def federalReports (c : FederalCase) : Except CaseError (List FederalReport) := do
  let ssaReport ← Ssa.report c.ssaFacts
  pure [Form1310.report c.form1310Facts, ssaReport]

/-! ## Regressions -/

namespace AssessmentExamples

private def itemsOf (r : Except CaseError (List FederalReport)) : List String :=
  match r with
  | .ok reports => reports.map (·.item.wireName)
  | .error _ => []

private def statusesOf (r : Except CaseError (List FederalReport)) : List String :=
  match r with
  | .ok reports => reports.map (·.status.wireName)
  | .error _ => []

private def payeesOf (r : Except CaseError (List FederalReport)) : List (Option String) :=
  match r with
  | .ok reports => reports.map (fun report => report.payee.map (·.wireName))
  | .error _ => []

private def amountsOf (r : Except CaseError (List FederalReport)) : List (Option Money) :=
  match r with
  | .ok reports => reports.map (·.amountCents)
  | .error _ => []

private def allWellFormed (r : Except CaseError (List FederalReport)) : Bool :=
  match r with
  | .ok reports => reports.all (·.wellFormed)
  | .error _ => false

/-- The canonical fixture of CONTRACT-SETTLEMENT.md §6: California domicile,
died 2026-03-04, married with a surviving spouse, assessed 2026-08-12. The
federal facts the fixture does not spell out — that the spouse files a joint
return, that the decedent died insured, and that the spouse shared the
household — are supplied here explicitly, because the engine will not
assume any of them. -/
def canonicalFixture : FederalCase :=
  { asOfDate := ⟨2026, 8, 12⟩
    deathDate := some ⟨2026, 3, 4⟩
    refundClaimant := some .survivingSpouseJointReturn
    finalReturnKind := some .original
    insuredAtDeath := some true
    survivingSpouse := some true
    heirsComplete := some true
    claimants := [
      { index := 0
        relationship := some .spouse
        livedInSameHouseholdAtDeath := some true
        entitledToSpouseBenefitsMonthOfDeath := some false
        entitledToChildBenefitsMonthOfDeath := some false }] }

-- Stable order and stable wire names.
example :
    itemsOf (federalReports canonicalFixture) =
      ["irs_form_1310", "ssa_lump_sum_death_payment"] := by decide

-- §6: Form 1310 not required (surviving spouse filing jointly); lump-sum
-- death payment payable to the surviving spouse, $255.
example :
    statusesOf (federalReports canonicalFixture) = ["not_required", "payable"] := by
  decide

example :
    payeesOf (federalReports canonicalFixture) = [none, some "surviving_spouse"] := by
  decide

example :
    amountsOf (federalReports canonicalFixture) = [none, some 25_500] := by decide

example : allWellFormed (federalReports canonicalFixture) := by decide

/-- A case with nothing federal supplied. -/
def emptyCase : FederalCase := { asOfDate := ⟨2026, 8, 12⟩ }

-- Doctrine 1: silence is not a verdict in either direction.
example :
    statusesOf (federalReports emptyCase) =
      ["needs_information", "needs_information"] := by decide

example : allWellFormed (federalReports emptyCase) := by decide

-- And it says exactly which facts it is waiting on.
example :
    (match federalReports emptyCase with
     | .ok reports => reports.map (·.missingFacts)
     | .error _ => []) =
      [[Form1310.factClaimant, Form1310.factRefundDue],
       [Ssa.factInsured, Ssa.factDeathDate, Ssa.factSurvivingSpouse,
        Ssa.factHeirsComplete]] := by decide

-- Doctrine 3: a death date past the snapshot is a typed error for the whole
-- federal array, not two verdicts.
example :
    federalReports { canonicalFixture with deathDate := some ⟨2027, 1, 2⟩ } =
      .error .afterSnapshot := by decide

end AssessmentExamples

end Fed
end SimpleProbate
