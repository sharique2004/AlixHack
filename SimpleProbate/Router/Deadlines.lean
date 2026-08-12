import SimpleProbate.Router.Classify
import SimpleProbate.Router.Dates

/-!
# Deadlines

Dates are computed where the facts allow it and left explicitly uncomputed
where they do not. There are exactly three states and no fourth:

* `computed` — the triggering event has happened and is known, so there is a
  real date on the wire.
* `awaiting_event` — the clock is real but has not started. Letters of
  administration have not issued, so "four months after letters" is not a date
  yet. The offset is still reported, because that is the part that is known.
* `needs_information` — the clock would have started, but a fact needed to
  compute it (the date of death) is missing.

A deadline is never guessed forward from today, and never rendered as a date
that the facts do not support.
-/

namespace SimpleProbate
namespace Router

private def fromDeath (c : IntakeCase) (compute : CivilDate → CivilDate) :
    DeadlineStatus × Option CivilDate :=
  match c.decedent.deathDate with
  | some d => (.computed, some (compute d))
  | none => (.needsInformation, none)

/-- The decedent's final individual income tax return: due on the ordinary
due date for the year of death, i.e. April 15 of the following year. -/
def finalIncomeTaxReturn (c : IntakeCase) : Deadline :=
  let (status, date) := fromDeath c april15Following
  { id := "final_form_1040"
    label := "Decedent's final income tax return (Form 1040) due"
    status := status
    date := date
    relativeTo := "date_of_death"
    offsetDays := none
    citation := some ⟨"26 U.S.C. §6072(a)", none⟩ }

/-- Creditor claims: the later of four months after letters first issue, or
sixty days after notice is given to that particular creditor. Letters have not
issued in an intake, so the window is `awaiting_event` — reporting a date here
would be inventing one. -/
def creditorClaimWindow : Deadline :=
  { id := "ca_creditor_claim_window"
    label := "Creditor claim window closes (later of 4 months after letters, or 60 days after notice to that creditor)"
    status := .awaitingEvent
    date := none
    relativeTo := "letters_issued"
    offsetDays := some 120
    citation := some ⟨"Cal. Prob. Code §9100", none⟩ }

/-- Inventory and appraisal: four months after letters first issue. -/
def inventoryAndAppraisal : Deadline :=
  { id := "ca_inventory_and_appraisal"
    label := "Inventory and appraisal due to be filed"
    status := .awaitingEvent
    date := none
    relativeTo := "letters_issued"
    offsetDays := some 120
    citation := some ⟨"Cal. Prob. Code §8800", none⟩ }

/-- Federal estate tax return, when one is required: nine months after death,
extendable by six months on a timely Form 4768. Whether a return is required
turns on the gross estate plus adjusted taxable gifts against the filing
threshold for the year of death — a figure this snapshot does not carry, so
the date is reported and the applicability question is left to the reader. -/
def federalEstateTaxReturn (c : IntakeCase) : Deadline :=
  let (status, date) := fromDeath c (fun d => addMonths d 9)
  { id := "federal_estate_tax_return"
    label := "Federal estate tax return (Form 706) due, if the estate is required to file"
    status := status
    date := date
    relativeTo := "date_of_death"
    offsetDays := none
    citation := some ⟨"26 U.S.C. §6075(a)", none⟩ }

/-- Social Security's lump-sum death payment must be applied for within two
years of the death; the claim is lost after that, with no equitable
extension. -/
def ssaLumpSumClaim (c : IntakeCase) : Deadline :=
  let (status, date) := fromDeath c (fun d => addMonths d 24)
  { id := "ssa_lump_sum_claim_deadline"
    label := "Last day to apply for the Social Security lump-sum death payment"
    status := status
    date := date
    relativeTo := "date_of_death"
    offsetDays := none
    citation := some ⟨"42 U.S.C. §402(i); 20 C.F.R. §404.390", none⟩ }

/-- Whoever holds the original will must deliver it to the clerk of the
superior court within thirty days of learning of the death. This one binds
even when no probate is ever opened, and it is the deadline families miss
most often. -/
def willLodging (c : IntakeCase) : Option Deadline :=
  match c.decedent.willStatus with
  | some WillStatus.none => none
  | some .unsure => none
  | Option.none => none
  | some _ =>
    let (status, date) := fromDeath c (fun d => addDays d 30)
    some {
      id := "ca_will_lodging"
      label := "Original will must be delivered to the clerk of the superior court"
      status := status
      date := date
      relativeTo := "date_of_death"
      offsetDays := some 30
      citation := some ⟨"Cal. Prob. Code §8200", none⟩ }

def deadlinesOf (c : IntakeCase) : List Deadline :=
  let base := [finalIncomeTaxReturn c, federalEstateTaxReturn c, ssaLumpSumClaim c]
  let ca :=
    if c.decedent.domicileState == some "CA" then
      (match willLodging c with | some d => [d] | none => []) ++
        [creditorClaimWindow, inventoryAndAppraisal]
    else
      []
  ca ++ base

end Router
end SimpleProbate
