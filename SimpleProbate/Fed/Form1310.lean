import SimpleProbate.Fed.Report

/-!
# IRS Form 1310 — Statement of Person Claiming Refund Due a Deceased Taxpayer

Form 1310 is a printed decision tree, so it formalizes almost verbatim. The
Instructions for Form 1310, under *Who Must File*, state the rule as one
requirement with two exceptions:

> If you are claiming a refund on behalf of a deceased taxpayer, you must
> file Form 1310 unless either of the following applies.
> • You are a surviving spouse filing an original or amended joint return
>   with the decedent.
> • You are a personal representative filing an original return for the
>   decedent and a court certificate showing your appointment is attached to
>   the return.

Three things follow, and this module encodes exactly those three:

1. **The requirement is conditional on a refund.** Form 1310 claims a refund;
   if no refund is due to the decedent, the question does not arise.
2. **The spouse exception does not depend on the kind of return.** The
   instructions extend it to an amended joint return, so a surviving spouse
   filing jointly never files Form 1310.
3. **The representative exception is narrower than it is usually described.**
   It reaches an *original* return only, and only when the court certificate
   of appointment is actually attached — the certificate is what substitutes
   for the form. A court-appointed representative filing an amended return,
   or filing without the certificate, files Form 1310 (Part I, box B).

Anyone else claiming the refund files Form 1310 and completes the Part II
affidavit: no personal representative has been or will be appointed, and the
claimant will pay out the refund under the laws of the decedent's state of
residence.

Nothing here is a number, a threshold, or a date, so nothing here goes stale
with an inflation adjustment.
-/

namespace SimpleProbate
namespace Fed
namespace Form1310

/-! ## Facts

The intake fields this module consumes. `IntakeCase` (CONTRACT-SETTLEMENT.md
§2) carries no tax facts, so these are four additions under `decedent.*`;
they are named here once and every fact path the module emits comes from
these constants. -/

def factRefundDue : FactPath := "decedent.federal_refund_due"
def factClaimant : FactPath := "decedent.refund_claimant"
def factReturnKind : FactPath := "decedent.final_return_kind"
def factCertificate : FactPath := "decedent.court_certificate_attached"

/-- Who is claiming the decedent's refund. -/
inductive Claimant
  | /-- A surviving spouse filing a joint return with the decedent. -/
    survivingSpouseJointReturn
  | /-- A representative appointed by a court. -/
    courtAppointedRepresentative
  | /-- Anyone else claiming on the decedent's behalf. -/
    otherClaimant
deriving BEq, DecidableEq, Repr

/-- The return on which the refund is claimed. The representative exception
reaches original returns only. -/
inductive ReturnKind
  | original
  | amended
deriving BEq, DecidableEq, Repr

/-! ## Prop layer (total facts) -/

/-- A case in which every fact is known. -/
structure Case where
  refundDue : Bool
  claimant : Claimant
  returnKind : ReturnKind
  courtCertificateAttached : Bool
deriving BEq, DecidableEq, Repr

/-- Exception 1: a surviving spouse filing a joint return with the decedent,
original or amended. -/
def SpouseJointReturnException (c : Case) : Prop :=
  c.claimant = .survivingSpouseJointReturn

/-- Exception 2: a court-appointed representative filing the decedent's
*original* return with the court certificate of appointment attached. -/
def CourtCertificateException (c : Case) : Prop :=
  c.claimant = .courtAppointedRepresentative ∧
  c.returnKind = .original ∧
  c.courtCertificateAttached = true

/-- Form 1310 must be filed: a refund is due to the decedent and neither
exception applies. -/
def Required (c : Case) : Prop :=
  c.refundDue = true ∧
  ¬ SpouseJointReturnException c ∧
  ¬ CourtCertificateException c

instance (c : Case) : Decidable (SpouseJointReturnException c) := by
  unfold SpouseJointReturnException; infer_instance

instance (c : Case) : Decidable (CourtCertificateException c) := by
  unfold CourtCertificateException; infer_instance

instance (c : Case) : Decidable (Required c) := by
  unfold Required; infer_instance

/-! ## Partial layer (unknown is never false) -/

/-- The same four facts, each possibly unknown. -/
structure Facts where
  refundDue : Option Bool := none
  claimant : Option Claimant := none
  returnKind : Option ReturnKind := none
  courtCertificateAttached : Option Bool := none
deriving BEq, DecidableEq, Repr

def Case.toFacts (c : Case) : Facts :=
  { refundDue := some c.refundDue
    claimant := some c.claimant
    returnKind := some c.returnKind
    courtCertificateAttached := some c.courtCertificateAttached }

/-- The verdict, with the branch of the decision tree that produced it.
A typed result, not a boolean: "not required" because no refund is due is a
different fact about the world than "not required" because a court
certificate is attached. -/
inductive Outcome
  | /-- No refund is due to the decedent; no refund claim arises. -/
    notRequiredNoRefundDue
  | /-- Exception 1 — surviving spouse filing a joint return. -/
    notRequiredSpouseJointReturn
  | /-- Exception 2 — court certificate of appointment attached. -/
    notRequiredCourtCertificate
  | /-- Neither exception applies; file Form 1310 with the Part II affidavit. -/
    requiredPartII
  | /-- Unknown is not false: these facts decide the answer. -/
    needsInformation (facts : List FactPath)
deriving BEq, DecidableEq, Repr

/-- The bare filing verdict a decisive outcome asserts (`none` while
unresolved). Used to state soundness against the Prop layer. -/
def Outcome.requiredVerdict : Outcome → Option Bool
  | .requiredPartII => some true
  | .needsInformation _ => none
  | _ => some false

def Outcome.isDecisive (o : Outcome) : Bool := o.requiredVerdict.isSome

def Outcome.missingFacts : Outcome → List FactPath
  | .needsInformation facts => facts
  | _ => []

/-- The refund gate, reached once the exceptions are known not to apply.
A refund that is not due settles the question; an unknown one does not. -/
private def refundGate (refundDue : Option Bool) : Outcome :=
  match refundDue with
  | none => .needsInformation [factRefundDue]
  | some false => .notRequiredNoRefundDue
  | some true => .requiredPartII

/-- Walk the form's decision tree over partially known facts.

Order matters and is chosen so that no question is asked that cannot change
the answer. A known "no refund" settles the case first. The spouse exception
then settles it without reference to the return or a certificate. The
representative exception needs both of its own facts, but only reaches the
refund question once it is known not to apply. -/
def assess (f : Facts) : Outcome :=
  if f.refundDue == some false then
    .notRequiredNoRefundDue
  else
    match f.claimant with
    | none =>
      .needsInformation <|
        [factClaimant] ++ (if f.refundDue.isNone then [factRefundDue] else [])
    | some .survivingSpouseJointReturn => .notRequiredSpouseJointReturn
    | some .otherClaimant => refundGate f.refundDue
    | some .courtAppointedRepresentative =>
      match f.returnKind, f.courtCertificateAttached with
      | some .original, some true => .notRequiredCourtCertificate
      | some .amended, _ => refundGate f.refundDue
      | _, some false => refundGate f.refundDue
      | returnKind, certificate =>
        -- The exception is neither established nor ruled out.
        .needsInformation <|
          (if returnKind.isNone then [factReturnKind] else []) ++
          (if certificate.isNone then [factCertificate] else []) ++
          (if f.refundDue.isNone then [factRefundDue] else [])

/-! ## Wire report -/

def citations : List Citation :=
  [ { label := "IRS Form 1310, Statement of Person Claiming Refund Due a Deceased Taxpayer" },
    { label := "Instructions for Form 1310, Who Must File" } ]

private def outcomeReasons : Outcome → List Disqualifier
  | .notRequiredNoRefundDue =>
    [reason "no_refund_due"
      "No federal income tax refund is due to the decedent, so no refund claim arises and Form 1310 is not filed."]
  | .notRequiredSpouseJointReturn =>
    [reason "surviving_spouse_joint_return"
      "A surviving spouse filing a joint return with the decedent does not file Form 1310. The exception covers an original or an amended joint return."]
  | .notRequiredCourtCertificate =>
    [reason "court_certificate_attached"
      "A court-appointed personal representative filing the decedent's original return does not file Form 1310 when the court certificate showing the appointment is attached to the return; the certificate serves in its place."]
  | .requiredPartII =>
    [reason "refund_claimed_for_decedent"
      "A refund is due to the decedent and neither exception applies, so the person claiming it files Form 1310.",
     reason "part_ii_affidavit_required"
      "Complete Part II: state whether a personal representative has been or will be appointed, and confirm that the refund will be paid out under the laws of the state where the decedent was a legal resident."]
  | .needsInformation _ =>
    [reason "form_1310_undetermined"
      "Whether Form 1310 must be filed depends on facts that are not yet known. Unknown is not treated as \"no form required\"."]

private def outcomeStatus : Outcome → FederalStatus
  | .requiredPartII => .required
  | .needsInformation _ => .needsInformation
  | _ => .notRequired

/-- The contract row for Form 1310. -/
def report (f : Facts) : FederalReport :=
  let outcome := assess f
  { item := .irsForm1310
    label := FederalItem.label .irsForm1310
    status := outcomeStatus outcome
    payee := none
    amountCents := none
    reasons := outcomeReasons outcome
    missingFacts := outcome.missingFacts
    citations := citations }

/-! ## Regressions

The four total facts range over `2 × 3 × 2 × 2 = 24` cases and the partial
facts over `3 × 4 × 3 × 3 = 108`, so both spaces are enumerated and the
partial layer is checked against the Prop layer on every one of them. -/

def allClaimants : List Claimant :=
  [.survivingSpouseJointReturn, .courtAppointedRepresentative, .otherClaimant]

def allReturnKinds : List ReturnKind := [.original, .amended]

private def allBools : List Bool := [true, false]

private def options (xs : List α) : List (Option α) := none :: xs.map some

/-- Every total case. -/
def allCases : List Case :=
  allBools.flatMap fun refundDue =>
  allClaimants.flatMap fun claimant =>
  allReturnKinds.flatMap fun returnKind =>
  allBools.map fun certificate =>
    { refundDue := refundDue
      claimant := claimant
      returnKind := returnKind
      courtCertificateAttached := certificate }

/-- Every partial fact set, unknowns included. -/
def allFacts : List Facts :=
  (options allBools).flatMap fun refundDue =>
  (options allClaimants).flatMap fun claimant =>
  (options allReturnKinds).flatMap fun returnKind =>
  (options allBools).map fun certificate =>
    { refundDue := refundDue
      claimant := claimant
      returnKind := returnKind
      courtCertificateAttached := certificate }

example : allCases.length = 24 := by decide
example : allFacts.length = 108 := by decide

private def agrees [BEq α] (o : Option α) (v : α) : Bool :=
  match o with
  | none => true
  | some x => x == v

/-- `f` is a partial description of `c`: every fact `f` knows, `c` has. -/
def Facts.completes (f : Facts) (c : Case) : Bool :=
  agrees f.refundDue c.refundDue &&
  agrees f.claimant c.claimant &&
  agrees f.returnKind c.returnKind &&
  agrees f.courtCertificateAttached c.courtCertificateAttached

/-- **Exactness on total facts.** With every fact known, the decision tree
agrees with the `Required` predicate on all 24 cases. -/
theorem assess_total_exact :
    allCases.all (fun c =>
      (assess c.toFacts).requiredVerdict == some (decide (Required c))) = true := by
  decide

/-- **Decisiveness on total facts.** With every fact known the tree never
asks for more. -/
theorem assess_total_decisive :
    allCases.all (fun c => (assess c.toFacts).isDecisive) = true := by decide

/-- **Soundness under partial information.** Whenever the tree returns a
verdict from incomplete facts, every completion of those facts yields the
same verdict — `2592` fact-set/completion pairs. -/
theorem assess_partial_sound :
    allFacts.all (fun f =>
      allCases.all (fun c =>
        !f.completes c ||
        match (assess f).requiredVerdict with
        | none => true
        | some verdict => (assess c.toFacts).requiredVerdict == some verdict)) = true := by
  decide

/-- **No unnecessary questions.** Conversely, whenever every completion of a
fact set agrees on the verdict, the tree already returns it rather than
asking for facts that cannot change the answer. -/
theorem assess_partial_complete :
    allFacts.all (fun f =>
      let verdicts :=
        (allCases.filter (f.completes ·)).map (fun c => (assess c.toFacts).requiredVerdict)
      !(verdicts.all (· == verdicts.headD none)) ||
      (assess f).requiredVerdict == verdicts.headD none) = true := by
  decide

/-- Every emitted report satisfies the contract's shape invariants. -/
theorem report_wellFormed :
    allFacts.all (fun f => (report f).wellFormed) = true := by decide

namespace Examples

/-! Branch-by-branch, in the order the form presents them. -/

-- Exception 1: the canonical fixture — surviving spouse filing jointly.
-- Note that this branch does not need to know whether a refund is due: if
-- one is, the exception applies; if none is, no claim arises. Either way the
-- form is not filed.
example :
    assess { claimant := some .survivingSpouseJointReturn } =
      .notRequiredSpouseJointReturn := by decide

example :
    (report { claimant := some .survivingSpouseJointReturn }).status =
      .notRequired := by decide

-- Exception 2: court-appointed representative, original return, certificate
-- attached.
example :
    assess { refundDue := some true
             claimant := some .courtAppointedRepresentative
             returnKind := some .original
             courtCertificateAttached := some true } =
      .notRequiredCourtCertificate := by decide

-- The exception is narrow: an amended return does not carry it.
example :
    assess { refundDue := some true
             claimant := some .courtAppointedRepresentative
             returnKind := some .amended
             courtCertificateAttached := some true } =
      .requiredPartII := by decide

-- Nor does an original return with the certificate left off.
example :
    assess { refundDue := some true
             claimant := some .courtAppointedRepresentative
             returnKind := some .original
             courtCertificateAttached := some false } =
      .requiredPartII := by decide

-- The general rule: anyone else claiming the refund files the form.
example :
    assess { refundDue := some true, claimant := some .otherClaimant } =
      .requiredPartII := by decide

example :
    (report { refundDue := some true, claimant := some .otherClaimant }).reasons.map (·.id) =
      ["refund_claimed_for_decedent", "part_ii_affidavit_required"] := by decide

-- No refund, no claim — whoever is asking.
example :
    assess { refundDue := some false, claimant := some .otherClaimant } =
      .notRequiredNoRefundDue := by decide

example : assess { refundDue := some false } = .notRequiredNoRefundDue := by decide

/-! Unknowns produce `needs_information` naming the deciding facts, never a
guess in either direction. -/

-- Nothing known at all.
example :
    assess {} = .needsInformation [factClaimant, factRefundDue] := by decide

-- Who is claiming decides it; the refund is already known due.
example :
    assess { refundDue := some true } = .needsInformation [factClaimant] := by
  decide

-- A representative with the exception unresolved: both exception facts and
-- the refund are still live.
example :
    assess { claimant := some .courtAppointedRepresentative } =
      .needsInformation [factReturnKind, factCertificate, factRefundDue] := by
  decide

-- Once the exception is ruled out, only the refund remains.
example :
    assess { claimant := some .courtAppointedRepresentative
             returnKind := some .original
             courtCertificateAttached := some false } =
      .needsInformation [factRefundDue] := by decide

-- An unknown claimant never defaults to "no form required".
example :
    (report { refundDue := some true }).status = .needsInformation := by decide

example :
    (report { refundDue := some true }).missingFacts = [factClaimant] := by decide

end Examples

end Form1310
end Fed
end SimpleProbate
