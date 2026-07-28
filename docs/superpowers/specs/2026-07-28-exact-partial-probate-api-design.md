# Exact Partial-Information Probate API Design

## Status

Approved in design review on July 28, 2026.

This specification extends and corrects the existing California simple-transfer
formalization. It keeps the source snapshot of July 28, 2026 and the supported
death-date endpoint of December 31, 2026.

## Purpose

The Lean API must distinguish three materially different conclusions for every
supported simplified-transfer route:

1. the supplied facts establish that the route qualifies;
2. a known fact establishes that the route does not qualify; or
3. the result remains unresolved because required information is unknown.

The API must also determine procedural readiness. It must distinguish an
ineligible route, unknown facts, known-absent documents or actions, and a fully
ready packet.

The implementation must prove that its executable classifications and
diagnostics agree with independent declarative eligibility and readiness
predicates. It is an educational formal model, not legal advice, and it does
not prove that user-supplied facts or documents are true.

## Existing Baseline

The repository already contains a dependency-free Lean 4.32.1 implementation
covering:

- direct transfers;
- the personal-property small-estate affidavit;
- the small-value real-property affidavit;
- the primary-residence petition;
- the spousal-property petition; and
- a formal-probate-or-other-procedure fallback.

The baseline compiles and includes boundary examples plus a one-way
`candidateRoutes_sound` theorem. It does not provide:

- an exact completeness theorem for route classification;
- a representation of unknown facts;
- a distinction between known disqualification and missing information;
- a proof that an empty missing-requirement list is equivalent to readiness; or
- a completion-based soundness contract for partial inputs.

The review also identified legal-model defects that this design corrects:

- the section 13050(c)(2) employment-compensation exclusion is currently
  applied once per asset instead of once to aggregate qualifying compensation;
- one `grossValue` field currently conflates current gross fair market value
  with date-of-death appraisal value; and
- the small-real-property will attachment is currently required whenever a
  claimant claims under a will, even though section 13200(d) makes it
  conditional on no California estate proceeding being pending or having been
  conducted.

## Success Criteria

The work is complete when:

- every supported route receives an independent, typed report;
- complete inputs produce exact `qualifies` or `doesNotQualify` results;
- incomplete inputs never turn unknown facts into negative facts;
- every `needsInformation` report names the unresolved atomic facts;
- fallback is recommended only when every simplified route is conclusively
  disqualified;
- each packet report distinguishes unknown facts from known-absent
  requirements;
- each total packet has a proved
  `missingRequirements = [] ↔ Ready` theorem;
- valuation functions implement the corrected statutory rules;
- all public proof contracts compile without `sorry`, `admit`, `axiom`, or
  `unsafe`; and
- the project remains a Lean API without an interactive questionnaire or new
  external dependency.

## Design Principles

### Independent specification and execution

Declarative `Prop`-valued eligibility and readiness predicates remain the
normative Lean specification. Executable reports are derived from typed atomic
checks, not defined as the predicates themselves. Theorems connect the two.

### Unknown is not false

Externally supplied facts use an explicit knowledge type. A route is
disqualified only by a known violation. Missing information produces a
separate outcome.

### Nonexclusive routes

All simplified routes are evaluated independently. A case may qualify for more
than one route, and one route may qualify while another remains unresolved.

### Structural errors are not legal conclusions

Known invalid dates and contradictory input structures yield typed errors.
They do not yield `doesNotQualify`.

## Architecture

### `SimpleProbate/Date.lean`

Keep civil-date validation, death-date bands, and the supported snapshot
endpoint. Date-dependent checks will accept partial dates:

- an unknown date creates a `deathDate` information requirement;
- a known invalid date yields `CaseError.invalidDate`; and
- a known date after December 31, 2026 yields
  `CaseError.afterSnapshot`.

No post-2026 rule is inferred.

### `SimpleProbate/Thresholds.lean`

Keep money in natural-number cents and preserve the existing threshold
schedule. Add or retain theorem examples for every band boundary.

Threshold lookup for a partial date returns an unresolved check when the date
is unknown and an error when the known date is invalid or unsupported.

### `SimpleProbate/Decision.lean`

Add a focused module containing generic partial-information machinery.

The core knowledge type has two states:

```lean
inductive Knowledge (α : Type)
  | unknown
  | known (value : α)
```

Atomic checks evaluate to:

```lean
inductive CheckResult
  | satisfied
  | violated (reason : Disqualifier)
  | unknown (fact : RequiredFact)
```

Generic aggregation obeys this precedence:

1. one or more violations produce `doesNotQualify` with all known
   disqualifiers;
2. no violations and one or more unknowns produce `needsInformation` with all
   unresolved facts; and
3. all checks satisfied produces `qualifies`.

Diagnostic lists preserve stable source order and contain no duplicates.

### `SimpleProbate/Estate.lean`

Replace structural target equality with stable asset identifiers. An asset
name remains descriptive, while an `AssetId` supplies identity. A transfer
case refers to its target by ID.

Separate the two relevant value concepts:

- current gross fair market value, used by the personal-property affidavit
  valuation in section 13101(a)(5); and
- date-of-death fair market value, used by inventory and appraisal procedures
  governed by section 8802.

A partial asset exposes independently known fields, including:

- property kind;
- current gross value;
- date-of-death value;
- valuation treatment;
- primary-residence status; and
- inclusion in a section 13151 petition.

A partial estate contains its currently listed assets and an
`inventoryComplete` fact. If the inventory is not known to be complete, a
known subtotal above a cap can disqualify a capped route, but a known subtotal
at or below a cap cannot establish qualification.

Well-formed total estates require:

- unique asset IDs;
- a resolvable target ID when a target is required;
- property-kind and treatment combinations used by a route to be consistent;
- only California real property to be marked as a primary residence or as
  included in a section 13151 petition; and
- every asset field required by a selected valuation to be known.

Known violations of these structural rules yield `CaseError.malformedCase`
with finite issue labels.

#### Correct employment-compensation aggregation

The personal-affidavit valuation will first sum all qualifying employment
compensation, then exclude:

```text
min aggregateEmploymentCompensation applicableSection13050Limit
```

exactly once. The residual employment amount is added to the other countable
property. Separate theorems establish:

- the aggregate exclusion never exceeds the dated limit;
- splitting one compensation amount across multiple assets does not change the
  result;
- all qualifying military-service compensation remains excluded;
- encumbrances do not reduce any gross eligibility value; and
- each section 13050 treatment contributes the intended amount.

### `SimpleProbate/Eligibility.lean`

Keep independent declarative predicates for:

- each direct-transfer basis;
- personal-property affidavit eligibility;
- small-value real-property affidavit eligibility;
- primary-residence petition eligibility; and
- spousal-property petition eligibility.

Each route is also represented by an ordered collection of typed atomic checks.
Each check has:

- a stable requirement identifier;
- a total declarative meaning;
- a partial evaluator; and
- a lemma connecting complete evaluation to its declarative meaning.

The public per-route status is:

```lean
inductive RouteStatus
  | qualifies
  | doesNotQualify (reasons : List Disqualifier)
  | needsInformation (facts : List RequiredFact)
```

Constructors that carry lists have proved nonempty-list invariants.

The primary public function is:

```lean
assessRoutes :
  PartialTransferCase → Except CaseError CaseAssessment
```

`CaseAssessment` contains a report for every route and one overall outcome:

- `simplifiedRoutesAvailable`;
- `unresolved`; or
- `formalProbateOrOtherProcedure`.

The overall fallback outcome is produced only when every simplified route is
`doesNotQualify`. It is not produced if any route qualifies or needs
information.

The existing total `routeEligible` and candidate-route surface may remain as
compatibility helpers where that does not obscure the new exact API. Any
breaking change will be documented in the README.

### `SimpleProbate/Procedure.lean`

Packet items use three states:

```lean
inductive PacketItemState
  | unknown
  | absent
  | present
```

Applicability remains derived from case and context facts. An unknown
applicability fact is reported as required information. A required item that
is known absent is reported as a missing requirement.

The public packet function is:

```lean
assessPacket :
  Route → PartialTransferCase → PartialPacket →
    Except CaseError ReadinessAssessment
```

`ReadinessAssessment` is:

- `ineligible`, with route disqualifiers;
- `incomplete`, with separate unresolved-fact and missing-requirement lists; or
- `ready`.

An incomplete result may contain both unknown facts and known-absent
requirements. Readiness requires route qualification, every applicable fact
resolved, and every applicable packet item present.

The small-real-property affidavit requires a will attachment precisely when
the claimant claims under the will and no estate proceeding is pending or has
been conducted. Written personal-representative consent does not trigger that
attachment rule by itself.

Direct transfer and fallback retain workflows but do not receive artificial
court-packet predicates.

### `SimpleProbate/Examples.lean`

Keep examples as compile-checked regression theorems. Add examples for every
new outcome and corrected boundary.

### Root modules and README

`SimpleProbate.lean` will import the new public decision module. The README
will document:

- total and partial API entry points;
- the three route outcomes;
- readiness outcomes;
- the source snapshot and supported date boundary;
- corrected valuation-time semantics; and
- the disclaimer that Lean proves consequences of supplied facts rather than
  their truth or legal sufficiency.

`Main.lean` remains informational. No questionnaire is added.

## Data Flow

### Route assessment

1. Validate every known date and structural invariant.
2. Evaluate each route's atomic checks against the partial case.
3. Collect every known violation and unresolved fact for that route.
4. Aggregate the checks into the route's status.
5. Produce all route reports without selecting a preferred route.
6. Compute the overall outcome from the complete set of route statuses.

### Packet assessment

1. Run route assessment for the requested route.
2. If the route is disqualified, return the known disqualifiers.
3. Evaluate packet applicability and supplied-item checks even if some route
   facts remain unknown.
4. Keep unknown facts separate from known-absent requirements.
5. Return `ready` only if route eligibility and every applicable packet
   obligation are established.

## Formal Proof Contract

### Total route exactness

For every well-formed total case and supported route:

```text
the route report is qualifies ↔ RouteEligible case route
the route report is doesNotQualify ↔ ¬ RouteEligible case route
```

The list of qualifying routes is therefore both sound and complete.

### Fallback exactness

For every well-formed total case:

```text
overall outcome is formalProbateOrOtherProcedure
  ↔ every simplified route is ineligible
```

For partial cases, fallback implies that every compatible well-formed
completion leaves every simplified route ineligible.

### Partial-input soundness

Define `Completes partial total` to mean that the total case agrees with every
known fact in the partial case and supplies each unknown fact.

For every well-formed partial case:

```text
qualifies
  → every compatible well-formed completion satisfies the route predicate

doesNotQualify
  → no compatible well-formed completion satisfies the route predicate
```

`needsInformation` contains exactly the unresolved atomic checks after known
violations are excluded by the aggregation precedence. The design does not
claim that unknown facts are false.

### Packet equivalence

For each total packet type:

```text
missingRequirements context case packet = []
  ↔ Ready context case packet
```

For each requirement:

```text
requirement ∈ missingRequirements context case packet
  ↔ requirement applies and is not supplied
```

The corresponding partial theorem separates unknown applicability or supply
facts from known absence.

### Error contract

Successful assessment proves that all known structural inputs passed
validation. Invalid dates, unsupported dates, duplicate IDs, unresolved target
references in otherwise total cases, and contradictory asset classifications
cannot be silently converted into route outcomes.

## Error Handling

`CaseError` includes at least:

- `invalidDate`;
- `afterSnapshot`; and
- `malformedCase (issues : List StructuralIssue)`.

Unknown facts are ordinary report data, not errors. A route does not qualify
merely because its disqualifiers are unknown, and it is not disqualified
merely because its qualifying evidence is missing.

## Verification

The authoritative verification command remains:

```bash
lake build
```

Focused checks also run:

```bash
lake env lean SimpleProbate/Examples.lean
lake exe simple-probate
git diff --check
rg -n '\b(sorry|admit|axiom|unsafe)\b' --glob '*.lean' .
```

Required regression coverage includes:

- all existing date and threshold boundaries;
- personal-property value exactly at and one cent over each relevant cap;
- two or more employment-compensation assets whose aggregate exceeds the
  exclusion;
- invariance under splitting or combining compensation assets;
- current-value versus date-of-death-value examples;
- incomplete inventory below a cap producing `needsInformation`;
- a known subtotal over a cap producing `doesNotQualify` despite an incomplete
  inventory;
- a known disqualifier taking precedence over unrelated unknown facts;
- a qualifying route coexisting with another unresolved route;
- fallback suppression whenever any route is unresolved;
- fallback exactness when all routes are known ineligible;
- malformed asset and duplicate-ID errors;
- all four packet empty-list equivalences;
- unknown versus absent packet items;
- the section 13200(d) will-attachment condition under both authority modes;
- invalid and post-snapshot date errors; and
- compile-time scans showing no prohibited declarations.

## Source Traceability

The corrections and proof targets rely on these official sources:

- [California Courts: When formal probate may not be needed](https://selfhelp.courts.ca.gov/probate/simple-transfer)
- [Probate Code section 13050](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=PROB&sectionNum=13050.)
- [Probate Code section 13101](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=PROB&sectionNum=13101.)
- [Probate Code section 13200](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=PROB&sectionNum=13200.)
- [Probate Code section 8802](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?article=&chapter=1.&division=7.&lawCode=PROB&part=3.&title=)

The original design document retains the complete route and form source list.

## Out of Scope

- proving the truth of factual inputs;
- determining heirs, ownership, title, will validity, value, domicile, venue,
  community-property character, or primary-residence status;
- selecting the legally best route when multiple routes qualify;
- guaranteeing acceptance by a holder, court, clerk, recorder, notary, or
  probate referee;
- preparing or filing forms;
- an interactive CLI, web UI, or questionnaire;
- rules effective after December 31, 2026; and
- unrelated refactoring of the existing Lean project.
