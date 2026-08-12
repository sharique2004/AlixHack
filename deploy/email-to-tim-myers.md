# Draft email — review before sending

**To:** tim.myers@meetalix.com
**Subject:** Probate eligibility, compiled to proof-checked code — a working demo

---

Hi Tim,

I went to the Agents of Administration hackathon in July and have kept building
since. I wanted to show you where it ended up, because I think it argues
something specific about agent reliability that's relevant to how Alix is
building.

**The claim:** models are now good enough to *author* deterministic code from a
statute. So the right place for the LLM is authoring time, not query time. Read
the law once, compile it into machine-checked Lean 4, and run every case through
the compiled code — same answer every time, traceable to a code section, and
refusing by construction to answer beyond the law it actually read.

Live: https://atlas.shariquekhatri.com · Code: <repo link>

**The ten-second version.** Two estates, identical in every respect, with dates
of death one day apart:

- died 2026-06-30 → summary administration ruled out, estate exceeds $75,000
- died 2026-07-01 → **qualifies**, under the $150,000 limit

Florida's CS/HB 1337 took effect July 1 and is keyed on date of death, so both
limits are live simultaneously and will be for years. The engine tracks the law
as of a date and shows its work. The interesting part is subtler: one asset's
creditor-exemption status is left *unknown* in both cases. June fails on the
lower bound, July passes on the upper, so the unknown never has to be resolved.

**What's actually formalized.** California simple transfer (Prob. Code §§13100,
13150, 13200, 13500 — five routes across three date-of-death threshold bands),
Florida summary administration and disposition without administration (§§735.201,
735.301, 735.304), and the federal layer (IRS Form 1310's decision tree, and the
SSA lump-sum death payment under 42 U.S.C. §402(i)). On top of that sits a
router that classifies each asset probate or non-probate — including the traps
that actually bite, like a predeceased beneficiary dropping an asset back into
the probate estate — plus fifteen referral flags and a deadline calendar.

**The design rule I'd want to be judged on: unknown is never false.** Every
intake field is optional. A missing fact produces `needs_information` naming the
exact path that would resolve it — never a guess, never a silent default — while
a *known* violation still beats an unknown, so the engine stays decisive where it
legitimately can. That's enforced in the type system rather than asked for in a
prompt, which is the whole point: it's a property of the architecture, not of how
well the prompt was written that day.

**What's proved, and what isn't.** Soundness theorems for California and Florida:
every route the engine reports genuinely satisfies the statutory predicate, so it
cannot invent an eligibility. The federal module is proved sound by exhaustion
over all 2,592 partial-fact × completion pairs — that's the unknown-is-never-
false property machine-checked rather than merely tested. 366 kernel-checked
lemmas run on every build; no `sorry`, no `axiom`.

What is *not* proved is completeness, and the general correctness of California's
partial-information layer — five theorems I've stated and deliberately left open
in the code rather than papered over. That layer is covered by property-based
harnesses instead (a 12-case ground-truth audit, 8,940 fuzz invariant checks, and
a deliberately sabotaged engine as a control to prove the harness can actually
fail). It's well-tested, not verified, and the repo says so in those words.

I'm aware this is a demonstration of an architecture, not a product, and that the
hard part of a real estate is characterizing the facts — which sits outside the
verified boundary and stays a human judgment.

I saw the Agent Systems Engineer role is open. I'd welcome 20 minutes to walk
through it, or to hear where you think it breaks.

Best,
Sharique Khatri
<phone> · <github/linkedin>

---

## Before you send

- [ ] Replace `<repo link>`, `<phone>`, `<github/linkedin>`
- [ ] Confirm https://atlas.shariquekhatri.com actually resolves and the two
      Florida samples return different verdicts — the email leads with that claim
- [ ] If the site isn't up yet, cut the live link rather than promising it
- [ ] Decide whether to mention the hackathon by name (he may not have attended)
