# Main/Demo Exact API Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge `origin/main` into `feat/exact-partial-probate-api`, keep the theorem-backed exact assessment as the only semantic engine, and expose it through main's JSON executable and six-row demo contract.

**Architecture:** Delete main's duplicate `SimpleProbate.Partial` implementation. Decode the existing JSON input, plus optional separate valuation-time fields, directly into the exact `PartialTransferCase`; call the proved `assessRoutes`; then project its eleven exact route reports to the demo's stable six-row wire representation. Keep the backend as a subprocess/schema adapter and the frontend as a consumer of the same documented contract.

**Tech Stack:** Lean 4.32.1, Lake, `Lean.Data.Json`, Python 3.12/FastAPI/Pydantic v2, React 18, TypeScript 5.6, Vite 5, Git/GitHub CLI.

## Global Constraints

- The exact types and functions in `Decision.lean`, `Estate.lean`, `Case.lean`, and `Eligibility.lean` remain the only source of route semantics.
- Do not retain, rename, or recreate main's `SimpleProbate/Partial.lean` evaluator.
- The wire response remains six rows in the approved stable order; do not expose the eleven internal exact reports directly.
- Preserve absent-or-`null` as `Knowledge.unknown`; never decode unknown as `false` or zero.
- Preserve the legacy `gross_value_cents` field and add independent optional current/date-of-death fields with the approved precedence.
- Do not alter the proved eligibility or readiness definitions to accommodate the demo.
- Do not introduce `sorry`, `admit`, `axiom`, `unsafe`, or a Python/TypeScript copy of the probate rules.
- Use the approved design at `docs/superpowers/specs/2026-07-28-main-demo-exact-api-integration-design.md` as the acceptance authority.
- Keep unrelated user changes intact.

---

## Task 1: Merge `origin/main` and replace the duplicate Lean engine with the exact JSON adapter

**Files:**

- Delete: `SimpleProbate/Partial.lean`
- Modify: `SimpleProbate.lean`
- Modify: `SimpleProbate/Api.lean`
- Create: `SimpleProbate/Examples/Api.lean`
- Modify: `SimpleProbate/Examples.lean`
- Keep from main: `ApiMain.lean`
- Keep from main: `lakefile.toml`

### 1.1 Start the merge from the reviewed commits

- [ ] Confirm the worktree is on `feat/exact-partial-probate-api`, has no uncommitted implementation changes, and still points at the reviewed heads:

```bash
git status --short --branch
git rev-parse HEAD
git rev-parse origin/main
git log --oneline --decorate -5
```

Expected before the merge: feature HEAD includes the approved design/plan commits and `origin/main` is `28e1b034e4f7feb552d5a06e32f5ba60d01067ec` unless a fresh fetch reveals a newer main that must first be reviewed.

- [ ] Fetch without rebasing, then merge explicitly:

```bash
git fetch origin main
git merge --no-commit --no-ff origin/main
```

- [ ] Confirm the only textual conflict is `SimpleProbate.lean`; if the fetched main changed or new conflicts appear, stop this task and compare those changes with the approved design before resolving them.

### 1.2 Add failing Lean API examples first

- [ ] Create `SimpleProbate/Examples/Api.lean` importing `SimpleProbate.Api`.
- [ ] Add small JSON fixtures and assertions for these public adapter contracts:

```lean
SimpleProbate.Api.decodeCase :
  Lean.Json → Except String PartialTransferCase

SimpleProbate.Api.projectAssessment :
  CaseAssessment → List WireRouteReport

SimpleProbate.Api.resultJson :
  Except CaseError CaseAssessment → Lean.Json

SimpleProbate.Api.run : String → Lean.Json
```

- [ ] Cover at least:

  - legacy `gross_value_cents` populates both `currentGrossValue` and `dateOfDeathValue`;
  - explicit `current_gross_value_cents` and `date_of_death_value_cents` independently override the legacy value;
  - absent/null values decode to `.unknown`;
  - asset IDs equal zero-based array indices and `target_index` becomes `.known ⟨index⟩`;
  - an out-of-range `target_index` is rejected before assessment;
  - direct-transfer projection prefers any qualifying basis, then unresolved facts, then one `no_direct_transfer_basis` reason;
  - current and date-of-death value facts map to different JSON paths;
  - all three exact overall outcomes produce the approved fallback row;
  - typed structural errors render deterministically;
  - a successful end-to-end response has exactly six rows in stable order.

- [ ] Import `SimpleProbate.Examples.Api` from `SimpleProbate/Examples.lean`.
- [ ] Run the focused examples and record the expected RED failure caused by the old API importing/relying on `SimpleProbate.Partial`:

```bash
lake env lean SimpleProbate/Examples/Api.lean
```

The failure must be about missing/new adapter behavior or duplicate old declarations, not a malformed test.

### 1.3 Resolve the module architecture

- [ ] Delete `SimpleProbate/Partial.lean`.
- [ ] Resolve `SimpleProbate.lean` to this dependency-safe public import list:

```lean
import SimpleProbate.Date
import SimpleProbate.Thresholds
import SimpleProbate.Decision
import SimpleProbate.Estate
import SimpleProbate.Case
import SimpleProbate.Eligibility
import SimpleProbate.Procedure
import SimpleProbate.ProcedureAssessment
import SimpleProbate.Api
import SimpleProbate.Examples
```

- [ ] Retain main's `ApiMain.lean` and `probate-api` Lake executable target unchanged unless compilation proves a small import/name adjustment is necessary.
- [ ] Verify there are no remaining imports or declarations from the retired module:

```bash
rg -n 'SimpleProbate\.Partial|import SimpleProbate\.Partial' --glob '*.lean' .
```

Expected: no matches.

### 1.4 Rewrite `SimpleProbate/Api.lean` as a wire adapter

- [ ] Import `Lean.Data.Json` and `SimpleProbate.Eligibility`, not the retired partial module.
- [ ] Keep path-aware primitive decoders for booleans, natural-number cents, strings, enums, structured dates, optional fields, arrays, and objects.
- [ ] Add a `Knowledge.ofOption`-style local helper so every optional wire fact is converted explicitly:

```lean
private def knowledgeOfOption : Option α → Knowledge α
  | none => .unknown
  | some value => .known value
```

- [ ] Decode each asset with deterministic `id := ⟨index⟩`, required `name`, and these value rules:

```lean
let currentValue :=
  match currentGrossValueField with
  | some value => some value
  | none => legacyGrossValueField
let dateOfDeathValue :=
  match dateOfDeathValueField with
  | some value => some value
  | none => legacyGrossValueField
```

Convert those resolved options to `Knowledge`. `encumbrances_cents` remains independent and unknown when absent.

- [ ] Require `estate`, `estate.assets`, and `target_index`; range-check the target against the decoded asset list and emit a path-specific `Except String` error when invalid.
- [ ] Construct the exact case:

```lean
{
  deathDate := ...
  estate := { assets := ..., inventoryComplete := ... }
  targetId := .known ⟨targetIndex⟩
  authority := ...
  daysSinceDeath := ...
  sixMonthsElapsed := ...
  claimantIsSuccessor := ...
  noSuperiorRight := ...
  funeralLastIllnessAndUnsecuredDebtsPaid := ...
  survivorStatus := ...
  propertyPassesToSurvivor := ...
  propertyBelongsToSurvivor := ...
}
```

### 1.5 Define the wire-only output model and stable mappings

- [ ] Keep wire declarations under `namespace SimpleProbate.Api` so they cannot collide with exact semantic types:

```lean
inductive WireRouteId
  | directTransfer
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
  | formalProbateOrOtherProcedure

structure WireReason where
  id : String
  text : String

inductive WireRouteStatus
  | qualifies
  | doesNotQualify (reasons : List WireReason)
  | needsInformation (facts : List String)

structure WireRouteReport where
  route : WireRouteId
  status : WireRouteStatus
  detail : String
  forms : List String
```

Derive only the equality/repr instances actually needed by examples and encoding.

- [ ] Define total mappings:

```lean
factPath : EligibilityFact → String
failureReason : EligibilityFailure → WireReason
structuralIssueDetail : StructuralIssue → String
courtReport : RouteReport → Option WireRouteReport
directReport : List RouteReport → WireRouteReport
fallbackReport : CaseAssessment → WireRouteReport
projectAssessment : CaseAssessment → List WireRouteReport
```

- [ ] Map facts to the approved paths:

  - `deathDate` → `death_date`
  - `targetAsset` → `target_index`
  - `inventoryComplete` → `estate.inventory_complete`
  - asset kind/treatment/residence/inclusion fields → their indexed asset paths
  - `currentGrossValue` → `estate.assets[i].current_gross_value_cents`
  - `dateOfDeathValue` → `estate.assets[i].date_of_death_value_cents`
  - authority, waiting period, successor, superior right, debt, survivor, and survivor-property facts → their existing top-level JSON keys.

- [ ] Map every `EligibilityFailure` constructor to one of the approved stable IDs. Preserve value/cap amounts in the text for the three over-cap constructors; do not branch semantic behavior based on text.
- [ ] Collapse all seven `.directTransfer basis` reports:

  1. If any qualify, return `.qualifies` and list qualifying bases in exact report order in `detail`.
  2. Else, if any need information, return `.needsInformation` with `dedupStable` mapped fact paths.
  3. Else, return `.doesNotQualify` with one `no_direct_transfer_basis` reason.

- [ ] Map the four court reports one-for-one, preserving the exact engine's reason/fact ordering.
- [ ] Synthesize the fallback row only from `assessment.overall`:

  - `.formalProbateOrOtherProcedure` → `.qualifies`;
  - `.unresolved` → `.needsInformation` with the stable union of unresolved facts from exact reports;
  - `.simplifiedRoutesAvailable` → `.doesNotQualify` with `simplified_route_available`.

- [ ] Make `projectAssessment` always return these six rows:

```text
direct_transfer
personal_property_affidavit
small_value_real_property_affidavit
primary_residence_petition
spousal_property_petition
formal_probate_or_other_procedure
```

### 1.6 Encode results and errors without changing semantics

- [ ] Encode `WireRouteReport` into the existing `route/status/reasons/missing_facts/detail/forms` shape.
- [ ] Derive top-level `verdict`, `overall`, and one-sentence `reasoning` from the exact `CaseAssessment.overall`; do not recompute them from projected rows.
- [ ] Preserve `engine := "lean4"` and binary-owned `latency_ms := 0`.
- [ ] Map:

  - `.invalidDate` → `invalid_date`;
  - `.afterSnapshot` → `after_snapshot`;
  - `.malformedCase issues` → `malformed_case` with an ordered, stable rendering of all typed structural issues;
  - parse/decode errors → `malformed_case` with the path-specific decoder message.

- [ ] Keep `run` as the single stdin-text pipeline:

```lean
def run (input : String) : Lean.Json :=
  match Lean.Json.parse input with
  | .error parseError => ...
  | .ok json =>
      match decodeCase json with
      | .error decodeError => ...
      | .ok partialCase => resultJson (assessRoutes partialCase)
```

### 1.7 Make the Lean merge green

- [ ] Run the focused test:

```bash
lake env lean SimpleProbate/Examples/Api.lean
```

- [ ] Run every exact proof/example module explicitly:

```bash
for file in \
  SimpleProbate/Examples/Decision.lean \
  SimpleProbate/Examples/Valuation.lean \
  SimpleProbate/Examples/Case.lean \
  SimpleProbate/Examples/EligibilityAssessment.lean \
  SimpleProbate/Examples/ProcedureExactness.lean \
  SimpleProbate/Examples/ProcedureAssessment.lean \
  SimpleProbate/Examples/Api.lean \
  SimpleProbate/Examples.lean
do
  lake env lean "$file"
done
```

- [ ] Build the library and both executables:

```bash
lake build
lake build simple-probate
lake build probate-api
```

- [ ] Smoke-test valid and invalid JSON through the compiled executable and inspect the output:

```bash
printf '%s\n' '{"estate":{"inventory_complete":true,"assets":[{"name":"account","kind":"personal","gross_value_cents":100000,"treatment":"counted"}]},"target_index":0}' | lake exe probate-api
printf '%s\n' '{"estate":{"inventory_complete":true,"assets":[]},"target_index":0}' | lake exe probate-api
```

Expected: the first result has six route rows and no error; the second has `error.type = "malformed_case"`.

- [ ] Scan the merged Lean source:

```bash
rg -n '\b(sorry|admit|axiom|unsafe)\b' --glob '*.lean' .
git diff --check
git status --short
```

- [ ] Commit the resolved merge only after all Lean checks pass:

```bash
git add SimpleProbate.lean SimpleProbate SimpleProbate/Examples ApiMain.lean lakefile.toml
git commit
```

Keep Git's merge parentage and use a message whose subject makes the integration explicit, for example `Merge main demo onto exact probate API`.

---

## Task 2: Update the Python contract, demo content, and regression checks

**Files:**

- Modify: `demo/backend/app/schemas.py`
- Modify: `demo/backend/app/main.py`
- Create: `demo/backend/tests/__init__.py`
- Create: `demo/backend/tests/test_contract.py`
- Modify: `demo/CONTRACT.md`
- Modify: `demo/README.md`
- Modify: `demo/content/rules.md`
- Modify: `demo/content/sample_cases.derivation.md`
- Modify as required by exact output: `demo/content/sample_cases.json`
- Modify if it contains stale engine language: `demo/content/simple-transfer.md`
- Modify if audit expectations change after exact execution: `demo/AUDIT.md`

### 2.1 Add failing backend contract tests

- [ ] Add `unittest` coverage that:

  - `Asset` accepts legacy-only, explicit-only, and all-three value field combinations;
  - model dumping preserves explicit `null` and explicit current/date-of-death values;
  - the source endpoint contains `Decision.lean`, `Case.lean`, `Eligibility.lean`, `ProcedureAssessment.lean`, and `Api.lean`;
  - the source endpoint does not contain `Partial.lean`;
  - all referenced source files exist.

- [ ] Run the tests before implementation:

```bash
PYTHONPATH=demo/backend python3 -m unittest discover -s demo/backend/tests -v
```

Expected RED: the two explicit valuation fields are rejected/absent and the source list still names `Partial.lean`.

### 2.2 Expand the Pydantic input without changing HTTP behavior

- [ ] In `demo/backend/app/schemas.py`, retain:

```python
gross_value_cents: Optional[int] = None
```

and add:

```python
current_gross_value_cents: Optional[int] = None
date_of_death_value_cents: Optional[int] = None
```

- [ ] Document that the Lean adapter applies precedence and that Pydantic is only the HTTP shape gate; keep raw request forwarding unchanged.

### 2.3 Fix the exact Lean source inventory

- [ ] Replace `SimpleProbate/Partial.lean` in `LEAN_SOURCE_ORDER` with the exact dependency order:

```python
"SimpleProbate/Decision.lean",
"SimpleProbate/Estate.lean",
"SimpleProbate/Case.lean",
"SimpleProbate/Eligibility.lean",
"SimpleProbate/Procedure.lean",
"SimpleProbate/ProcedureAssessment.lean",
"SimpleProbate/Api.lean",
```

Keep `Date.lean` and `Thresholds.lean` before those and `Examples.lean`/`ApiMain.lean` after them.

### 2.4 Rewrite stale contract and content claims

- [ ] Update `demo/CONTRACT.md` to:

  - identify the exact theorem-backed partial API as the authority;
  - remove the "new Partial.lean" architecture and deferred proof TODO;
  - document all three accepted value keys and exact precedence;
  - explain zero-based `AssetId` assignment and `target_index` conversion;
  - explain the 11-to-6 route projection and fallback synthesis;
  - use exact value fact paths;
  - list the corrected source endpoint order.

- [ ] Update `demo/content/rules.md`, `demo/content/sample_cases.derivation.md`, and `demo/README.md` so they refer to typed exact facts/failures, proved exactness/soundness, and the adapter boundary.
- [ ] Remove statements that claim existing exact Lean modules are read-only, that proofs are deferred, or that the demo-specific partial layer is authoritative.
- [ ] Keep the educational/not-legal-advice boundary intact.

### 2.5 Reconcile sample data with exact valuation semantics

- [ ] Keep legacy-only sample assets valid so backward compatibility is exercised.
- [ ] Change at least one relevant sample to provide distinct explicit current/date-of-death values, without silently changing the legal scenario described by its title/blurb.
- [ ] Update missing-fact examples/derivations to expect:

  - `current_gross_value_cents` for current-value questions;
  - `date_of_death_value_cents` for date-at-death questions.

- [ ] Do not edit `expected_verdict` by intuition. Run each sample through `lake exe probate-api`, record its actual top-level verdict/error, and update content only where the exact engine reveals the old demo expectation was based on superseded semantics.

### 2.6 Make backend/content checks green

- [ ] Run:

```bash
PYTHONPATH=demo/backend python3 -m unittest discover -s demo/backend/tests -v
python3 -m compileall -q demo/backend/app demo/backend/tests
python3 -m json.tool demo/content/sample_cases.json >/dev/null
rg -n 'SimpleProbate/Partial\.lean|TODO\\(proof-contract\\)|deferred theorem' demo
git diff --check
```

Expected: tests and compile pass; JSON is valid; stale partial/deferred-proof references are gone.

- [ ] Commit:

```bash
git add demo/backend demo/CONTRACT.md demo/README.md demo/content demo/AUDIT.md
git commit -m "feat: align demo contract with exact probate API"
```

Omit `demo/AUDIT.md` from `git add` if no audit change is required.

---

## Task 3: Update the frontend for dual values without breaking legacy editing

**Files:**

- Modify: `demo/frontend/src/types.ts`
- Modify: `demo/frontend/src/App.tsx`
- Modify only if labels/help text need clarification: `demo/frontend/src/components/CaseEditor.tsx`

### 3.1 Establish the frontend RED check

- [ ] Add these optional fields to the `AssetInput` interface usage in `App.tsx` first, so the code intentionally references fields that `types.ts` does not yet define:

```ts
current_gross_value_cents
date_of_death_value_cents
```

- [ ] Run:

```bash
cd demo/frontend
npm run build
```

Expected RED: TypeScript reports that the explicit valuation fields do not exist on `AssetInput`.

### 3.2 Update wire types and value editing behavior

- [ ] Add to `AssetInput`:

```ts
/** Current gross value in integer cents; overrides legacy gross_value_cents. */
current_gross_value_cents?: number | null;
/** Date-of-death gross value in integer cents; overrides legacy gross_value_cents. */
date_of_death_value_cents?: number | null;
```

- [ ] Keep `gross_value_cents?: number | null` and label it as the backward-compatible fallback for both exact value fields.
- [ ] Make `targetValueCents` display:

  1. explicit current value when present;
  2. otherwise legacy gross value;
  3. otherwise `null`.

- [ ] Make the slider preserve the input mode:

  - if the target asset already has a non-null/non-undefined `current_gross_value_cents`, update that field only;
  - otherwise update `gross_value_cents` as before.

This prevents a current-value slider edit from overwriting an explicit date-of-death value while preserving all current sample behavior.

- [ ] Ensure raw JSON editor parsing/stringifying retains both explicit fields without normalization or deletion.

### 3.3 Build and commit

- [ ] Run:

```bash
cd demo/frontend
npm run build
```

- [ ] If `node_modules` is absent, run `npm install` using the existing lockfile first; do not alter dependency versions unless required by the existing lockfile.
- [ ] Return to the repo root and run:

```bash
git diff --check
git status --short
```

- [ ] Commit:

```bash
git add demo/frontend/src
git commit -m "feat: support exact probate valuation fields in demo"
```

---

## Task 4: Prove end-to-end compatibility against every sample

**Files:**

- Create: `demo/backend/tests/test_probate_api_samples.py`
- Modify if actual exact results require corrections: `demo/content/sample_cases.json`
- Modify if expectations/claims change: `demo/content/sample_cases.derivation.md`
- Modify if reported audit totals change: `demo/AUDIT.md`

### 4.1 Add an executable sample-contract test

- [ ] Add a standard-library `unittest` that:

  - loads every object in `demo/content/sample_cases.json`;
  - invokes `.lake/build/bin/probate-api` once per case via `subprocess.run` with a timeout;
  - parses the single JSON result;
  - for non-error samples, asserts `verdict == expected_verdict`, `error is None`, exactly six routes, and the stable route order;
  - for `expected_verdict == "ERROR"`, asserts `verdict is None`, a non-null error, and no route rows;
  - asserts route status invariants: reasons only for `does_not_qualify`, missing facts only for `needs_information`;
  - asserts each emitted missing-fact path uses a documented input key.

- [ ] Run it before correcting any stale sample expectations:

```bash
lake build probate-api
PYTHONPATH=demo/backend python3 -m unittest demo.backend.tests.test_probate_api_samples -v
```

If RED, inspect whether the implementation violates the approved projection or the fixture describes superseded semantics. Fix the responsible layer; do not merely weaken the assertion.

### 4.2 Exercise the live FastAPI subprocess boundary

- [ ] Extend the test, or add a focused async test, to call `analyze_lean` with one legacy sample and one dual-value sample and validate the resulting `CheckResult`.
- [ ] Confirm the backend still overwrites `latency_ms` and attaches usage without changing the Lean verdict/routes.
- [ ] Run the full backend suite:

```bash
PYTHONPATH=demo/backend python3 -m unittest discover -s demo/backend/tests -v
```

### 4.3 Run the complete repository verification

- [ ] From the repo root:

```bash
lake build
lake build simple-probate
lake build probate-api
lake exe simple-probate
PYTHONPATH=demo/backend python3 -m unittest discover -s demo/backend/tests -v
python3 -m compileall -q demo/backend/app demo/backend/tests
cd demo/frontend && npm run build
```

- [ ] Scan source and diffs:

```bash
cd ../../
rg -n '\b(sorry|admit|axiom|unsafe)\b' --glob '*.lean' .
rg -n 'SimpleProbate\.Partial|SimpleProbate/Partial\.lean' .
rg -n 'gross_value_cents' demo | sort
git diff --check
git status --short --branch
git log --oneline --decorate --graph -12
```

Expected:

  - all builds/tests pass;
  - the retired engine is absent;
  - remaining `gross_value_cents` references explicitly describe legacy compatibility or legacy fixtures;
  - no uncommitted changes remain after the final commit.

- [ ] Commit the end-to-end regression if it was not included earlier:

```bash
git add demo/backend/tests demo/content/sample_cases.json demo/content/sample_cases.derivation.md demo/AUDIT.md
git commit -m "test: verify demo cases against exact probate engine"
```

Only stage files actually changed.

---

## Task 5: Independent review, push, and make PR #1 merge-ready

**Files:**

- Modify only if review finds a defect: files from Tasks 1–4
- Remote update: `origin/feat/exact-partial-probate-api`
- PR update: GitHub PR #1

### 5.1 Review against the approved design

- [ ] Use a fresh review agent that did not implement the task to inspect:

  - exact engine remains sole authority;
  - legacy and dual-value precedence;
  - target index/id conversion;
  - all failure/fact mappings are exhaustive;
  - 7-to-1 direct projection precedence;
  - fallback derives only from `overall`;
  - six-row stable output;
  - typed malformed errors;
  - no stale docs or hidden second evaluator;
  - test coverage and successful commands.

- [ ] Resolve every High/Medium issue with a focused test first. Re-run the smallest affected verification plus the complete Task 4 verification.
- [ ] Request a final verification/review pass after fixes.

### 5.2 Push the merge and implementation commits

- [ ] Inspect what will be pushed:

```bash
git status --short --branch
git log --oneline --decorate origin/feat/exact-partial-probate-api..HEAD
git diff --stat origin/feat/exact-partial-probate-api...HEAD
git diff --check origin/feat/exact-partial-probate-api...HEAD
```

- [ ] Push:

```bash
git push origin feat/exact-partial-probate-api
```

### 5.3 Update and verify PR #1

- [ ] Update the PR description to state:

  - `origin/main` was merged;
  - `SimpleProbate.Partial` was retired;
  - the JSON executable now adapts the exact, proved assessment;
  - legacy wire input is preserved with optional dual valuation fields;
  - exact eleven-route results project to the stable six-row demo;
  - the commands/tests run and their results.

- [ ] Inspect mergeability/checks:

```bash
gh pr view 1 --json url,title,mergeable,mergeStateStatus,headRefName,baseRefName,statusCheckRollup
gh pr checks 1
```

Expected: no merge conflict. If checks are pending, report that accurately; do not call the PR ready until required checks pass.

- [ ] Final local proof before reporting completion:

```bash
git status --short --branch
git rev-parse HEAD
git rev-parse origin/feat/exact-partial-probate-api
```

Expected: clean worktree and matching local/remote heads.

## Definition of Done

- `main` is merged into the feature branch with real merge parentage.
- `SimpleProbate/Partial.lean` is gone and no duplicate semantic engine remains.
- `probate-api` decodes legacy/dual input into exact `PartialTransferCase`, calls exact `assessRoutes`, and returns the six-row compatibility projection.
- Exact classification, soundness/exactness proofs, and procedure readiness/missing-requirement equivalence still compile.
- Lean, backend, sample-contract, and frontend checks pass.
- PR #1 is pushed, accurately documented, and no longer conflicted.
