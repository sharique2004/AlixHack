# California Simple Transfer 2026 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an executable, theorem-backed Lean 4 formalization of the California probate simple-transfer process and limits in force during 2026.

**Architecture:** Separate date and threshold rules, estate valuation, route eligibility, and procedural readiness into focused Lean modules. Expose computable queries backed by Prop-valued predicates, then compile concrete boundary examples and document source-to-definition traceability.

**Tech Stack:** Lean 4.32.1, Lake, Lean core/Std only, Markdown

## Global Constraints

- Work in the existing `simple-probate` Lean project; do not add external Lean dependencies.
- Represent `Money` as a natural number of U.S. cents.
- Treat December 31, 2026 as the legal snapshot boundary; post-2026 dates return an explicit unsupported result.
- Use gross date-of-death values; debts, mortgages, liens, and encumbrances never reduce an eligibility value.
- Preserve these April 1, 2025 through December 31, 2026 values exactly: family set-aside $107,900; employment-compensation exclusion $20,875; personal-property affidavit $208,850; primary-residence petition $750,000; small-value real-property affidavit $69,625; surviving-spouse earnings $20,875.
- Candidate routes are nonexclusive and asset-specific.
- Name the fallback `formalProbateOrOtherProcedure`; never assert that formal probate is necessarily required.
- Treat ownership, value, successor status, primary-residence status, consent, document truth, notice, and external official acts as supplied facts.
- Do not use `sorry`, `admit`, `axiom`, or `unsafe`.
- `lake build` must compile all public modules and theorem examples.
- Use one-shot `git -c commit.gpgsign=false commit` commands because the configured 1Password signing socket is unavailable; do not change global Git configuration.

---

### Task 1: Civil Dates and 2026 Threshold Schedule

**Files:**
- Create: `SimpleProbate/Date.lean`
- Create: `SimpleProbate/Thresholds.lean`
- Create: `SimpleProbate/Examples.lean`
- Modify: `SimpleProbate.lean`

**Interfaces:**
- Consumes: no project interfaces beyond Lean core/Std.
- Produces: `Money`, `Money.dollars`, `CivilDate`, `CivilDate.valid`, `CivilDate.before`, `DateError`, `DeathBand`, `classifyDeathDate`, `Thresholds`, and `thresholdsFor`.

- [ ] **Step 1: Write the failing date and threshold examples**

Create `SimpleProbate/Examples.lean` with imports of the not-yet-created
modules and exact boundary expectations:

```lean
import SimpleProbate.Date
import SimpleProbate.Thresholds

namespace SimpleProbate.Examples

open SimpleProbate

example : classifyDeathDate ⟨2022, 3, 31⟩ = .ok .beforeApr2022 := by decide
example : classifyDeathDate ⟨2022, 4, 1⟩ = .ok .apr2022ToMar2025 := by decide
example : classifyDeathDate ⟨2025, 3, 31⟩ = .ok .apr2022ToMar2025 := by decide
example : classifyDeathDate ⟨2025, 4, 1⟩ = .ok .apr2025ToDec2026 := by decide
example : classifyDeathDate ⟨2026, 12, 31⟩ = .ok .apr2025ToDec2026 := by decide
example : classifyDeathDate ⟨2027, 1, 1⟩ = .error .afterSnapshot := by decide
example : classifyDeathDate ⟨2026, 2, 29⟩ = .error .invalidDate := by decide

example :
    thresholdsFor ⟨2026, 7, 28⟩ =
      .ok {
        familySetAside := Money.dollars 107_900
        employmentCompensationExclusion := Money.dollars 20_875
        personalPropertyAffidavit := Money.dollars 208_850
        primaryResidencePetition := Money.dollars 750_000
        smallValueRealPropertyAffidavit := Money.dollars 69_625
        survivingSpouseEarnings := Money.dollars 20_875
      } := by decide

end SimpleProbate.Examples
```

- [ ] **Step 2: Run the examples and verify the imports fail**

Run:

```bash
lake env lean SimpleProbate/Examples.lean
```

Expected: failure reporting that `SimpleProbate.Date` or
`SimpleProbate.Thresholds` cannot be found.

- [ ] **Step 3: Implement civil-date validation and snapshot classification**

Create `SimpleProbate/Date.lean` with this public surface and a total Gregorian
validity check:

```lean
import Std

namespace SimpleProbate

structure CivilDate where
  year : Nat
  month : Nat
  day : Nat
deriving DecidableEq, Repr

def CivilDate.key (d : CivilDate) : Nat × Nat × Nat :=
  (d.year, d.month, d.day)

def CivilDate.before (a b : CivilDate) : Bool :=
  decide (a.key < b.key)

def CivilDate.atMost (a b : CivilDate) : Bool :=
  decide (a.key ≤ b.key)

def CivilDate.isLeapYear (year : Nat) : Bool :=
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)

def CivilDate.daysInMonth (year month : Nat) : Nat :=
  match month with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
  | 4 | 6 | 9 | 11 => 30
  | 2 => if CivilDate.isLeapYear year then 29 else 28
  | _ => 0

def CivilDate.valid (d : CivilDate) : Bool :=
  decide (1 ≤ d.month) &&
  decide (d.month ≤ 12) &&
  decide (1 ≤ d.day) &&
  decide (d.day ≤ CivilDate.daysInMonth d.year d.month)

inductive DateError
  | invalidDate
  | afterSnapshot
deriving DecidableEq, Repr

inductive DeathBand
  | beforeApr2022
  | apr2022ToMar2025
  | apr2025ToDec2026
deriving DecidableEq, Repr

def apr1_2022 : CivilDate := ⟨2022, 4, 1⟩
def apr1_2025 : CivilDate := ⟨2025, 4, 1⟩
def snapshotEnd : CivilDate := ⟨2026, 12, 31⟩

def classifyDeathDate (date : CivilDate) : Except DateError DeathBand :=
  if !date.valid then
    .error .invalidDate
  else if !date.atMost snapshotEnd then
    .error .afterSnapshot
  else if date.before apr1_2022 then
    .ok .beforeApr2022
  else if date.before apr1_2025 then
    .ok .apr2022ToMar2025
  else
    .ok .apr2025ToDec2026

end SimpleProbate
```

- [ ] **Step 4: Implement the exact dated threshold table**

Create `SimpleProbate/Thresholds.lean`:

```lean
import SimpleProbate.Date

namespace SimpleProbate

abbrev Money := Nat

namespace Money

def dollars (amount : Nat) : Money := amount * 100

end Money

structure Thresholds where
  familySetAside : Money
  employmentCompensationExclusion : Money
  personalPropertyAffidavit : Money
  primaryResidencePetition : Money
  smallValueRealPropertyAffidavit : Money
  survivingSpouseEarnings : Money
deriving DecidableEq, Repr

def thresholdsForBand : DeathBand → Thresholds
  | .beforeApr2022 => {
      familySetAside := Money.dollars 85_900
      employmentCompensationExclusion := Money.dollars 16_625
      personalPropertyAffidavit := Money.dollars 166_250
      primaryResidencePetition := Money.dollars 166_250
      smallValueRealPropertyAffidavit := Money.dollars 55_425
      survivingSpouseEarnings := Money.dollars 16_625
    }
  | .apr2022ToMar2025 => {
      familySetAside := Money.dollars 95_325
      employmentCompensationExclusion := Money.dollars 18_450
      personalPropertyAffidavit := Money.dollars 184_500
      primaryResidencePetition := Money.dollars 184_500
      smallValueRealPropertyAffidavit := Money.dollars 61_500
      survivingSpouseEarnings := Money.dollars 18_450
    }
  | .apr2025ToDec2026 => {
      familySetAside := Money.dollars 107_900
      employmentCompensationExclusion := Money.dollars 20_875
      personalPropertyAffidavit := Money.dollars 208_850
      primaryResidencePetition := Money.dollars 750_000
      smallValueRealPropertyAffidavit := Money.dollars 69_625
      survivingSpouseEarnings := Money.dollars 20_875
    }

def thresholdsFor (date : CivilDate) : Except DateError Thresholds :=
  (classifyDeathDate date).map thresholdsForBand

end SimpleProbate
```

- [ ] **Step 5: Export the modules and run the tests**

Replace `SimpleProbate.lean` with:

```lean
import SimpleProbate.Date
import SimpleProbate.Thresholds
import SimpleProbate.Examples
```

Run:

```bash
lake env lean SimpleProbate/Examples.lean
lake build
```

Expected: both commands exit successfully and all seven date examples plus the
2026 threshold example compile.

- [ ] **Step 6: Commit Task 1**

```bash
git add SimpleProbate.lean SimpleProbate/Date.lean SimpleProbate/Thresholds.lean SimpleProbate/Examples.lean
git -c commit.gpgsign=false commit -m "feat: encode 2026 probate threshold schedule"
```

---

### Task 2: Estate Assets, Exclusions, and Gross Valuation

**Files:**
- Create: `SimpleProbate/Estate.lean`
- Modify: `SimpleProbate/Examples.lean`
- Modify: `SimpleProbate.lean`

**Interfaces:**
- Consumes: `Money`, `CivilDate`, `DateError`, and `thresholdsFor` from Task 1.
- Produces: `PropertyKind`, `ValuationTreatment`, `DirectTransferBasis`,
  `Asset`, `Estate`, `Asset.directTransferBasis`,
  `Estate.personalAffidavitValue`, `Estate.smallValueRealPropertyValue`,
  `Estate.primaryResidenceValue`, and
  `Estate.containsCountedCaliforniaRealProperty`.

- [ ] **Step 1: Add failing estate-valuation examples**

Append these declarations inside `namespace SimpleProbate.Examples`:

```lean
def countedPersonal (name : String) (gross encumbrances : Money) : Asset := {
  name := name
  kind := .personal
  grossValue := gross
  encumbrances := encumbrances
  treatment := .counted
}

def estateAtPersonalCap : Estate := {
  assets := [
    countedPersonal "account" (Money.dollars 208_850) (Money.dollars 80_000)
  ]
}

example :
    estateAtPersonalCap.personalAffidavitValue ⟨2026, 7, 28⟩ =
      .ok (Money.dollars 208_850) := by decide

example :
    ({ assets := [
      countedPersonal "account" (Money.dollars 100_000) (Money.dollars 99_000),
      { countedPersonal "joint account" (Money.dollars 500_000) 0 with
        treatment := .jointTenancy }
    ] } : Estate).personalAffidavitValue ⟨2026, 7, 28⟩ =
      .ok (Money.dollars 100_000) := by decide

example :
    ({ assets := [
      { countedPersonal "salary" (Money.dollars 30_875) 0 with
        treatment := .employmentCompensation }
    ] } : Estate).personalAffidavitValue ⟨2026, 7, 28⟩ =
      .ok (Money.dollars 10_000) := by decide

example :
    ({ assets := [
      { countedPersonal "military pay" (Money.dollars 100_000) 0 with
        treatment := .militaryCompensation }
    ] } : Estate).personalAffidavitValue ⟨2026, 7, 28⟩ = .ok 0 := by decide

example :
    ({ assets := [{
      name := "California parcel"
      kind := .californiaReal
      grossValue := Money.dollars 69_625
      encumbrances := Money.dollars 60_000
      treatment := .counted
    }] } : Estate).smallValueRealPropertyValue = Money.dollars 69_625 := by decide
```

- [ ] **Step 2: Run the examples and verify the estate symbols are missing**

Run:

```bash
lake env lean SimpleProbate/Examples.lean
```

Expected: failure reporting unknown identifiers including `Asset` and `Estate`.

- [ ] **Step 3: Implement the asset model and direct-transfer classification**

Create `SimpleProbate/Estate.lean` with these exact public declarations:

```lean
import SimpleProbate.Thresholds

namespace SimpleProbate

inductive PropertyKind
  | personal
  | californiaReal
  | outsideCaliforniaReal
deriving BEq, DecidableEq, Repr

inductive ValuationTreatment
  | counted
  | jointTenancy
  | terminableAtDeath
  | revocableTrust
  | spousePassage
  | multiplePartySurvivor
  | registeredVehicle
  | vessel
  | registeredHome
  | directBeneficiary
  | transferOnDeath
  | governmentBenefit
  | militaryCompensation
  | employmentCompensation
deriving BEq, DecidableEq, Repr

inductive DirectTransferBasis
  | governmentBenefit
  | namedBeneficiary
  | revocableTrust
  | jointTenancy
  | transferOnDeath
  | multiplePartyAccount
  | spousePassage
deriving BEq, DecidableEq, Repr

structure Asset where
  name : String
  kind : PropertyKind
  grossValue : Money
  encumbrances : Money := 0
  treatment : ValuationTreatment := .counted
  includedInPrimaryResidencePetition : Bool := false
  isPrimaryResidence : Bool := false
deriving DecidableEq, Repr

structure Estate where
  assets : List Asset
deriving DecidableEq, Repr

def Asset.directTransferBasis (asset : Asset) : Option DirectTransferBasis :=
  match asset.treatment with
  | .governmentBenefit => some .governmentBenefit
  | .directBeneficiary => some .namedBeneficiary
  | .revocableTrust => some .revocableTrust
  | .jointTenancy => some .jointTenancy
  | .transferOnDeath => some .transferOnDeath
  | .multiplePartySurvivor => some .multiplePartyAccount
  | .spousePassage => some .spousePassage
  | _ => none
```

Keep `encumbrances` as descriptive data only. No valuation function may subtract
it.

- [ ] **Step 4: Implement the three statutory aggregations**

Continue `SimpleProbate/Estate.lean` with:

```lean
def Asset.personalAffidavitValue
    (thresholds : Thresholds) (asset : Asset) : Money :=
  if asset.kind == .outsideCaliforniaReal ||
      asset.includedInPrimaryResidencePetition then
    0
  else
    match asset.treatment with
    | .counted => asset.grossValue
    | .employmentCompensation =>
        asset.grossValue - min asset.grossValue thresholds.employmentCompensationExclusion
    | _ => 0

def Estate.personalAffidavitValue
    (estate : Estate) (date : CivilDate) : Except DateError Money := do
  let thresholds ← thresholdsFor date
  pure <| estate.assets.foldl
    (fun total asset => total + asset.personalAffidavitValue thresholds) 0

def Asset.countedCaliforniaRealValue (asset : Asset) : Money :=
  if asset.kind == .californiaReal && asset.treatment == .counted then
    asset.grossValue
  else
    0

def Estate.smallValueRealPropertyValue (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset => total + asset.countedCaliforniaRealValue) 0

def Asset.countedPrimaryResidenceValue (asset : Asset) : Money :=
  if asset.kind == .californiaReal &&
      asset.treatment == .counted &&
      asset.isPrimaryResidence then
    asset.grossValue
  else
    0

def Estate.primaryResidenceValue (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset => total + asset.countedPrimaryResidenceValue) 0

def Estate.containsCountedCaliforniaRealProperty (estate : Estate) : Bool :=
  estate.assets.any
    (fun asset => asset.kind == .californiaReal && asset.treatment == .counted)

end SimpleProbate
```

- [ ] **Step 5: Export Estate and verify gross-value behavior**

Add `import SimpleProbate.Estate` before the Examples import in
`SimpleProbate.lean`, and add `import SimpleProbate.Estate` to
`SimpleProbate/Examples.lean`.

Run:

```bash
lake env lean SimpleProbate/Examples.lean
lake build
```

Expected: success. The encumbered $208,850 account still counts as $208,850;
the joint-tenancy asset counts as zero; only $10,000 of the $30,875 salary
counts; military pay counts as zero; and the encumbered real parcel still
counts at its $69,625 gross value.

- [ ] **Step 6: Commit Task 2**

```bash
git add SimpleProbate.lean SimpleProbate/Estate.lean SimpleProbate/Examples.lean
git -c commit.gpgsign=false commit -m "feat: formalize small-estate valuation exclusions"
```

---

### Task 3: Eligibility Predicates and Candidate Routes

**Files:**
- Create: `SimpleProbate/Eligibility.lean`
- Modify: `SimpleProbate/Examples.lean`
- Modify: `SimpleProbate.lean`

**Interfaces:**
- Consumes: all Task 1 and Task 2 public interfaces.
- Produces: `SummaryAuthority`, `SummaryAuthority.Permits`,
  `SurvivorStatus`, `TransferCase`, `Route`, the four statutory eligibility
  predicates, `DirectTransferEligible`, `SpousalPropertyPetitionEligible`,
  `RouteEligible`, `routeEligible`, `nonFallbackRoutes`, `candidateRoutes`, and
  `candidateRoutes_sound`.

- [ ] **Step 1: Add failing eligibility and boundary examples**

Append:

```lean
def personalTarget : Asset :=
  countedPersonal "account" (Money.dollars 208_850) 0

def base2026Case : TransferCase := {
  deathDate := ⟨2026, 1, 1⟩
  estate := { assets := [personalTarget] }
  target := personalTarget
  targetIsPartOfEstate := true
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

example : PersonalPropertyAffidavitEligible base2026Case := by decide
example : !routeEligible { base2026Case with daysSinceDeath := 39 }
    .personalPropertyAffidavit := by decide
example : routeEligible { base2026Case with
    authority := .writtenPersonalRepresentativeConsent }
    .personalPropertyAffidavit := by decide
example : !routeEligible { base2026Case with
    estate := { assets := [
      { personalTarget with grossValue := Money.dollars 208_850 + 1 }
    ] } }
    .personalPropertyAffidavit := by decide

def smallRealTarget : Asset := {
  name := "small parcel"
  kind := .californiaReal
  grossValue := Money.dollars 69_625
  treatment := .counted
}

example : routeEligible { base2026Case with
    estate := { assets := [smallRealTarget] }
    target := smallRealTarget
    sixMonthsElapsed := true }
    .smallValueRealPropertyAffidavit := by decide

example : !routeEligible { base2026Case with
    estate := { assets := [smallRealTarget] }
    target := smallRealTarget
    sixMonthsElapsed := false }
    .smallValueRealPropertyAffidavit := by decide

def primaryResidenceTarget : Asset := {
  name := "primary residence"
  kind := .californiaReal
  grossValue := Money.dollars 750_000
  treatment := .counted
  includedInPrimaryResidencePetition := true
  isPrimaryResidence := true
}

example : routeEligible { base2026Case with
    estate := { assets := [primaryResidenceTarget] }
    target := primaryResidenceTarget }
    .primaryResidencePetition := by decide

example : !routeEligible { base2026Case with
    estate := { assets := [
      { primaryResidenceTarget with grossValue := Money.dollars 750_000 + 1 }
    ] }
    target := { primaryResidenceTarget with
      grossValue := Money.dollars 750_000 + 1 } }
    .primaryResidencePetition := by decide

example : routeEligible { base2026Case with
    estate := { assets := [] }
    targetIsPartOfEstate := false
    claimantIsSuccessor := false
    noSuperiorRight := false
    survivorStatus := .spouse
    propertyPassesToSurvivor := true }
    .spousalPropertyPetition := by decide

example :
    candidateRoutes { base2026Case with
      authority := .blockedByProceeding
      daysSinceDeath := 0
      claimantIsSuccessor := false
      noSuperiorRight := false } =
      [.formalProbateOrOtherProcedure] := by decide
```

- [ ] **Step 2: Run the examples and verify eligibility symbols are missing**

Run:

```bash
lake env lean SimpleProbate/Examples.lean
```

Expected: failure reporting unknown identifiers including `TransferCase` and
`routeEligible`.

- [ ] **Step 3: Define shared case facts and route names**

Create `SimpleProbate/Eligibility.lean`:

```lean
import SimpleProbate.Estate

namespace SimpleProbate

inductive SummaryAuthority
  | noProceeding
  | writtenPersonalRepresentativeConsent
  | blockedByProceeding
deriving BEq, DecidableEq, Repr

def SummaryAuthority.Permits : SummaryAuthority → Prop
  | .noProceeding => True
  | .writtenPersonalRepresentativeConsent => True
  | .blockedByProceeding => False

instance (authority : SummaryAuthority) : Decidable authority.Permits :=
  match authority with
  | .noProceeding => isTrue trivial
  | .writtenPersonalRepresentativeConsent => isTrue trivial
  | .blockedByProceeding => isFalse id

inductive SurvivorStatus
  | none
  | spouse
  | registeredDomesticPartner
deriving BEq, DecidableEq, Repr

structure TransferCase where
  deathDate : CivilDate
  estate : Estate
  target : Asset
  targetIsPartOfEstate : Bool
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

inductive Route
  | directTransfer (basis : DirectTransferBasis)
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
  | formalProbateOrOtherProcedure
deriving BEq, DecidableEq, Repr
```

- [ ] **Step 4: Implement Prop-valued eligibility predicates**

Continue the file with predicates having these exact conditions:

```lean
def DirectTransferEligible
    (case : TransferCase) (basis : DirectTransferBasis) : Prop :=
  case.target.directTransferBasis = some basis

def PersonalPropertyAffidavitEligible (case : TransferCase) : Prop :=
  case.target.kind = .personal ∧
  case.targetIsPartOfEstate = true ∧
  case.claimantIsSuccessor = true ∧
  case.noSuperiorRight = true ∧
  40 ≤ case.daysSinceDeath ∧
  case.authority.Permits ∧
  match case.estate.personalAffidavitValue case.deathDate,
      thresholdsFor case.deathDate with
  | .ok value, .ok thresholds =>
      value ≤ thresholds.personalPropertyAffidavit
  | _, _ => False

def SmallValueRealPropertyAffidavitEligible (case : TransferCase) : Prop :=
  case.target.kind = .californiaReal ∧
  case.target.treatment = .counted ∧
  case.targetIsPartOfEstate = true ∧
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

def PrimaryResidencePetitionEligible (case : TransferCase) : Prop :=
  case.target.kind = .californiaReal ∧
  case.target.treatment = .counted ∧
  case.target.isPrimaryResidence = true ∧
  case.targetIsPartOfEstate = true ∧
  case.claimantIsSuccessor = true ∧
  40 ≤ case.daysSinceDeath ∧
  case.authority.Permits ∧
  match thresholdsFor case.deathDate with
  | .ok thresholds =>
      case.estate.primaryResidenceValue ≤ thresholds.primaryResidencePetition
  | .error _ => False

def SpousalPropertyPetitionEligible (case : TransferCase) : Prop :=
  case.survivorStatus ≠ .none ∧
  (case.propertyPassesToSurvivor = true ∨
   case.propertyBelongsToSurvivor = true)
```

Define:

```lean
def RouteEligible (case : TransferCase) : Route → Prop
  | .directTransfer basis => DirectTransferEligible case basis
  | .personalPropertyAffidavit => PersonalPropertyAffidavitEligible case
  | .smallValueRealPropertyAffidavit =>
      SmallValueRealPropertyAffidavitEligible case
  | .primaryResidencePetition => PrimaryResidencePetitionEligible case
  | .spousalPropertyPetition => SpousalPropertyPetitionEligible case
  | .formalProbateOrOtherProcedure => nonFallbackRoutes case = []
```

Place `nonFallbackRoutes` before `RouteEligible` in the final file so the
definition is nonrecursive.

- [ ] **Step 5: Implement route computation and its soundness theorem**

Use this ordered basis list and route order:

```lean
def directTransferBases : List DirectTransferBasis := [
  .governmentBenefit,
  .namedBeneficiary,
  .revocableTrust,
  .jointTenancy,
  .transferOnDeath,
  .multiplePartyAccount,
  .spousePassage
]

def routeEligibleNonFallback (case : TransferCase) : Route → Bool
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

def nonFallbackRoutes (case : TransferCase) : List Route :=
  (directTransferBases.map Route.directTransfer ++ [
    .personalPropertyAffidavit,
    .smallValueRealPropertyAffidavit,
    .primaryResidencePetition,
    .spousalPropertyPetition
  ]).filter (routeEligibleNonFallback case)

def candidateRoutes (case : TransferCase) : List Route :=
  if nonFallbackRoutes case = [] then
    [.formalProbateOrOtherProcedure]
  else
    nonFallbackRoutes case

def routeEligible (case : TransferCase) (route : Route) : Bool :=
  decide (RouteEligible case route)

theorem candidateRoutes_sound
    {case : TransferCase} {route : Route}
    (membership : route ∈ candidateRoutes case) :
    RouteEligible case route := by
  unfold candidateRoutes at membership
  split at membership
  next noRoutes =>
    have routeIsFallback : route = .formalProbateOrOtherProcedure := by
      simpa using membership
    subst route
    simpa [RouteEligible] using noRoutes
  next someRoute =>
    have eligibleCheck :
        routeEligibleNonFallback case route = true :=
      (List.mem_filter.mp membership).2
    cases route <;>
      simpa [routeEligibleNonFallback, RouteEligible] using eligibleCheck
```

- [ ] **Step 6: Export Eligibility and verify all route boundaries**

Add `import SimpleProbate.Eligibility` before the Examples import in
`SimpleProbate.lean`, and add the same import to `Examples.lean`.

Run:

```bash
lake env lean SimpleProbate/Examples.lean
lake build
```

Expected: success for the exact cap, one-cent-over, 39/40-day, six-month,
written-consent, $750,000 primary-residence, value-independent spousal, and
fallback examples.

- [ ] **Step 7: Commit Task 3**

```bash
git add SimpleProbate.lean SimpleProbate/Eligibility.lean SimpleProbate/Examples.lean
git -c commit.gpgsign=false commit -m "feat: decide simple-transfer eligibility routes"
```

---

### Task 4: Procedural Packets, Missing Requirements, and Ordered Workflows

**Files:**
- Create: `SimpleProbate/Procedure.lean`
- Modify: `SimpleProbate/Examples.lean`
- Modify: `SimpleProbate.lean`

**Interfaces:**
- Consumes: `TransferCase`, all route predicates, `classifyDeathDate`, and
  `Estate.containsCountedCaliforniaRealProperty`.
- Produces: `ProcedureContext`, four packet structures, four readiness
  predicates, `Requirement`, four missing-requirement functions,
  `WorkflowStage`, and `workflowFor`.

- [ ] **Step 1: Add failing packet and workflow examples**

Append:

```lean
def baseProcedureContext : ProcedureContext := {
  claimsUnderWill := false
  ownershipEvidenceAvailable := true
  hasOtherEntitledSuccessors := false
  knownGuardianOrConservator := false
  institutionRequiresNotary := false
  propertyAgreementExists := false
}

def completePersonalPacket : PersonalAffidavitPacket := {
  affidavitDeclarations := true
  certifiedDeathCertificate := true
  identityProof := true
  ownershipEvidencePresented := true
  holderIndemnityAlternative := false
  allEntitledSuccessorsSigned := true
  notarized := false
  consentAndLettersAttached := true
  datedAmountListAttached := true
  inventoryAndAppraisalAttached := true
  presentedToHolder := true
}

example :
    PersonalAffidavitReady baseProcedureContext base2026Case
      completePersonalPacket := by decide

example :
    !PersonalAffidavitReady baseProcedureContext base2026Case
      { completePersonalPacket with certifiedDeathCertificate := false } := by decide

example :
    .certifiedDeathCertificate ∈
      personalAffidavitMissing baseProcedureContext base2026Case
        { completePersonalPacket with certifiedDeathCertificate := false } := by decide

example :
    PersonalAffidavitReady
      { baseProcedureContext with institutionRequiresNotary := false }
      base2026Case
      { completePersonalPacket with notarized := false } := by decide

example :
    !PersonalAffidavitReady
      { baseProcedureContext with institutionRequiresNotary := true }
      base2026Case
      { completePersonalPacket with notarized := false } := by decide

example :
    workflowFor .smallValueRealPropertyAffidavit = [
      .assessEligibility,
      .waitForStatutoryPeriod,
      .gatherEvidence,
      .obtainProbateRefereeAppraisal,
      .prepareAffidavit,
      .notarize,
      .fileWithCourt,
      .obtainCertifiedCopy,
      .recordWithCounty
    ] := by decide
```

- [ ] **Step 2: Run the examples and verify procedure symbols are missing**

Run:

```bash
lake env lean SimpleProbate/Examples.lean
```

Expected: failure reporting unknown identifiers including `ProcedureContext`
and `PersonalAffidavitReady`.

- [ ] **Step 3: Define procedure context and packet records**

Create `SimpleProbate/Procedure.lean` and define:

```lean
import SimpleProbate.Eligibility

namespace SimpleProbate

structure ProcedureContext where
  claimsUnderWill : Bool
  ownershipEvidenceAvailable : Bool
  hasOtherEntitledSuccessors : Bool
  knownGuardianOrConservator : Bool
  institutionRequiresNotary : Bool
  propertyAgreementExists : Bool
deriving DecidableEq, Repr

structure PersonalAffidavitPacket where
  affidavitDeclarations : Bool
  certifiedDeathCertificate : Bool
  identityProof : Bool
  ownershipEvidencePresented : Bool
  holderIndemnityAlternative : Bool
  allEntitledSuccessorsSigned : Bool
  notarized : Bool
  consentAndLettersAttached : Bool
  datedAmountListAttached : Bool
  inventoryAndAppraisalAttached : Bool
  presentedToHolder : Bool
deriving DecidableEq, Repr

structure SmallRealPropertyPacket where
  de305Statements : Bool
  notarizedAcknowledgments : Bool
  inventoryAndAppraisalAttached : Bool
  certifiedDeathCertificate : Bool
  willAttached : Bool
  consentAndLettersAttached : Bool
  datedAmountListAttached : Bool
  guardianOrConservatorDelivery : Bool
  filedInProperCourt : Bool
  clerkCertifiedCopyIssued : Bool
  recordedInPropertyCounty : Bool
deriving DecidableEq, Repr

structure PrimaryResidencePetitionPacket where
  de310VerifiedStatements : Bool
  inventoryAndAppraisalAttached : Bool
  willAttached : Bool
  consentAttached : Bool
  datedAmountListAttached : Bool
  filedInProperCourt : Bool
  heirAndDeviseeCopyWithinFiveBusinessDays : Bool
  statutoryHearingNotice : Bool
  courtFindingsMade : Bool
  de315OrderIssued : Bool
deriving DecidableEq, Repr

structure SpousalPetitionPacket where
  de221Allegations : Bool
  propertyDescriptionsAndSupportingFacts : Bool
  knownInterestedPersonsListed : Bool
  propertyAgreementDisclosed : Bool
  willAttached : Bool
  propertyAgreementAttached : Bool
  statutoryHearingNotice : Bool
  de226OrderIssued : Bool
deriving DecidableEq, Repr
```

- [ ] **Step 4: Define conditional obligations and readiness predicates**

Add helpers:

```lean
def suppliedWhen (required supplied : Bool) : Prop :=
  required = false ∨ supplied = true

def needsDatedAmountList (date : CivilDate) : Bool :=
  match classifyDeathDate date with
  | .ok .beforeApr2022 => false
  | .ok _ => true
  | .error _ => true

def needsConsentAttachment (authority : SummaryAuthority) : Bool :=
  authority == .writtenPersonalRepresentativeConsent
```

Implement readiness predicates as conjunctions of eligibility and these exact
obligations:

```lean
def PersonalAffidavitReady
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) : Prop :=
  PersonalPropertyAffidavitEligible case ∧
  packet.affidavitDeclarations = true ∧
  packet.certifiedDeathCertificate = true ∧
  packet.identityProof = true ∧
  (if context.ownershipEvidenceAvailable
    then packet.ownershipEvidencePresented = true
    else packet.holderIndemnityAlternative = true) ∧
  suppliedWhen context.hasOtherEntitledSuccessors
    packet.allEntitledSuccessorsSigned ∧
  suppliedWhen context.institutionRequiresNotary packet.notarized ∧
  suppliedWhen (needsConsentAttachment case.authority)
    packet.consentAndLettersAttached ∧
  suppliedWhen (needsDatedAmountList case.deathDate)
    packet.datedAmountListAttached ∧
  suppliedWhen case.estate.containsCountedCaliforniaRealProperty
    packet.inventoryAndAppraisalAttached ∧
  packet.presentedToHolder = true

def SmallRealPropertyAffidavitReady
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) : Prop :=
  SmallValueRealPropertyAffidavitEligible case ∧
  packet.de305Statements = true ∧
  packet.notarizedAcknowledgments = true ∧
  packet.inventoryAndAppraisalAttached = true ∧
  packet.certifiedDeathCertificate = true ∧
  suppliedWhen context.claimsUnderWill packet.willAttached ∧
  suppliedWhen (needsConsentAttachment case.authority)
    packet.consentAndLettersAttached ∧
  suppliedWhen (needsDatedAmountList case.deathDate)
    packet.datedAmountListAttached ∧
  suppliedWhen context.knownGuardianOrConservator
    packet.guardianOrConservatorDelivery ∧
  packet.filedInProperCourt = true ∧
  packet.clerkCertifiedCopyIssued = true ∧
  packet.recordedInPropertyCounty = true

def PrimaryResidencePetitionReady
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) : Prop :=
  PrimaryResidencePetitionEligible case ∧
  packet.de310VerifiedStatements = true ∧
  packet.inventoryAndAppraisalAttached = true ∧
  suppliedWhen context.claimsUnderWill packet.willAttached ∧
  suppliedWhen (needsConsentAttachment case.authority)
    packet.consentAttached ∧
  suppliedWhen (needsDatedAmountList case.deathDate)
    packet.datedAmountListAttached ∧
  packet.filedInProperCourt = true ∧
  packet.heirAndDeviseeCopyWithinFiveBusinessDays = true ∧
  packet.statutoryHearingNotice = true ∧
  packet.courtFindingsMade = true ∧
  packet.de315OrderIssued = true

def SpousalPetitionReady
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) : Prop :=
  SpousalPropertyPetitionEligible case ∧
  packet.de221Allegations = true ∧
  packet.propertyDescriptionsAndSupportingFacts = true ∧
  packet.knownInterestedPersonsListed = true ∧
  packet.propertyAgreementDisclosed = true ∧
  suppliedWhen context.claimsUnderWill packet.willAttached ∧
  suppliedWhen context.propertyAgreementExists
    packet.propertyAgreementAttached ∧
  packet.statutoryHearingNotice = true ∧
  packet.de226OrderIssued = true
```

- [ ] **Step 5: Implement finite missing-requirement reports**

Define a finite enum containing every readiness label:

```lean
inductive Requirement
  | eligibleRoute
  | affidavitDeclarations
  | certifiedDeathCertificate
  | identityProof
  | ownershipEvidenceOrIndemnity
  | allEntitledSuccessorsSigned
  | notarization
  | consentAndLetters
  | datedAmountList
  | inventoryAndAppraisal
  | presentationToHolder
  | de305Statements
  | willAttachment
  | guardianOrConservatorDelivery
  | properCourtFiling
  | clerkCertifiedCopy
  | countyRecording
  | de310VerifiedStatements
  | heirAndDeviseeCopyWithinFiveBusinessDays
  | statutoryHearingNotice
  | courtFindings
  | de315Order
  | de221Allegations
  | propertyDescriptionsAndSupportingFacts
  | knownInterestedPersons
  | propertyAgreementDisclosure
  | propertyAgreementAttachment
  | de226Order
deriving BEq, DecidableEq, Repr
```

Implement:

```lean
def suppliedWhenBool (required supplied : Bool) : Bool :=
  !required || supplied

def missingUnless (satisfied : Bool) (requirement : Requirement) :
    List Requirement :=
  if satisfied then [] else [requirement]

def personalAffidavitMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) : List Requirement :=
  missingUnless (decide (PersonalPropertyAffidavitEligible case)) .eligibleRoute ++
  missingUnless packet.affidavitDeclarations .affidavitDeclarations ++
  missingUnless packet.certifiedDeathCertificate .certifiedDeathCertificate ++
  missingUnless packet.identityProof .identityProof ++
  missingUnless
    (if context.ownershipEvidenceAvailable
      then packet.ownershipEvidencePresented
      else packet.holderIndemnityAlternative)
    .ownershipEvidenceOrIndemnity ++
  missingUnless
    (suppliedWhenBool context.hasOtherEntitledSuccessors
      packet.allEntitledSuccessorsSigned)
    .allEntitledSuccessorsSigned ++
  missingUnless
    (suppliedWhenBool context.institutionRequiresNotary packet.notarized)
    .notarization ++
  missingUnless
    (suppliedWhenBool (needsConsentAttachment case.authority)
      packet.consentAndLettersAttached)
    .consentAndLetters ++
  missingUnless
    (suppliedWhenBool (needsDatedAmountList case.deathDate)
      packet.datedAmountListAttached)
    .datedAmountList ++
  missingUnless
    (suppliedWhenBool case.estate.containsCountedCaliforniaRealProperty
      packet.inventoryAndAppraisalAttached)
    .inventoryAndAppraisal ++
  missingUnless packet.presentedToHolder .presentationToHolder

def smallRealPropertyAffidavitMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) : List Requirement :=
  missingUnless
    (decide (SmallValueRealPropertyAffidavitEligible case)) .eligibleRoute ++
  missingUnless packet.de305Statements .de305Statements ++
  missingUnless packet.notarizedAcknowledgments .notarization ++
  missingUnless packet.inventoryAndAppraisalAttached .inventoryAndAppraisal ++
  missingUnless packet.certifiedDeathCertificate .certifiedDeathCertificate ++
  missingUnless
    (suppliedWhenBool context.claimsUnderWill packet.willAttached)
    .willAttachment ++
  missingUnless
    (suppliedWhenBool (needsConsentAttachment case.authority)
      packet.consentAndLettersAttached)
    .consentAndLetters ++
  missingUnless
    (suppliedWhenBool (needsDatedAmountList case.deathDate)
      packet.datedAmountListAttached)
    .datedAmountList ++
  missingUnless
    (suppliedWhenBool context.knownGuardianOrConservator
      packet.guardianOrConservatorDelivery)
    .guardianOrConservatorDelivery ++
  missingUnless packet.filedInProperCourt .properCourtFiling ++
  missingUnless packet.clerkCertifiedCopyIssued .clerkCertifiedCopy ++
  missingUnless packet.recordedInPropertyCounty .countyRecording

def primaryResidencePetitionMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) : List Requirement :=
  missingUnless (decide (PrimaryResidencePetitionEligible case)) .eligibleRoute ++
  missingUnless packet.de310VerifiedStatements .de310VerifiedStatements ++
  missingUnless packet.inventoryAndAppraisalAttached .inventoryAndAppraisal ++
  missingUnless
    (suppliedWhenBool context.claimsUnderWill packet.willAttached)
    .willAttachment ++
  missingUnless
    (suppliedWhenBool (needsConsentAttachment case.authority)
      packet.consentAttached)
    .consentAndLetters ++
  missingUnless
    (suppliedWhenBool (needsDatedAmountList case.deathDate)
      packet.datedAmountListAttached)
    .datedAmountList ++
  missingUnless packet.filedInProperCourt .properCourtFiling ++
  missingUnless packet.heirAndDeviseeCopyWithinFiveBusinessDays
    .heirAndDeviseeCopyWithinFiveBusinessDays ++
  missingUnless packet.statutoryHearingNotice .statutoryHearingNotice ++
  missingUnless packet.courtFindingsMade .courtFindings ++
  missingUnless packet.de315OrderIssued .de315Order

def spousalPetitionMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) : List Requirement :=
  missingUnless (decide (SpousalPropertyPetitionEligible case)) .eligibleRoute ++
  missingUnless packet.de221Allegations .de221Allegations ++
  missingUnless packet.propertyDescriptionsAndSupportingFacts
    .propertyDescriptionsAndSupportingFacts ++
  missingUnless packet.knownInterestedPersonsListed .knownInterestedPersons ++
  missingUnless packet.propertyAgreementDisclosed .propertyAgreementDisclosure ++
  missingUnless
    (suppliedWhenBool context.claimsUnderWill packet.willAttached)
    .willAttachment ++
  missingUnless
    (suppliedWhenBool context.propertyAgreementExists
      packet.propertyAgreementAttached)
    .propertyAgreementAttachment ++
  missingUnless packet.statutoryHearingNotice .statutoryHearingNotice ++
  missingUnless packet.de226OrderIssued .de226Order
```

Each function returns every unsatisfied conjunct from its matching readiness
predicate exactly once. Add these four compile-checked equivalence examples for
the complete packets used by the test fixtures:

```lean
example :
    personalAffidavitMissing baseProcedureContext base2026Case
      completePersonalPacket = [] := by decide

example :
    PersonalAffidavitReady baseProcedureContext base2026Case
      completePersonalPacket := by decide

def smallReal2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [smallRealTarget] }
  target := smallRealTarget
  sixMonthsElapsed := true
}

def completeSmallRealPacket : SmallRealPropertyPacket := {
  de305Statements := true
  notarizedAcknowledgments := true
  inventoryAndAppraisalAttached := true
  certifiedDeathCertificate := true
  willAttached := true
  consentAndLettersAttached := true
  datedAmountListAttached := true
  guardianOrConservatorDelivery := true
  filedInProperCourt := true
  clerkCertifiedCopyIssued := true
  recordedInPropertyCounty := true
}

example :
    smallRealPropertyAffidavitMissing baseProcedureContext smallReal2026Case
      completeSmallRealPacket = [] := by decide

example :
    SmallRealPropertyAffidavitReady baseProcedureContext smallReal2026Case
      completeSmallRealPacket := by decide

def primaryResidence2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [primaryResidenceTarget] }
  target := primaryResidenceTarget
}

def completePrimaryResidencePacket : PrimaryResidencePetitionPacket := {
  de310VerifiedStatements := true
  inventoryAndAppraisalAttached := true
  willAttached := true
  consentAttached := true
  datedAmountListAttached := true
  filedInProperCourt := true
  heirAndDeviseeCopyWithinFiveBusinessDays := true
  statutoryHearingNotice := true
  courtFindingsMade := true
  de315OrderIssued := true
}

example :
    primaryResidencePetitionMissing baseProcedureContext
      primaryResidence2026Case completePrimaryResidencePacket = [] := by decide

example :
    PrimaryResidencePetitionReady baseProcedureContext primaryResidence2026Case
      completePrimaryResidencePacket := by decide

def spouse2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [] }
  targetIsPartOfEstate := false
  claimantIsSuccessor := false
  noSuperiorRight := false
  survivorStatus := .spouse
  propertyPassesToSurvivor := true
}

def completeSpousalPacket : SpousalPetitionPacket := {
  de221Allegations := true
  propertyDescriptionsAndSupportingFacts := true
  knownInterestedPersonsListed := true
  propertyAgreementDisclosed := true
  willAttached := true
  propertyAgreementAttached := true
  statutoryHearingNotice := true
  de226OrderIssued := true
}

example :
    spousalPetitionMissing baseProcedureContext spouse2026Case
      completeSpousalPacket = [] := by decide

example :
    SpousalPetitionReady baseProcedureContext spouse2026Case
      completeSpousalPacket := by decide
```

Use complete constructive proofs; no admitted declarations.

- [ ] **Step 6: Encode ordered human-readable workflows**

Define:

```lean
inductive WorkflowStage
  | assessEligibility
  | waitForStatutoryPeriod
  | gatherEvidence
  | obtainProbateRefereeAppraisal
  | prepareAffidavit
  | preparePetition
  | notarize
  | fileWithCourt
  | deliverNotice
  | attendHearing
  | obtainCourtOrder
  | obtainCertifiedCopy
  | presentToHolder
  | recordWithCounty
  | contactBenefitOrTitleAdministrator
  | investigateFormalProbateOrOtherProcedure
deriving BEq, DecidableEq, Repr

def workflowFor : Route → List WorkflowStage
  | .directTransfer _ =>
      [.assessEligibility, .gatherEvidence, .contactBenefitOrTitleAdministrator]
  | .personalPropertyAffidavit =>
      [.assessEligibility, .waitForStatutoryPeriod, .gatherEvidence,
       .prepareAffidavit, .presentToHolder]
  | .smallValueRealPropertyAffidavit =>
      [.assessEligibility, .waitForStatutoryPeriod, .gatherEvidence,
       .obtainProbateRefereeAppraisal, .prepareAffidavit, .notarize,
       .fileWithCourt, .obtainCertifiedCopy, .recordWithCounty]
  | .primaryResidencePetition =>
      [.assessEligibility, .waitForStatutoryPeriod, .gatherEvidence,
       .obtainProbateRefereeAppraisal, .preparePetition, .fileWithCourt,
       .deliverNotice, .attendHearing, .obtainCourtOrder]
  | .spousalPropertyPetition =>
      [.assessEligibility, .gatherEvidence, .preparePetition, .fileWithCourt,
       .deliverNotice, .attendHearing, .obtainCourtOrder]
  | .formalProbateOrOtherProcedure =>
      [.assessEligibility, .investigateFormalProbateOrOtherProcedure]

end SimpleProbate
```

- [ ] **Step 7: Export Procedure and verify packet behavior**

Add `import SimpleProbate.Procedure` before the Examples import in
`SimpleProbate.lean`, and add it to `Examples.lean`.

Run:

```bash
lake env lean SimpleProbate/Examples.lean
lake build
```

Expected: success. The tests demonstrate a complete packet, a missing death
certificate, optional notarization under state law, institution-required
notarization, and the ordered DE-305 workflow.

- [ ] **Step 8: Commit Task 4**

```bash
git add SimpleProbate.lean SimpleProbate/Procedure.lean SimpleProbate/Examples.lean
git -c commit.gpgsign=false commit -m "feat: formalize simple-transfer procedure packets"
```

---

### Task 5: Public Documentation, Source Traceability, and Final Verification

**Files:**
- Modify: `README.md`
- Modify: `Main.lean`
- Modify: `SimpleProbate.lean`
- Modify: `SimpleProbate/Examples.lean`
- Delete: `SimpleProbate/Basic.lean`

**Interfaces:**
- Consumes: every public definition from Tasks 1–4.
- Produces: a stable public import root, a snapshot-identifying executable,
  source traceability, and the final regression suite.

- [ ] **Step 1: Add final regression examples**

Append examples establishing the remaining design claims:

```lean
example :
    ({ assets := [
      { personalTarget with treatment := .jointTenancy },
      { countedPersonal "ordinary account" (Money.dollars 208_850) 0 with
        includedInPrimaryResidencePetition := false }
    ] } : Estate).personalAffidavitValue ⟨2026, 12, 31⟩ =
      .ok (Money.dollars 208_850) := by decide

example : !routeEligible { base2026Case with
    estate := { assets := [{
      primaryResidenceTarget with
        grossValue := Money.dollars 750_000
        isPrimaryResidence := false
    }] }
    target := {
      primaryResidenceTarget with
        grossValue := Money.dollars 750_000
        isPrimaryResidence := false
    } }
    .primaryResidencePetition := by decide

example :
    routeEligible { base2026Case with authority := .noProceeding }
      .personalPropertyAffidavit =
    routeEligible { base2026Case with
      authority := .writtenPersonalRepresentativeConsent }
      .personalPropertyAffidavit := by decide

example :
    routeEligible { base2026Case with
      estate := { assets := [] }
      targetIsPartOfEstate := false
      claimantIsSuccessor := false
      noSuperiorRight := false
      survivorStatus := .registeredDomesticPartner
      propertyBelongsToSurvivor := true }
      .spousalPropertyPetition := true := by decide
```

- [ ] **Step 2: Replace the scaffold README with project documentation**

Write `README.md` with these sections and concrete content:

```markdown
# California Simple Transfer — Lean 4

This project formalizes the California Courts simple-transfer probate decision
process using rules in force during 2026. It computes candidate routes and
checks typed eligibility and procedural-readiness predicates.

## Legal-model boundary

This is an educational formal model, not legal advice. Lean proves consequences
of supplied facts; it does not establish ownership, heirship, property value,
community-property character, primary-residence status, consent, notice,
document truth, or court acceptance. The fallback is deliberately named
`formalProbateOrOtherProcedure` because another procedure may apply.

## Build and inspect

```bash
lake build
lake env lean SimpleProbate/Examples.lean
lake exe simple-probate
```

## Modules

- `Date`: validates dates and enforces the December 31, 2026 snapshot.
- `Thresholds`: contains the date-of-death threshold schedule in cents.
- `Estate`: applies section 13050 exclusions and gross-value aggregation.
- `Eligibility`: states and decides candidate transfer routes.
- `Procedure`: checks route-specific packets and exposes ordered workflows.
- `Examples`: compile-checked boundary scenarios and regression theorems.

## 2026 route limits

For deaths from April 1, 2025 through December 31, 2026:

- personal-property affidavit: $208,850;
- primary-residence petition: $750,000;
- small-value real-property affidavit: $69,625;
- employment-compensation exclusion: $20,875.

The spousal property petition has no value cap in this model.

## Source traceability

| Lean definition | Official source |
| --- | --- |
| `thresholdsFor`, `thresholdsForBand` | Probate Code §890 and Judicial Council form DE-300 |
| `Asset.personalAffidavitValue` | Probate Code §§13050 and 13100 |
| `PersonalPropertyAffidavitEligible` | Probate Code §§13100–13101 |
| `SmallValueRealPropertyAffidavitEligible` | Probate Code §13200 and form DE-305 |
| `PrimaryResidencePetitionEligible` | Probate Code §§13150–13154 and forms DE-310/DE-315 |
| `SpousalPropertyPetitionEligible` | Probate Code §§13500 and 13650–13656; forms DE-221/DE-226 |
| packet readiness predicates | California Courts Self-Help Guide plus the cited Probate Code sections |

The source snapshot and full URLs are recorded in
`docs/superpowers/specs/2026-07-28-california-simple-transfer-design.md`.
```

- [ ] **Step 3: Replace the scaffold executable and root imports**

Delete `SimpleProbate/Basic.lean`.

Set `SimpleProbate.lean` to:

```lean
import SimpleProbate.Date
import SimpleProbate.Thresholds
import SimpleProbate.Estate
import SimpleProbate.Eligibility
import SimpleProbate.Procedure
import SimpleProbate.Examples
```

Set `Main.lean` to:

```lean
import SimpleProbate

def main : IO Unit :=
  IO.println "California simple-transfer formalization — legal snapshot: 2026-12-31"
```

- [ ] **Step 4: Run the complete verification suite**

Run:

```bash
lake env lean SimpleProbate/Examples.lean
lake build
lake exe simple-probate
rg -n '\b(sorry|admit|axiom|unsafe)\b' --glob '*.lean' .
git diff --check
```

Expected:

- both Lean commands and `lake build` exit successfully;
- the executable prints
  `California simple-transfer formalization — legal snapshot: 2026-12-31`;
- the forbidden-declaration scan prints no matches; and
- `git diff --check` prints no errors.

- [ ] **Step 5: Commit Task 5**

```bash
git add README.md Main.lean SimpleProbate.lean SimpleProbate/Examples.lean
git add -u SimpleProbate/Basic.lean
git -c commit.gpgsign=false commit -m "docs: publish 2026 simple-transfer model"
```
