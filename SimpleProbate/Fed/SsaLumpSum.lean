import SimpleProbate.Fed.Report

/-!
# Social Security lump-sum death payment — 42 U.S.C. §402(i)

A closed rule system with four moving parts and no discretion:

* **Insured status.** §402(i) opens "upon the death … of an individual who
  died a fully or currently insured individual". Both suffice; this module
  takes one fact meaning the disjunction, because a claimant who knows only
  "currently insured" has already satisfied it and asking about fully
  insured status could not change the answer.
* **Amount.** The statute pays "three times such individual's primary
  insurance amount …, or an amount equal to $255, whichever is the smaller".
  $255 is not indexed and has bound since the 1981 amendment, so the module
  reports a flat `25_500` cents and never computes a primary insurance
  amount it was not given.
* **Priority.** A strict ladder: (1) the widow(er) living in the same
  household at death; (2) otherwise a widow(er) entitled to benefits on the
  decedent's record for the month of death; (3) otherwise each person
  entitled to child's insurance benefits on that record for that month,
  sharing equally; (4) otherwise nobody. The estate is not on the ladder and
  cannot be paid — `Ssa.payee_ne_estate`.
* **Deadline.** §402(i) itself: no payment "unless an application therefor
  shall have been filed … prior to the expiration of two years after the
  date of death". Two *years*, not 730 days — see `SimpleProbate.Fed.Days`.

Rung (3) turns on entitlement to child's insurance benefits under §402(d),
not on the probate relationship label: the two do not coincide (a
step-grandchild can be entitled, an adult child usually is not). This module
therefore never infers that fact from `heirs[i].relationship`.

Concluding that *nobody* is paid means asserting a negative about people,
which the listed heirs alone cannot support. As with `inventory_complete`
for the valuation caps, a negative rung conclusion is gated on the heir list
being known complete — except that a known-absent surviving spouse
(`decedent.surviving_spouse = false`) settles the two spouse rungs on its own.
-/

namespace SimpleProbate
namespace Fed
namespace Ssa

/-! ## Facts -/

/-- JSON path for a field of heir `index` in the contract's `IntakeCase`. -/
def heirFact (index : Nat) (field : String) : FactPath :=
  s!"heirs[{index}].{field}"

def fieldRelationship : String := "relationship"
def fieldSameHousehold : String := "lived_in_same_household_at_death"
def fieldSpouseBenefits : String := "entitled_to_spouse_benefits_month_of_death"
def fieldChildBenefits : String := "entitled_to_child_benefits_month_of_death"

/-- `decedent.death_date` and `decedent.surviving_spouse` are already in
`IntakeCase`; the other two are additions this module needs. -/
def factDeathDate : FactPath := "decedent.death_date"
def factSurvivingSpouse : FactPath := "decedent.surviving_spouse"
def factInsured : FactPath := "decedent.ssa_insured_at_death"
def factHeirsComplete : FactPath := "heirs_complete"
/-- The heir array itself: named when the intake reports a surviving spouse
who is not among the listed heirs. -/
def factHeirs : FactPath := "heirs"

/-- The decedent's relation to a claimant, as the contract records it.
`parent`, `sibling` and `other` all map to `otherRelation`: only `spouse`
carries statutory weight, and rung (3) does not consult this field at all. -/
inductive Relationship
  | spouse
  | child
  | otherRelation
deriving BEq, DecidableEq, Repr

/-- One potential claimant, mirroring `heirs[i]` with the three federal facts
the ladder needs. `index` is the position in the contract's `heirs[]` array
and is used only to build fact paths. -/
structure Claimant where
  index : Nat
  relationship : Option Relationship := none
  livedInSameHouseholdAtDeath : Option Bool := none
  entitledToSpouseBenefitsMonthOfDeath : Option Bool := none
  entitledToChildBenefitsMonthOfDeath : Option Bool := none
deriving BEq, DecidableEq, Repr

/-- A partially known case. `asOfDate` is required by the contract, so it is
not optional here; everything else may be unknown. -/
structure Facts where
  asOfDate : CivilDate
  deathDate : Option CivilDate := none
  insuredAtDeath : Option Bool := none
  survivingSpouse : Option Bool := none
  heirsComplete : Option Bool := none
  claimants : List Claimant := []
deriving BEq, DecidableEq, Repr

/-- The flat statutory payment, in cents. 42 U.S.C. §402(i). -/
def lumpSumAmountCents : Money := 25_500

/-- The claim period, in years, from the date of death. 42 U.S.C. §402(i). -/
def claimPeriodYears : Nat := 2

/-! ## Prop layer (total facts)

The three rungs as predicates over a claimant whose facts are all known, and
payability and priority as predicates over a case whose claimant list is
complete. -/

structure TotalClaimant where
  relationship : Relationship
  livedInSameHouseholdAtDeath : Bool
  entitledToSpouseBenefitsMonthOfDeath : Bool
  entitledToChildBenefitsMonthOfDeath : Bool
deriving BEq, DecidableEq, Repr

structure TotalCase where
  insuredAtDeath : Bool
  deathDate : CivilDate
  asOfDate : CivilDate
  /-- Every person who could claim; a total case has no unlisted heirs. -/
  claimants : List TotalClaimant
deriving BEq, DecidableEq, Repr

/-- §402(i)(1) — the widow(er) living in the same household at death. -/
def Rung1 (h : TotalClaimant) : Prop :=
  h.relationship = .spouse ∧ h.livedInSameHouseholdAtDeath = true

/-- §402(i)(2) — the widow(er) entitled to benefits on the decedent's record
for the month of death. -/
def Rung2 (h : TotalClaimant) : Prop :=
  h.relationship = .spouse ∧ h.entitledToSpouseBenefitsMonthOfDeath = true

/-- §402(i)(3) — entitlement to child's insurance benefits on the decedent's
record for the month of death. Relationship is not a separate requirement. -/
def Rung3 (h : TotalClaimant) : Prop :=
  h.entitledToChildBenefitsMonthOfDeath = true

instance (h : TotalClaimant) : Decidable (Rung1 h) := by unfold Rung1; infer_instance
instance (h : TotalClaimant) : Decidable (Rung2 h) := by unfold Rung2; infer_instance
instance (h : TotalClaimant) : Decidable (Rung3 h) := by unfold Rung3; infer_instance

def Insured (c : TotalCase) : Prop := c.insuredAtDeath = true

/-- The application is timely: the as-of date has not passed the second
anniversary of the death. -/
def TimelyClaim (c : TotalCase) : Prop :=
  c.asOfDate.atMost (plusYears c.deathDate claimPeriodYears) = true

def SomeoneOnLadder (c : TotalCase) : Prop :=
  (∃ h ∈ c.claimants, Rung1 h) ∨
  (∃ h ∈ c.claimants, Rung2 h) ∨
  (∃ h ∈ c.claimants, Rung3 h)

/-- The lump-sum death payment is payable. -/
def Payable (c : TotalCase) : Prop :=
  Insured c ∧ TimelyClaim c ∧ SomeoneOnLadder c

/-- Who takes, by the statutory priority. `estate` is `False` by
construction: §402(i) does not name the estate. -/
def PayeeIs (c : TotalCase) : FederalPayee → Prop
  | .survivingSpouse =>
    (∃ h ∈ c.claimants, Rung1 h) ∨ (∃ h ∈ c.claimants, Rung2 h)
  | .child =>
    ¬ (∃ h ∈ c.claimants, Rung1 h) ∧
    ¬ (∃ h ∈ c.claimants, Rung2 h) ∧
    (∃ h ∈ c.claimants, Rung3 h)
  | .nobody => ¬ SomeoneOnLadder c
  | .estate => False

instance (c : TotalCase) : Decidable (Insured c) := by unfold Insured; infer_instance
instance (c : TotalCase) : Decidable (TimelyClaim c) := by
  unfold TimelyClaim; infer_instance
instance (c : TotalCase) : Decidable (SomeoneOnLadder c) := by
  unfold SomeoneOnLadder; infer_instance
instance (c : TotalCase) : Decidable (Payable c) := by unfold Payable; infer_instance
instance (c : TotalCase) (p : FederalPayee) : Decidable (PayeeIs c p) := by
  cases p <;> simp only [PayeeIs] <;> infer_instance

/-- Every fact of a total claimant, known, at heir position `index`. -/
def TotalClaimant.toClaimant (h : TotalClaimant) (index : Nat) : Claimant :=
  { index := index
    relationship := some h.relationship
    livedInSameHouseholdAtDeath := some h.livedInSameHouseholdAtDeath
    entitledToSpouseBenefitsMonthOfDeath := some h.entitledToSpouseBenefitsMonthOfDeath
    entitledToChildBenefitsMonthOfDeath := some h.entitledToChildBenefitsMonthOfDeath }

private def indexFrom (i : Nat) : List TotalClaimant → List Claimant
  | [] => []
  | h :: rest => h.toClaimant i :: indexFrom (i + 1) rest

/-- A total case knows every fact, including that its heir list is complete
and whether a surviving spouse is among the listed claimants. -/
def TotalCase.toFacts (c : TotalCase) : Facts :=
  { asOfDate := c.asOfDate
    deathDate := some c.deathDate
    insuredAtDeath := some c.insuredAtDeath
    survivingSpouse := some (c.claimants.any (fun h => h.relationship == .spouse))
    heirsComplete := some true
    claimants := indexFrom 0 c.claimants }

/-! ## Partial layer -/

/-- Result of testing one claimant against one rung under partial
information. A known-false conjunct is a `miss` even when another conjunct
is unknown; unknown is never a `miss`. -/
private inductive Conjunct
  | hit
  | miss
  | unresolved (facts : List FactPath)
deriving BEq, DecidableEq, Repr

private def Conjunct.and : Conjunct → Conjunct → Conjunct
  | .miss, _ => .miss
  | _, .miss => .miss
  | .unresolved a, .unresolved b => .unresolved (a ++ b)
  | .unresolved a, .hit => .unresolved a
  | .hit, .unresolved b => .unresolved b
  | .hit, .hit => .hit

private def knownTrue (value : Option Bool) (fact : FactPath) : Conjunct :=
  match value with
  | none => .unresolved [fact]
  | some true => .hit
  | some false => .miss

private def isSpouse (h : Claimant) : Conjunct :=
  match h.relationship with
  | none => .unresolved [heirFact h.index fieldRelationship]
  | some .spouse => .hit
  | some _ => .miss

private def rung1 (h : Claimant) : Conjunct :=
  (isSpouse h).and
    (knownTrue h.livedInSameHouseholdAtDeath (heirFact h.index fieldSameHousehold))

private def rung2 (h : Claimant) : Conjunct :=
  (isSpouse h).and
    (knownTrue h.entitledToSpouseBenefitsMonthOfDeath
      (heirFact h.index fieldSpouseBenefits))

private def rung3 (h : Claimant) : Conjunct :=
  knownTrue h.entitledToChildBenefitsMonthOfDeath
    (heirFact h.index fieldChildBenefits)

/-- Outcome of one rung across every listed claimant. `hit` is non-empty by
construction. -/
private inductive RungResult
  | hit (first : Nat) (others : List Nat)
  | allMiss
  | unresolved (facts : List FactPath)
deriving BEq, DecidableEq, Repr

/-- Whether the listed claimants are enough to support a negative conclusion
about a rung, and if not, what would settle it. -/
private inductive Gate
  | allowed
  | blocked (facts : List FactPath)
deriving BEq, DecidableEq, Repr

/-- Evaluate one rung. A claimant known to satisfy it settles the rung even
when another claimant's facts are unknown — a known hit is decisive, and the
ladder does not care which of several people at the same rung is asked about
first. Concluding that *nobody* satisfies the rung requires `missGate`,
which encodes what it takes to rule out an unlisted claimant. -/
private def evalRung
    (claimants : List Claimant) (rung : Claimant → Conjunct)
    (missGate : Gate) : RungResult :=
  let hits := (claimants.filter (fun h => rung h == .hit)).map (·.index)
  match hits with
  | first :: others => .hit first others
  | [] =>
    let facts := claimants.flatMap fun h =>
      match rung h with
      | .unresolved fs => fs
      | _ => []
    if !facts.isEmpty then
      .unresolved facts
    else
      match missGate with
      | .allowed => .allMiss
      | .blocked gateFacts => .unresolved gateFacts

/-- Ruling out a spouse at rungs (1) and (2). A decedent known to have left
no surviving spouse settles both rungs on its own. Otherwise the heir list
must be known complete — and, if the intake reports a surviving spouse, must
actually contain one: nothing negative can be concluded about a person who
is known to exist and is not described. -/
private def spouseMissGate (f : Facts) : Gate :=
  if f.survivingSpouse == some false then
    .allowed
  else if f.heirsComplete == some true then
    if f.survivingSpouse == some true &&
        !f.claimants.any (fun h => h.relationship == some .spouse) then
      .blocked [factHeirs]
    else
      .allowed
  else
    .blocked <|
      (if f.survivingSpouse.isNone then [factSurvivingSpouse] else []) ++
      [factHeirsComplete]

/-- Ruling out an entitled child at rung (3): the heir list must be known
complete. -/
private def childMissGate (heirsComplete : Option Bool) : Gate :=
  if heirsComplete == some true then .allowed else .blocked [factHeirsComplete]

/-- Where the priority ladder lands. -/
inductive Ladder
  | /-- §402(i)(1) — widow(er) in the same household at death. -/
    spouseSameHousehold (heirIndex : Nat)
  | /-- §402(i)(2) — widow(er) entitled on the decedent's record. -/
    spouseEntitled (heirIndex : Nat)
  | /-- §402(i)(3) — entitled children, sharing equally. -/
    entitledChildren (first : Nat) (others : List Nat)
  | /-- No one on the ladder; the payment is not made, and never to the estate. -/
    nobody
  | unresolved (facts : List FactPath)
deriving BEq, DecidableEq, Repr

/-- Walk the ladder in statutory order, stopping at the first rung that is
satisfied and refusing to descend past one that is merely unknown. -/
def ladder (f : Facts) : Ladder :=
  let spouseGate := spouseMissGate f
  match evalRung f.claimants rung1 spouseGate with
  | .hit first _ => .spouseSameHousehold first
  | .unresolved facts => .unresolved facts
  | .allMiss =>
    match evalRung f.claimants rung2 spouseGate with
    | .hit first _ => .spouseEntitled first
    | .unresolved facts => .unresolved facts
    | .allMiss =>
      match evalRung f.claimants rung3 (childMissGate f.heirsComplete) with
      | .hit first others => .entitledChildren first others
      | .unresolved facts => .unresolved facts
      | .allMiss => .nobody

/-- Who is paid, once the ladder has landed. Never the estate. -/
def Ladder.payee : Ladder → Option FederalPayee
  | .spouseSameHousehold _ => some .survivingSpouse
  | .spouseEntitled _ => some .survivingSpouse
  | .entitledChildren _ _ => some .child
  | .nobody => some .nobody
  | .unresolved _ => none

/-- 42 U.S.C. §402(i) names a widow(er) and entitled children and no one
else. The estate is unreachable, whatever the facts. -/
theorem payee_ne_estate (l : Ladder) : l.payee ≠ some .estate := by
  cases l <;> simp [Ladder.payee]

/-! ## Wire report -/

def citations : List Citation :=
  [ { label := "42 U.S.C. §402(i)" },
    { label := "20 C.F.R. §404.621(b)" },
    { label := "SSA POMS RS 00210 (Lump-Sum Death Payment)" } ]

private def insuredCheck (insured : Option Bool) : AtomicResult :=
  match insured with
  | none => .unknown [factInsured]
  | some true => .satisfied
  | some false =>
    .violated (reason "decedent_not_insured"
      "The decedent did not die fully or currently insured, so no lump-sum death payment is payable.")

private def windowCheck (window : ClaimWindow) : AtomicResult :=
  match window with
  | .unknown facts => .unknown facts
  | .stillOpen _ _ => .satisfied
  | .expired deadline days =>
    .violated (reason "claim_window_expired"
      s!"The two-year period to apply ran out on {isoDate deadline}, {days} day(s) ago, so an application filed now is untimely. This does not disturb an application already filed within the period.")

private def ladderCheck (l : Ladder) : AtomicResult :=
  match l with
  | .unresolved facts => .unknown facts
  | .nobody =>
    .violated (reason "no_eligible_claimant"
      "No surviving spouse and no person entitled to child's insurance benefits on the decedent's record qualifies under the statutory priority. The lump-sum death payment is never payable to the estate.")
  | _ => .satisfied

private def ladderReasons : Ladder → List Disqualifier
  | .spouseSameHousehold _ =>
    [reason "spouse_living_in_same_household"
      "The surviving spouse was living in the same household as the decedent at the time of death and takes first priority under §402(i)(1)."]
  | .spouseEntitled _ =>
    [reason "spouse_entitled_on_record"
      "No surviving spouse was living in the same household at death; the surviving spouse entitled to benefits on the decedent's record for the month of death takes under §402(i)(2)."]
  | .entitledChildren _ others =>
    reason "entitled_child_on_record"
      "No surviving spouse qualifies; the payment goes to the person(s) entitled to child's insurance benefits on the decedent's record for the month of death, under §402(i)(3)."
    :: (if others.isEmpty then [] else
        [reason "shared_equally_among_entitled_children"
          "More than one person is entitled for that month, so the payment is divided equally among them."])
  | _ => []

private def amountReason : Disqualifier :=
  reason "statutory_amount"
    "42 U.S.C. §402(i) pays the lesser of three times the decedent's primary insurance amount and $255. The $255 figure is not indexed and has not changed since 1981."

private def windowReason : ClaimWindow → List Disqualifier
  | .stillOpen deadline days =>
    [reason "claim_window_open"
      s!"An application must be filed before the two-year period after the date of death expires, on {isoDate deadline} — {days} day(s) from the as-of date."]
  | _ => []

/-- Structural validation, shared with the assessment entry point. A death
date beyond the source snapshot is a typed error, not a verdict. -/
def validate (f : Facts) : Except CaseError Unit := do
  if !f.asOfDate.valid then
    throw (CaseError.malformedCase
      s!"as_of_date {isoDate f.asOfDate} is not a valid calendar date")
  match f.deathDate with
  | none => pure ()
  | some death =>
    match classifyDeathDate death with
    | .error .invalidDate => throw CaseError.invalidDate
    | .error .afterSnapshot => throw CaseError.afterSnapshot
    | .ok _ =>
      if !death.atMost f.asOfDate then
        throw (CaseError.malformedCase
          s!"as_of_date {isoDate f.asOfDate} precedes decedent.death_date {isoDate death}")

/-- The contract row for the lump-sum death payment.

The three conditions — insured status, a timely claim, and someone on the
ladder — are aggregated by `SimpleProbate.aggregate`, so a known violation
beats an unknown exactly as it does for the state routes: an expired claim
period settles the row even if insured status was never supplied. -/
def report (f : Facts) : Except CaseError FederalReport := do
  validate f
  let window := claimWindow f.deathDate f.asOfDate claimPeriodYears factDeathDate
  let landing := ladder f
  let status := aggregate [insuredCheck f.insuredAtDeath, windowCheck window, ladderCheck landing]
  let base : FederalReport :=
    { item := .ssaLumpSumDeathPayment
      label := FederalItem.label .ssaLumpSumDeathPayment
      citations := citations
      status := .needsInformation }
  pure <|
    match status with
    | .qualifies =>
      { base with
        status := .payable
        payee := landing.payee
        amountCents := some lumpSumAmountCents
        reasons := ladderReasons landing ++ windowReason window ++ [amountReason] }
    | .doesNotQualify reasons =>
      { base with
        status := .notPayable
        payee := some .nobody
        reasons := reasons }
    | .needsInformation facts =>
      { base with
        status := .needsInformation
        missingFacts := facts
        reasons :=
          [reason "lump_sum_undetermined"
            "Whether the lump-sum death payment is payable, and to whom, depends on facts that are not yet known. Unknown is not treated as \"not payable\"."] }

/-! ## Regressions -/

namespace Examples

/-- Died within the snapshot; the canonical fixture's date of death. -/
def death : CivilDate := ⟨2026, 3, 4⟩

/-- Well inside the two-year window (the contract's as-of date). -/
def asOfTimely : CivilDate := ⟨2026, 8, 12⟩

/-- One day past the second anniversary, 2028-03-04. -/
def asOfLate : CivilDate := ⟨2028, 3, 5⟩

def spouseInHousehold : Claimant :=
  { index := 0
    relationship := some .spouse
    livedInSameHouseholdAtDeath := some true
    entitledToSpouseBenefitsMonthOfDeath := some false
    entitledToChildBenefitsMonthOfDeath := some false }

def spouseElsewhereEntitled : Claimant :=
  { index := 0
    relationship := some .spouse
    livedInSameHouseholdAtDeath := some false
    entitledToSpouseBenefitsMonthOfDeath := some true
    entitledToChildBenefitsMonthOfDeath := some false }

def spouseElsewhereNotEntitled : Claimant :=
  { spouseElsewhereEntitled with entitledToSpouseBenefitsMonthOfDeath := some false }

def entitledChild (index : Nat) : Claimant :=
  { index := index
    relationship := some .child
    livedInSameHouseholdAtDeath := some false
    entitledToSpouseBenefitsMonthOfDeath := some false
    entitledToChildBenefitsMonthOfDeath := some true }

def unentitledChild (index : Nat) : Claimant :=
  { entitledChild index with entitledToChildBenefitsMonthOfDeath := some false }

/-- Base case: insured, timely, heir list complete. -/
def base : Facts :=
  { asOfDate := asOfTimely
    deathDate := some death
    insuredAtDeath := some true
    survivingSpouse := some true
    heirsComplete := some true
    claimants := [spouseInHousehold] }

private def statusOf (r : Except CaseError FederalReport) : Option FederalStatus :=
  match r with
  | .ok report => some report.status
  | .error _ => none

private def payeeOf (r : Except CaseError FederalReport) : Option FederalPayee :=
  match r with
  | .ok report => report.payee
  | .error _ => none

private def amountOf (r : Except CaseError FederalReport) : Option Money :=
  match r with
  | .ok report => report.amountCents
  | .error _ => none

private def reasonIdsOf (r : Except CaseError FederalReport) : List String :=
  match r with
  | .ok report => report.reasons.map (·.id)
  | .error _ => []

private def missingOf (r : Except CaseError FederalReport) : List FactPath :=
  match r with
  | .ok report => report.missingFacts
  | .error _ => []

/-! ### Rung 1 — widow(er) in the same household -/

example : ladder base = .spouseSameHousehold 0 := by decide
example : statusOf (report base) = some .payable := by decide
example : payeeOf (report base) = some .survivingSpouse := by decide
example : amountOf (report base) = some 25_500 := by decide
example :
    reasonIdsOf (report base) =
      ["spouse_living_in_same_household", "claim_window_open", "statutory_amount"] := by
  decide

/-! ### Rung 2 — widow(er) entitled on the record, living elsewhere -/

def rung2Case : Facts := { base with claimants := [spouseElsewhereEntitled] }

example : ladder rung2Case = .spouseEntitled 0 := by decide
example : payeeOf (report rung2Case) = some .survivingSpouse := by decide

/-! ### Rung 3 — entitled children, and only once both spouse rungs miss -/

def rung3Case : Facts :=
  { base with claimants := [spouseElsewhereNotEntitled, entitledChild 1] }

example : ladder rung3Case = .entitledChildren 1 [] := by decide
example : payeeOf (report rung3Case) = some .child := by decide
example : amountOf (report rung3Case) = some 25_500 := by decide

-- A spouse in the same household outranks an entitled child.
def rung1BeatsRung3 : Facts :=
  { base with claimants := [entitledChild 0, spouseInHousehold] }

example : ladder rung1BeatsRung3 = .spouseSameHousehold 0 := by decide
example : payeeOf (report rung1BeatsRung3) = some .survivingSpouse := by decide

-- An entitled spouse living elsewhere still outranks an entitled child.
def rung2BeatsRung3 : Facts :=
  { base with claimants := [entitledChild 1, spouseElsewhereEntitled] }

example : ladder rung2BeatsRung3 = .spouseEntitled 0 := by decide

-- Two entitled children share equally; the amount is not doubled.
def twoChildren : Facts :=
  { base with
    survivingSpouse := some false
    claimants := [entitledChild 0, entitledChild 1] }

example : ladder twoChildren = .entitledChildren 0 [1] := by decide
example : amountOf (report twoChildren) = some 25_500 := by decide
example :
    reasonIdsOf (report twoChildren) =
      ["entitled_child_on_record", "shared_equally_among_entitled_children",
       "claim_window_open", "statutory_amount"] := by decide

/-! ### Rung 4 — nobody, and never the estate -/

def nobodyCase : Facts :=
  { base with
    survivingSpouse := some false
    claimants := [unentitledChild 0] }

example : ladder nobodyCase = .nobody := by decide
example : statusOf (report nobodyCase) = some .notPayable := by decide
example : payeeOf (report nobodyCase) = some .nobody := by decide
example : amountOf (report nobodyCase) = none := by decide
example : reasonIdsOf (report nobodyCase) = ["no_eligible_claimant"] := by decide

-- An empty heir list is not a finding of "nobody" unless it is known complete.
example :
    statusOf (report
      { base with
        claimants := []
        survivingSpouse := some false
        heirsComplete := some true }) = some .notPayable := by decide

example :
    missingOf (report
      { base with
        claimants := []
        survivingSpouse := none
        heirsComplete := none }) =
      [factSurvivingSpouse, factHeirsComplete] := by decide

-- Nor is a "complete" heir list that omits a surviving spouse the intake
-- reports: the spouse is known to exist and is not described.
example :
    missingOf (report
      { base with
        claimants := [entitledChild 0]
        survivingSpouse := some true
        heirsComplete := some true }) = [factHeirs] := by decide

-- Known-absent spouse settles the spouse rungs without a complete heir list,
-- but rung 3 still needs one.
example :
    missingOf (report
      { base with
        claimants := []
        survivingSpouse := some false
        heirsComplete := none }) = [factHeirsComplete] := by decide

/-! ### Insured status -/

example :
    statusOf (report { base with insuredAtDeath := some false }) =
      some .notPayable := by decide

example :
    reasonIdsOf (report { base with insuredAtDeath := some false }) =
      ["decedent_not_insured"] := by decide

example :
    missingOf (report { base with insuredAtDeath := none }) = [factInsured] := by
  decide

example :
    statusOf (report { base with insuredAtDeath := none }) =
      some .needsInformation := by decide

/-! ### The two-year deadline, at the boundary

Death 2026-03-04 → the period runs through 2028-03-04. 2028 is a leap year
and 29 February 2028 falls inside the period, so it is 731 days long: a
730-day rule would close it a day early. -/

example : daysBetween death (plusYears death 2) = 731 := by decide

-- Day 730 (2028-03-03) and day 731 (2028-03-04): still payable.
example :
    statusOf (report { base with asOfDate := ⟨2028, 3, 3⟩ }) = some .payable := by
  decide

example :
    statusOf (report { base with asOfDate := ⟨2028, 3, 4⟩ }) = some .payable := by
  decide

-- Day 732 (2028-03-05): the period has expired.
example : statusOf (report { base with asOfDate := asOfLate }) = some .notPayable := by
  decide

example :
    reasonIdsOf (report { base with asOfDate := asOfLate }) =
      ["claim_window_expired"] := by decide

example : payeeOf (report { base with asOfDate := asOfLate }) = some .nobody := by
  decide

-- An expired period is a known violation and beats unknown insured status
-- and an unknown ladder (doctrine 2).
example :
    statusOf (report
      { base with
        asOfDate := asOfLate
        insuredAtDeath := none
        heirsComplete := none
        survivingSpouse := none
        claimants := [] }) = some .notPayable := by decide

-- An unknown date of death leaves the window unknown, never open or closed.
example :
    missingOf (report { base with deathDate := none }) = [factDeathDate] := by decide

/-! ### Unknowns name the deciding fact and never guess -/

example :
    missingOf (report
      { base with claimants := [{ index := 0, relationship := some .spouse }] }) =
      [heirFact 0 fieldSameHousehold] := by decide

-- Rung 1 unknown blocks descent to rung 2, even with an entitled child
-- standing by: the ladder does not skip a rung it cannot resolve.
example :
    missingOf (report
      { base with
        claimants := [{ index := 0, relationship := some .spouse }, entitledChild 1] }) =
      [heirFact 0 fieldSameHousehold] := by decide

-- A known hit at rung 1 settles it even though another claimant is unknown.
example :
    ladder { base with claimants := [spouseInHousehold, { index := 1 }] } =
      .spouseSameHousehold 0 := by decide

-- An unknown relationship is not "not a spouse".
example :
    missingOf (report
      { base with
        survivingSpouse := none
        claimants := [{ index := 0, livedInSameHouseholdAtDeath := some true }] }) =
      [heirFact 0 fieldRelationship] := by decide

/-! ### Structural errors are not verdicts -/

example :
    report { base with deathDate := some ⟨2027, 1, 2⟩ } =
      .error .afterSnapshot := by decide

example :
    report { base with deathDate := some ⟨2026, 2, 30⟩ } =
      .error .invalidDate := by decide

example :
    report { base with asOfDate := ⟨2026, 3, 3⟩ } =
      .error (.malformedCase
        "as_of_date 2026-03-03 precedes decedent.death_date 2026-03-04") := by
  decide

example :
    report { base with asOfDate := ⟨2026, 13, 1⟩ } =
      .error (.malformedCase
        "as_of_date 2026-13-01 is not a valid calendar date") := by decide

/-! ### Agreement with the Prop layer

Every total single-claimant case — `24` claimant shapes × insured/uninsured ×
timely/untimely — is checked against `Payable`, against `PayeeIs`, and for
decisiveness. Priority between claimants is then checked on every ordered
pair drawn from a representative pool. -/

private def allRelationships : List Relationship := [.spouse, .child, .otherRelation]
private def allBools : List Bool := [true, false]

def allTotalClaimants : List TotalClaimant :=
  allRelationships.flatMap fun relationship =>
  allBools.flatMap fun sameHousehold =>
  allBools.flatMap fun spouseBenefits =>
  allBools.map fun childBenefits =>
    { relationship := relationship
      livedInSameHouseholdAtDeath := sameHousehold
      entitledToSpouseBenefitsMonthOfDeath := spouseBenefits
      entitledToChildBenefitsMonthOfDeath := childBenefits }

example : allTotalClaimants.length = 24 := by decide

def singleClaimantCases : List TotalCase :=
  allBools.flatMap fun insured =>
  [asOfTimely, asOfLate].flatMap fun asOf =>
  allTotalClaimants.map fun h =>
    { insuredAtDeath := insured
      deathDate := death
      asOfDate := asOf
      claimants := [h] }

/-- A pool spanning every rung plus a claimant on none of them. -/
def priorityPool : List TotalClaimant := [
  { relationship := .spouse, livedInSameHouseholdAtDeath := true
    entitledToSpouseBenefitsMonthOfDeath := false
    entitledToChildBenefitsMonthOfDeath := false },
  { relationship := .spouse, livedInSameHouseholdAtDeath := false
    entitledToSpouseBenefitsMonthOfDeath := true
    entitledToChildBenefitsMonthOfDeath := false },
  { relationship := .spouse, livedInSameHouseholdAtDeath := false
    entitledToSpouseBenefitsMonthOfDeath := false
    entitledToChildBenefitsMonthOfDeath := false },
  { relationship := .child, livedInSameHouseholdAtDeath := false
    entitledToSpouseBenefitsMonthOfDeath := false
    entitledToChildBenefitsMonthOfDeath := true },
  { relationship := .child, livedInSameHouseholdAtDeath := false
    entitledToSpouseBenefitsMonthOfDeath := false
    entitledToChildBenefitsMonthOfDeath := false },
  { relationship := .otherRelation, livedInSameHouseholdAtDeath := false
    entitledToSpouseBenefitsMonthOfDeath := false
    entitledToChildBenefitsMonthOfDeath := true }
]

def priorityCases : List TotalCase :=
  priorityPool.flatMap fun a =>
  priorityPool.map fun b =>
    { insuredAtDeath := true, deathDate := death, asOfDate := asOfTimely
      claimants := [a, b] }

def totalCases : List TotalCase := singleClaimantCases ++ priorityCases

-- The enumerated regressions below evaluate a few hundred reports inside the
-- kernel; the default unfolding budget is not sized for that.
set_option maxRecDepth 100000

example : totalCases.length = 132 := by decide

/-- **Payability is exact on total facts.** -/
theorem payable_exact :
    totalCases.all (fun c =>
      (statusOf (report c.toFacts) == some .payable) == decide (Payable c)) = true := by
  decide

/-- **Total facts are always decisive** — never `needs_information`. -/
theorem total_decisive :
    totalCases.all (fun c =>
      statusOf (report c.toFacts) != some .needsInformation) = true := by decide

/-- **The reported payee is the statutory payee** whenever the payment is
payable. -/
theorem payee_exact :
    totalCases.all (fun c =>
      statusOf (report c.toFacts) != some .payable ||
      (match payeeOf (report c.toFacts) with
       | none => false
       | some p => decide (PayeeIs c p))) = true := by decide

/-- **The estate is never the payee**, on any input. -/
theorem never_estate :
    totalCases.all (fun c => payeeOf (report c.toFacts) != some .estate) = true := by
  decide

/-- Every emitted report satisfies the contract's shape invariants. -/
theorem report_wellFormed :
    totalCases.all (fun c =>
      match report c.toFacts with
      | .ok r => r.wellFormed
      | .error _ => false) = true := by decide

end Examples

end Ssa
end Fed
end SimpleProbate
