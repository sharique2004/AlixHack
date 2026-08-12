# STATUS — honest state of this repo

*Rewritten 2026-08-12 by the integration pass, replacing an earlier STATUS.md that described
Atlas as not existing. It does now. Every claim below was produced by a command run against
this working tree on this machine, and every command is reproduced so you can re-run it.
Where I did not verify something, I say so.*

**Read this before showing the project to anyone.** The short version: there are now two
working products in this repo, and the verification story behind them is real but narrower
than the word "verified" usually implies. §4 states exactly how narrow.

---

## 0. The one-paragraph truth

The **California simple-transfer demo** (the Evidence page) works end to end and its
verification story holds up. The **Atlas settlement router** — a multi-jurisdiction CA/FL/
federal engine with an intake wizard and a case-file UI — now also works end to end: it
builds, it runs as a compiled binary, it serves over HTTP, and the browser renders live
engine output. What is *proved* about either engine is a soundness theorem plus a large body
of compile-time regressions. What is *not* proved is completeness and the general
correctness of the partial-information layer — the five theorems still open at
`SimpleProbate/Partial.lean:24-38`. That gap is the single most important thing on this page
and §4 is about nothing else.

---

## 1. What works end-to-end (verified this session)

### 1.1 The Lean engine builds clean, from scratch

```bash
cd /Users/shariquekhatri/Alix/AlixHack && rm -rf .lake/build \
  && ~/.elan/bin/lake build && ~/.elan/bin/lake build settlement-api
```
→ `Build completed successfully (68 jobs).` in **13.7 s**, then
`Build completed successfully (64 jobs).` in **5.0 s**.

`lake build` alone compiles every module including `Router/`, `FL/` and `Fed/` — the lib root
`SimpleProbate.lean` imports them, so the regressions in those modules gate the default
build. `settlement-api` is a separate executable target.

No `sorry`, no `axiom`, no `unsafe`, no `native_decide` anywhere:
```bash
grep -rn "\bsorry\b\|\baxiom \|\bunsafe \|native_decide" --include="*.lean" . | grep -v "\.lake"
```
→ no matches.

**366 kernel-checked lemmas** are discharged on every build (352 `example`, 14 `theorem`):
```bash
grep -rn "^\s*example\b" --include="*.lean" SimpleProbate | wc -l          # 352
grep -rn "^\s*\(private \)\?theorem\b" --include="*.lean" SimpleProbate | wc -l  # 14
```
Split by module: core CA 79 + 2, Router 118, FL 63 + 1, Fed 92 + 11.

### 1.2 The Florida date-of-death band — the flagship demo — is live

Two cases identical apart from `decedent.death_date`, through the real compiled binary:

```bash
cd /Users/shariquekhatri/Alix/AlixHack && python3 - <<'EOF'
import json, subprocess
S={s['id']:s for s in json.load(open('demo/content/settlement_samples.json'))['samples']}
for sid in ('fl-threshold-death-june-30-2026','fl-threshold-death-july-1-2026'):
    r=json.loads(subprocess.run(['./.lake/build/bin/settlement-api'],
        input=json.dumps(S[sid]['case']),capture_output=True,text=True).stdout)
    j=r['jurisdictions'][0]
    print(sid, j['verdict'], [(x['route'],x['status']) for x in j['routes']])
EOF
```

Observed:

| death date | verdict | summary administration | formal administration |
|---|---|---|---|
| 2026-06-30 | `OTHER_FORM_REQUIRED` | `does_not_qualify` | `qualifies` |
| 2026-07-01 | `ELIGIBLE` | **`qualifies`** | `does_not_qualify` |

The reason string on the June case, verbatim from the engine:

> `Fla. Stat. §735.201(2): the estate exceeds the $75,000.00 limit for this date of death and the decedent has not been dead for more than 2 years`

Same $120,000 estate, one day apart, opposite answers, because CS/HB 1337 raised the
§735.201(2) ceiling from $75,000 to $150,000 effective 2026-07-01. The pair is also pinned as
compile-time regressions in `SimpleProbate/Router/Tests.lean` ("Florida — the date-of-death
band"), including an `example` proving the two cases differ in exactly one field.

One detail worth pointing at in a demo: the car's `exempt_from_creditors` is deliberately
left **unknown** in both samples. The June case is disqualified on the *lower* bound (the two
accounts alone are $105,000 > $75,000) and the July case qualifies on the *upper* bound
($120,000 ≤ $150,000), so the unknown never has to be resolved in either direction. That is
the two-sided valuation bound in `SimpleProbate/FL/Partial.lean` doing real work.

### 1.3 All 11 sample cases return contract-shaped JSON

```bash
cd /Users/shariquekhatri/Alix/AlixHack && python3 tools/contract_check.py
```
→ `11 samples checked against CONTRACT-SETTLEMENT.md §§0,3,4,5` / `contract shape: OK — 0 violations`

That harness is not a smoke test. Per sample it checks: exact top-level key set; every enum
value against the contract's list; `classification == unknown ⟺ missing_facts non-empty`;
`probate_estate.status == partial ⟺ missing_facts non-empty`; every route id against §4;
`needs_information ⟺ missing_facts non-empty`; `does_not_qualify ⟺ reasons non-empty`; every
route, flag, deadline and federal row carrying at least one citation; every non-`unknown`
asset classification carrying a citation; the jurisdiction verdict being the exact function
of its rows; the federal rows' status ranges (Form 1310 is never `payable`, the lump sum is
never `required` and never payable to the estate) and their stable order;
`unresolved_facts` being a duplicate-free superset of every missing fact anywhere in the
response; and money being non-negative integer cents.

Verdicts observed:

| sample | jurisdictions | federal |
|---|---|---|
| `ca-canonical-married-couple` | CA `INCOMPLETE_INFO` | 1310 `not_required`, SSA `payable` |
| `fl-threshold-death-june-30-2026` | FL `OTHER_FORM_REQUIRED` | 1310 `required`, SSA `not_payable` |
| `fl-threshold-death-july-1-2026` | FL `ELIGIBLE` | 1310 `required`, SSA `not_payable` |
| `ca-beneficiary-predeceased` | CA `OTHER_FORM_REQUIRED` | — |
| `ca-unknown-title-residence` | CA `INCOMPLETE_INFO` (8 open facts) | both `needs_information` |
| `ca-insolvent-estate` | CA `ELIGIBLE` + `insolvent_estate`, `medicaid_estate_recovery` | — |
| `ca-death-under-investigation` | CA `INCOMPLETE_INFO` + `slayer_rule_screen` (critical) | SSA `payable` |
| `ca-domicile-out-of-state-real-property` | CA `ELIGIBLE`, **AZ** `ancillary` (no routes) | — |
| `ca-domicile-florida-condo` | CA `ELIGIBLE`, **FL** `ancillary` with real routes | — |
| `ca-small-estate-all-known` | CA `ELIGIBLE` | — |
| `error-death-after-snapshot` | error envelope `after_snapshot` | — |

The `ca-canonical-married-couple` row reproduces CONTRACT §6 exactly: home and 401(k)
non-probate, brokerage + car probate at $159,000 known subtotal, savings `unknown` and
blocking the cap test, CA `INCOMPLETE_INFO`, spousal petition `qualifies`, nothing critical,
final Form 1040 computed 2027-04-15, Form 1310 `not_required`, lump sum `payable` to the
surviving spouse at $255.

### 1.4 The engine does not crash on hostile input

20 adversarial payloads (empty string, non-JSON, bare array, bare `null`, missing
`as_of_date`, non-integer and negative cents, unknown enum values on both §2 and §2.1 fields,
duplicate asset names, death after the snapshot, 2026-02-29, death after `as_of_date`, an
all-`null` case, an unknown top-level key, an unmodelled domicile) →
**exit 0 and a parseable contract envelope every time, 0 crashes**, stderr empty. Structural
problems come back as `malformed_case` / `invalid_date` / `after_snapshot`; they are never
reported as legal conclusions.

### 1.5 The backend serves both products

```bash
cd /Users/shariquekhatri/Alix/AlixHack/demo/backend && .venv/bin/python -m uvicorn app.main:app --port 8000
```

| Endpoint | Observed |
|---|---|
| `GET /api/health` | `{"ok":true,"gemini_configured":true,"lean_engine":"binary","settlement_engine":"binary"}` |
| `GET /api/settlement/samples` | `{"samples":[…]}`, 11 samples |
| `POST /api/settlement/assess` | 200 on all 11; `x-engine-path: binary`, `x-engine-latency-ms: 27` |
| `POST /api/settlement/assess` (post-snapshot death) | **200** with the error envelope, per contract — not a 5xx |
| `POST /api/settlement/assess` (bad enum, missing `as_of_date`) | 422 from the Pydantic gate |
| `GET /api/cases` | 12 cases (the Evidence page's own fixtures) |
| `POST /api/analyze/lean` | **200 on all 12**, verdict matches the AUDIT.md expectation on all 12 (the error case correctly returns `verdict: null`) |

The Evidence page has not regressed. `IntakeCase` is a wire-shape gate only: it is validated
and discarded, and the endpoint forwards the **raw request body** to the engine, so an
explicit `null` can never become `false` on the way through.

### 1.6 The frontend type-checks, builds, and renders live engine output

```bash
cd /Users/shariquekhatri/Alix/AlixHack/demo/frontend && npx tsc --noEmit && npm run build
```
→ both clean; 62 modules, `dist/assets/index-*.js` 144 KB (47 KB gzip), `CaseFile-*.js`
29 KB in the production bundle.

Driven live in a browser against `vite --port 5173` proxying to the running backend:
loading the `fl-threshold-death-july-1-2026` sample fires `POST /api/settlement/assess`
→ 200, and the real `CaseFile` component (not a fixture) renders

> *"Everything with a value on record sits inside the probate estate. What's left qualifies in
> Florida — summary administration."* · `FL Florida — State of domicile` · `ELIGIBLE` ·
> `Summary administration / fl_summary_administration / Qualifies / Fla. Stat. §735.201 /
> CS/HB 1337 (2026), eff. 2026-07-01`

Switching to the June sample re-renders as `OTHER_FORM_REQUIRED` / formal administration.
No console errors. `/evidence` still loads the original CA comparison page with its own
stylesheet and its own `<title>`.

### 1.7 The property-based harnesses run and pass

All figures below were observed on this machine this session, seed `20260812`:

| command | observed |
|---|---|
| `python3 tools/run_audit.py` | **Lean 12/12** at verdict level, 0 discrepancies against `demo/AUDIT.md`; writes `tools/audit_runs.json` |
| `python3 tools/fuzz_probate.py --cases 1000 --seed 20260812` | 1,000 cases → **7,940 engine invocations, 8,940 invariant checks, 0 violations**, 30.4 s |
| `python3 tools/fuzz_probate.py --self-test` | **13/13** checkers behaved as specified |
| `python3 tools/fuzz_probate.py --bin tools/sabotage_engine.py --cases 60` | **22 violations** caught against a deliberately broken engine — the harness is not vacuous |
| `python3 tools/contract_check.py` | 11 samples, **0 violations** |

Invariants asserted by the fuzzer: response shape, aggregation (the fallback row and the
overall outcome are the exact function of the five simplified rows), monotonicity of the five
simplified routes under value increases, unknown-safety (nulling a known fact never promotes
a route), snapshot handling, invalid-date handling, determinism.

A previously recorded 25,000-case run (`tools/fuzz_report_25k.json`: 198,523 invocations,
223,523 checks, 0 violations, 915 s) is in the repo. **I did not re-run it this session** —
re-run it yourself before quoting it.

---

## 2. What is new since the previous STATUS.md

Everything the old file listed as "absent from disk" now exists and compiles:
`SimpleProbate/Router/` (3,667 lines), `SimpleProbate/FL/` (1,812), `SimpleProbate/Fed/`
(1,731), `SettlementMain.lean`, `tools/`, `demo/content/settlement_samples.json`,
`demo/frontend/src/atlas/**` (7,055 lines of TS/TSX/CSS).

The integration pass itself did the following, beyond assembling what six agents built:

1. **Wired the two seams the router left open.** `SimpleProbate/Router/Florida.lean` and
   `SimpleProbate/Router/Federal.lean` are new: they adapt `IntakeCase` to
   `FL.PartialCase` / `Fed.FederalCase` and project the results back onto the wire types.
   `Assess.lean`'s `federalReports`/`domicileJurisdiction` stubs are gone; ancillary
   jurisdictions in a modelled state now carry real routes.
2. **Extended the intake with the facts those engines need**, as an explicitly additive
   CONTRACT §2.1 (see §3 below).
3. **Fixed a real verdict defect.** `verdictOf` counted the fallback row, so a case whose
   only qualifying route was *formal probate* reported `ELIGIBLE` — the opposite of what it
   means. It now excludes `ca_formal_probate_or_other` / `fl_formal_administration`, matching
   `SimpleProbate/Partial.lean:584` and `Api.verdictFor` in the older frozen contract. This
   is why `ca-beneficiary-predeceased` now reads `OTHER_FORM_REQUIRED`. Two regressions pin it.
4. **Closed two doctrine-4 holes** (a legal conclusion without a citation): Florida-domicile
   asset classifications shipped with `citation: null`, and the `conflict_risk` flag carried
   none at all. Both now carry authorities verified this session against primary sources —
   see §3.
5. **Made `lake build` cover the new modules** by importing them from the lib root, so their
   regressions gate the default build instead of only the executable target.
6. **Dated the one non-reproducible number in the UI** (§5).

---

## 3. Contract changes made this session

The contract wins over any implementation, so where the implementation needed something the
contract did not have, the contract was amended rather than the rule bent.

**§2.1 — additive request fields.** §2 is unchanged and a §2-only request still works. The
FL and federal engines need facts §2 did not carry, so §2.1 names them:
`decedent.{will_directs_administration, administration_pending, federal_refund_due,
refund_claimant, final_return_kind, court_certificate_attached, ssa_insured_at_death}`,
`assets[i].exempt_from_creditors`,
`heirs[i].{lived_in_same_household_at_death, entitled_to_spouse_benefits_month_of_death,
entitled_to_child_benefits_month_of_death}`, `heirs_complete`, and `expenses`. All optional,
all defaulting to unknown. Omitting them yields `needs_information` naming those exact paths
— which is what `ca-unknown-title-residence` shows.

This matters for reading §6: the contract states a federal *outcome* (1310 `not_required`,
lump sum `payable`) without stating the facts that produce it. The engine assumes neither, so
the canonical sample now supplies them explicitly.

**Two things the §2.1 note holds the implementation to**, both verified in the code:

* `situs_state` is **never** defaulted to the domicile. §735.201(2) measures the estate
  subject to administration *in Florida*; a defaulted situs would be an assumption doing real
  work inside a cap test. An asset with no situs is counted neither in nor out.
* `entitled_to_child_benefits_month_of_death` is **never** derived from `relationship`.
  §402(d) entitlement does not track the probate label.

**§3 — the verdict precedence is now written down**, because two jurisdictions in one
response must not grade themselves on different curves.

**§4 — the Florida citation was wrong.** The $10,000 → $20,000 figure CS/HB 1337 raised is in
Fla. Stat. **§735.304**, not §735.301 (§735.301 has no fixed dollar figure at all — its limit
is entirely the preferred-funeral-plus-last-60-days-medical allowance). Both sections are
disposition without administration and share the one route id. Found by the FL agent,
verified against flsenate.gov.

**Citations added this session**, each checked against the primary source before it was
written (leg.state.fl.us and leginfo.legislature.ca.gov, 2026-08-12):

| where | authority |
|---|---|
| FL asset classification — survivorship | Fla. Stat. §689.15 *Estates by survivorship* |
| FL — pay-on-death accounts | §655.82 *Pay-on-death accounts* |
| FL — beneficiary designation / designation to estate | §222.13(1) *Life insurance policies; disposition of proceeds* |
| FL — sole name, no designation | §733.607(1) *Possession of estate* |
| FL — funded trust | ch. 736 *Florida Trust Code* |
| `conflict_risk` flag | UPC §3-1202; Cal. Prob. Code §13110(a); Cal. Code Civ. Proc. §377.31 |

One near-miss worth recording as a caution: my first draft of the `conflict_risk` citation
was Cal. Prob. Code **§13109**. Checking it showed §13109 is about a transferee's liability
for the decedent's *unsecured debts*; the superior-right liability is **§13110(a)**. The
citation was corrected before it shipped. Every citation in this repo should be treated as
checkable, and this one is why.

---

## 4. The verification story — precisely what is and is not proved

This matters more than anything else here, because verifiability is the project's entire
thesis. Overstating it would undercut the one thing the project is arguing.

### What is genuinely machine-checked

* **A soundness theorem.** `SimpleProbate/Eligibility.lean`, `candidateRoutes_sound`: if
  `candidateRoutes case = .ok routes` and `route ∈ routes`, then `RouteEligible case route`.
  Every route the engine reports as available really does satisfy the statutory predicate —
  the engine cannot invent an eligibility it has not earned. `SimpleProbate/FL/Eligibility.lean`
  proves the same shape for Florida. `#print axioms` on both → `[propext]`.
* **The federal module's soundness is proved by exhaustion, and it is the strongest result in
  the repo.** `Form1310.assess_partial_sound` checks all 108 partial fact sets against all 24
  completions — 2,592 pairs — and confirms that whenever the decision tree gives a verdict
  from incomplete facts, every completion agrees. `assess_partial_complete` proves the
  converse: it never asks for a fact that cannot change the answer.
  `Ssa.payee_ne_estate` is a real proof by cases that the lump sum is never payable to the
  estate. This is the doctrine-1 property machine-checked, not merely exercised — for the
  federal items only.
* **366 compile-time lemmas** across the four module groups, discharged by `decide`/`rfl` at
  build time. They hold if and only if `lake build` is green.

### What is NOT proved — the open TODO

`SimpleProbate/Partial.lean:24-38` documents five deferred theorems for the **California**
partial layer. They are honestly omitted, not stubbed — there is no `sorry` pretending they
hold:

1. **Total route exactness** — `qualifies ↔ RouteEligible`, `doesNotQualify ↔ ¬RouteEligible`
   for well-formed total cases. Soundness is proved; the converse, completeness, is not.
   Nothing yet rules out the engine failing to report a route that is in fact available.
2. **Fallback exactness** — overall `formalProbateOrOtherProcedure` ↔ every simplified route
   is conclusively ineligible.
3. **Partial-input soundness** via `Completes partial total` — that `qualifies` holds under
   *every* compatible completion and `doesNotQualify` under none.
4. **`needsInformation` exactness** — that it lists exactly the unresolved atomic checks.
5. **Nonempty-list invariants** on the `doesNotQualify` / `needsInformation` constructors.

**(3) is the important gap.** The unknown-is-never-false behaviour is the product's headline
differentiator and the thing the LLM demonstrably gets wrong in `AUDIT.md`. For California it
is validated by concrete examples, by the 12-case audit, and by 8,940 fuzzer invariant checks
— **but its general correctness is not proved. It is well-tested, not verified.** Florida's
partial layer is in the same position: its two-sided bounds are argued in the module
docstring and exercised by 63 examples, and the partial/total agreement is demonstrated on
three concrete fully-known cases by `decide`, not proved universally.

### The fuzzer covers the old engine, not the new one

`tools/fuzz_probate.py` drives `probate-api` — the **California** engine behind the Evidence
page. There is no property-based fuzzer for `settlement-api`. The new engine's evidence is
366 compile-time lemmas, `tools/contract_check.py` over 11 samples, and the 20 adversarial
inputs in §1.4. That is real, and it is less than what the CA engine has. Do not describe the
settlement router as fuzzed.

### Honest phrasing

Accurate: "machine-checked"; "soundness is proved: it never invents an eligibility"; "366
lemmas checked at compile time"; "the federal layer's partial-information soundness is proved
by exhaustion over all 2,592 fact/completion pairs"; "12/12 against an independent
ground-truth audit"; "1,000 fuzzed cases, 8,940 invariant checks, zero violations, on the CA
engine"; "the Florida date-of-death band is demonstrated end to end through the compiled
binary".

Not accurate: "proved correct"; "verified complete"; any claim that the *California* partial
layer's general correctness is proved; any fuzzing claim about the settlement engine; any
figure not in §1.

---

## 5. Numbers displayed in the product

Every figure the UI shows is reproducible from this repo, with one that is now dated rather
than removed:

* **"79 checked lemmas"** on the Evidence page — accurate for the CA engine that page is
  about: `grep -c '^\s*example\b' SimpleProbate/*.lean` → 64 in `Examples.lean` + 15 in
  `Partial.lean`. (The repo-wide figure is 366; the page is scoped to the CA engine.)
* **"12/12 audit"** — `python3 tools/run_audit.py`.
* **"23/36 runs correct · audit of 2026-07-28"** — the Gemini half. It is a **record of a
  dated run, not a live score**: re-sampling a non-deterministic model at non-zero
  temperature produces new numbers rather than confirming old ones. The badge now carries the
  date and its tooltip says so; `demo/AUDIT.md` says so; `tools/run_audit.py --llm 3` will
  re-run it with a `GEMINI_API_KEY` and real money. **Do not present it as reproducible.**
* The fabricated **"435,456 fuzzed cases"** claim removed by an earlier pass has **not**
  returned:
  ```bash
  grep -rn "435,456\|435456" . --exclude-dir={node_modules,.venv,.git,.lake,dist} --exclude=STATUS.md
  ```
  → no matches. (This file is excluded because the line above quotes it in order to document
  it; that is the only surviving occurrence in the repo.)

---

## 6. Known defects and caveats

| # | Item | Severity |
|---|---|---|
| 1 | CA partial-information layer is tested, not proved (§4). Same for FL. | disclose, don't hide |
| 2 | Completeness is not proved for either engine — an engine could in principle under-report a route. No such case is known; the audit and the fuzzer found none. | disclose |
| 3 | **No property-based fuzzer for `settlement-api`.** Its evidence is compile-time lemmas + `contract_check.py` + adversarial inputs. | real gap |
| 4 | Florida route rows report **no form numbers**. Florida has no statewide numbered small-estate forms answering to California's DE-series; these are Probate Rules petitions on county circuit-court forms. `forms: []` is deliberate — inventing numbers would be worse. | by design |
| 5 | Florida assets carry **no `counts_toward`**. §735.201(2) subtracts exempt property, so an asset whose exemption is unknown may or may not count; a flat list cannot express a two-sided bound without overstating one side. The FL route rows carry the separating facts instead. | by design, documented in `Classify.lean` |
| 6 | Ancillary jurisdictions in **unmodelled** states (e.g. AZ) carry `routes: []` and verdict `OTHER_FORM_REQUIRED`; only the `ancillary_probate_required` flag explains why. FL ancillary entries do carry real routes. | known gap |
| 7 | Three California facts are **derived, not asked**: `authority` ← `pending_litigation == false`; `claimant_is_successor` ← a non-disclaiming heir exists; `no_superior_right` ← heirs listed **and** `conflict_signals == false`. A `notes` entry states this on every CA response. | disclosed in-band |
| 8 | `snapshot.source_as_of` is `"2026-07-28"` (the date the sources were read), not the `"2026-08-12"` in the contract's illustrative JSON, which is that fixture's `as_of_date`. | intentional |
| 9 | `GET /api/lean-source` still globs `SimpleProbate/*.lean` only, so the Evidence page's source viewer does not show `Router/`, `FL/`, `Fed/` or `SettlementMain.lean`. CONTRACT §0 froze that surface, so it was left alone. | known, cosmetic |
| 10 | `_children_cpu_ms()` uses process-wide `RUSAGE_CHILDREN`; concurrent requests can cross-contaminate the CPU metric. Fine for a demo, wrong for billing. | known, acceptable |
| 11 | Snapshot boundary hard-coded to 2026-12-31. Correct by design (doctrine 3), but the repo goes stale after that date. | by design |
| 12 | The Gemini comparison needs a live `GEMINI_API_KEY` and real money per run; 23/36 is not reproducible (§5). | operational |
| 13 | The intake wizard does not yet **ask** for the §2.1 facts. It round-trips them faithfully when a sample supplies them (verified: the FL flagship survives load → assess), but a user typing a Florida case by hand will get `needs_information` on `will_directs_administration` and `expenses`. | real gap, next job |
| 14 | `tools/fuzz_report_25k.json` records a run I did not repeat this session, and an absolute `engine_binary` path. | disclose |

---

## 7. Run the whole thing

```bash
# 1. Engine — both binaries, from scratch
cd /Users/shariquekhatri/Alix/AlixHack
rm -rf .lake/build && ~/.elan/bin/lake build && ~/.elan/bin/lake build settlement-api

# 2. The engine alone, no server — the flagship demo
python3 -c "import json;print(json.dumps([s for s in json.load(open('demo/content/settlement_samples.json'))['samples'] if s['id']=='fl-threshold-death-july-1-2026'][0]['case']))" \
  | ./.lake/build/bin/settlement-api | python3 -m json.tool

# 3. Evidence — run every harness
python3 tools/run_audit.py                                   # Lean 12/12
python3 tools/contract_check.py                              # 11 samples, 0 violations
python3 tools/fuzz_probate.py --cases 1000 --seed 20260812   # 0 violations
python3 tools/fuzz_probate.py --self-test                    # 13/13
python3 tools/fuzz_probate.py --bin tools/sabotage_engine.py --cases 60   # 22 violations (control)

# 4. Backend  (GEMINI_API_KEY in demo/backend/.env only for the LLM half)
cd demo/backend && .venv/bin/python -m uvicorn app.main:app --port 8000

# 5. Frontend
cd ../frontend && npm install && npx tsc --noEmit && npm run dev
#   http://localhost:5173           Atlas — settlement router
#   http://localhost:5173/evidence  the original CA / LLM comparison
```

Demo path, 60 seconds: open `/`, click **See it on a sample case**, then load
*Florida — $120,000 estate, death June 30 2026* and *…death July 1 2026* back to back.

---

## 8. If you are picking this up to finish it

In value order:

1. **Ask for the §2.1 facts in the wizard** (defect #13). Five controls — will directs
   administration, administration pending, per-asset exempt-from-creditors, funeral and
   last-illness expenses — and a hand-typed Florida case becomes as sharp as the sample.
2. **Fuzz `settlement-api`** (defect #3). `tools/fuzz_probate.py` already has the shape:
   invariants, coverage histogram, and a sabotage control. The settlement invariants worth
   asserting are the ones `tools/contract_check.py` checks on 11 samples, over generated
   cases — plus unknown-safety, which is the doctrine that matters and the one no theorem
   covers for CA or FL.
3. **Discharge theorem (3)** at `Partial.lean:24-38`. `SimpleProbate/Fed/Form1310.lean` shows
   the shape at a scale where exhaustion works; the CA layer's fact space is too large for
   `decide`, so this one needs a real proof rather than an enumeration. It is the claim the
   whole project would most like to be able to make.
4. **Give unmodelled ancillary states real content** (defect #6), or say plainly in the UI
   that the engine models CA and FL and everything else is a referral.
