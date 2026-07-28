# Final Fix Wave 2 Report

## Status

Complete.

## Scope and root cause

Resolved only the residual fallback-eligibility boundary finding.

All substantive `RouteEligible` branches already require
`SupportedDeathDate case.deathDate`. Consequently, an invalid or
post-snapshot date makes every entry in `nonFallbackRoutes case` disappear.
The fallback branch previously required only `nonFallbackRoutes case = []`,
which therefore made fallback eligibility true precisely when the date was
unsupported.

The regression mutation caught by this change is removal of the
`SupportedDeathDate` conjunct from fallback `RouteEligible`: both new examples
then fail.

## RED

Before editing production code, added two examples proving that fallback
eligibility does not hold for:

- the valid post-snapshot date `2027-01-01`; and
- the invalid civil date `2026-02-29`.

Command:

```text
lake env lean SimpleProbate/Examples.lean
```

Result: exit 1, with the expected failures:

```text
SimpleProbate/Examples.lean:233:43: error: Tactic `decide` proved that the proposition
  ¬RouteEligible postSnapshotDirectCase Route.formalProbateOrOtherProcedure
is false
SimpleProbate/Examples.lean:269:43: error: Tactic `decide` proved that the proposition
  ¬RouteEligible invalidDateCase Route.formalProbateOrOtherProcedure
is false
```

This confirmed that the existing fallback predicate affirmatively held for
both unsupported dates.

## Minimal fix

Changed fallback `RouteEligible` to require both:

1. `SupportedDeathDate case.deathDate`; and
2. `nonFallbackRoutes case = []`.

To preserve `candidateRoutes_sound`, the private unchecked soundness lemma now
accepts a supported-date witness. The checked theorem constructs that witness
from its existing successful `classifyDeathDate` branch and passes it to the
private lemma. The fallback branch combines the witness with the existing
empty-route proof.

No theorem was weakened, and no `sorry`, `admit`, `axiom`, or `unsafe` was
introduced.

## GREEN

The first focused rerun still displayed the old proposition because direct
file checking loaded Lake's stale imported `Eligibility.olean`. Checking
`SimpleProbate/Eligibility.lean` directly succeeded but did not emit the Lake
artifact. The actual imported module target was therefore refreshed:

```text
lake build SimpleProbate.Eligibility
```

Output:

```text
✔ [5/5] Built SimpleProbate.Eligibility (484ms)
Build completed successfully (5 jobs).
```

The required focused command then succeeded:

```text
lake env lean SimpleProbate/Examples.lean
```

Result: exit 0 with no output.

## Full verification

Fresh required commands:

```text
lake env lean SimpleProbate/Examples.lean
lake build
lake exe simple-probate
git diff --check
rg -n '\b(sorry|admit|axiom|unsafe)\b' --glob '*.lean' .
```

Results:

- focused Lean check: exit 0 with no output;
- full build: exit 0, `Build completed successfully (18 jobs).`;
- executable: exit 0 and printed
  `California simple-transfer formalization — sources as of: 2026-07-28; supported death dates through: 2026-12-31`;
- `git diff --check`: exit 0 with no output;
- prohibited-proof scan: exit 1 with no output, the expected clean no-match
  result.

Existing examples continue to verify the checked API contract:

- post-snapshot queries return `.error .afterSnapshot`;
- invalid-date queries return `.error .invalidDate`; and
- a supported case with no substantive route returns
  `.ok [.formalProbateOrOtherProcedure]`.

## Files changed

- `SimpleProbate/Eligibility.lean`
- `SimpleProbate/Examples.lean`
- `.superpowers/sdd/2026-07-28-california-simple-transfer/final-fix-wave-2-report.md`

## Concerns

None.
