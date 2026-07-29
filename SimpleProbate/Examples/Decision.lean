import SimpleProbate.Decision

namespace SimpleProbate.Examples.Decision

open SimpleProbate

inductive TestFact
  | deathDate
  | estateValue
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive TestFailure
  | tooSoon
  | overCap
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

example :
    aggregateChecks
      ([.satisfied, .satisfied] :
        List (CheckResult TestFact TestFailure)) =
      .qualifies := by decide

example :
    aggregateChecks
      ([.unknown .deathDate, .unknown .estateValue, .satisfied,
        .unknown .deathDate] :
        List (CheckResult TestFact TestFailure)) =
      .needsInformation [.deathDate, .estateValue] := by decide

example :
    aggregateChecks
      ([.unknown .estateValue, .violated .tooSoon,
        .violated .overCap, .violated .tooSoon] :
        List (CheckResult TestFact TestFailure)) =
      .doesNotQualify [.tooSoon, .overCap] := by decide

example : Knowledge.unknown.Completes (true : Bool) := by trivial
example : (Knowledge.known true).Completes true := by rfl
example : ¬(Knowledge.known false).Completes true := by decide

end SimpleProbate.Examples.Decision
