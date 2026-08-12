import SimpleProbate.Router.California

/-!
# Flags — the referral layer

A settlement engine that only answers "which form do I file" is dangerous,
because the cases that hurt people are the ones where the form is not the
problem. These are the screens for those cases: small, defensible rules over
intake facts, each with the fact paths that triggered it and a concrete next
step.

Two rules constrain severity:

* **`critical` means stop and get a professional**, and it may only fire on a
  fact the caller actually asserted. An unknown produces at most a `warning`
  or an `info` asking for the fact — never a critical alarm.
* **A flag is not a verdict.** Nothing here decides a route; flags sit beside
  the routes and tell the reader what the routes cannot see.
-/

namespace SimpleProbate
namespace Router

/-- Intake paths of the heirs matching a predicate, e.g. every heir marked as
a suspect. -/
private def heirPathsWhere (p : IntakeHeir → Bool) (field : String) :
    Nat → List IntakeHeir → List FactPath
  | _, [] => []
  | i, h :: rest =>
    let tail := heirPathsWhere p field (i + 1) rest
    if p h then heirPath i field :: tail else tail

private def assetPathsWhere (p : IntakeAsset → Bool) (field : String) :
    Nat → List IntakeAsset → List FactPath
  | _, [] => []
  | i, a :: rest =>
    let tail := assetPathsWhere p field (i + 1) rest
    if p a then assetPath i field :: tail else tail

/-- Debts that would be paid out of the probate estate. A debt secured by an
asset that passes outside probate follows that asset to the taker, so counting
it against the probate estate would manufacture insolvency that is not there. -/
private def probateDebtTotal (c : IntakeCase) (m : List AssetClassification) : Money :=
  c.debts.foldl
    (fun total d =>
      let securedByNonProbate : Bool :=
        match d.securedByAsset with
        | some name =>
          match findAsset m name with
          | some ac => ac.classification == .nonProbate
          | none => false
        | none => false
      match d.amountCents with
      | some amount => if securedByNonProbate then total else total + amount
      | none => total)
    0

/-! ## The rules -/

def slayerRuleFlag (c : IntakeCase) : Option Flag :=
  let suspects := heirPathsWhere (·.isSuspectInDeath == some true) "is_suspect_in_death" 0 c.heirs
  let homicide := c.decedent.mannerOfDeath == some .homicide
  if homicide || !suspects.isEmpty then
    some {
      id := "slayer_rule_screen"
      severity := .critical
      title := "Screen every heir under the slayer rule before anything is distributed."
      detail :=
        (if homicide then "The manner of death is homicide. " else "") ++
        (if suspects.isEmpty then "" else "An heir is identified as a suspect in the death. ") ++
        "A person who feloniously and intentionally kills the decedent is barred from taking in every capacity — by will, by intestacy, as a trust beneficiary, as a named beneficiary on a policy or account, and by survivorship. A joint tenancy is severed and treated as a tenancy in common, so the killer's survivorship right does not operate. The bar applies whether or not there is a criminal conviction; a civil finding on the preponderance standard is enough."
      citation := some ⟨"UPC §2-803; Cal. Prob. Code §250", none⟩
      triggeredBy :=
        (if homicide then [decedentPath "manner_of_death"] else []) ++ suspects
      action := "Distribute nothing to any heir under investigation, and refer the matter to counsel before any transfer is signed."
    }
  else none

def wrongfulDeathFlag (c : IntakeCase) : Option Flag :=
  if c.decedent.thirdPartyFaultSuspected == some true then
    some {
      id := "wrongful_death_vs_survival_claim"
      severity := .warning
      title := "Two different claims exist here, and they belong to different people."
      detail := "Third-party fault is suspected, which raises two distinct claims that are routinely confused. The wrongful-death claim belongs to the statutory beneficiaries in their own right; it compensates their loss, it generally does not pass through the estate, and it is generally beyond the reach of the decedent's creditors. The survival action belongs to the decedent's own cause of action, is an asset of the estate, and is reachable by creditors and by estate recovery. Which claim the recovery is attributed to therefore changes who receives the money. A personal representative may have to be appointed for the sole purpose of having standing to bring the survival action, even if the estate would otherwise need no administration. A two-year limitations period is typical and runs from the death, not from the appointment."
      citation := some ⟨"Cal. Code Civ. Proc. §§377.60, 377.30, 335.1", none⟩
      triggeredBy := [decedentPath "third_party_fault_suspected"]
      action := "Consult litigation counsel before signing any release, and before any settlement is allocated between the two claims."
    }
  else none

def simultaneousDeathFlag (c : IntakeCase) : Option Flag :=
  if c.decedent.relatedDeathWithin120h == some true then
    some {
      id := "simultaneous_death_120h"
      severity := .warning
      title := "A related death within 120 hours changes who inherits."
      detail := "A person who does not survive the decedent by at least 120 hours is treated as having predeceased. That reorders intestate succession, can defeat a will's residuary gift, and can turn a survivorship interest into a probate asset. Survival by the required period must be established by clear and convincing evidence."
      citation := some ⟨"Cal. Prob. Code §§220–224, 6403; UPC §2-702", none⟩
      triggeredBy := [decedentPath "related_death_within_120h"]
      action := "Establish the exact times of both deaths from the certificates before distributing anything."
    }
  else none

def insuranceContestabilityFlag (c : IntakeCase) : Option Flag :=
  let policies := assetPathsWhere (·.kind == some .lifeInsurance) "kind" 0 c.assets
  if policies.isEmpty then none
  else
    let suicide := c.decedent.mannerOfDeath == some .suicide
    some {
      id := "insurance_contestability_window"
      severity := if suicide then .warning else .info
      title := "Check the policy issue date against the contestability window."
      detail :=
        "A life policy is ordinarily contestable for two years from issue: within that window the insurer may rescind for a material misstatement in the application, and most policies also exclude death by suicide. Outside the window the policy is generally incontestable. The intake does not carry the issue date, so this cannot be resolved here." ++
        (if suicide then " The manner of death is recorded as suicide, which makes the issue date decisive rather than merely relevant." else "")
      citation := some ⟨"Cal. Ins. Code §10113.5", none⟩
      triggeredBy :=
        policies ++ (if suicide then [decedentPath "manner_of_death"] else [])
      action := "Obtain the policy and its issue date before counting the proceeds on anyone's behalf."
    }

def pendingDeathCertificateFlag (c : IntakeCase) : Option Flag :=
  let mannerOpen :=
    c.decedent.mannerOfDeath == some .pending || c.decedent.mannerOfDeath == some .undetermined
  let notFinal := c.decedent.deathCertificateFinal == some false
  if mannerOpen || notFinal then
    some {
      id := "pending_death_certificate"
      severity := .warning
      title := "Nearly everything downstream is gated on a final death certificate."
      detail := "The certificate is not final — the manner of death is pending or undetermined, or the caller has said the certificate has not issued. Banks, transfer agents, insurers and the court all require a certified copy, and an amended manner of death can reopen questions that were treated as settled (insurance exclusions, the slayer screen, workers' compensation). Filings that depend on it should not be prepared as though the fact were fixed."
      citation := some ⟨"Cal. Health & Safety Code §§102775, 103225", none⟩
      triggeredBy :=
        (if mannerOpen then [decedentPath "manner_of_death"] else []) ++
        (if notFinal then [decedentPath "death_certificate_final"] else [])
      action := "Track the certificate with the coroner or medical examiner, and re-run the assessment when the amended certificate issues."
    }
  else none

def insolventEstateFlag (c : IntakeCase) (m : List AssetClassification)
    (estate : ProbateEstate) : Option Flag :=
  let debts := probateDebtTotal c m
  if debts ≤ estate.knownSubtotalCents then none
  else
    let complete := estate.status == .known
    some {
      id := "insolvent_estate"
      severity := if complete then .critical else .warning
      title :=
        if complete then
          "The estate is insolvent — debts exceed everything there is to pay them with."
        else
          "On the facts supplied so far, the debts already exceed the known probate assets."
      detail :=
        s!"Known debts payable from the probate estate come to {Money.formatUSD debts}; the known probate estate is {Money.formatUSD estate.knownSubtotalCents}. " ++
        (if complete then
          "Creditors must be paid in statutory order of priority, and no distribution may be made to heirs or devisees until that ladder is satisfied. A personal representative who pays a lower-priority creditor, or distributes to a beneficiary, while a higher-priority claim is unpaid can be held personally liable for the amount misapplied."
        else
          "The asset inventory is not complete, so this is not yet a finding of insolvency — further assets may close the gap. It is enough of a signal to stop discretionary payments in the meantime.")
      citation := some ⟨"Cal. Prob. Code §§11420–11429", none⟩
      triggeredBy := ["debts"] ++ estate.missingFacts
      action := "Pay nothing to heirs. Confirm the full asset and debt picture, then pay claims strictly in statutory priority order."
    }

def medicaidRecoveryFlag (c : IntakeCase) : Option Flag :=
  if c.decedent.receivedMedicaidLtc == some true then
    some {
      id := "medicaid_estate_recovery"
      severity := .warning
      title := "Medi-Cal / Medicaid estate recovery may reach this estate."
      detail := "The decedent received long-term-care benefits. The State must seek recovery of correctly paid benefits from the estate of a beneficiary who was 55 or older or was institutionalised. California limits recovery to the probate estate and defers or waives it in defined circumstances — a surviving spouse, a surviving minor or disabled child, and hardship waivers. Which assets are probate therefore directly determines the State's reach, and the asset map above is the relevant analysis."
      citation := some ⟨"42 U.S.C. §1396p(b); Cal. Welf. & Inst. Code §14009.5", none⟩
      triggeredBy := [decedentPath "received_medicaid_ltc"]
      action := "Request the State's estate-recovery claim amount before distributing, and check whether an exemption or hardship waiver applies."
    }
  else none

def minorBeneficiaryFlag (c : IntakeCase) : Option Flag :=
  let minors := heirPathsWhere (fun h => match h.age with | some a => a < 18 | none => false) "age" 0 c.heirs
  if minors.isEmpty then none
  else
    some {
      id := "minor_beneficiary"
      severity := .warning
      title := "A minor cannot take an inheritance outright."
      detail := "A minor has no legal capacity to hold or receive the property, so a transfer directly to the child is not effective. Depending on the amount and the instrument, the property goes to a custodian under the Uniform Transfers to Minors Act, to a guardian of the estate appointed by the court, or into a blocked account — and the choice has to be made before the transfer, not after."
      citation := some ⟨"Cal. Prob. Code §§3900–3925; §§2400 et seq.", none⟩
      triggeredBy := minors
      action := "Decide the receiving vehicle (custodianship, guardianship of the estate, or blocked account) before any distribution is made."
    }

def specialNeedsFlag (c : IntakeCase) : Option Flag :=
  let recipients :=
    heirPathsWhere (·.receivesMeansTestedBenefits == some true) "receives_means_tested_benefits" 0 c.heirs
  if recipients.isEmpty then none
  else
    some {
      id := "special_needs_beneficiary"
      severity := .critical
      title := "An outright inheritance will destroy this beneficiary's benefits."
      detail := "An heir receives means-tested benefits. Received outright, an inheritance is a countable resource: it terminates SSI and the Medicaid eligibility that usually rides on it, and the beneficiary must spend down before requalifying. The damage is done by the transfer itself, and a disclaimer or an after-the-fact assignment is generally treated as a transfer for less than fair market value that carries its own penalty period. The remedy — a first-party special needs trust, a pooled trust, or a redirection through the estate plan — has to be in place before the distribution."
      citation := some ⟨"42 U.S.C. §1396p(d)(4)(A); 20 C.F.R. §416.1201", none⟩
      triggeredBy := recipients
      action := "Distribute nothing to this heir until a special-needs practitioner has structured the receipt."
    }

def ancillaryProbateFlag (c : IntakeCase) : Option Flag :=
  let states := ancillaryStates c
  match states with
  | [] => none
  | _ =>
    let paths := assetPathsWhere
      (fun a => a.kind == some .realProperty &&
        a.situsState != c.decedent.domicileState && a.situsState.isSome)
      "situs_state" 0 c.assets
    some {
      id := "ancillary_probate_required"
      severity := .warning
      title := s!"Real property outside the domicile state needs its own proceeding ({String.intercalate ", " states})."
      detail := "Title to real property is governed by, and cleared in, the state where the land sits. A domiciliary administration cannot pass title to an out-of-state parcel, so an ancillary proceeding is required in each such state — with its own filing, its own personal representative or local agent, and its own creditor and tax exposure. Some states offer a simplified route for a foreign personal representative; the situs state's rules, not the domicile's, decide."
      citation := some ⟨"Cal. Prob. Code §§12500–12591", none⟩
      triggeredBy := paths
      action := "Engage counsel in each situs state before listing, transferring or encumbering the parcel."
    }

def willCopyOnlyFlag (c : IntakeCase) : Option Flag :=
  if c.decedent.willStatus == some .copyOnly then
    some {
      id := "will_copy_only"
      severity := .warning
      title := "Only a copy of the will exists — the law may presume it was revoked."
      detail := "Where a will was last known to be in the testator's possession and the original cannot be found, most states presume the testator destroyed it with intent to revoke. The copy can still be admitted, but the proponent must overcome that presumption and prove the will's execution and contents. Until it is admitted, the estate is on an intestate footing, which can produce an entirely different set of takers."
      citation := some ⟨"Cal. Prob. Code §6124; §8223", none⟩
      triggeredBy := [decedentPath "will_status"]
      action := "Search the decedent's records, the drafting attorney's file and any safe-deposit box for the original before petitioning on the copy."
    }
  else none

def conflictRiskFlag (c : IntakeCase) : Option Flag :=
  let conflict := c.conflictSignals == some true
  let litigation := c.decedent.pendingLitigation == some true
  if conflict || litigation then
    some {
      id := "conflict_risk"
      severity := .warning
      title := "This estate has contest or litigation signals."
      detail :=
        (if conflict then "The caller has reported disagreement among the people involved. " else "") ++
        (if litigation then "Litigation involving the decedent is pending. " else "") ++
        "The simplified affidavit routes assume nobody with a superior right objects; an affidavit signed into a live dispute exposes the signer to personal liability to the true successor. A pending action also survives the death and must be substituted into, which can itself require a personal representative."
      -- The general rule first, then the California pin cites, so the flag is
      -- not mis-citing California law at a decedent domiciled elsewhere:
      -- UPC §3-1202 makes the recipient under an affidavit "answerable and
      -- accountable … to any other person having a superior right"; Cal. Prob.
      -- Code §13110(a) is California's enactment of that liability; Cal. Code
      -- Civ. Proc. §377.31 is the substitution rule for the pending action.
      citation :=
        some ⟨"UPC §3-1202; Cal. Prob. Code §13110(a); Cal. Code Civ. Proc. §377.31", none⟩
      triggeredBy :=
        (if conflict then ["conflict_signals"] else []) ++
        (if litigation then [decedentPath "pending_litigation"] else [])
      action := "Do not use a self-executing affidavit route. Get the disputed question resolved, or opened as a formal proceeding, first."
    }
  else none

def businessContinuityFlag (c : IntakeCase) : Option Flag :=
  let businesses := assetPathsWhere (·.kind == some .business) "kind" 0 c.assets
  if businesses.isEmpty then none
  else
    some {
      id := "business_continuity"
      severity := .warning
      title := "A business interest stops for nobody, including probate."
      detail := "Payroll, leases, licences, insurance and bank authority all fail the moment signature authority dies, and the loss compounds daily while the estate is being sorted out. A personal representative generally needs court authority to continue operating the business, and the operating agreement or partnership agreement may itself contain a buy-sell provision that has already been triggered by the death."
      citation := some ⟨"Cal. Prob. Code §9760", none⟩
      triggeredBy := businesses
      action := "Read the operating or partnership agreement now, and seek authority to continue operations before the next payroll date."
    }

def workersCompFlag (c : IntakeCase) : Option Flag :=
  if c.decedent.employmentRelatedDeath == some true then
    some {
      id := "workers_comp_death_benefit"
      severity := .warning
      title := "A work-related death carries a separate death benefit."
      detail := "Dependants of a worker who dies from a work-related injury or illness are entitled to death benefits, plus a burial allowance, paid through the workers' compensation system rather than through the estate. The benefit belongs to the dependants and is separate from anything in this assessment. The claim is time-limited: it must generally be filed within one year of the death, and no later than 240 weeks from the date of injury."
      citation := some ⟨"Cal. Lab. Code §§4700–4709, §5406", none⟩
      triggeredBy := [decedentPath "employment_related_death"]
      action := "File the dependants' death-benefit claim with the employer's carrier now; the one-year clock runs from the date of death."
    }
  else none

def vaBenefitsFlag (c : IntakeCase) : Option Flag :=
  if c.decedent.veteran == some true then
    some {
      id := "va_benefits"
      severity := .info
      title := "Veteran survivor benefits are separate from the estate."
      detail := "A veteran's survivors may be entitled to a burial and plot allowance, interment in a national cemetery, a headstone or marker, and — where the death was service-connected or the veteran was rated totally disabled for the required period — Dependency and Indemnity Compensation. These are paid to survivors directly and do not pass through the estate."
      citation := some ⟨"38 U.S.C. §§1310, 2302; 38 C.F.R. §3.1600", none⟩
      triggeredBy := [decedentPath "veteran"]
      action := "Obtain the DD-214 and apply to the VA; keep the funeral home's itemised bill for the burial allowance."
    }
  else none

/-! ## Assembly -/

private def collect {α : Type} : List (Option α) → List α
  | [] => []
  | none :: rest => collect rest
  | some x :: rest => x :: collect rest

/-- Every flag that fires, ordered critical → warning → info and, within a
severity, in the fixed order below. -/
def flagsOf (c : IntakeCase) (m : List AssetClassification)
    (estate : ProbateEstate) : List Flag :=
  let all := collect [
    slayerRuleFlag c,
    specialNeedsFlag c,
    insolventEstateFlag c m estate,
    wrongfulDeathFlag c,
    simultaneousDeathFlag c,
    pendingDeathCertificateFlag c,
    medicaidRecoveryFlag c,
    minorBeneficiaryFlag c,
    ancillaryProbateFlag c,
    willCopyOnlyFlag c,
    conflictRiskFlag c,
    businessContinuityFlag c,
    workersCompFlag c,
    insuranceContestabilityFlag c,
    vaBenefitsFlag c
  ]
  (all.filter fun f => f.severity == .critical) ++
  (all.filter fun f => f.severity == .warning) ++
  (all.filter fun f => f.severity == .info)

end Router
end SimpleProbate
