# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Two audiences, weighted equally: (1) hackathon judges and attendees seeing the demo projected or
hands-on for 2–5 minutes; (2) product evaluators (Alix-adjacent, legal-tech) deciding whether the
architecture is a real product direction afterward. Mixed technical fluency: some read Lean and
token counts, some read only the story. The surface must land for both without a presenter.

## Product Purpose

An interactive demo of one architecture claim: LLMs have gotten good enough to *author*
deterministic code from a legal document — so the right design is to use the LLM once at
authoring time (court page → proof-checked Lean 4 code) and run every user query through the
compiled code, not through an LLM. The demo proves it live on California probate "simple
transfer" eligibility: the same structured case answered by per-query Gemini inference (left)
and by the compiled Lean engine (right). Success: a first-time viewer grasps the
author-once/execute-forever pipeline in under a minute, and can verify every claim by running
cases themselves.

## Positioning

The pipeline is the product, not the comparison. Competing demos run user queries through an
LLM and hope; this one runs queries through law that was compiled (with LLM assistance) into
machine-checked Lean code — deterministic, traceable to Probate Code sections, and refusing to
answer beyond its source snapshot. NOT positioned as "LLM bad": positioned as "put the LLM at
authoring time, not query time."

## Operating Context

Hackathon stage (projected, ~1-minute walkthrough, unreliable Wi-Fi possible) and quiet
follow-up evaluation on a laptop. Live Gemini calls take 8–20 s, cost ~$0.01, and vary
run-to-run; the Lean binary answers in ~20 ms CPU for ≈$0.0000005, identically every time.
Twelve curated sample cases exercise every verdict, including partial-information and
snapshot-boundary cases.

## Capabilities and Constraints

- Three verdicts (ELIGIBLE / INCOMPLETE_INFO / OTHER_FORM_REQUIRED) plus a typed error state
  (invalid date, after-snapshot, malformed case). Six transfer routes assessed independently.
- Unknown ≠ false: null input fields are unknowns; known violations beat unknowns.
- Money in integer cents; death-date thresholds banded by statute; source snapshot ends
  2026-12-31 — the Lean engine refuses beyond it by construction.
- Backend contract (FastAPI :8000): POST /api/analyze/llm (optional ?model= override),
  /api/analyze/lean; GET /api/cases, /api/lean-source, /api/models, /api/health. CheckResult
  carries verdict/routes/reasoning/engine/latency_ms/usage.
- NEW REQUIREMENT: a dropdown to switch the Gemini model (model choice only, nothing else);
  current text-capable IDs include gemini-2.5-flash (default), gemini-2.5-pro,
  gemini-2.5-flash-lite, gemini-3.5-flash, gemini-3.5-flash-lite, gemini-3.6-flash.
- All existing functionality must survive the redesign: run case, per-route results, rule
  trace/reasons, Lean source viewer, latency/token/cost metrics, LLM re-run, sample picker,
  JSON editing (may be progressively disclosed), per-panel error states.

## Brand Commitments

No product name yet. USER-PINNED AESTHETIC (2026-07-28, binding; supersedes the earlier
split-flap direction, which the user rejected): modern light SaaS comparison-section style per
a user-provided Dribbble reference (Abu Fahim, "Crypto Market Problems vs Smart Solutions") —
white page, centered pill-badge + large bold heading + gray subtext, two large rounded
comparison cards (neutral card vs blue-gradient-tinted "solution" card), rounded icon tiles,
arrow-bullet checklists with hairline dividers, soft borders/shadows, Inter-class typography.
Execute the convention at full fidelity, no irony. Earlier pin still holds where compatible:
keep copy tight; depiction over words.

## Evidence on Hand

Real, non-fabricated numbers only (do not invent others). Every figure below is reproducible
from this repo — if you cannot reproduce it, delete it rather than repeat it:

* Ground-truth audit of 12 cases — Lean 12/12 correct, Gemini 23/36 runs correct, with
  systematic (not sampling-noise) partial-information failures. Source: `AUDIT.md`.
  The Lean half replays on demand (`python3 tools/run_audit.py`); the Gemini half is a
  **record of the 2026-07-28 run**, not a reproducible result — always date it.
* 12/12 sample cases replay to their documented verdict through the compiled binary
  (`.lake/build/bin/probate-api`), exit 0, no crash. Re-run: see `STATUS.md`.
* 79 machine-checked `example` lemmas discharged at compile time (64 in
  `SimpleProbate/Examples.lean`, 15 in `SimpleProbate/Partial.lean`); no `sorry`, no `axiom`,
  no `unsafe`. They hold iff `lake build` is green.
* Live metrics per run, measured not asserted. Observed over all 12 sample cases through
  `POST /api/analyze/lean`: median 18 ms wall, 16.8 ms CPU, ≈$0.00000019 per case (first
  call of a session is a ~145 ms / 40 ms cold start). The LLM side is measured live per run
  from the API response and varies a lot, so quote whatever the run in front of you reports
  rather than a remembered figure.
* Lean source at `AlixHack/SimpleProbate/*.lean`; court page content in
  `content/simple-transfer.md`.

### The settlement router (Atlas), observed 2026-08-12

* **366 kernel-checked lemmas** repo-wide (352 `example` + 14 `theorem`), all discharged on
  every `lake build`: 81 core CA, 118 router, 64 Florida, 103 federal. Count them with the
  two `grep`s in `STATUS.md` §1.1.
* **The Florida date-of-death band, end to end through the compiled binary.** Two sample
  cases identical apart from `decedent.death_date`: 2026-06-30 → `OTHER_FORM_REQUIRED`
  (summary administration ruled out, $75,000 band), 2026-07-01 → `ELIGIBLE` (summary
  administration qualifies, $150,000 band, CS/HB 1337). Also pinned as compile-time
  regressions. This is the demo.
* **11 sample cases, 0 contract violations** (`python3 tools/contract_check.py`) against
  CONTRACT-SETTLEMENT.md §§0, 3, 4, 5 — including "every legal conclusion carries a citation"
  and "needs_information iff missing_facts non-empty".
* **20 adversarial inputs, 0 crashes**, exit 0 and a parseable envelope every time.
* The federal layer's partial-information soundness is **proved by exhaustion** over all 108
  partial fact sets × 24 completions (2,592 pairs), plus a proof by cases that the Social
  Security lump sum is never payable to the estate.

### What you may NOT claim

* **No fuzzing of the settlement engine.** `tools/fuzz_probate.py` drives the *California*
  `probate-api` only: 1,000 cases → 7,940 invocations, 8,940 invariant checks, 0 violations,
  30.4 s, seed 20260812; self-test 13/13; sabotage control catches 22 violations. Quote it as
  a result about the CA engine, never about Atlas.
* **Not "proved correct" and not "verified complete."** Soundness is proved for CA and FL
  ("it never invents an eligibility"); completeness is not, and the California
  partial-information layer's general correctness is **tested, not proved** — the five open
  theorems at `SimpleProbate/Partial.lean:24-38`. `STATUS.md` §4 has the exact wording.

## Product Principles

1. Show, don't tell: every concept a viewer must grasp gets a depiction first, prose second.
2. The pipeline is the story: authored once (law → code), executed forever (case → verdict).
3. Every claim is runnable: numbers on screen come from live runs the viewer can trigger.
4. One surface, two depths: instant comprehension for everyone; inspectable detail (routes,
   traces, source, costs) one deliberate step away, never deleted.
5. Honest theater: real variance, real latency, real costs — the drama is never staged.
