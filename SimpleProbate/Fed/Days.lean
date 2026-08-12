import SimpleProbate.Partial

/-!
# Civil-date day arithmetic for federal claim windows

`SimpleProbate.Date` orders and validates `CivilDate`s but does not count
days between them. The federal layer needs that: 42 U.S.C. §402(i) bars a
lump-sum death payment unless an application is filed "prior to the
expiration of two years after the date of death", so the engine has to turn
a date of death and an as-of date into an open/closed window.

Two things are computed here and nothing else:

* `dayNumber` — the proleptic-Gregorian day index of a valid `CivilDate`,
  with 0001-01-01 as day 0. Used only for differences, so the choice of
  epoch is immaterial; it is fixed so the regressions below can pin exact
  day counts.
* `plusYears` — the calendar anniversary. A period measured in *years* runs
  to the same month and day, not to a fixed number of days, so a period
  spanning a 29 February is one day longer. 29 February itself has no
  anniversary in a common year and clamps to 28 February, which is how SSA
  and the courts treat it.

`daysBetween` is Nat-subtracting and therefore truncates at zero; callers
must establish ordering first (`CivilDate.atMost`). `claimWindow` does.
-/

namespace SimpleProbate
namespace Fed

/-- Days in months `1 … m` of `year` (so `m = 0` is zero days). -/
private def cumulativeDaysInMonths (year : Nat) : Nat → Nat
  | 0 => 0
  | m + 1 => cumulativeDaysInMonths year m + CivilDate.daysInMonth year (m + 1)

/-- Day index of a valid `CivilDate` in the proleptic Gregorian calendar,
counting 0001-01-01 as day 0. Meaningless for invalid dates; every caller
validates with `CivilDate.valid` / `classifyDeathDate` first. -/
def dayNumber (d : CivilDate) : Nat :=
  let priorYears := d.year - 1
  365 * priorYears + priorYears / 4 - priorYears / 100 + priorYears / 400 +
    cumulativeDaysInMonths d.year (d.month - 1) + (d.day - 1)

/-- Days from `start` to `finish`, truncated at zero when `finish` precedes
`start`. Only call with `start.atMost finish`. -/
def daysBetween (start finish : CivilDate) : Nat :=
  dayNumber finish - dayNumber start

/-- The same month and day, `n` calendar years later. 29 February clamps to
28 February in a common year; no other date moves. -/
def plusYears (d : CivilDate) (n : Nat) : CivilDate :=
  let year := d.year + n
  { year := year
    month := d.month
    day := min d.day (CivilDate.daysInMonth year d.month) }

private def pad2 (n : Nat) : String :=
  if n < 10 then "0" ++ toString n else toString n

/-- ISO-8601 rendering, for citation and reason text. -/
def isoDate (d : CivilDate) : String :=
  s!"{d.year}-{pad2 d.month}-{pad2 d.day}"

/-- State of a statutory claim period measured in years from an event date,
evaluated at an as-of date. `unknown` carries the fact paths blocking the
computation — the period is never assumed to be open or closed. -/
inductive ClaimWindow
  | stillOpen (deadline : CivilDate) (daysRemaining : Nat)
  | expired (deadline : CivilDate) (daysSinceDeadline : Nat)
  | unknown (facts : List FactPath)
deriving BEq, DecidableEq, Repr

/-- The deadline date of a computed window (`none` while unknown). -/
def ClaimWindow.deadline? : ClaimWindow → Option CivilDate
  | .stillOpen deadline _ => some deadline
  | .expired deadline _ => some deadline
  | .unknown _ => none

/-- A claim period of `years` years running from `eventDate`, evaluated at
`asOf`. The period expires at the end of its anniversary date, so a claim
made *on* the anniversary is still timely; `asOf` one day later is not.

`eventDate` is `Option` because the date of death may be unknown, in which
case the window is unknown and names `eventFact` — never open, never closed. -/
def claimWindow
    (eventDate : Option CivilDate) (asOf : CivilDate) (years : Nat)
    (eventFact : FactPath) : ClaimWindow :=
  match eventDate with
  | none => .unknown [eventFact]
  | some event =>
    let deadline := plusYears event years
    if asOf.atMost deadline then
      .stillOpen deadline (daysBetween asOf deadline)
    else
      .expired deadline (daysBetween deadline asOf)

/-! ## Regressions

The day-count formula is pinned against known-length calendar spans, and the
anniversary rule is pinned at its boundary in all three shapes it can take:
a span with no 29 February (730 days), a span containing one (731 days), and
a 29 February date of death (730 days, clamped to 28 February). -/

namespace DaysExamples

-- Common year, leap year, and a full Gregorian cycle.
example : daysBetween ⟨2025, 1, 1⟩ ⟨2026, 1, 1⟩ = 365 := by decide
example : daysBetween ⟨2024, 1, 1⟩ ⟨2025, 1, 1⟩ = 366 := by decide
example : daysBetween ⟨1900, 1, 1⟩ ⟨2000, 1, 1⟩ = 36524 := by decide
example : daysBetween ⟨2026, 3, 4⟩ ⟨2026, 3, 4⟩ = 0 := by decide

-- Anniversaries.
example : plusYears ⟨2026, 3, 4⟩ 2 = ⟨2028, 3, 4⟩ := by decide
example : plusYears ⟨2024, 2, 29⟩ 2 = ⟨2026, 2, 28⟩ := by decide
example : plusYears ⟨2024, 2, 29⟩ 4 = ⟨2028, 2, 29⟩ := by decide

/-! ### Two-year boundary, span with no 29 February: the window is 730 days -/

-- Death 2025-03-01 → deadline 2027-03-01, which is 730 days later.
example : daysBetween ⟨2025, 3, 1⟩ (plusYears ⟨2025, 3, 1⟩ 2) = 730 := by decide

-- Day 729 (2027-02-28): open, one day left.
example :
    claimWindow (some ⟨2025, 3, 1⟩) ⟨2027, 2, 28⟩ 2 "decedent.death_date" =
      .stillOpen ⟨2027, 3, 1⟩ 1 := by decide

-- Day 730 (2027-03-01): the anniversary itself — still open, zero days left.
example :
    claimWindow (some ⟨2025, 3, 1⟩) ⟨2027, 3, 1⟩ 2 "decedent.death_date" =
      .stillOpen ⟨2027, 3, 1⟩ 0 := by decide

-- Day 731 (2027-03-02): expired by one day.
example :
    claimWindow (some ⟨2025, 3, 1⟩) ⟨2027, 3, 2⟩ 2 "decedent.death_date" =
      .expired ⟨2027, 3, 1⟩ 1 := by decide

/-! ### Two-year boundary, span containing 29 February: the window is 731 days

Counting 730 days from the date of death would close this window a day early. -/

-- Death 2023-03-01 → deadline 2025-03-01, 731 days later (29 Feb 2024 falls inside).
example : daysBetween ⟨2023, 3, 1⟩ (plusYears ⟨2023, 3, 1⟩ 2) = 731 := by decide

-- Day 730 (2025-02-28): open.
example :
    claimWindow (some ⟨2023, 3, 1⟩) ⟨2025, 2, 28⟩ 2 "decedent.death_date" =
      .stillOpen ⟨2025, 3, 1⟩ 1 := by decide

-- Day 731 (2025-03-01): the anniversary — still open.
example :
    claimWindow (some ⟨2023, 3, 1⟩) ⟨2025, 3, 1⟩ 2 "decedent.death_date" =
      .stillOpen ⟨2025, 3, 1⟩ 0 := by decide

-- Day 732 (2025-03-02): expired.
example :
    claimWindow (some ⟨2023, 3, 1⟩) ⟨2025, 3, 2⟩ 2 "decedent.death_date" =
      .expired ⟨2025, 3, 1⟩ 1 := by decide

/-! ### 29 February date of death: the anniversary clamps to 28 February -/

example : daysBetween ⟨2024, 2, 29⟩ (plusYears ⟨2024, 2, 29⟩ 2) = 730 := by decide

example :
    claimWindow (some ⟨2024, 2, 29⟩) ⟨2026, 2, 28⟩ 2 "decedent.death_date" =
      .stillOpen ⟨2026, 2, 28⟩ 0 := by decide

example :
    claimWindow (some ⟨2024, 2, 29⟩) ⟨2026, 3, 1⟩ 2 "decedent.death_date" =
      .expired ⟨2026, 2, 28⟩ 1 := by decide

-- An unknown date of death leaves the window unknown, never open or closed.
example :
    claimWindow none ⟨2026, 8, 12⟩ 2 "decedent.death_date" =
      .unknown ["decedent.death_date"] := by decide

end DaysExamples

end Fed
end SimpleProbate
