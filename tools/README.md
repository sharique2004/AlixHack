# tools/ — reproducing every number this product displays

Three harnesses. All are deterministic, all run from a clean checkout, and the
first two write their raw output into this directory so a reader never has to
take a figure on trust.

If a number appears in the UI, in `PRODUCT.md`, or in a slide, it must be
traceable to a command below. If it isn't, it does not get displayed.

---

## Prerequisites

```bash
cd /path/to/AlixHack
~/.elan/bin/lake build                  # builds .lake/build/bin/probate-api
~/.elan/bin/lake build settlement-api   # builds .lake/build/bin/settlement-api
```

Both harnesses use only the Python standard library. They shell out to the
built Lean binary exactly the way `demo/backend/app/lean_runner.py` does — one
subprocess per case, stdin JSON in, stdout JSON out — falling back to
`lake exe probate-api` when the binary is not present.

---

## 1. `run_audit.py` — the "Lean 12/12" claim

```bash
python3 tools/run_audit.py            # replay, write tools/audit_runs.json
python3 tools/run_audit.py --check    # replay and diff against the committed run
```

`demo/AUDIT.md` states a ground-truth verdict for each of 12 sample cases and
claims the Lean engine gets all 12 right. It cited raw outputs in an
`audit_runs.json` that **was never committed**, so until now that claim could
not be checked from the repo.

This script reads the expected verdicts **out of AUDIT.md's own scoreboard
table** — it parses the markdown rather than keeping a second hardcoded copy —
cross-checks them against `expected_verdict` in
`demo/content/sample_cases.json`, replays every case through the engine, and
writes `tools/audit_runs.json` with expected-vs-actual plus the full six-row
route table, the reasoning string, a SHA-256 of the engine's raw stdout, and
the input case for each.

**Observed on 2026-08-12 (this machine, `.lake/build/bin/probate-api`):**

| | |
|---|---|
| Cases replayed | 12 |
| Correct at verdict level | **12 / 12** |
| Divergences between AUDIT.md and `sample_cases.json` | 0 |
| Wall time | about 1 s |

Exit status is non-zero on any mismatch, so this is usable as a CI gate.
`--check` additionally diffs the route tables against the committed
`audit_runs.json`, which turns any silent change in the Lean engine's answers
into a loud failure.

### What this does and does not establish

* It **does** establish that the verdict-level 12/12 is reproducible by anyone
  with the repo, in about a second.
* It **does** commit the raw route tables that AUDIT.md's per-case prose refers
  to, so its route-level statements can now be read against real output.
* It **does not** re-derive the route-level ground truth. AUDIT.md's auditors
  worked that out by hand, in prose, per case. This script records what the
  engine says; it is not a second legal opinion about what the engine ought to
  say.

### The Gemini half is not reproduced by default

AUDIT.md also reports **23/36 Gemini runs correct**. That half is opt-in:

```bash
python3 tools/run_audit.py --llm 3     # needs GEMINI_API_KEY; costs money
```

It is off by default because it calls a paid third-party API and samples at
non-zero temperature, so re-running it produces *new* numbers rather than
confirming the old ones. With `--llm 0` the report records
`"llm": {"status": "skipped", "reason": ...}`. Results are never simulated,
estimated, or filled in from the document. **As shipped, the 23/36 figure is
not independently reproducible from this repo** — it is a record of a run that
happened on 2026-07-28, and should be described that way.

---

## 2. `fuzz_probate.py` — the property-based fuzz harness

```bash
python3 tools/fuzz_probate.py                          # default corpus
python3 tools/fuzz_probate.py --self-test              # test the tests
python3 tools/fuzz_probate.py --cases 250000 --jobs 10 # overnight run
python3 tools/fuzz_probate.py --only 4711              # replay one case
```

A seeded generator produces `PartialTransferCase` JSON (the `CaseInput` wire
shape of `demo/CONTRACT.md`) and drives the built `probate-api` over it. Every
case is derived from `(--seed, case index)`, so a run is fully reproducible and
`--jobs` never changes the result; any reported violation replays on its own
with `--only <index>`.

Roughly 45% of the corpus is uniform over the input space and 55% is aimed at a
specific route's decision boundary — all conjuncts satisfied, and the relevant
§13050 valuation placed within cents of that route's cap. Without the second
half the capped routes essentially never reach `qualifies`, and most of the
invariants below would be checked only where they are vacuous.

### The invariants

| id | property |
|---|---|
| `shape` | every non-error response is contract-shaped and carries all six CA route rows in the contract's stable order; `does_not_qualify` always carries reasons, `needs_information` always carries missing facts; a typed error never also carries a verdict |
| `aggregation` | the fallback row and `overall` are exactly the function of the five simplified rows that `Partial.lean` specifies, including the order-stable union of missing facts |
| `monotonicity` | raising a known asset value never turns a **simplified** route from `does_not_qualify` into `qualifies`, and never yields ELIGIBLE from a non-ELIGIBLE verdict |
| `unknown_safety` | replacing a known fact with `null` never turns any route into `qualifies`, never yields ELIGIBLE where the fuller case was not, and never turns a well-formed case into a structural error — **unknown must never help** |
| `snapshot` | every death date after 2026-12-31 returns the typed `after_snapshot` error, never a verdict |
| `invalid_date` | an impossible civil date returns the typed `invalid_date` error |
| `determinism` | byte-identical input produces byte-identical output across separate process invocations |

**Monotonicity is deliberately scoped to the five simplified routes.** The sixth
row, `formal_probate_or_other_procedure`, is the catch-all: pushing every
simplified route over its cap is precisely when it is *supposed* to start
qualifying, so it is not monotone in asset value and must not be asserted to
be. Its behaviour is pinned exactly by the `aggregation` invariant instead.
That exclusion is the one place where a naive reading of "raising a value never
turns a no into a yes" would produce a false alarm.

### Observed runs (2026-08-12, 10 workers, seed `20260812`)

| run | cases | engine invocations | invariant checks | wall time | **violations** |
|---|---|---|---|---|---|
| default (`--cases 1000`) | 1,000 | 7,940 | 8,940 | 37.4 s | **0** |
| large (`--cases 25000`) | 25,000 | 198,523 | 223,523 | 915.0 s | **0** |

Raw reports: `tools/fuzz_report.json` (default) and
`tools/fuzz_report_25k.json` (large). Both are byte-reproducible from the seed;
only `wall_seconds` and `cases_per_second` vary between machines.

**These two numbers — 25,000 cases and zero invariant violations — are the only
fuzz figures the product is allowed to display.** Anything larger requires
running the harness and updating this table with what it actually printed.

Both reports carry a `coverage` block, because "zero violations" is worthless if
the corpus never reached an interesting state. On the 25,000-case run:

* all three verdicts were reached (15,645 ELIGIBLE / 6,765 INCOMPLETE_INFO /
  2,590 OTHER_FORM_REQUIRED);
* all six route rows reached all three statuses — the rarest cell is
  `primary_residence_petition: qualifies` at 1,234;
* the value-raising mutation changed the engine's answer in **4,995 of 23,531**
  cases where it applied;
* the null-a-known-fact mutation changed it in **18,625 of 74,992** probes.

The mutations bite. The invariants held anyway.

### Testing the tests

A property harness that cannot fail proves nothing, so the harness is checked
two ways.

**1. The checkers, against hand-built counterexamples:**

```bash
python3 tools/fuzz_probate.py --self-test
```

Feeds each invariant checker a synthetic response that violates it and asserts
it fires, plus a clean response and asserts it does not. **Observed: 13/13
checks behaved as specified.** No engine needed; takes milliseconds.

**2. The whole harness, against a deliberately broken engine:**

```bash
python3 tools/fuzz_probate.py --cases 60 --bin tools/sabotage_engine.py
```

`tools/sabotage_engine.py` shells out to the real `probate-api` and injects
exactly one wrong behaviour: when `estate.inventory_complete` is unknown, the
personal-property affidavit is reported as `qualifies`. That is "unknown
helps" — the precise failure `demo/AUDIT.md` case 6 records Gemini committing
0/3 times, and the one thing this product must never do.

**Observed: 22 violations in 60 cases** (18 `aggregation`, 4 `unknown_safety`).
The real generator, driving a real subprocess, caught a one-line regression in
under two seconds. That is the claim "the harness would catch a regression"
reduced to a command anyone can run.

---

## What none of this is

These are **property-based tests**: a large, seeded, randomly generated sample
of inputs, checked against invariants that must hold by construction. They are
strong evidence and they are honest evidence, but they are evidence, not proof.

* They sample an input space; they do not quantify over it. Zero violations in
  25,000 cases means the properties held on 25,000 cases — no more than that.
* They check the properties written down above and nothing else. A legal error
  that is consistent across every mutation — a misread threshold, a wrong band
  boundary — passes every one of them. That class of error is what
  `demo/AUDIT.md`'s hand-derived ground truth is for.
* They are not the machine-checked refinement proofs. Those remain an open
  **TODO** in `SimpleProbate/Partial.lean`, lines 24–38: total route exactness,
  fallback exactness, partial-input soundness via `Completes partial total`,
  exact `needsInformation` fact lists, and the non-empty-list invariants on the
  `doesNotQualify` / `needsInformation` constructors. Those theorems are stated
  in the source and deliberately **omitted, not stubbed** — there is no `sorry`
  anywhere in this repo. Until they are proved, the correct description of this
  engine is "a decidable executable model with a hand-audited ground truth and
  property-tested doctrine", not "a verified engine".

The gap between those two descriptions is the honest one, and it is the gap the
proofs in `Partial.lean` are meant to close.

---

## Files written here

| file | written by | contents |
|---|---|---|
| `audit_runs.json` | `run_audit.py` | per-case expected-vs-actual, full route tables, stdout hashes, input cases |
| `fuzz_report.json` | `fuzz_probate.py` | seed, counts, wall time, coverage histogram, any findings |
| `fuzz_report_25k.json` | `fuzz_probate.py --cases 25000` | same, for the large run |

`sabotage_engine.py` is a test fixture, not part of the product. Nothing in
`demo/backend` imports it and no normal run touches it.

A run that finds a violation records it in `findings` with the generating case,
the mutated case, and both engine responses — enough to reproduce it by hand.


---

## 3. `contract_check.py` — the settlement engine's contract conformance

```bash
python3 tools/contract_check.py
```
→ `11 samples checked against CONTRACT-SETTLEMENT.md §§0,3,4,5` /
`contract shape: OK — 0 violations` (exit 0; exit 1 lists every violation).

Runs every case in `demo/content/settlement_samples.json` through
`.lake/build/bin/settlement-api` and checks the response against the contract,
not against a golden file — so it stays honest when the engine's *answers*
legitimately change and still fails the moment its *shape* or its doctrine
slips. Per sample it asserts:

* the exact top-level key set, and every enum value against the contract's list;
* `classification == "unknown"` **iff** `missing_facts` is non-empty (doctrine 1);
* `probate_estate.status == "partial"` iff its `missing_facts` is non-empty;
* every route id is one of the nine in §4;
* `status == "needs_information"` iff `missing_facts` is non-empty, and
  `status == "does_not_qualify"` iff `reasons` is non-empty;
* every route, flag, deadline, federal row and non-`unknown` asset
  classification carries at least one citation (doctrine 4);
* the jurisdiction verdict is the exact function of its rows, with the fallback
  route excluded from the qualifying test;
* Form 1310 is never `payable` and carries no payee or amount; the lump-sum row
  is never `required` and never payable to the estate; the two rows are in
  stable order;
* `unresolved_facts` is a duplicate-free superset of every missing fact
  anywhere in the response — the product asks its next question from that list,
  so a path missing from it is a question that would never be asked;
* money is non-negative integer cents everywhere;
* an error response is the bare `{"error": {...}}` envelope with a code from
  §3 and a non-empty detail — never a verdict.

**This is not a fuzzer.** It checks 11 authored cases, not generated ones.
There is no property-based fuzzer for `settlement-api`; `fuzz_probate.py` drives
the California `probate-api` only. Do not describe the settlement router as
fuzzed. Writing that fuzzer is the highest-value piece of verification work
left in this repo, and `fuzz_probate.py` already has the shape to copy:
invariants, a coverage histogram, and a sabotage control that proves the
harness is not vacuous.
