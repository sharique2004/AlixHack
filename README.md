# Probate, compiled

**LLMs have gotten good enough to *author* deterministic code from a legal document.
So put the model at authoring time, not query time.** Read the statute once, compile it
into proof-checked Lean 4, and run every case through the compiled code — same answer
every time, traceable to a code section, and refusing by construction to answer beyond
the law it actually read.

This repo does that for US probate eligibility, and then builds the product it enables.

As far as I can find, there is no prior formal-methods or rules-as-code treatment of US
probate. Catala formalized French tax law, PolicyEngine models benefits, Blawx encodes
Canadian statutes — machine-checked probate eligibility appears to be new ground.

---

## Two surfaces

**Atlas** (`/`) — the product. Answer questions about an estate; get back a settlement
map: every asset classified probate or non-probate **with the statute that decides it**,
the transfer routes each jurisdiction allows, the referral flags, the deadlines, and —
the part that matters most — **exactly which facts are still unknown and what each one is
blocking.** Nothing is guessed and nothing is defaulted.

**Evidence** (`/evidence`) — the argument. The same case answered two ways: per-query
Gemini inference on the left, the compiled Lean engine on the right, with live latency,
tokens, and cost. A 12-case ground-truth audit ([`demo/AUDIT.md`](demo/AUDIT.md)) found
the compiled engine correct 12/12; Gemini was correct in 23 of 36 runs, with systematic
— not random — failures on exactly the cases where a fact was unknown.

### The demo that makes the point in ten seconds

Load the two Florida samples back to back. Same estate, same assets, same everything —
the death dates are one day apart:

| death date | summary administration | verdict |
|---|---|---|
| 2026-06-30 | `does_not_qualify` — estate exceeds the **$75,000** limit | `OTHER_FORM_REQUIRED` |
| 2026-07-01 | **`qualifies`** — under the **$150,000** limit | **`ELIGIBLE`** |

Florida's CS/HB 1337 took effect July 1, 2026 and is keyed on date of death, so both
limits are live simultaneously and will be for years. The engine tracks the law *as of a
date*, and it shows its work: `Fla. Stat. §735.201 · CS/HB 1337 (2026), eff. 2026-07-01`.

The car's creditor-exemption is deliberately left **unknown** in both cases. June is ruled
out on the lower bound, July qualifies on the upper — the unknown never has to be resolved.
Two-sided bounds, earning their keep.

## The design rule everything follows

**Unknown is never false.** Every intake field is optional. A missing fact yields
`needs_information` naming the exact path that would resolve it — never a guess, never a
silent default. A *known* violation still beats an unknown, so the engine stays decisive
where it legitimately can. This is enforced in the types, not asked for in a prompt, and
it is the reason the output is safe to hand to a grieving family.

## What is proved, and what is not

Read [`STATUS.md`](STATUS.md) before repeating any claim from this file. The short version:

**Proved.** A soundness theorem for California and for Florida — every route the engine
reports really does satisfy the statutory predicate; it cannot invent an eligibility
(`candidateRoutes_sound`, axioms: `[propext]`). The **federal module is proved sound by
exhaustion** over all 2,592 partial-fact × completion pairs: whenever it answers from
incomplete facts, every completion agrees — and it never asks for a fact that cannot
change the answer. That is the unknown-is-never-false property *machine-checked*, for the
federal items. Plus **366 kernel-checked lemmas** discharged on every build. No `sorry`,
no `axiom`, no `unsafe`, no `native_decide`.

**Not proved.** Completeness, and the general correctness of the *California*
partial-information layer — five theorems stated and left open at
[`SimpleProbate/Partial.lean:24-38`](SimpleProbate/Partial.lean). They are honestly
omitted, not stubbed. That layer is validated by concrete examples, the 12-case audit, and
8,940 fuzzer invariant checks: **well-tested, not verified.** Saying otherwise would
undercut the only thing this project is arguing.

## Reproduce every number

Nothing is displayed that you cannot regenerate from this repo.

```bash
python3 tools/run_audit.py                                   # Lean 12/12
python3 tools/contract_check.py                              # 11 samples, 0 violations
python3 tools/fuzz_probate.py --cases 1000 --seed 20260812   # 8,940 checks, 0 violations
python3 tools/fuzz_probate.py --self-test                    # 13/13 — the harness works
python3 tools/fuzz_probate.py --bin tools/sabotage_engine.py --cases 60   # 22 — control
```

That last line matters: a deliberately broken engine trips 22 violations where the real one
trips zero. A harness that cannot fail proves nothing.

## Run it

```bash
lake build && lake build settlement-api
cd demo/backend && .venv/bin/python -m uvicorn app.main:app --port 8000
cd demo/frontend && npm install && npm run dev
#   localhost:5173            Atlas
#   localhost:5173/evidence   the LLM-vs-compiled comparison
```

## Modules

**California** — `Date` (validity + the Dec 31 2026 snapshot boundary) · `Thresholds`
(§890 date-of-death schedule, in cents) · `Estate` (§13050 exclusions, gross-value
aggregation) · `Eligibility` (typed route predicates + soundness) · `Procedure` (packet
readiness, DE-form checklists) · `Partial` (the tristate engine: satisfied / violated /
unknown, with violation > unknown > satisfied precedence) · `Api`, `Examples`.

**Florida** — `FL/` — summary administration (§735.201), disposition without
administration (§§735.301, 735.304), date-of-death threshold bands.

**Federal** — `Fed/` — IRS Form 1310 decision tree; SSA lump-sum death payment
(42 U.S.C. §402(i)) with its priority ladder, proved never payable to the estate.

**Router** — `Router/` — intake decoding, per-asset probate classification, referral
flags, deadline arithmetic, and the `settlement-api` JSON surface
([`CONTRACT-SETTLEMENT.md`](CONTRACT-SETTLEMENT.md)).

Source traceability for the California thresholds and predicates is in
[`docs/`](docs/); every route carries its statutory citation in the API response.

## Boundary

An educational formal model, **not legal advice**. Lean proves consequences of *supplied*
facts; it does not establish ownership, heirship, valuation, community-property character,
primary-residence status, consent, notice, document truth, or court acceptance. Those stay
human judgments, and the product says so on screen. The California fallback is deliberately
named `formalProbateOrOtherProcedure` because another procedure may apply.

Independent prototype by Sharique Khatri. **Not affiliated with, endorsed by, or connected
to Alix.** Alix's design language is referenced for evaluation purposes only.
