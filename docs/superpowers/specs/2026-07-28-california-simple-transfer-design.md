# California Simple Transfer 2026 Lean Formalization Design

## Purpose

Build a Lean 4 model of the California probate “simple transfer” decision
process described by the California Courts Self-Help Guide, using the rules in
force during 2026. The model will answer two distinct questions:

1. Which simplified transfer routes are supported by a supplied set of facts?
2. What factual assertions, documents, notices, and ordered steps are required
   before a supported route is ready to use?

The formalization is an executable and theorem-backed explanation of the
published process. It is not legal advice, does not decide disputed facts, and
does not prove that the supplied facts are true.

## Source-as-of Date and Authority

The model is based on the law and official guidance available on July 28, 2026.
The California Courts page controls the project’s practical scope and route
names. The Probate Code controls statutory prerequisites when the guide is
abbreviated. Judicial Council forms identify the operative filing artifacts.

Primary sources:

- [California Courts: When formal probate may not be needed](https://selfhelp.courts.ca.gov/probate/simple-transfer)
- [California Courts: Small estate affidavit to transfer personal property](https://selfhelp.courts.ca.gov/probate/small-estate)
- [Probate Code section 890](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=PROB&division=2.&title=&part=21.&chapter=&article=)
- [Probate Code sections 13000–13007](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=PROB&division=8.&title=&part=1.&chapter=1.&article=)
- [Probate Code sections 13050–13054](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=PROB&division=8.&title=&part=1.&chapter=2.&article=)
- [Probate Code sections 13100–13117](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=PROB&division=8.&title=&part=1.&chapter=3.&article=)
- [Probate Code sections 13150–13157](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=PROB&division=8.&title=&part=1.&chapter=4.&article=)
- [Probate Code sections 13200–13211](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=PROB&division=8.&title=&part=1.&chapter=5.&article=)
- [Probate Code sections 13500–13506](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=PROB&division=8.&title=&part=2.&chapter=1.&article=)
- [Probate Code sections 13650–13660](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=PROB&division=8.&title=&part=2.&chapter=5.&article=)
- Judicial Council forms DE-221, DE-226, DE-300, DE-305, DE-310, and
  DE-315 as effective in 2026.

The model records its snapshot year and rejects any claim that it supplies
post-2026 rules. It may classify older death dates because the applicable limit
depends on the date of death.

## Approaches Considered

### Theorem-backed executable rules model — selected

Computable functions calculate countable estate values, applicable limits, and
candidate routes. Prop-valued predicates state legal prerequisites, and
theorems connect the computations to those predicates. This provides useful
scenario evaluation without reducing the formalization to opaque Boolean
answers.

### Proof certificates only

Each successful transfer would be represented solely by an inhabitant of an
inductive proof type. This is logically clean but makes route discovery and
boundary testing unnecessarily cumbersome.

### Full court workflow state machine

Every filing, notice, hearing, and recording could be modeled as a transition.
This would represent chronology more literally, but it would introduce
court-administration detail not supplied by the source page. The selected
design instead formalizes ordered checklists and readiness predicates.

## 2026 Threshold Schedule

All money is represented as a natural number of U.S. cents. Gross values are
used; debts, mortgages, liens, and encumbrances never reduce an eligibility
value unless a statute expressly says otherwise.

| Rule | Before Apr. 1, 2022 | Apr. 1, 2022–Mar. 31, 2025 | Apr. 1, 2025–Dec. 31, 2026 |
| --- | ---: | ---: | ---: |
| Family set-aside, §§6602/6609 | $85,900 | $95,325 | $107,900 |
| Employment-compensation exclusion, §13050(c) | $16,625 | $18,450 | $20,875 |
| Personal-property affidavit estate cap, §§13100/13101 | $166,250 | $184,500 | $208,850 |
| Primary-residence petition cap, §§13151–13154 | $166,250 | $184,500 | $750,000 |
| Small-value California real-property affidavit cap, §13200 | $55,425 | $61,500 | $69,625 |
| Surviving-spouse earnings collection, §§13600/13601 | $16,625 | $18,450 | $20,875 |

The next regular adjustment is April 1, 2028. No post-2026 adjusted value will
be guessed.

## Formal Boundary

Lean will treat the following as supplied facts:

- the date of death and elapsed-time facts;
- ownership form, location, asset classification, and gross date-of-death
  value;
- whether property was a California primary residence;
- whether the claimant is a statutory successor and whether anyone has a
  superior right;
- whether a probate proceeding exists and whether the personal representative
  gave written consent;
- whether property passes to a surviving spouse or domestic partner;
- whether declarations are truthful, debts have been paid when required, and
  notices were properly delivered;
- whether a court, clerk, recorder, holder, probate referee, or notary has
  performed an external act.

Lean will prove only that route eligibility or readiness follows from those
inputs under the encoded 2026 rules. The fallback result will be named
`formalProbateOrOtherProcedure`; it will not claim that formal probate is
legally necessary because the site itself says it “may” be necessary and other
specialized procedures may exist.

## Architecture

The existing `simple-probate` Lean project will remain dependency-free and use
Lean 4.32.1.

### `SimpleProbate/Date.lean`

Defines `CivilDate`, date validity and comparison, the three supported
date-of-death bands, and the December 31, 2026 supported death-date endpoint.
Concrete boundary examples establish that March 31 and April 1 fall into the
intended bands.

### `SimpleProbate/Thresholds.lean`

Defines `Money` in cents, exact threshold constants, and total functions from a
supported death date to each threshold. It exposes named definitions matching
the Probate Code sections and proves the 2026 values.

### `SimpleProbate/Estate.lean`

Defines assets, property location and kind, direct-transfer bases, valuation
treatments, and estate aggregation.

The personal-affidavit estate value will:

- include gross California real and personal property;
- include insurance or retirement benefits payable to the estate;
- exclude joint-tenancy and death-terminable interests, revocable trusts,
  property passing directly to a surviving spouse, qualifying multiple-party
  accounts, registered vehicles, vessels, registered mobile or manufactured
  homes, real property outside California, direct-beneficiary assets, and
  government benefits;
- exclude all qualifying military-service amounts;
- exclude qualifying employment compensation only up to the dated
  section 13050(c) limit;
- exclude property included in a section 13151 primary-residence petition; and
- never subtract debt or encumbrance amounts from gross value.

Separate aggregations compute California real-property value for section 13200
and the gross value of California primary-residence property for sections
13151–13154.

### `SimpleProbate/Eligibility.lean`

Defines shared facts, `SummaryAuthority` (`noProceeding`,
`writtenPersonalRepresentativeConsent`, or `blockedByProceeding`), route
predicates, and a computable list of candidate routes.

The supported routes are:

1. `directTransfer basis`, for government benefits, named beneficiaries,
   trusts, joint tenancy, transfer-on-death ownership, qualifying
   multiple-party accounts, and direct spousal passage represented by an
   explicit `DirectTransferBasis`;
2. `personalPropertyAffidavit`, requiring a personal-property target,
   successor status, no superior claimant, at least 40 elapsed days, permitted
   summary authority, and countable estate value no greater than the dated
   personal-affidavit cap;
3. `smallValueRealPropertyAffidavit`, requiring a California real-property
   target, successor status, no superior claimant, six elapsed calendar months,
   permitted summary authority, paid funeral, last-illness, and unsecured
   debts, and aggregate qualifying California real property no greater than the
   dated section 13200 cap;
4. `primaryResidencePetition`, requiring California primary-residence
   property, successor status, at least 40 elapsed days, permitted summary
   authority, and primary-residence gross value no greater than the dated
   section 13151 cap; and
5. `spousalPropertyPetition`, requiring a surviving spouse or registered
   domestic partner and facts supporting property passing to or already
   belonging to that survivor. This route has no value cap.

Candidate routes are nonexclusive because one fact pattern can permit more
than one procedure. Direct-transfer bases are asset-specific and do not imply
that every estate asset transfers directly.

### `SimpleProbate/Procedure.lean`

Defines document and performance records and readiness predicates for each
court or affidavit route.

The personal-property affidavit packet requires the section 13101 declarations,
a certified death certificate, reasonable identity proof, available ownership
evidence or the modeled holder-required indemnity alternative, written consent
and letters when consent is the authority, the dated DE-300 amount list for
deaths on or after April 1, 2022, and a probate-referee inventory and appraisal
when the estate contains California real property. Notarization is recorded as
recommended or institution-requested, not universally mandatory.

The small-value real-property affidavit packet requires DE-305-compatible
statements, notarized acknowledgments, a probate-referee inventory and
appraisal, certified death certificate, conditional will and consent
attachments, the dated amount list when applicable, delivery to a known
guardian or conservator, court filing, a clerk-certified copy, and county
recording.

The primary-residence petition packet requires DE-310-compatible verified
statements, inventory and appraisal, conditional will and consent attachments,
the dated amount list when applicable, delivery to each named heir and devisee
within five business days after filing, statutory hearing notice, court
findings, and a DE-315-compatible order.

The spousal petition packet requires DE-221-compatible allegations, property
descriptions and supporting facts, known heir/devisee/executor information,
disclosure of any non-pro-rata property agreement, conditional attachments,
hearing notice, and a DE-226-compatible order.

Each workflow exposes an ordered list of stages for human readability, but
readiness is a conjunction of typed obligations rather than a simulation of
court behavior.

### `SimpleProbate/Examples.lean`

Contains compile-checked examples and theorem tests. It will include:

- a 2026 personal-property estate exactly at $208,850 that qualifies;
- the same estate one cent over the cap that does not qualify;
- a 39-day personal affidavit case that fails and a 40-day case that succeeds;
- exclusion of a joint-tenancy asset from the personal-affidavit value;
- proof that a mortgage does not reduce the gross eligibility value;
- the partial $20,875 employment-compensation exclusion for a 2026 death;
- a 2026 section 13200 case at $69,625 and a one-cent-over counterexample;
- failure of section 13200 before six calendar months;
- a qualifying $750,000 California primary residence and failures for
  one-cent-over and non-primary-residence property;
- equivalence of no proceeding and written-consent authority where the statutes
  provide those alternatives;
- a spousal petition example independent of estate value; and
- a case with no encoded route returning
  `formalProbateOrOtherProcedure`.

### Root modules and README

`SimpleProbate.lean` imports every public module. `Main.lean` prints the
source-as-of date and supported death-date endpoint rather than acting as a
legal questionnaire. `README.md` states the scope, run commands, source-as-of
date, disclaimer, and a source-to-definition traceability table.

## Proof and API Design

Every route has:

- a Prop-valued eligibility predicate;
- a decidable instance or Boolean-facing query;
- a theorem showing that every route returned by the candidate-route function
  satisfies the corresponding eligibility predicate; and
- boundary examples compiled by `lake build`.

The four court or affidavit routes—personal-property affidavit, small-value
real-property affidavit, primary-residence petition, and spousal-property
petition—also have readiness predicates for their procedural packets. Direct
transfer and the fallback route expose workflows but no artificial readiness
packets.

The public API will favor descriptive names tied to source sections. Internal
proof helpers remain private where possible. No axiom, `sorry`, `admit`, or
unsafe declaration is permitted.

## Error Handling

Invalid dates and post-2026 dates yield explicit unsupported results rather
than silently selecting a threshold. Missing facts or documents yield an
ineligible or not-ready result together with a finite list of unmet requirement
labels. The labels are explanatory identifiers, not legal conclusions.

## Verification

`lake build` is the authoritative test command. The implementation will also
scan all Lean sources for `sorry`, `admit`, `axiom`, and `unsafe`. Concrete
`example` declarations and decision evaluations cover threshold, timing,
exclusion, proceeding-consent, and packet-readiness boundaries.

## Out of Scope

- determining heirs, will validity, title, community-property character, fair
  market value, domicile, venue, or whether a residence is “primary”;
- automating court forms, e-filing, notices, notarization, appraisal, or
  recording;
- modeling creditor priority, transferee liability, fraud damages, taxes, fees,
  appeals, or later estate administration in full;
- benefit-program-specific collection rules, DMV/HCD transfers, trust
  administration, or financial-institution policies;
- law effective after December 31, 2026; and
- guaranteeing that a holder or court accepts a filing.
