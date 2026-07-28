# Exact Partial-Information Probate API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Lean API that exactly classifies every supported simplified probate route, distinguishes known disqualification from missing information, reports packet gaps, and proves the executable results correct.

**Architecture:** Independent `Prop`-valued route and readiness specifications remain normative. A generic three-valued decision layer evaluates typed atomic checks over partial cases; total cases are completions with no unknown fields, and proofs connect executable reports to the independent specifications. Estate valuation is corrected before route and packet assessment are layered on top.

**Tech Stack:** Lean 4.32.1, Lean standard library, Lake, dependency-free theorem examples.

## Global Constraints

- Keep the source snapshot at July 28, 2026.
- Support death dates only through December 31, 2026.
- Represent money as natural-number U.S. cents.
- Keep the project dependency-free on Lean 4.32.1.
- Keep the deliverable a Lean API; do not add an interactive questionnaire.
- Evaluate every simplified route independently; do not select a preferred route.
- Recommend `formalProbateOrOtherProcedure` only when every simplified route is conclusively disqualified.
- Treat unknown facts as unknown, never as false.
- Return known invalid dates and malformed structures as typed errors, not legal disqualifications.
- Use current gross fair market value for section 13101 eligibility and date-of-death value for section 8802 inventory/appraisal routes.
- Apply the section 13050(c)(2) employment-compensation exclusion once to aggregate qualifying compensation.
- Require the section 13200 will attachment only when claiming under a will and no California estate proceeding is pending or has been conducted.
- Do not add `sorry`, `admit`, `axiom`, or `unsafe`.
- Treat the model as educational and theorem-backed, not as legal advice or proof that supplied facts are true.
- Run `lake build` as the authoritative full verification command.

---

## File Structure

### New production files

- `SimpleProbate/Decision.lean` — generic `Knowledge`, atomic check results, three-valued aggregation, deduplicated diagnostics, and aggregation theorems.
- `SimpleProbate/Case.lean` — asset-ID-based total and partial cases, completion relations, structural issues, validation, and conversion from total to partial inputs.
- `SimpleProbate/ProcedureAssessment.lean` — route-indexed partial packets, partial procedure context, readiness reports, assessment, and partial-packet proof contracts.

### New theorem-example files

- `SimpleProbate/Examples/Fixtures.lean` — shared total cases, procedure contexts, and complete packet fixtures with no imports back to the example aggregator.
- `SimpleProbate/Examples/Decision.lean` — decision aggregation truth table and diagnostic-order regressions.
- `SimpleProbate/Examples/Valuation.lean` — corrected current/date-of-death valuation and aggregate compensation regressions.
- `SimpleProbate/Examples/Case.lean` — partial completion and structural validation regressions.
- `SimpleProbate/Examples/EligibilityAssessment.lean` — total exactness, partial outcomes, and fallback regressions.
- `SimpleProbate/Examples/ProcedureExactness.lean` — total missing-list/readiness equivalence and section 13200(d) regressions.
- `SimpleProbate/Examples/ProcedureAssessment.lean` — partial packet unknown/absent/ready regressions.

### Existing files to modify

- `SimpleProbate/Estate.lean` — add asset IDs and dual values; correct aggregate compensation; add partial valuation bounds.
- `SimpleProbate/Eligibility.lean` — move case structures to `Case`, retain independent predicates, add typed eligibility checks and exact/partial route reports.
- `SimpleProbate/Procedure.lean` — correct will applicability; add `CourtRoute`; prove total missing-list/readiness equivalence.
- `SimpleProbate/Examples.lean` — migrate existing examples to asset IDs and dual values; import focused example modules.
- `SimpleProbate.lean` — expose new public modules.
- `README.md` — document exact and partial APIs, valuation meanings, results, and proof guarantees.
- `Main.lean` — retain the informational executable output; no behavior change beyond imports if required.

## Scope Check

This remains one implementation plan because the decision core, estate bounds,
route assessment, and packet assessment form one dependency chain and share
the same completion relation. None is a useful standalone product without the
preceding layer. Each task nevertheless ends with an independently compiling,
reviewable deliverable.

---

### Task 1: Generic Three-Valued Decision Core

**Files:**
- Create: `SimpleProbate/Decision.lean`
- Create: `SimpleProbate/Examples/Decision.lean`
- Modify: `SimpleProbate.lean`

**Interfaces:**
- Consumes: Lean `List`, `BEq`, and `LawfulBEq`.
- Produces:
  - `Knowledge α`
  - `Knowledge.Completes : Knowledge α → α → Prop`
  - `CheckResult fact reason`
  - `DecisionStatus fact reason`
  - `aggregateChecks : List (CheckResult fact reason) → DecisionStatus fact reason`
  - aggregation truth-table and nonempty-diagnostic theorems.

- [ ] **Step 1: Write the failing decision truth-table examples**

Create `SimpleProbate/Examples/Decision.lean`:

```lean
import SimpleProbate.Decision

namespace SimpleProbate.Examples.Decision

open SimpleProbate

inductive TestFact
  | deathDate
  | estateValue
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive TestFailure
  | tooSoon
  | overCap
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

example :
    aggregateChecks
      ([.satisfied, .satisfied] :
        List (CheckResult TestFact TestFailure)) =
      .qualifies := by decide

example :
    aggregateChecks
      ([.unknown .deathDate, .unknown .estateValue, .satisfied,
        .unknown .deathDate] :
        List (CheckResult TestFact TestFailure)) =
      .needsInformation [.deathDate, .estateValue] := by decide

example :
    aggregateChecks
      ([.unknown .estateValue, .violated .tooSoon,
        .violated .overCap, .violated .tooSoon] :
        List (CheckResult TestFact TestFailure)) =
      .doesNotQualify [.tooSoon, .overCap] := by decide

example : Knowledge.unknown.Completes (true : Bool) := by trivial
example : (Knowledge.known true).Completes true := by rfl
example : ¬(Knowledge.known false).Completes true := by decide

end SimpleProbate.Examples.Decision
```

- [ ] **Step 2: Run the focused check and confirm the module is missing**

Run:

```bash
lake env lean SimpleProbate/Examples/Decision.lean
```

Expected: failure reporting that `SimpleProbate.Decision` does not exist.

- [ ] **Step 3: Implement the generic types and aggregator**

Create `SimpleProbate/Decision.lean` with these public definitions:

```lean
import Std

namespace SimpleProbate

inductive Knowledge (α : Type)
  | unknown
  | known (value : α)
deriving DecidableEq, Repr

namespace Knowledge

def Completes : Knowledge α → α → Prop
  | .unknown, _ => True
  | .known expected, actual => expected = actual

instance [DecidableEq α] (knowledge : Knowledge α) (value : α) :
    Decidable (knowledge.Completes value) := by
  cases knowledge <;> simp [Completes] <;> infer_instance

def ofValue (value : α) : Knowledge α := .known value

end Knowledge

inductive CheckResult (fact reason : Type)
  | satisfied
  | violated (reason : reason)
  | unknown (fact : fact)
deriving DecidableEq, Repr

inductive DecisionStatus (fact reason : Type)
  | qualifies
  | doesNotQualify (reasons : List reason)
  | needsInformation (facts : List fact)
deriving DecidableEq, Repr

private def violatedReasons :
    List (CheckResult fact reason) → List reason
  | [] => []
  | .violated reason :: rest => reason :: violatedReasons rest
  | _ :: rest => violatedReasons rest

private def unknownFacts :
    List (CheckResult fact reason) → List fact
  | [] => []
  | .unknown fact :: rest => fact :: unknownFacts rest
  | _ :: rest => unknownFacts rest

def dedupStable [BEq α] (values : List α) : List α :=
  values.foldl
    (fun result value =>
      if result.contains value then result else result ++ [value]) []

def aggregateChecks
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    (checks : List (CheckResult fact reason)) :
    DecisionStatus fact reason :=
  match dedupStable (violatedReasons checks) with
  | reason :: reasons => .doesNotQualify (reason :: reasons)
  | [] =>
      match dedupStable (unknownFacts checks) with
      | fact :: facts => .needsInformation (fact :: facts)
      | [] => .qualifies

end SimpleProbate
```

- [ ] **Step 4: Add aggregation proof contracts**

First prove stable deduplication preserves membership and produces no
duplicates:

```lean
private theorem mem_dedupStable_fold
    [BEq α] [LawfulBEq α]
    (value : α) (values result : List α) :
    value ∈ values.foldl
      (fun current candidate =>
        if current.contains candidate
        then current
        else current ++ [candidate]) result ↔
      value ∈ result ∨ value ∈ values := by
  induction values generalizing result with
  | nil => simp
  | cons head tail ih =>
      simp only [List.foldl]
      rw [ih]
      by_cases present : result.contains head
      · simp_all
      · simp_all

theorem mem_dedupStable
    [BEq α] [LawfulBEq α] (value : α) (values : List α) :
    value ∈ dedupStable values ↔ value ∈ values := by
  simpa [dedupStable] using
    mem_dedupStable_fold value values []

theorem dedupStable_nodup
    [BEq α] [LawfulBEq α] (values : List α) :
    (dedupStable values).Nodup := by
  unfold dedupStable
  induction values using List.reverseRecOn <;> simp_all
```

If `List.reverseRecOn` does not simplify the fold on the installed Lean
version, prove the same `dedupStable_nodup` statement with a generalized
fold-accumulator invariant: an initially `Nodup` accumulator remains `Nodup`
after each step.

Append the following aggregation theorem signatures and prove them by induction over
`checks`, splitting each `CheckResult` constructor and simplifying
`aggregateChecks`, `violatedReasons`, and `unknownFacts`:

```lean
theorem aggregateChecks_qualifies_iff
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    (checks : List (CheckResult fact reason)) :
    aggregateChecks checks = .qualifies ↔
      ∀ check ∈ checks, check = .satisfied := by
  induction checks with
  | nil => simp [aggregateChecks, violatedReasons, unknownFacts]
  | cons check rest ih =>
      cases check <;>
        simp_all [aggregateChecks, violatedReasons, unknownFacts]

theorem aggregateChecks_disqualified_nonempty
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    {checks : List (CheckResult fact reason)} {reasons : List reason}
    (result : aggregateChecks checks = .doesNotQualify reasons) :
    reasons ≠ [] := by
  unfold aggregateChecks at result
  split at result <;> simp_all

theorem aggregateChecks_information_nonempty
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    {checks : List (CheckResult fact reason)} {facts : List fact}
    (result : aggregateChecks checks = .needsInformation facts) :
    facts ≠ [] := by
  unfold aggregateChecks at result
  split at result <;> simp_all

theorem mem_disqualifier_of_aggregate
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    {checks : List (CheckResult fact reason)} {reasons : List reason}
    (result : aggregateChecks checks = .doesNotQualify reasons)
    (reason : reason) :
    reason ∈ reasons ↔ .violated reason ∈ checks := by
  unfold aggregateChecks at result
  cases reasonsResult : dedupStable (violatedReasons checks) with
  | nil => simp_all
  | cons head tail =>
      injection result with result
      subst reasons
      simp [violatedReasons, mem_dedupStable]

theorem mem_requiredFact_of_aggregate
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    {checks : List (CheckResult fact reason)} {facts : List fact}
    (result : aggregateChecks checks = .needsInformation facts)
    (fact : fact) :
    fact ∈ facts ↔ .unknown fact ∈ checks := by
  unfold aggregateChecks at result
  cases reasonsResult : dedupStable (violatedReasons checks) with
  | cons head tail => simp_all
  | nil =>
      cases factsResult : dedupStable (unknownFacts checks) with
      | nil => simp_all
      | cons head tail =>
          injection result with result
          subst facts
          simp [unknownFacts, mem_dedupStable]
```

If Lean's generated split names differ, preserve these theorem statements and
use `cases reasonsResult : dedupStable (violatedReasons checks)` followed by
`cases factsResult : dedupStable (unknownFacts checks)`; do not weaken the
statements.

- [ ] **Step 5: Expose and verify the module**

Add these imports to `SimpleProbate.lean` before the estate and eligibility
modules:

```lean
import SimpleProbate.Decision
```

Run:

```bash
lake env lean SimpleProbate/Decision.lean
lake env lean SimpleProbate/Examples/Decision.lean
lake build
```

Expected: all commands succeed; the full build continues to compile the
baseline implementation.

- [ ] **Step 6: Commit the decision core**

```bash
git add SimpleProbate/Decision.lean SimpleProbate/Examples/Decision.lean SimpleProbate.lean
git commit -m "feat: add three-valued decision core"
```

---

### Task 2: Correct Estate Values and Employment Aggregation

**Files:**
- Modify: `SimpleProbate/Estate.lean` (current `Asset` and valuation definitions, lines 22–105)
- Modify: `SimpleProbate/Eligibility.lean` (field references only)
- Modify: `SimpleProbate/Examples.lean` (existing asset fixtures)
- Create: `SimpleProbate/Examples/Valuation.lean`

**Interfaces:**
- Consumes:
  - `Money`
  - `Thresholds`
  - existing property kinds and valuation treatments.
- Produces:
  - `AssetId`
  - `AssetField`
  - `Asset.currentGrossValue`
  - `Asset.dateOfDeathValue`
  - `PartialAsset`
  - `PartialEstate`
  - `Estate.aggregateEmploymentCompensation`
  - corrected `Estate.personalAffidavitValue`
  - date-of-death `smallValueRealPropertyValue` and
    `primaryResidenceValue`
  - valuation invariance theorem statements used by Tasks 4 and 5.

- [ ] **Step 1: Write failing dual-value and aggregate-compensation examples**

Create `SimpleProbate/Examples/Valuation.lean`:

```lean
import SimpleProbate.Estate

namespace SimpleProbate.Examples.Valuation

open SimpleProbate

def salary (id : Nat) (current atDeath : Money) : Asset := {
  id := ⟨id⟩
  name := s!"salary-{id}"
  kind := .personal
  currentGrossValue := current
  dateOfDeathValue := atDeath
  treatment := .employmentCompensation
}

def realProperty
    (id : Nat) (current atDeath : Money) (primary : Bool) : Asset := {
  id := ⟨id⟩
  name := s!"real-{id}"
  kind := .californiaReal
  currentGrossValue := current
  dateOfDeathValue := atDeath
  treatment := .counted
  isPrimaryResidence := primary
}

example :
    ({ assets := [
      salary 1 (Money.dollars 15_000) (Money.dollars 12_000),
      salary 2 (Money.dollars 15_000) (Money.dollars 13_000)
    ] } : Estate).personalAffidavitValue ⟨2026, 1, 1⟩ =
      .ok (Money.dollars 9_125) := by decide

example :
    ({ assets := [
      salary 1 (Money.dollars 30_000) (Money.dollars 25_000)
    ] } : Estate).personalAffidavitValue ⟨2026, 1, 1⟩ =
      .ok (Money.dollars 9_125) := by decide

example :
    ({ assets := [
      realProperty 3 (Money.dollars 900_000)
        (Money.dollars 700_000) true
    ] } : Estate).primaryResidenceValue =
      Money.dollars 700_000 := by decide

example :
    ({ assets := [
      realProperty 4 (Money.dollars 80_000)
        (Money.dollars 60_000) false
    ] } : Estate).smallValueRealPropertyValue =
      Money.dollars 60_000 := by decide

end SimpleProbate.Examples.Valuation
```

The first two examples are intentionally equal: splitting one $30,000
compensation obligation into two assets must not double the $20,875 exclusion.

- [ ] **Step 2: Run the examples and verify field/constructor failures**

Run:

```bash
lake env lean SimpleProbate/Examples/Valuation.lean
```

Expected: failure because `AssetId`, `currentGrossValue`, and
`dateOfDeathValue` do not exist.

- [ ] **Step 3: Replace the ambiguous asset value with explicit values**

In `SimpleProbate/Estate.lean`, define:

```lean
import SimpleProbate.Decision
import SimpleProbate.Thresholds

structure AssetId where
  value : Nat
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive AssetField
  | kind
  | currentGrossValue
  | dateOfDeathValue
  | treatment
  | primaryResidence
  | primaryPetitionInclusion
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure Asset where
  id : AssetId
  name : String
  kind : PropertyKind
  currentGrossValue : Money
  dateOfDeathValue : Money
  encumbrances : Money := 0
  treatment : ValuationTreatment := .counted
  includedInPrimaryResidencePetition : Bool := false
  isPrimaryResidence : Bool := false
deriving DecidableEq, Repr

structure PartialAsset where
  id : AssetId
  name : String
  kind : Knowledge PropertyKind
  currentGrossValue : Knowledge Money
  dateOfDeathValue : Knowledge Money
  encumbrances : Knowledge Money
  treatment : Knowledge ValuationTreatment
  includedInPrimaryResidencePetition : Knowledge Bool
  isPrimaryResidence : Knowledge Bool
deriving DecidableEq, Repr

structure PartialEstate where
  assets : List PartialAsset
  inventoryComplete : Knowledge Bool
deriving DecidableEq, Repr
```

Migrate every existing asset fixture:

- assign deterministic IDs in source order;
- set both new value fields to the old `grossValue` unless a regression
  intentionally distinguishes valuation times; and
- when a structure update changes a value, update both fields unless the
  example is explicitly about one valuation time.

For example, replace:

```lean
grossValue := Money.dollars 69_625
```

with:

```lean
currentGrossValue := Money.dollars 69_625
dateOfDeathValue := Money.dollars 69_625
```

- [ ] **Step 4: Implement aggregate compensation and route-specific values**

Replace the per-asset employment deduction with:

```lean
def Asset.personalOrdinaryValue (asset : Asset) : Money :=
  if asset.kind == .outsideCaliforniaReal ||
      asset.includedInPrimaryResidencePetition then
    0
  else
    match asset.treatment with
    | .counted => asset.currentGrossValue
    | _ => 0

def Asset.qualifyingEmploymentCompensation (asset : Asset) : Money :=
  if asset.kind == .outsideCaliforniaReal ||
      asset.includedInPrimaryResidencePetition then
    0
  else if asset.treatment == .employmentCompensation then
    asset.currentGrossValue
  else
    0

def Estate.aggregateEmploymentCompensation (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset =>
      total + asset.qualifyingEmploymentCompensation) 0

def Estate.personalAffidavitValueWith
    (estate : Estate) (thresholds : Thresholds) : Money :=
  let ordinary := estate.assets.foldl
    (fun total asset => total + asset.personalOrdinaryValue) 0
  let employment := estate.aggregateEmploymentCompensation
  ordinary +
    (employment -
      min employment thresholds.employmentCompensationExclusion)

def Estate.personalAffidavitValue
    (estate : Estate) (date : CivilDate) : Except DateError Money := do
  let thresholds ← thresholdsFor date
  pure <| estate.personalAffidavitValueWith thresholds
```

Change `countedCaliforniaRealValue` and
`countedPrimaryResidenceValue` to return `asset.dateOfDeathValue`. Do not use
`currentGrossValue` for those two functions.

- [ ] **Step 5: Add valuation theorem contracts**

Add and prove:

```lean
def theoremEmploymentAsset (id : Nat) (value : Money) : Asset := {
  id := ⟨id⟩
  name := s!"employment-{id}"
  kind := .personal
  currentGrossValue := value
  dateOfDeathValue := value
  treatment := .employmentCompensation
}

theorem aggregateEmployment_split_invariant
    (thresholds : Thresholds) (left right : Money) :
    ({ assets := [
      theoremEmploymentAsset 1 left,
      theoremEmploymentAsset 2 right
    ] } : Estate).personalAffidavitValueWith thresholds =
    ({ assets := [
      theoremEmploymentAsset 1 (left + right)
    ] } : Estate).personalAffidavitValueWith thresholds := by
  simp [Estate.personalAffidavitValueWith,
    Estate.aggregateEmploymentCompensation,
    Asset.personalOrdinaryValue,
    Asset.qualifyingEmploymentCompensation,
    theoremEmploymentAsset, Nat.add_assoc]

theorem personalAffidavitValueWith_ignores_encumbrances
    (estate : Estate) (thresholds : Thresholds) (asset : Asset) :
    ({ assets := asset :: estate.assets } : Estate).personalAffidavitValueWith
        thresholds =
      ({ assets := { asset with encumbrances := 0 } :: estate.assets } :
        Estate).personalAffidavitValueWith thresholds := by
  simp [Estate.personalAffidavitValueWith,
    Estate.aggregateEmploymentCompensation,
    Asset.personalOrdinaryValue,
    Asset.qualifyingEmploymentCompensation]
```

Also retain the two concrete split/combined examples as the regression that
would fail if the cap were applied per asset. Do not substitute a tautological
per-asset theorem for those examples.

- [ ] **Step 6: Run focused and full verification**

Run:

```bash
lake env lean SimpleProbate/Examples/Valuation.lean
lake env lean SimpleProbate/Examples.lean
lake build
```

Expected: all succeed. Existing threshold and route examples must still pass
after their fixtures receive IDs and dual values.

- [ ] **Step 7: Commit corrected valuation**

```bash
git add SimpleProbate/Estate.lean SimpleProbate/Eligibility.lean SimpleProbate/Examples.lean SimpleProbate/Examples/Valuation.lean
git commit -m "fix: formalize route-specific probate values"
```

---

### Task 3: Total and Partial Case Model with Structural Validation

**Files:**
- Modify: `SimpleProbate/Estate.lean` (completion relations and total conversion)
- Create: `SimpleProbate/Case.lean`
- Create: `SimpleProbate/Examples/Case.lean`
- Create: `SimpleProbate/Examples/Fixtures.lean`
- Modify: `SimpleProbate/Eligibility.lean` (move case structures and import `Case`)
- Modify: `SimpleProbate/Examples.lean` (import shared fixtures)
- Modify: `SimpleProbate.lean`

**Interfaces:**
- Consumes:
  - `Knowledge`
  - `CivilDate`
  - total and partial asset/estate types from Task 2.
- Produces:
  - total `TransferCase` using `targetId`
  - `PartialTransferCase`
  - `PartialAsset.Completes`
  - `PartialEstate.Completes`
  - `PartialTransferCase.Completes`
  - `StructuralIssue`
  - `CaseError`
  - `validatePartialCase`
  - `TransferCase.toPartial`.

- [ ] **Step 1: Write failing completion and validation examples**

Create `SimpleProbate/Examples/Case.lean`:

```lean
import SimpleProbate.Case

namespace SimpleProbate.Examples.Case

open SimpleProbate

def knownPersonalAsset : Asset := {
  id := ⟨1⟩
  name := "account"
  kind := .personal
  currentGrossValue := Money.dollars 10_000
  dateOfDeathValue := Money.dollars 10_000
}

def partialKnownPersonal : PartialAsset := {
  id := ⟨1⟩
  name := "account"
  kind := .known .personal
  currentGrossValue := .known (Money.dollars 10_000)
  dateOfDeathValue := .known (Money.dollars 10_000)
  encumbrances := .known 0
  treatment := .known .counted
  includedInPrimaryResidencePetition := .known false
  isPrimaryResidence := .known false
}

example : partialKnownPersonal.Completes knownPersonalAsset := by decide

example :
    ({ assets := [partialKnownPersonal]
       inventoryComplete := .known true } : PartialEstate).Completes
      { assets := [knownPersonalAsset] } := by decide

example :
    ¬({ assets := [partialKnownPersonal]
        inventoryComplete := .known true } : PartialEstate).Completes
      { assets := [
        knownPersonalAsset,
        { knownPersonalAsset with id := ⟨2⟩ }
      ] } := by decide

def malformedPrimary : PartialTransferCase := {
  deathDate := .known ⟨2026, 1, 1⟩
  estate := {
    assets := [{
      partialKnownPersonal with
      isPrimaryResidence := .known true
    }]
    inventoryComplete := .known true
  }
  targetId := .known ⟨1⟩
  authority := .known .noProceeding
  daysSinceDeath := .known 40
  sixMonthsElapsed := .known false
  claimantIsSuccessor := .known true
  noSuperiorRight := .known true
  funeralLastIllnessAndUnsecuredDebtsPaid := .known true
  survivorStatus := .known .none
  propertyPassesToSurvivor := .known false
  propertyBelongsToSurvivor := .known false
}

example :
    validatePartialCase malformedPrimary =
      .error (.malformedCase [.primaryResidenceNotCaliforniaReal ⟨1⟩]) := by
  decide

def duplicateIds : PartialTransferCase := {
  malformedPrimary with
  estate := {
    assets := [
      partialKnownPersonal,
      { partialKnownPersonal with name := "duplicate" }
    ]
    inventoryComplete := .known true
  }
}

example :
    validatePartialCase duplicateIds =
      .error (.malformedCase [.duplicateAssetId ⟨1⟩]) := by decide

end SimpleProbate.Examples.Case
```

- [ ] **Step 2: Run the focused check and confirm missing case types**

Run:

```bash
lake env lean SimpleProbate/Examples/Case.lean
```

Expected: failure because `SimpleProbate.Case`, partial structures, and
validation do not exist.

- [ ] **Step 3: Move shared case enums and define total/partial structures**

Create `SimpleProbate/Case.lean`. Move `SummaryAuthority` and `SurvivorStatus`
from `Eligibility.lean` without changing their constructors. Define:

```lean
import SimpleProbate.Decision
import SimpleProbate.Estate

namespace SimpleProbate

inductive SummaryAuthority
  | noProceeding
  | writtenPersonalRepresentativeConsent
  | blockedByProceeding
deriving BEq, DecidableEq, Repr

inductive SurvivorStatus
  | none
  | spouse
  | registeredDomesticPartner
deriving BEq, DecidableEq, Repr

structure TransferCase where
  deathDate : CivilDate
  estate : Estate
  targetId : AssetId
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

structure PartialTransferCase where
  deathDate : Knowledge CivilDate
  estate : PartialEstate
  targetId : Knowledge AssetId
  authority : Knowledge SummaryAuthority
  daysSinceDeath : Knowledge Nat
  sixMonthsElapsed : Knowledge Bool
  claimantIsSuccessor : Knowledge Bool
  noSuperiorRight : Knowledge Bool
  funeralLastIllnessAndUnsecuredDebtsPaid : Knowledge Bool
  survivorStatus : Knowledge SurvivorStatus
  propertyPassesToSurvivor : Knowledge Bool
  propertyBelongsToSurvivor : Knowledge Bool
deriving DecidableEq, Repr
```

Add:

```lean
def Estate.findAsset? (estate : Estate) (id : AssetId) : Option Asset :=
  estate.assets.find? (fun asset => asset.id == id)

def PartialEstate.findAsset?
    (estate : PartialEstate) (id : AssetId) : Option PartialAsset :=
  estate.assets.find? (fun asset => asset.id == id)
```

Migrate every `TransferCase` fixture from `target := asset` and
`targetIsPartOfEstate := true` to `targetId := asset.id`. Keep the
`malformedEmptyEstateRealCase` regression malformed by assigning its target
ID while leaving the estate empty. Give every supported-date spousal
eligibility fixture a listed `spousalTarget`; do not preserve an empty estate
in a case intended to qualify. Post-snapshot fixtures may remain structurally
malformed because their checked API result is the earlier `afterSnapshot`
error.

- [ ] **Step 4: Implement asset and estate completion semantics**

In `SimpleProbate/Estate.lean`, implement pointwise asset completion:

```lean
def PartialAsset.Completes
    (partial : PartialAsset) (total : Asset) : Prop :=
  partial.id = total.id ∧
  partial.name = total.name ∧
  partial.kind.Completes total.kind ∧
  partial.currentGrossValue.Completes total.currentGrossValue ∧
  partial.dateOfDeathValue.Completes total.dateOfDeathValue ∧
  partial.encumbrances.Completes total.encumbrances ∧
  partial.treatment.Completes total.treatment ∧
  partial.includedInPrimaryResidencePetition.Completes
    total.includedInPrimaryResidencePetition ∧
  partial.isPrimaryResidence.Completes total.isPrimaryResidence
```

Define the listed-assets relation and inventory semantics:

```lean
def PartialEstate.listedAssetsComplete
    (partial : PartialEstate) (total : Estate) : Prop :=
  ∀ partialAsset ∈ partial.assets,
    ∃ totalAsset ∈ total.assets, partialAsset.Completes totalAsset

def PartialEstate.sameAssetIds
    (partial : PartialEstate) (total : Estate) : Prop :=
  ∀ id,
    id ∈ partial.assets.map (·.id) ↔
      id ∈ total.assets.map (·.id)

def PartialEstate.hasAdditionalAsset
    (partial : PartialEstate) (total : Estate) : Prop :=
  ∃ asset ∈ total.assets, asset.id ∉ partial.assets.map (·.id)

def PartialEstate.Completes
    (partial : PartialEstate) (total : Estate) : Prop :=
  partial.listedAssetsComplete total ∧
  match partial.inventoryComplete with
  | .known true => partial.sameAssetIds total
  | .known false => partial.hasAdditionalAsset total
  | .unknown => True
```

Define `PartialTransferCase.Completes` as the conjunction of estate completion
and `Knowledge.Completes` for every remaining field. Provide decidable
instances for the concrete finite structures.

- [ ] **Step 5: Implement exact structural validation**

Define:

```lean
inductive StructuralIssue
  | duplicateAssetId (id : AssetId)
  | missingTargetAsset (id : AssetId)
  | primaryResidenceNotCaliforniaReal (id : AssetId)
  | petitionAssetNotCaliforniaReal (id : AssetId)
  | petitionAssetNotPrimaryResidence (id : AssetId)
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive CaseError
  | invalidDate
  | afterSnapshot
  | malformedCase (issues : List StructuralIssue)
deriving DecidableEq, Repr
```

`validatePartialCase` must:

1. reject a known invalid or post-snapshot date;
2. report each duplicate listed asset ID once;
3. report a missing known target only when `inventoryComplete = .known true`;
4. report `isPrimaryResidence = .known true` combined with a known non-
   California-real kind;
5. report petition inclusion combined with a known non-California-real kind;
6. report petition inclusion combined with `isPrimaryResidence = .known false`;
7. return `.ok ()` for unknown fields rather than treating them as errors.

Use this signature:

```lean
def validatePartialCase :
    PartialTransferCase → Except CaseError Unit
```

Map `DateError.invalidDate` and `DateError.afterSnapshot` to the matching
`CaseError` constructors.

- [ ] **Step 6: Add total conversion and well-formedness**

Define `PartialAsset.ofTotal`, `PartialEstate.ofTotal`, and
`TransferCase.toPartial` by wrapping every total field with `.known` and
setting `inventoryComplete := .known true`.

Define:

```lean
def TransferCase.WellFormed (case : TransferCase) : Prop :=
  (case.estate.assets.map (·.id)).Nodup ∧
  (∃ target ∈ case.estate.assets, target.id = case.targetId) ∧
  ∀ asset ∈ case.estate.assets,
    (asset.isPrimaryResidence = true →
      asset.kind = .californiaReal) ∧
    (asset.includedInPrimaryResidencePetition = true →
      asset.kind = .californiaReal ∧
      asset.isPrimaryResidence = true)
```

Prove:

```lean
theorem toPartial_completes (case : TransferCase) :
    case.toPartial.Completes case := by
  simp [TransferCase.toPartial, PartialTransferCase.Completes,
    PartialEstate.ofTotal, PartialEstate.Completes,
    PartialEstate.listedAssetsComplete, PartialEstate.sameAssetIds,
    PartialAsset.ofTotal, PartialAsset.Completes, Knowledge.Completes]
```

- [ ] **Step 7: Extract cycle-free shared example fixtures**

Create `SimpleProbate/Examples/Fixtures.lean`:

```lean
import SimpleProbate.Procedure

namespace SimpleProbate.Examples

open SimpleProbate
```

Relocate these definitions from `SimpleProbate/Examples.lean` into that
namespace without changing their public names:

```text
countedPersonal
personalTarget
personalTargetOverCap
base2026Case
smallRealTarget
smallRealTargetOverCap
smallReal2026Case
primaryResidenceTarget
primaryResidence2026Case
spousalTarget
spouse2026Case
baseProcedureContext
completePersonalPacket
completeSmallRealPacket
completePrimaryResidencePacket
completeSpousalPacket
```

Use this replacement for the former empty-estate spousal fixture so the new
total-case target invariant is satisfied:

```lean
def spousalTarget : Asset := {
  id := ⟨4⟩
  name := "spousal property"
  kind := .personal
  currentGrossValue := Money.dollars 1
  dateOfDeathValue := Money.dollars 1
  treatment := .spousePassage
}

def spouse2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [spousalTarget] }
  targetId := spousalTarget.id
  claimantIsSuccessor := false
  noSuperiorRight := false
  survivorStatus := .spouse
  propertyPassesToSurvivor := true
}
```

Close the namespace with:

```lean
end SimpleProbate.Examples
```

Import the fixture module near the top of `SimpleProbate/Examples.lean`:

```lean
import SimpleProbate.Examples.Fixtures
```

Delete only the relocated duplicate definitions from the aggregator; keep all
existing `example` declarations.

- [ ] **Step 8: Wire imports and verify**

Change `Eligibility.lean` to:

```lean
import SimpleProbate.Case
```

Remove the moved enum and case declarations from `Eligibility.lean`. Add to
`SimpleProbate.lean`:

```lean
import SimpleProbate.Case
```

Run:

```bash
lake env lean SimpleProbate/Case.lean
lake env lean SimpleProbate/Examples/Case.lean
lake env lean SimpleProbate/Examples/Fixtures.lean
lake env lean SimpleProbate/Examples.lean
lake build
```

Expected: all succeed.

- [ ] **Step 9: Commit the case model**

```bash
git add SimpleProbate/Estate.lean SimpleProbate/Case.lean SimpleProbate/Eligibility.lean SimpleProbate/Examples.lean SimpleProbate/Examples/Case.lean SimpleProbate/Examples/Fixtures.lean SimpleProbate.lean
git commit -m "feat: model partial probate cases"
```

---

### Task 4: Typed Eligibility Checks and Exact Total Classification

**Files:**
- Modify: `SimpleProbate/Estate.lean` (partial valuation result)
- Modify: `SimpleProbate/Eligibility.lean` (replace unchecked candidate filter)
- Create: `SimpleProbate/Examples/EligibilityAssessment.lean`

**Interfaces:**
- Consumes:
  - total and partial cases from Task 3;
  - `aggregateChecks` from Task 1;
  - corrected valuations from Task 2.
- Produces:
  - `SimplifiedRoute`
  - `EligibilityFact`
  - `EligibilityFailure`
  - `PartialValuation`
  - `eligibilityChecks`
  - `assessRoute`
  - independent `RouteEligible`
  - exact total route theorems.

- [ ] **Step 1: Write failing exact-classification examples**

Create `SimpleProbate/Examples/EligibilityAssessment.lean` with a complete
personal-property case converted through `toPartial`:

```lean
import SimpleProbate.Eligibility

namespace SimpleProbate.Examples.EligibilityAssessment

open SimpleProbate

def personalAsset : Asset := {
  id := ⟨1⟩
  name := "account"
  kind := .personal
  currentGrossValue := Money.dollars 208_850
  dateOfDeathValue := Money.dollars 208_850
}

def personalCase : TransferCase := {
  deathDate := ⟨2026, 1, 1⟩
  estate := { assets := [personalAsset] }
  targetId := ⟨1⟩
  authority := .noProceeding
  daysSinceDeath := 40
  sixMonthsElapsed := false
  claimantIsSuccessor := true
  noSuperiorRight := true
  funeralLastIllnessAndUnsecuredDebtsPaid := true
  survivorStatus := .none
  propertyPassesToSurvivor := false
  propertyBelongsToSurvivor := false
}

example :
    assessRoute personalCase.toPartial .personalPropertyAffidavit =
      .ok .qualifies := by decide

example :
    assessRoute
      ({ personalCase with daysSinceDeath := 39 }).toPartial
      .personalPropertyAffidavit =
      .ok (.doesNotQualify [.fortyDaysNotElapsed]) := by decide

example :
    RouteEligible personalCase .personalPropertyAffidavit := by decide

example :
    assessRoute personalCase.toPartial .personalPropertyAffidavit =
        .ok .qualifies ↔
      RouteEligible personalCase .personalPropertyAffidavit := by
  exact assessRoute_ofTotal_qualifies_iff personalCase
    .personalPropertyAffidavit

end SimpleProbate.Examples.EligibilityAssessment
```

- [ ] **Step 2: Run the focused check and confirm missing assessment API**

Run:

```bash
lake env lean SimpleProbate/Examples/EligibilityAssessment.lean
```

Expected: failure because `SimplifiedRoute`, `assessRoute`, and the exactness
theorem do not exist.

- [ ] **Step 3: Define stable route, fact, and failure types**

In `Eligibility.lean`, define:

```lean
inductive SimplifiedRoute
  | directTransfer (basis : DirectTransferBasis)
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

def SimplifiedRoute.toRoute : SimplifiedRoute → Route
  | .directTransfer basis => .directTransfer basis
  | .personalPropertyAffidavit => .personalPropertyAffidavit
  | .smallValueRealPropertyAffidavit =>
      .smallValueRealPropertyAffidavit
  | .primaryResidencePetition => .primaryResidencePetition
  | .spousalPropertyPetition => .spousalPropertyPetition

inductive EligibilityFact
  | deathDate
  | targetAsset
  | inventoryComplete
  | assetField (id : AssetId) (field : AssetField)
  | authority
  | daysSinceDeath
  | sixMonthsElapsed
  | claimantIsSuccessor
  | noSuperiorRight
  | debtsPaid
  | survivorStatus
  | propertyPassesToSurvivor
  | propertyBelongsToSurvivor
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive EligibilityFailure
  | directTransferBasisAbsent (basis : DirectTransferBasis)
  | targetNotPersonalProperty
  | targetNotCaliforniaRealProperty
  | targetNotCounted
  | targetNotPrimaryResidence
  | claimantNotSuccessor
  | superiorRightExists
  | fortyDaysNotElapsed
  | sixMonthsNotElapsed
  | blockedByProceeding
  | requiredDebtsUnpaid
  | personalPropertyValueOverCap (value cap : Money)
  | smallRealPropertyValueOverCap (value cap : Money)
  | primaryResidenceValueOverCap (value cap : Money)
  | noSurvivingSpouseOrPartner
  | propertyNeitherPassesNorBelongsToSurvivor
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr
```

Define the stable ordered route list:

```lean
def simplifiedRoutes : List SimplifiedRoute :=
  directTransferBases.map SimplifiedRoute.directTransfer ++ [
    .personalPropertyAffidavit,
    .smallValueRealPropertyAffidavit,
    .primaryResidencePetition,
    .spousalPropertyPetition
  ]
```

- [ ] **Step 4: Add partial valuation bounds**

In `Estate.lean`, define:

```lean
structure PartialValuation where
  lowerBound : Money
  exactValue : Option Money
  missingFields : List (AssetId × AssetField)
  needsCompleteInventory : Bool
deriving DecidableEq, Repr
```

Use the `AssetField` type added to `Estate.lean` in Task 2.

Implement:

```lean
def PartialEstate.personalAffidavitValuation :
    Thresholds → PartialValuation

def PartialEstate.smallRealPropertyValuation : PartialValuation

def PartialEstate.primaryResidenceValuation : PartialValuation
```

For each valuation:

- `lowerBound` sums contributions forced by known fields;
- `exactValue = some value` only when `inventoryComplete = .known true` and
  every field relevant to that valuation is known;
- `needsCompleteInventory = true` unless inventory completeness is known
  `true`;
- excluded assets do not require an otherwise irrelevant value field;
- employment lower bounds aggregate known compensation before subtracting the
  one dated exclusion; and
- missing fields are deduplicated in asset-list and field order.

Prove for each total estate:

```lean
theorem personalValuation_ofTotal_exact
    (estate : Estate) (thresholds : Thresholds) :
    (PartialEstate.ofTotal estate).personalAffidavitValuation thresholds = {
      lowerBound := estate.personalAffidavitValueWith thresholds
      exactValue := some (estate.personalAffidavitValueWith thresholds)
      missingFields := []
      needsCompleteInventory := false
    } := by
  induction estate.assets <;>
    simp_all [PartialEstate.ofTotal,
      PartialEstate.personalAffidavitValuation,
      Estate.personalAffidavitValueWith]
```

Add matching exactness theorems for the two date-of-death real-property
valuations.

- [ ] **Step 5: Keep declarative predicates independent**

Rewrite the existing `RouteEligible` family to consume `SimplifiedRoute` and a
target found by `targetId`. Keep the route predicates as direct propositions,
not as statements about `assessRoute`.

Use:

```lean
def TransferCase.target? (case : TransferCase) : Option Asset :=
  case.estate.findAsset? case.targetId

def RouteEligible (case : TransferCase) : SimplifiedRoute → Prop
  | .directTransfer basis =>
      SupportedDeathDate case.deathDate ∧
      case.WellFormed ∧
      ∃ target, case.target? = some target ∧
        target.directTransferBasis = some basis
  | .personalPropertyAffidavit =>
      PersonalPropertyAffidavitEligible case
  | .smallValueRealPropertyAffidavit =>
      SmallValueRealPropertyAffidavitEligible case
  | .primaryResidencePetition =>
      PrimaryResidencePetitionEligible case
  | .spousalPropertyPetition =>
      SpousalPropertyPetitionEligible case
```

Update each named predicate to look up the target by ID and use the corrected
route-specific total valuation. Preserve the existing statutory conjuncts.

- [ ] **Step 6: Implement atomic checks and route assessment**

Add helpers:

```lean
def checkKnowledge
    (fact : EligibilityFact) (failure : EligibilityFailure)
    (predicate : α → Bool) :
    Knowledge α → CheckResult EligibilityFact EligibilityFailure
  | .unknown => .unknown fact
  | .known value =>
      if predicate value then .satisfied else .violated failure

def checkAuthority :
    Knowledge SummaryAuthority →
      CheckResult EligibilityFact EligibilityFailure
  | .unknown => .unknown .authority
  | .known .blockedByProceeding => .violated .blockedByProceeding
  | .known _ => .satisfied
```

Build each route's checks in this exact order:

| Route | Check | Unknown fact(s) | Known failure |
| --- | --- | --- | --- |
| all | known supported death date | `deathDate` | invalid and post-snapshot dates are `CaseError`s |
| all | target ID resolves to a listed asset | `targetAsset` | a known missing target in a complete inventory is `CaseError.malformedCase` |
| direct | target direct-transfer basis equals requested basis | `assetField targetId treatment` | `directTransferBasisAbsent basis` |
| personal | target kind is personal | `assetField targetId kind` | `targetNotPersonalProperty` |
| personal | claimant is successor | `claimantIsSuccessor` | `claimantNotSuccessor` |
| personal | no superior right | `noSuperiorRight` | `superiorRightExists` |
| personal | at least 40 days | `daysSinceDeath` | `fortyDaysNotElapsed` |
| personal | authority permits procedure | `authority` | `blockedByProceeding` |
| personal | personal value at or below dated cap | valuation missing fields, `inventoryComplete`, or `deathDate` | `personalPropertyValueOverCap value cap` |
| small real | target kind is California real | `assetField targetId kind` | `targetNotCaliforniaRealProperty` |
| small real | target treatment is counted | `assetField targetId treatment` | `targetNotCounted` |
| small real | claimant is successor | `claimantIsSuccessor` | `claimantNotSuccessor` |
| small real | no superior right | `noSuperiorRight` | `superiorRightExists` |
| small real | six months elapsed | `sixMonthsElapsed` | `sixMonthsNotElapsed` |
| small real | authority permits procedure | `authority` | `blockedByProceeding` |
| small real | funeral, last-illness, and unsecured debts paid | `debtsPaid` | `requiredDebtsUnpaid` |
| small real | California real value at or below dated cap | valuation missing fields, `inventoryComplete`, or `deathDate` | `smallRealPropertyValueOverCap value cap` |
| primary | target kind is California real | `assetField targetId kind` | `targetNotCaliforniaRealProperty` |
| primary | target treatment is counted | `assetField targetId treatment` | `targetNotCounted` |
| primary | target is primary residence | `assetField targetId primaryResidence` | `targetNotPrimaryResidence` |
| primary | claimant is successor | `claimantIsSuccessor` | `claimantNotSuccessor` |
| primary | at least 40 days | `daysSinceDeath` | `fortyDaysNotElapsed` |
| primary | authority permits procedure | `authority` | `blockedByProceeding` |
| primary | primary-residence value at or below dated cap | valuation missing fields, `inventoryComplete`, or `deathDate` | `primaryResidenceValueOverCap value cap` |
| spousal | survivor is spouse or registered domestic partner | `survivorStatus` | `noSurvivingSpouseOrPartner` |
| spousal | property passes to or belongs to survivor | each unresolved one of `propertyPassesToSurvivor`, `propertyBelongsToSurvivor` | `propertyNeitherPassesNorBelongsToSurvivor` only when both are known false |

Implement:

```lean
def eligibilityChecks
    (case : PartialTransferCase) (route : SimplifiedRoute) :
    Except CaseError
      (List (CheckResult EligibilityFact EligibilityFailure))

def assessRoute
    (case : PartialTransferCase) (route : SimplifiedRoute) :
    Except CaseError
      (DecisionStatus EligibilityFact EligibilityFailure) := do
  validatePartialCase case
  let checks ← eligibilityChecks case route
  pure <| aggregateChecks checks
```

Every route check list begins with supported-date and target-resolution checks,
then follows the predicate conjunct order. For a capped value:

- return the route-specific `personalPropertyValueOverCap`,
  `smallRealPropertyValueOverCap`, or `primaryResidenceValueOverCap`
  violation carrying `lowerBound` and `cap` when `lowerBound > cap`;
- return `satisfied` when `exactValue = some value` and `value ≤ cap`; and
- otherwise return one `.unknown` check for each missing asset field and one
  `.unknown .inventoryComplete` when the inventory is not known complete.

Do not emit a fallback check here.

- [ ] **Step 7: Prove total exactness**

Prove per-route check equivalence first:

```lean
theorem eligibilityChecks_ofTotal_all_satisfied_iff
    (case : TransferCase) (route : SimplifiedRoute) :
    (∀ checks,
      eligibilityChecks case.toPartial route = .ok checks →
      (∀ check ∈ checks, check = .satisfied)) ↔
    RouteEligible case route := by
  cases route <;>
    simp [eligibilityChecks, RouteEligible,
      DirectTransferEligible, PersonalPropertyAffidavitEligible,
      SmallValueRealPropertyAffidavitEligible,
      PrimaryResidencePetitionEligible,
      SpousalPropertyPetitionEligible,
      checkKnowledge, checkAuthority,
      personalValuation_ofTotal_exact]
```

Then prove the public iff:

```lean
theorem assessRoute_ofTotal_qualifies_iff
    (case : TransferCase) (route : SimplifiedRoute) :
    assessRoute case.toPartial route = .ok .qualifies ↔
      RouteEligible case route := by
  rw [← eligibilityChecks_ofTotal_all_satisfied_iff]
  simp [assessRoute, aggregateChecks_qualifies_iff]
```

Add the negative direction for valid, well-formed total cases:

```lean
theorem assessRoute_ofTotal_disqualified_iff
    (case : TransferCase) (route : SimplifiedRoute)
    (valid : validatePartialCase case.toPartial = .ok ()) :
    (∃ reasons,
      assessRoute case.toPartial route =
        .ok (.doesNotQualify reasons)) ↔
      ¬ RouteEligible case route := by
  rw [← assessRoute_ofTotal_qualifies_iff]
  cases result : assessRoute case.toPartial route <;>
    simp_all [valid]
```

The total conversion must never yield `needsInformation`; prove that as a
separate theorem and use it in the negative proof.

- [ ] **Step 8: Run focused and full verification**

Run:

```bash
lake env lean SimpleProbate/Estate.lean
lake env lean SimpleProbate/Eligibility.lean
lake env lean SimpleProbate/Examples/EligibilityAssessment.lean
lake env lean SimpleProbate/Examples.lean
lake build
```

Expected: all succeed.

- [ ] **Step 9: Commit exact route classification**

```bash
git add SimpleProbate/Estate.lean SimpleProbate/Eligibility.lean SimpleProbate/Examples/EligibilityAssessment.lean
git commit -m "feat: classify probate routes exactly"
```

---

### Task 5: Partial Route Soundness and Overall Fallback

**Files:**
- Modify: `SimpleProbate/Estate.lean` (completion-bound lemmas)
- Modify: `SimpleProbate/Eligibility.lean` (case reports and soundness)
- Modify: `SimpleProbate/Examples/EligibilityAssessment.lean`

**Interfaces:**
- Consumes:
  - `PartialTransferCase.Completes`
  - `assessRoute`
  - exact total route predicates.
- Produces:
  - `RouteReport`
  - `OverallOutcome`
  - `CaseAssessment`
  - `assessRoutes`
  - completion soundness theorems
  - exact fallback theorem.

- [ ] **Step 1: Add failing partial and fallback examples**

Append to `SimpleProbate/Examples/EligibilityAssessment.lean`:

```lean
def unknownSuccessorCase : PartialTransferCase := {
  personalCase.toPartial with
  claimantIsSuccessor := .unknown
}

example :
    assessRoute unknownSuccessorCase .personalPropertyAffidavit =
      .ok (.needsInformation [.claimantIsSuccessor]) := by decide

def incompleteBelowCap : PartialTransferCase := {
  personalCase.toPartial with
  estate := {
    (PartialEstate.ofTotal personalCase.estate) with
    inventoryComplete := .known false
  }
}

example :
    assessRoute incompleteBelowCap .personalPropertyAffidavit =
      .ok (.needsInformation [.inventoryComplete]) := by decide

def knownOverCapAsset : Asset := {
  personalAsset with
  currentGrossValue := Money.dollars 208_850 + 1
}

def incompleteOverCap : PartialTransferCase := {
  ({ personalCase with
      estate := { assets := [knownOverCapAsset] } }).toPartial with
  estate := {
    (PartialEstate.ofTotal { assets := [knownOverCapAsset] }) with
    inventoryComplete := .known false
  }
}

example :
    assessRoute incompleteOverCap .personalPropertyAffidavit =
      .ok (.doesNotQualify [
        .personalPropertyValueOverCap
          (Money.dollars 208_850 + 1) (Money.dollars 208_850)
      ]) := by decide

example :
    (assessRoutes unknownSuccessorCase).map (·.overall) =
      .ok .unresolved := by decide

def directAsset : Asset := {
  personalAsset with
  treatment := .directBeneficiary
}

def qualifiedAndUnresolved : PartialTransferCase := {
  ({ personalCase with
      estate := { assets := [directAsset] } }).toPartial with
  claimantIsSuccessor := .unknown
}

example :
    assessRoute qualifiedAndUnresolved
      (.directTransfer .namedBeneficiary) = .ok .qualifies := by decide

example :
    assessRoute qualifiedAndUnresolved .personalPropertyAffidavit =
      .ok (.needsInformation [.claimantIsSuccessor]) := by decide

example :
    (assessRoutes qualifiedAndUnresolved).map (·.overall) =
      .ok .simplifiedRoutesAvailable := by decide
```

- [ ] **Step 2: Run the focused check and verify missing overall API**

Run:

```bash
lake env lean SimpleProbate/Examples/EligibilityAssessment.lean
```

Expected: partial route examples may expose evaluator gaps; the final example
must fail because `assessRoutes` and `OverallOutcome` do not exist.

- [ ] **Step 3: Prove partial valuation bounds over completions**

For each valuation, prove:

```lean
theorem personalValuation_lowerBound_le
    {partial : PartialEstate} {total : Estate}
    (completion : partial.Completes total)
    (thresholds : Thresholds) :
    (partial.personalAffidavitValuation thresholds).lowerBound ≤
      total.personalAffidavitValueWith thresholds

theorem personalValuation_exact_eq
    {partial : PartialEstate} {total : Estate} {value : Money}
    (completion : partial.Completes total)
    (exact :
      (partial.personalAffidavitValuation thresholds).exactValue =
        some value) :
    total.personalAffidavitValueWith thresholds = value
```

Prove both by induction over the partial asset list, using
`PartialAsset.Completes` to rewrite known fields. Use the
`inventoryComplete` branch of `PartialEstate.Completes` to rule out additional
assets for the exact-value theorem.

Add corresponding lower-bound and exact-value theorems for small-real and
primary-residence valuations.

- [ ] **Step 4: Prove route-status soundness over completions**

Add:

```lean
theorem assessRoute_qualifies_all_completions
    {partial : PartialTransferCase} {route : SimplifiedRoute}
    (qualified : assessRoute partial route = .ok .qualifies) :
    ∀ total, partial.Completes total →
      TransferCase.WellFormed total →
      RouteEligible total route

theorem assessRoute_disqualified_no_completion
    {partial : PartialTransferCase} {route : SimplifiedRoute}
    {reasons : List EligibilityFailure}
    (disqualified :
      assessRoute partial route =
        .ok (.doesNotQualify reasons)) :
    ∀ total, partial.Completes total →
      TransferCase.WellFormed total →
      ¬ RouteEligible total route
```

Prove these by cases on `route`, expanding the ordered checks. For value-cap
branches, use the bound lemmas from Step 3. For known atomic facts, use the
matching `Knowledge.Completes` conjunct. Do not prove soundness by redefining
`RouteEligible` in terms of `assessRoute`.

Prove exact unresolved-fact membership:

```lean
theorem mem_assessRoute_needsInformation_iff
    {case : PartialTransferCase} {route : SimplifiedRoute}
    {facts : List EligibilityFact}
    (result :
      assessRoute case route = .ok (.needsInformation facts))
    (fact : EligibilityFact) :
    fact ∈ facts ↔
      ∃ checks,
        eligibilityChecks case route = .ok checks ∧
        .unknown fact ∈ checks := by
  unfold assessRoute at result
  split at result
  next error => simp_all
  next valid =>
    simp_all [mem_requiredFact_of_aggregate]
```

This theorem, together with stable `eligibilityChecks` ordering, is the exact
contract for each `needsInformation` list.

- [ ] **Step 5: Define full case reports**

Add:

```lean
structure RouteReport where
  route : SimplifiedRoute
  status : DecisionStatus EligibilityFact EligibilityFailure
deriving DecidableEq, Repr

inductive OverallOutcome
  | simplifiedRoutesAvailable
  | unresolved
  | formalProbateOrOtherProcedure
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure CaseAssessment where
  routes : List RouteReport
  overall : OverallOutcome
deriving DecidableEq, Repr
```

Implement:

```lean
def overallOutcome (reports : List RouteReport) : OverallOutcome :=
  if reports.any (fun report =>
      match report.status with
      | .qualifies => true
      | _ => false) then
    .simplifiedRoutesAvailable
  else if reports.any (fun report =>
      match report.status with
      | .needsInformation _ => true
      | _ => false) then
    .unresolved
  else
    .formalProbateOrOtherProcedure

def assessRoutes
    (case : PartialTransferCase) :
    Except CaseError CaseAssessment := do
  validatePartialCase case
  let reports ← simplifiedRoutes.mapM fun route => do
    let status ← assessRoute case route
    pure { route := route, status := status }
  pure { routes := reports, overall := overallOutcome reports }
```

Preserve the existing total convenience names as wrappers with the stronger
`CaseError` type:

```lean
def Route.toSimplified? : Route → Option SimplifiedRoute
  | .directTransfer basis => some (.directTransfer basis)
  | .personalPropertyAffidavit => some .personalPropertyAffidavit
  | .smallValueRealPropertyAffidavit =>
      some .smallValueRealPropertyAffidavit
  | .primaryResidencePetition => some .primaryResidencePetition
  | .spousalPropertyPetition => some .spousalPropertyPetition
  | .formalProbateOrOtherProcedure => none

def candidateRoutes
    (case : TransferCase) : Except CaseError (List Route) := do
  let assessment ← assessRoutes case.toPartial
  let qualifying := assessment.routes.filterMap fun report =>
    match report.status with
    | .qualifies => some report.route.toRoute
    | _ => none
  if qualifying = [] then
    pure [.formalProbateOrOtherProcedure]
  else
    pure qualifying

def routeEligible
    (case : TransferCase) (route : Route) : Except CaseError Bool := do
  match route.toSimplified? with
  | some simplified =>
      let status ← assessRoute case.toPartial simplified
      pure <| match status with
        | .qualifies => true
        | _ => false
  | none =>
      let assessment ← assessRoutes case.toPartial
      pure <| assessment.overall == .formalProbateOrOtherProcedure
```

Derive `BEq`, `ReflBEq`, and `LawfulBEq` for `OverallOutcome` so the fallback
wrapper comparison is lawful. Existing examples using `candidateRoutes` and
`routeEligible` should require only the error-type migration from `DateError`
to `CaseError`.

- [ ] **Step 6: Prove fallback exactness**

For total cases, prove:

```lean
theorem assessRoutes_ofTotal_fallback_iff
    (case : TransferCase)
    (valid : validatePartialCase case.toPartial = .ok ()) :
    (∃ assessment,
      assessRoutes case.toPartial = .ok assessment ∧
      assessment.overall = .formalProbateOrOtherProcedure) ↔
    ∀ route ∈ simplifiedRoutes, ¬ RouteEligible case route
```

For partial cases, prove:

```lean
theorem assessRoutes_fallback_all_completions_ineligible
    {partial : PartialTransferCase} {assessment : CaseAssessment}
    (result : assessRoutes partial = .ok assessment)
    (fallback :
      assessment.overall = .formalProbateOrOtherProcedure) :
    ∀ total, partial.Completes total →
      TransferCase.WellFormed total →
      ∀ route ∈ simplifiedRoutes, ¬ RouteEligible total route
```

Use `assessRoute_disqualified_no_completion` for every report. The proof must
also use that `simplifiedRoutes.mapM` preserves one report per route in the
same order.

Retain and strengthen the compatibility theorem:

```lean
theorem candidateRoutes_exact
    {case : TransferCase} {routes : List Route}
    (result : candidateRoutes case = .ok routes) :
    ∀ route,
      route ∈ routes ↔
      match route.toSimplified? with
      | some simplified => RouteEligible case simplified
      | none =>
          ∀ simplified ∈ simplifiedRoutes,
            ¬ RouteEligible case simplified
```

Prove it from `assessRoute_ofTotal_qualifies_iff` and
`assessRoutes_ofTotal_fallback_iff`. This subsumes the former one-way
`candidateRoutes_sound` guarantee.

- [ ] **Step 7: Verify all partial scenarios**

Run:

```bash
lake env lean SimpleProbate/Examples/EligibilityAssessment.lean
lake env lean SimpleProbate/Eligibility.lean
lake build
```

Expected: all succeed. Confirm the incomplete-below-cap case is unresolved,
the known-over-cap case is disqualified, and fallback is absent while any
route remains unknown.

- [ ] **Step 8: Commit partial eligibility**

```bash
git add SimpleProbate/Estate.lean SimpleProbate/Eligibility.lean SimpleProbate/Examples/EligibilityAssessment.lean
git commit -m "feat: assess incomplete probate cases"
```

---

### Task 6: Total Packet Exactness and Section 13200(d)

**Files:**
- Modify: `SimpleProbate/Procedure.lean` (readiness, missing lists, and proofs)
- Create: `SimpleProbate/Examples/ProcedureExactness.lean`

**Interfaces:**
- Consumes:
  - total route eligibility;
  - existing packet and context records.
- Produces:
  - `CourtRoute`
  - corrected small-real will applicability
  - four `missing_empty_iff_ready` theorems
  - membership-level missing-requirement theorems.

- [ ] **Step 1: Write the failing will-applicability regression**

Create `SimpleProbate/Examples/ProcedureExactness.lean` using the existing
complete small-real fixture, migrated to the new case model:

```lean
import SimpleProbate.Examples.Fixtures

namespace SimpleProbate.Examples.ProcedureExactness

open SimpleProbate
open SimpleProbate.Examples

def claimsUnderWillWithConsent : ProcedureContext := {
  baseProcedureContext with
  claimsUnderWill := true
}

def consentSmallRealCase : TransferCase := {
  smallReal2026Case with
  authority := .writtenPersonalRepresentativeConsent
}

def noWillSmallRealPacket : SmallRealPropertyPacket := {
  completeSmallRealPacket with
  willAttached := false
}

example :
    SmallRealPropertyAffidavitReady
      claimsUnderWillWithConsent consentSmallRealCase
      noWillSmallRealPacket := by decide

example :
    smallRealPropertyAffidavitMissing
      claimsUnderWillWithConsent consentSmallRealCase
      noWillSmallRealPacket = [] := by decide

example :
    ¬SmallRealPropertyAffidavitReady
      claimsUnderWillWithConsent smallReal2026Case
      noWillSmallRealPacket := by decide

example :
    .willAttachment ∈
      smallRealPropertyAffidavitMissing
        claimsUnderWillWithConsent smallReal2026Case
        noWillSmallRealPacket := by decide
```

- [ ] **Step 2: Run the regression and confirm RED**

Run:

```bash
lake env lean SimpleProbate/Examples/ProcedureExactness.lean
```

Expected: both examples fail because the current implementation requires the
will whenever `claimsUnderWill = true`.

- [ ] **Step 3: Correct will attachment applicability**

Define:

```lean
def noEstateProceeding (authority : SummaryAuthority) : Bool :=
  authority == .noProceeding

def needsSmallRealWillAttachment
    (context : ProcedureContext) (case : TransferCase) : Bool :=
  context.claimsUnderWill && noEstateProceeding case.authority
```

Use `needsSmallRealWillAttachment context case` in both
`SmallRealPropertyAffidavitReady` and
`smallRealPropertyAffidavitMissing`. Keep primary-residence and spousal will
rules unchanged because their statutes do not use the same no-proceeding
condition.

- [ ] **Step 4: Add CourtRoute and route-indexed total packet family**

Define:

```lean
inductive CourtRoute
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

def CourtRoute.toSimplifiedRoute : CourtRoute → SimplifiedRoute
  | .personalPropertyAffidavit => .personalPropertyAffidavit
  | .smallValueRealPropertyAffidavit =>
      .smallValueRealPropertyAffidavit
  | .primaryResidencePetition => .primaryResidencePetition
  | .spousalPropertyPetition => .spousalPropertyPetition

def TotalPacket : CourtRoute → Type
  | .personalPropertyAffidavit => PersonalAffidavitPacket
  | .smallValueRealPropertyAffidavit => SmallRealPropertyPacket
  | .primaryResidencePetition => PrimaryResidencePetitionPacket
  | .spousalPropertyPetition => SpousalPetitionPacket

def CourtReady
    (route : CourtRoute) (context : ProcedureContext)
    (case : TransferCase) (packet : TotalPacket route) : Prop :=
  match route with
  | .personalPropertyAffidavit =>
      PersonalAffidavitReady context case packet
  | .smallValueRealPropertyAffidavit =>
      SmallRealPropertyAffidavitReady context case packet
  | .primaryResidencePetition =>
      PrimaryResidencePetitionReady context case packet
  | .spousalPropertyPetition =>
      SpousalPetitionReady context case packet
```

- [ ] **Step 5: Write failing empty-list equivalence examples**

Append:

```lean
example :
    personalAffidavitMissing baseProcedureContext base2026Case
        completePersonalPacket = [] ↔
      PersonalAffidavitReady baseProcedureContext base2026Case
        completePersonalPacket :=
  personalAffidavitMissing_empty_iff_ready
    baseProcedureContext base2026Case completePersonalPacket

example :
    smallRealPropertyAffidavitMissing baseProcedureContext
        smallReal2026Case completeSmallRealPacket = [] ↔
      SmallRealPropertyAffidavitReady baseProcedureContext
        smallReal2026Case completeSmallRealPacket :=
  smallRealPropertyAffidavitMissing_empty_iff_ready
    baseProcedureContext smallReal2026Case completeSmallRealPacket

example :
    primaryResidencePetitionMissing baseProcedureContext
        primaryResidence2026Case completePrimaryResidencePacket = [] ↔
      PrimaryResidencePetitionReady baseProcedureContext
        primaryResidence2026Case completePrimaryResidencePacket :=
  primaryResidencePetitionMissing_empty_iff_ready
    baseProcedureContext primaryResidence2026Case
      completePrimaryResidencePacket

example :
    spousalPetitionMissing baseProcedureContext spouse2026Case
        completeSpousalPacket = [] ↔
      SpousalPetitionReady baseProcedureContext spouse2026Case
        completeSpousalPacket :=
  spousalPetitionMissing_empty_iff_ready
    baseProcedureContext spouse2026Case completeSpousalPacket
```

Run the file and expect unknown-theorem failures.

- [ ] **Step 6: Derive missing lists from typed requirement checks**

Add:

```lean
structure RequirementCheck where
  requirement : Requirement
  applies : Bool
  supplied : Bool
deriving DecidableEq, Repr

def RequirementCheck.isMissing (check : RequirementCheck) : Bool :=
  check.applies && !check.supplied

def missingFromChecks
    (checks : List RequirementCheck) : List Requirement :=
  checks.filterMap fun check =>
    if check.isMissing then some check.requirement else none
```

Define `personalRequirementChecks` with this exact ordered list:

```lean
def personalRequirementChecks
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) : List RequirementCheck := [
  ⟨.eligibleRoute, true,
    decide (PersonalPropertyAffidavitEligible case)⟩,
  ⟨.affidavitDeclarations, true, packet.affidavitDeclarations⟩,
  ⟨.certifiedDeathCertificate, true, packet.certifiedDeathCertificate⟩,
  ⟨.identityProof, true, packet.identityProof⟩,
  ⟨.ownershipEvidenceOrIndemnity, true,
    if context.ownershipEvidenceAvailable
    then packet.ownershipEvidencePresented
    else packet.holderIndemnityAlternative⟩,
  ⟨.allEntitledSuccessorsSigned, context.hasOtherEntitledSuccessors,
    packet.allEntitledSuccessorsSigned⟩,
  ⟨.notarization, context.institutionRequiresNotary, packet.notarized⟩,
  ⟨.consentAndLetters, needsConsentAttachment case.authority,
    packet.consentAndLettersAttached⟩,
  ⟨.datedAmountList, needsDatedAmountList case.deathDate,
    packet.datedAmountListAttached⟩,
  ⟨.inventoryAndAppraisal,
    case.estate.containsCountedCaliforniaRealProperty,
    packet.inventoryAndAppraisalAttached⟩,
  ⟨.presentationToHolder, true, packet.presentedToHolder⟩
]
```

Define the other check lists with these exact rows, in order:

| Check list | Requirement | Applies | Supplied |
| --- | --- | --- | --- |
| small real | `eligibleRoute` | `true` | `decide (SmallValueRealPropertyAffidavitEligible case)` |
| small real | `de305Statements` | `true` | `packet.de305Statements` |
| small real | `notarization` | `true` | `packet.notarizedAcknowledgments` |
| small real | `inventoryAndAppraisal` | `true` | `packet.inventoryAndAppraisalAttached` |
| small real | `certifiedDeathCertificate` | `true` | `packet.certifiedDeathCertificate` |
| small real | `willAttachment` | `needsSmallRealWillAttachment context case` | `packet.willAttached` |
| small real | `consentAndLetters` | `needsConsentAttachment case.authority` | `packet.consentAndLettersAttached` |
| small real | `datedAmountList` | `needsDatedAmountList case.deathDate` | `packet.datedAmountListAttached` |
| small real | `guardianOrConservatorDelivery` | `context.knownGuardianOrConservator` | `packet.guardianOrConservatorDelivery` |
| small real | `properCourtFiling` | `true` | `packet.filedInProperCourt` |
| small real | `clerkCertifiedCopy` | `true` | `packet.clerkCertifiedCopyIssued` |
| small real | `countyRecording` | `true` | `packet.recordedInPropertyCounty` |
| primary | `eligibleRoute` | `true` | `decide (PrimaryResidencePetitionEligible case)` |
| primary | `de310VerifiedStatements` | `true` | `packet.de310VerifiedStatements` |
| primary | `inventoryAndAppraisal` | `true` | `packet.inventoryAndAppraisalAttached` |
| primary | `willAttachment` | `context.claimsUnderWill` | `packet.willAttached` |
| primary | `consentAndLetters` | `needsConsentAttachment case.authority` | `packet.consentAttached` |
| primary | `datedAmountList` | `needsDatedAmountList case.deathDate` | `packet.datedAmountListAttached` |
| primary | `properCourtFiling` | `true` | `packet.filedInProperCourt` |
| primary | `heirAndDeviseeCopyWithinFiveBusinessDays` | `true` | `packet.heirAndDeviseeCopyWithinFiveBusinessDays` |
| primary | `statutoryHearingNotice` | `true` | `packet.statutoryHearingNotice` |
| primary | `courtFindings` | `true` | `packet.courtFindingsMade` |
| primary | `de315Order` | `true` | `packet.de315OrderIssued` |
| spousal | `eligibleRoute` | `true` | `decide (SpousalPropertyPetitionEligible case)` |
| spousal | `de221Allegations` | `true` | `packet.de221Allegations` |
| spousal | `propertyDescriptionsAndSupportingFacts` | `true` | `packet.propertyDescriptionsAndSupportingFacts` |
| spousal | `knownInterestedPersons` | `true` | `packet.knownInterestedPersonsListed` |
| spousal | `propertyAgreementDisclosure` | `true` | `packet.propertyAgreementDisclosed` |
| spousal | `willAttachment` | `context.claimsUnderWill` | `packet.willAttached` |
| spousal | `propertyAgreementAttachment` | `context.propertyAgreementExists` | `packet.propertyAgreementAttached` |
| spousal | `statutoryHearingNotice` | `true` | `packet.statutoryHearingNotice` |
| spousal | `de226Order` | `true` | `packet.de226OrderIssued` |

Redefine each existing missing-list function as `missingFromChecks` applied to
its route-specific list. This preserves stable order while putting
applicability and supply in one typed representation.

- [ ] **Step 7: Prove membership and all four empty-list equivalences**

Prove the generic membership theorem:

```lean
theorem mem_missingFromChecks_iff
    (checks : List RequirementCheck) (requirement : Requirement) :
    requirement ∈ missingFromChecks checks ↔
      ∃ check ∈ checks,
        check.requirement = requirement ∧
        check.applies = true ∧
        check.supplied = false := by
  induction checks with
  | nil => simp [missingFromChecks]
  | cons check rest ih =>
      cases applies : check.applies <;>
      cases supplied : check.supplied <;>
      simp_all [missingFromChecks, RequirementCheck.isMissing]
```

Expose route-specific corollaries by rewriting the four missing functions:

```lean
theorem mem_personalAffidavitMissing_iff
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) (requirement : Requirement) :
    requirement ∈ personalAffidavitMissing context case packet ↔
      ∃ check ∈ personalRequirementChecks context case packet,
        check.requirement = requirement ∧
        check.applies = true ∧
        check.supplied = false := by
  exact mem_missingFromChecks_iff
    (personalRequirementChecks context case packet) requirement
```

Add corollaries with the same shape for
`smallRealPropertyRequirementChecks`,
`primaryResidenceRequirementChecks`, and `spousalRequirementChecks`.

Finally prove:

```lean
theorem personalAffidavitMissing_empty_iff_ready
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) :
    personalAffidavitMissing context case packet = [] ↔
      PersonalAffidavitReady context case packet := by
  simp [personalAffidavitMissing, personalRequirementChecks,
    missingFromChecks, RequirementCheck.isMissing,
    PersonalAffidavitReady, suppliedWhen]
```

Add the matching theorem statements for:

```lean
smallRealPropertyAffidavitMissing_empty_iff_ready
primaryResidencePetitionMissing_empty_iff_ready
spousalPetitionMissing_empty_iff_ready
```

Prove each by simplifying its exact check list and independent readiness
predicate. Finish residual Boolean cases by cases on only the fields named in
that route's check-list table.

- [ ] **Step 8: Verify total packet proofs**

Run:

```bash
lake env lean SimpleProbate/Procedure.lean
lake env lean SimpleProbate/Examples/ProcedureExactness.lean
lake env lean SimpleProbate/Examples.lean
lake build
```

Expected: all succeed, including the written-consent/no-will regression and
all four iff examples.

- [ ] **Step 9: Commit packet exactness**

```bash
git add SimpleProbate/Procedure.lean SimpleProbate/Examples/ProcedureExactness.lean
git commit -m "fix: prove exact probate packet requirements"
```

---

### Task 7: Partial Packet Assessment and Readiness Soundness

**Files:**
- Create: `SimpleProbate/ProcedureAssessment.lean`
- Create: `SimpleProbate/Examples/ProcedureAssessment.lean`
- Modify: `SimpleProbate.lean`
- Modify: `SimpleProbate/Examples.lean`

**Interfaces:**
- Consumes:
  - `CourtRoute`
  - partial route assessment;
  - total packet exactness from Task 6.
- Produces:
  - `PacketItemState`
  - `PartialProcedureContext`
  - four partial packet records
  - route-indexed `PartialPacket`
  - `ProcedureFact`
  - `ReadinessGaps`
  - `ReadinessAssessment`
  - `assessPacket`
  - partial packet completion and soundness theorems.

- [ ] **Step 1: Write failing unknown-versus-absent examples**

Create `SimpleProbate/Examples/ProcedureAssessment.lean`:

```lean
import SimpleProbate.ProcedureAssessment
import SimpleProbate.Examples.Fixtures

namespace SimpleProbate.Examples.ProcedureAssessment

open SimpleProbate
open SimpleProbate.Examples

def partialContext : PartialProcedureContext :=
  baseProcedureContext.toPartial

def partialPersonal :
    PartialPacket .personalPropertyAffidavit :=
  completePersonalPacket.toPartial

example :
    assessPacket .personalPropertyAffidavit partialContext
      base2026Case.toPartial
      { partialPersonal with certifiedDeathCertificate := .unknown } =
    .ok (.incomplete {
      unresolvedFacts := [
        .packetItem .certifiedDeathCertificate
      ]
      missingRequirements := []
    }) := by decide

example :
    assessPacket .personalPropertyAffidavit partialContext
      base2026Case.toPartial
      { partialPersonal with certifiedDeathCertificate := .absent } =
    .ok (.incomplete {
      unresolvedFacts := []
      missingRequirements := [.certifiedDeathCertificate]
    }) := by decide

example :
    assessPacket .personalPropertyAffidavit partialContext
      base2026Case.toPartial partialPersonal =
    .ok .ready := by decide

end SimpleProbate.Examples.ProcedureAssessment
```

- [ ] **Step 2: Run the focused check and confirm missing module**

Run:

```bash
lake env lean SimpleProbate/Examples/ProcedureAssessment.lean
```

Expected: failure because `SimpleProbate.ProcedureAssessment` does not exist.

- [ ] **Step 3: Define partial context and packet states**

Create `SimpleProbate/ProcedureAssessment.lean`:

```lean
import SimpleProbate.Procedure

namespace SimpleProbate

inductive PacketItemState
  | unknown
  | absent
  | present
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure PartialProcedureContext where
  claimsUnderWill : Knowledge Bool
  ownershipEvidenceAvailable : Knowledge Bool
  hasOtherEntitledSuccessors : Knowledge Bool
  knownGuardianOrConservator : Knowledge Bool
  institutionRequiresNotary : Knowledge Bool
  propertyAgreementExists : Knowledge Bool
deriving DecidableEq, Repr
```

Define four partial packet records with exactly the same field names as their
total packet counterparts, replacing every `Bool` with `PacketItemState`.

Define the route-indexed family:

```lean
def PartialPacket : CourtRoute → Type
  | .personalPropertyAffidavit => PartialPersonalAffidavitPacket
  | .smallValueRealPropertyAffidavit => PartialSmallRealPropertyPacket
  | .primaryResidencePetition => PartialPrimaryResidencePetitionPacket
  | .spousalPropertyPetition => PartialSpousalPetitionPacket
```

Implement:

```lean
def ProcedureContext.toPartial :
    ProcedureContext → PartialProcedureContext

def PersonalAffidavitPacket.toPartial :
    PersonalAffidavitPacket → PartialPersonalAffidavitPacket

def SmallRealPropertyPacket.toPartial :
    SmallRealPropertyPacket → PartialSmallRealPropertyPacket

def PrimaryResidencePetitionPacket.toPartial :
    PrimaryResidencePetitionPacket →
      PartialPrimaryResidencePetitionPacket

def SpousalPetitionPacket.toPartial :
    SpousalPetitionPacket → PartialSpousalPetitionPacket

def TotalPacket.toPartial
    (route : CourtRoute) : TotalPacket route → PartialPacket route :=
  match route with
  | .personalPropertyAffidavit =>
      PersonalAffidavitPacket.toPartial
  | .smallValueRealPropertyAffidavit =>
      SmallRealPropertyPacket.toPartial
  | .primaryResidencePetition =>
      PrimaryResidencePetitionPacket.toPartial
  | .spousalPropertyPetition =>
      SpousalPetitionPacket.toPartial
```

The context conversion wraps each Boolean in `Knowledge.known`. Packet
conversions map `true` to `.present` and `false` to `.absent`.

- [ ] **Step 4: Define readiness report types**

Add:

```lean
inductive ProcedureContextField
  | claimsUnderWill
  | ownershipEvidenceAvailable
  | hasOtherEntitledSuccessors
  | knownGuardianOrConservator
  | institutionRequiresNotary
  | propertyAgreementExists
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive ProcedureFact
  | eligibility (fact : EligibilityFact)
  | context (field : ProcedureContextField)
  | packetItem (requirement : Requirement)
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure ReadinessGaps where
  unresolvedFacts : List ProcedureFact
  missingRequirements : List Requirement
deriving DecidableEq, Repr

inductive ReadinessAssessment
  | ineligible (reasons : List EligibilityFailure)
  | incomplete (gaps : ReadinessGaps)
  | ready
deriving DecidableEq, Repr
```

- [ ] **Step 5: Implement applicability and packet assessment**

Define:

```lean
structure PartialRequirementCheck where
  requirement : Requirement
  applicabilityFacts : List ProcedureFact
  supplyFact : ProcedureFact
  applies : Knowledge Bool
  item : PacketItemState
deriving DecidableEq, Repr

def PartialRequirementCheck.unresolvedFacts
    (check : PartialRequirementCheck) : List ProcedureFact :=
  match check.applies with
  | .unknown => check.applicabilityFacts
  | .known false => []
  | .known true =>
      if check.item == .unknown then [check.supplyFact] else []

def PartialRequirementCheck.missingRequirement
    (check : PartialRequirementCheck) : List Requirement :=
  match check.applies, check.item with
  | .known true, .absent => [check.requirement]
  | _, _ => []
```

Implement one typed partial requirement-check list per route, in the same
requirement order as the total check lists from Task 6. Then implement one
summary function per route returning:

Construct each row by these exact rules:

- an unconditional total `applies = true` becomes `.known true` with an empty
  `applicabilityFacts` list;
- `context.hasOtherEntitledSuccessors`,
  `context.institutionRequiresNotary`,
  `context.knownGuardianOrConservator`, `context.claimsUnderWill`, and
  `context.propertyAgreementExists` use the matching knowledge field and the
  matching `.context ProcedureContextField` singleton when unknown;
- consent applicability is `.known true` only for known
  `.writtenPersonalRepresentativeConsent`, `.known false` for the other known
  authorities, and `.unknown` with `[.eligibility .authority]` otherwise;
- dated-list applicability is `.known false` for a known pre-April-2022 date,
  `.known true` for the two later supported bands, and `.unknown` with
  `[.eligibility .deathDate]` for an unknown date;
- the personal inventory-and-appraisal condition is `.known true` when a
  listed asset is known counted California real property, `.known false` only
  when the inventory is known complete and every listed asset is known not to
  meet both conditions, and otherwise `.unknown` with the unresolved
  `.eligibility (.assetField id .kind)`,
  `.eligibility (.assetField id .treatment)`, and
  `.eligibility .inventoryComplete` facts in asset order;
- the small-real will condition is `.known false` when claims-under-will is
  known false or authority is known not `noProceeding`, `.known true` when
  claims-under-will is known true and authority is known `noProceeding`, and
  otherwise `.unknown` with the unresolved claims-under-will context fact
  and/or authority eligibility fact;
- every row's `supplyFact` is `.packetItem requirement`; and
- every row's `item` is the packet field named in the Task 6 check-list table.
  For `ownershipEvidenceOrIndemnity`, select
  `ownershipEvidencePresented` when ownership evidence is known available,
  `holderIndemnityAlternative` when it is known unavailable, and make
  applicability unknown with
  `[.context .ownershipEvidenceAvailable]` when availability is unknown.

```lean
structure PacketCheckSummary where
  unresolvedFacts : List ProcedureFact
  missingRequirements : List Requirement
deriving DecidableEq, Repr

def summarizePartialChecks
    (checks : List PartialRequirementCheck) : PacketCheckSummary := {
  unresolvedFacts :=
    dedupStable (checks.flatMap (·.unresolvedFacts))
  missingRequirements :=
    dedupStable (checks.flatMap (·.missingRequirement))
}

def packetChecks
    (route : CourtRoute) (context : PartialProcedureContext)
    (case : PartialTransferCase) (packet : PartialPacket route) :
    PacketCheckSummary :=
  match route with
  | .personalPropertyAffidavit =>
      summarizePartialChecks <|
        personalPartialRequirementChecks context case packet
  | .smallValueRealPropertyAffidavit =>
      summarizePartialChecks <|
        smallRealPartialRequirementChecks context case packet
  | .primaryResidencePetition =>
      summarizePartialChecks <|
        primaryPartialRequirementChecks context case packet
  | .spousalPropertyPetition =>
      summarizePartialChecks <|
        spousalPartialRequirementChecks context case packet
```
```

For every applicable item:

- `.present` contributes nothing;
- `.absent` contributes its `Requirement`;
- `.unknown` contributes `.packetItem requirement`.

For conditional applicability:

- a known `false` applicability fact contributes nothing;
- a known `true` applicability fact evaluates the item state; and
- an unknown applicability fact contributes the matching
  `.context ProcedureContextField`.

Implement:

```lean
def assessPacket
    (route : CourtRoute) (context : PartialProcedureContext)
    (case : PartialTransferCase) (packet : PartialPacket route) :
    Except CaseError ReadinessAssessment := do
  let routeStatus ← assessRoute case route.toSimplifiedRoute
  match routeStatus with
  | .doesNotQualify reasons =>
      pure <| .ineligible reasons
  | .qualifies =>
      let summary := packetChecks route context case packet
      if summary.unresolvedFacts = [] ∧
          summary.missingRequirements = [] then
        pure .ready
      else
        pure <| .incomplete {
          unresolvedFacts := dedupStable summary.unresolvedFacts
          missingRequirements :=
            dedupStable summary.missingRequirements
        }
  | .needsInformation facts =>
      let summary := packetChecks route context case packet
      pure <| .incomplete {
        unresolvedFacts :=
          dedupStable (facts.map ProcedureFact.eligibility ++
            summary.unresolvedFacts)
        missingRequirements :=
          dedupStable summary.missingRequirements
      }
```

Use the corrected `needsSmallRealWillAttachment` rule when both relevant
partial facts are known. If either is unknown and the other does not already
make the conjunction false, report the unresolved field.

- [ ] **Step 6: Define partial packet completions**

Define:

```lean
def PacketItemState.Completes : PacketItemState → Bool → Prop
  | .unknown, _ => True
  | .absent, supplied => supplied = false
  | .present, supplied => supplied = true
```

Define `PartialProcedureContext.Completes` pointwise with
`Knowledge.Completes`. Define one pointwise `Completes` predicate for each
partial packet record and its total counterpart.

Define the indexed completion relation:

```lean
def PartialPacketCompletes
    (route : CourtRoute) (partial : PartialPacket route)
    (total : TotalPacket route) : Prop :=
  match route with
  | .personalPropertyAffidavit =>
      PartialPersonalAffidavitPacket.Completes partial total
  | .smallValueRealPropertyAffidavit =>
      PartialSmallRealPropertyPacket.Completes partial total
  | .primaryResidencePetition =>
      PartialPrimaryResidencePetitionPacket.Completes partial total
  | .spousalPropertyPetition =>
      PartialSpousalPetitionPacket.Completes partial total
```

Prove every total conversion completes itself:

```lean
theorem partialPersonal_ofTotal_completes
    (packet : PersonalAffidavitPacket) :
    packet.toPartial.Completes packet := by
  cases packet <;>
    simp [PersonalAffidavitPacket.toPartial,
      PartialPersonalAffidavitPacket.Completes,
      PacketItemState.Completes]
```

Add matching theorems for the other three packet types and for procedure
context.

- [ ] **Step 7: Prove readiness soundness and total exactness**

For total conversions, prove the indexed theorem:

```lean
theorem assessPacket_ofTotal_ready_iff
    (route : CourtRoute) (context : ProcedureContext)
    (case : TransferCase) (packet : TotalPacket route) :
    assessPacket route context.toPartial case.toPartial
        (TotalPacket.toPartial route packet) = .ok .ready ↔
      CourtReady route context case packet
```

Use `assessRoute_ofTotal_qualifies_iff`,
the four route-specific missing-list/readiness equivalences, and the conversion
lemmas. Prove by cases on `route`; each branch reduces to its route-specific
theorem.

For partial inputs, prove:

```lean
theorem assessPacket_ready_all_completions
    {route : CourtRoute}
    {partialContext : PartialProcedureContext}
    {partialCase : PartialTransferCase}
    {partialPacket : PartialPacket route}
    (result :
      assessPacket route partialContext partialCase
        partialPacket = .ok .ready) :
    ∀ totalContext totalCase (totalPacket : TotalPacket route),
      partialContext.Completes totalContext →
      partialCase.Completes totalCase →
      PartialPacketCompletes route partialPacket totalPacket →
      TransferCase.WellFormed totalCase →
      CourtReady route totalContext totalCase totalPacket
```

Prove by cases on `route`; use `assessRoute_qualifies_all_completions` for the
route predicate and the matching route's partial-check completion lemmas for
each required packet item.

Prove exact diagnostic membership for each route-specific `packetChecks`
function. The personal theorem is:

```lean
theorem mem_personalPacket_unresolved_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialPersonalAffidavitPacket)
    (fact : ProcedureFact) :
    fact ∈
      (personalPacketChecks context case packet).unresolvedFacts ↔
    ∃ check ∈ personalPartialRequirementChecks context case packet,
      (check.applies = .unknown ∧
        fact ∈ check.applicabilityFacts) ∨
      (check.applies = .known true ∧
        check.item = .unknown ∧
        check.supplyFact = fact)

theorem mem_personalPacket_missing_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialPersonalAffidavitPacket)
    (requirement : Requirement) :
    requirement ∈
      (personalPacketChecks context case packet).missingRequirements ↔
    ∃ check ∈ personalPartialRequirementChecks context case packet,
      check.requirement = requirement ∧
      check.applies = .known true ∧
      check.item = .absent
```

Build each route's partial check list in the same requirement order as its
total check list from Task 6. Add the two matching membership theorems for
small real, primary residence, and spousal packets. Prove them by induction
over the concrete check list and cases on `applies` and `item`.

- [ ] **Step 8: Expose modules and verify**

Add:

```lean
import SimpleProbate.ProcedureAssessment
```

to `SimpleProbate.lean`. Import each focused example module from
`SimpleProbate/Examples.lean` so `lake build` checks them.

Run:

```bash
lake env lean SimpleProbate/ProcedureAssessment.lean
lake env lean SimpleProbate/Examples/ProcedureAssessment.lean
lake build
```

Expected: all succeed. Confirm unknown certificate and absent certificate
produce different lists, while the complete packet returns `ready`.

- [ ] **Step 9: Commit partial readiness**

```bash
git add SimpleProbate/ProcedureAssessment.lean SimpleProbate/Examples/ProcedureAssessment.lean SimpleProbate/Examples.lean SimpleProbate.lean
git commit -m "feat: assess incomplete probate packets"
```

---

### Task 8: Public API Documentation and Full Proof Verification

**Files:**
- Modify: `README.md`
- Modify: `SimpleProbate.lean`
- Modify: `Main.lean` only if imports require it
- Modify: `.github/workflows/lean_action_ci.yml` only if it does not already run `lake build`

**Interfaces:**
- Consumes all completed production modules and proof examples.
- Produces a documented, build-checked public API and final verification
  evidence.

- [ ] **Step 1: Add a README API example before editing prose**

Add a compile-checked example to
`SimpleProbate/Examples/EligibilityAssessment.lean` that matches the README
snippet:

```lean
example :
    (assessRoutes personalCase.toPartial).map (fun assessment =>
      assessment.routes.find? (fun report =>
        report.route == .personalPropertyAffidavit)) =
    .ok (some {
      route := .personalPropertyAffidavit
      status := .qualifies
    }) := by decide
```

Run:

```bash
lake env lean SimpleProbate/Examples/EligibilityAssessment.lean
```

Expected: success. This prevents documentation from advertising an uncompiled
API shape.

- [ ] **Step 2: Document the public API**

Update `README.md` with:

- `assessRoutes : PartialTransferCase → Except CaseError CaseAssessment`;
- the meanings of `qualifies`, `doesNotQualify`, and `needsInformation`;
- the fact that all simplified routes are reported independently;
- fallback semantics;
- `assessPacket` with its dependent `CourtRoute` packet type and
  `PartialProcedureContext`;
- unknown versus absent packet items;
- current gross versus date-of-death value fields;
- the aggregate employment-compensation exclusion;
- invalid-date, post-snapshot, and malformed-case errors;
- the exact route, fallback, completion-soundness, and packet iff theorems; and
- the existing educational-model disclaimer.

Use the compile-checked example from Step 1 verbatim in the README.

- [ ] **Step 3: Check public imports and CI**

Ensure `SimpleProbate.lean` imports, in dependency order:

```lean
import SimpleProbate.Date
import SimpleProbate.Thresholds
import SimpleProbate.Decision
import SimpleProbate.Estate
import SimpleProbate.Case
import SimpleProbate.Eligibility
import SimpleProbate.Procedure
import SimpleProbate.ProcedureAssessment
import SimpleProbate.Examples
```

Inspect `.github/workflows/lean_action_ci.yml`. If it already invokes
`lake build`, leave it unchanged. If it does not, set its project build step to
exactly:

```yaml
- name: Build Lean project
  run: lake build
```

Keep `Main.lean` informational and retain:

```text
California simple-transfer formalization — sources as of: 2026-07-28; supported death dates through: 2026-12-31
```

- [ ] **Step 4: Run the complete verification suite**

Run:

```bash
lake env lean SimpleProbate/Decision.lean
lake env lean SimpleProbate/Estate.lean
lake env lean SimpleProbate/Case.lean
lake env lean SimpleProbate/Eligibility.lean
lake env lean SimpleProbate/Procedure.lean
lake env lean SimpleProbate/ProcedureAssessment.lean
lake env lean SimpleProbate/Examples/Decision.lean
lake env lean SimpleProbate/Examples/Valuation.lean
lake env lean SimpleProbate/Examples/Case.lean
lake env lean SimpleProbate/Examples/EligibilityAssessment.lean
lake env lean SimpleProbate/Examples/ProcedureExactness.lean
lake env lean SimpleProbate/Examples/ProcedureAssessment.lean
lake env lean SimpleProbate/Examples.lean
lake build
lake exe simple-probate
git diff --check
```

Expected:

- every Lean command exits zero;
- `lake build` reports success;
- the executable prints the unchanged snapshot and endpoint line; and
- `git diff --check` produces no output.

- [ ] **Step 5: Scan for prohibited declarations**

Run:

```bash
rg -n '\b(sorry|admit|axiom|unsafe)\b' --glob '*.lean' .
```

Expected: exit status 1 with no matches. Any match is a release blocker.

- [ ] **Step 6: Confirm theorem and requirement coverage**

Run:

```bash
rg -n 'assessRoute_ofTotal_qualifies_iff|assessRoute_ofTotal_disqualified_iff|assessRoutes_ofTotal_fallback_iff|assessRoute_qualifies_all_completions|assessRoute_disqualified_no_completion|personalAffidavitMissing_empty_iff_ready|smallRealPropertyAffidavitMissing_empty_iff_ready|primaryResidencePetitionMissing_empty_iff_ready|spousalPetitionMissing_empty_iff_ready|assessPacket_ofTotal_ready_iff|assessPacket_ready_all_completions' SimpleProbate
```

Expected matches:

- total positive and negative route exactness;
- total fallback exactness;
- partial qualification and disqualification soundness;
- four total missing-list/readiness iff theorems;
- one route-indexed total packet assessment iff theorem covering all four
  `CourtRoute` constructors; and
- one route-indexed partial packet readiness theorem covering all four
  `CourtRoute` constructors.

If route-specific theorem names use lower-case prefixes, adjust only the search
case, not the proof obligations.

- [ ] **Step 7: Review the final diff against the approved spec**

Run:

```bash
git diff --stat 8fb31dc..HEAD
git diff --check
git status --short
```

Inspect every changed file and confirm:

- no route or existing boundary example was dropped;
- no unknown value is converted to false;
- no fallback is emitted for unresolved cases;
- packet absence and packet uncertainty remain distinct;
- total specifications do not depend on executable report equality;
- no post-2026 threshold was added; and
- README names match the compiled API.

- [ ] **Step 8: Commit the integrated API and documentation**

```bash
git add README.md SimpleProbate.lean Main.lean .github/workflows/lean_action_ci.yml SimpleProbate/Examples/EligibilityAssessment.lean
git commit -m "docs: publish exact partial probate API"
```

If `Main.lean` or the workflow did not change, omit the unchanged path from
`git add`.

- [ ] **Step 9: Record final repository state**

Run:

```bash
git status --short --branch
git log -8 --oneline --decorate
```

Expected: a clean worktree and one focused commit for each task in this plan.
