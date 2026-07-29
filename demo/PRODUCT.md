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

Use only evidence runnable at the shipped head: exactness and
partial-completion soundness theorems, the backend contract suite that executes
all 12 shipped cases against the compiled adapter, and live per-run metrics.
`AUDIT.md` is a historical pre-migration Gemini experiment, not current
performance evidence. Lean source lives in `SimpleProbate/*.lean`; court-page
content lives in `content/simple-transfer.md`.

## Product Principles

1. Show, don't tell: every concept a viewer must grasp gets a depiction first, prose second.
2. The pipeline is the story: authored once (law → code), executed forever (case → verdict).
3. Every claim is runnable: numbers on screen come from live runs the viewer can trigger.
4. One surface, two depths: instant comprehension for everyone; inspectable detail (routes,
   traces, source, costs) one deliberate step away, never deleted.
5. Honest theater: real variance, real latency, real costs — the drama is never staged.
