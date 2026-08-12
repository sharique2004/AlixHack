import SimpleProbate.Date

/-!
# Civil-date arithmetic

`SimpleProbate.Date` supplies validity and ordering for `CivilDate` but no
arithmetic. Deadlines need day counts and date addition, so this module adds
them: a bijection between valid proleptic-Gregorian dates (year ≥ 1) and a day
number, plus day/month offsets built on top of it.

The conversion is Howard Hinnant's `days_from_civil` / `civil_from_days`
algorithm transcribed to `Nat`, with the epoch left at the algorithm's natural
0000-03-01 so that every representable date has a non-negative day number and
no `Nat` subtraction ever truncates. Leap years come out of the algorithm
itself (the 400/100/4 rule of `days_before_year`), not out of a special case;
the boundary examples at the end of the file are checked by `decide`.
-/

namespace SimpleProbate
namespace Router

/-- Days elapsed since 0000-03-01 in the proleptic Gregorian calendar.
Defined for any date with `year ≥ 1`; garbage in, garbage out for dates that
fail `CivilDate.valid` (callers validate first). -/
def dayNumber (d : CivilDate) : Nat :=
  -- March-based year: January and February belong to the previous cycle year,
  -- which is what makes the leap day fall at the end of the year.
  let y := if d.month ≤ 2 then d.year - 1 else d.year
  let era := y / 400
  let yoe := y - era * 400                      -- year of era, [0, 399]
  let mp := if 2 < d.month then d.month - 3 else d.month + 9
  let doy := (153 * mp + 2) / 5 + d.day - 1     -- day of March-based year
  let doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe

/-- Inverse of `dayNumber`. -/
def ofDayNumber (z : Nat) : CivilDate :=
  let era := z / 146097
  let doe := z % 146097
  let yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y := yoe + era * 400
  let doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp := (5 * doy + 2) / 153
  let day := doy - (153 * mp + 2) / 5 + 1
  if mp < 10 then ⟨y, mp + 3, day⟩ else ⟨y + 1, mp - 9, day⟩

/-- `d` advanced by `n` days. -/
def addDays (d : CivilDate) (n : Nat) : CivilDate :=
  ofDayNumber (dayNumber d + n)

/-- Days from `start` to `finish`, `0` when `finish` is not after `start`. -/
def daysBetween (start finish : CivilDate) : Nat :=
  dayNumber finish - dayNumber start

/-- `d` advanced by `n` calendar months, clamping the day to the length of the
target month (31 January + 1 month = 28/29 February). -/
def addMonths (d : CivilDate) (n : Nat) : CivilDate :=
  let months := d.year * 12 + (d.month - 1) + n
  let year := months / 12
  let month := months % 12 + 1
  ⟨year, month, min d.day (CivilDate.daysInMonth year month)⟩

/-- April 15 of the year after `d` — the due date of the decedent's final
individual income tax return. -/
def april15Following (d : CivilDate) : CivilDate := ⟨d.year + 1, 4, 15⟩

def pad2 (n : Nat) : String := if n < 10 then "0" ++ toString n else toString n

/-- `YYYY-MM-DD`, for prose and for the snapshot header. -/
def isoDate (d : CivilDate) : String :=
  s!"{d.year}-{pad2 d.month}-{pad2 d.day}"

/-! ## Compile-time regression examples -/

namespace DateExamples

-- Round trip on both sides of a leap day and across an era boundary.
example : ofDayNumber (dayNumber ⟨2026, 3, 4⟩) = ⟨2026, 3, 4⟩ := by decide
example : ofDayNumber (dayNumber ⟨2024, 2, 29⟩) = ⟨2024, 2, 29⟩ := by decide
example : ofDayNumber (dayNumber ⟨2000, 1, 1⟩) = ⟨2000, 1, 1⟩ := by decide

-- Leap-year rule: 2024 is a leap year, 2023 is not, 2100 is not (÷100),
-- 2000 is (÷400).
example : addDays ⟨2024, 2, 28⟩ 1 = ⟨2024, 2, 29⟩ := by decide
example : addDays ⟨2023, 2, 28⟩ 1 = ⟨2023, 3, 1⟩ := by decide
example : addDays ⟨2100, 2, 28⟩ 1 = ⟨2100, 3, 1⟩ := by decide
example : addDays ⟨2000, 2, 28⟩ 1 = ⟨2000, 2, 29⟩ := by decide

-- Year boundary.
example : addDays ⟨2026, 12, 31⟩ 1 = ⟨2027, 1, 1⟩ := by decide

-- Year lengths.
example : daysBetween ⟨2023, 1, 1⟩ ⟨2024, 1, 1⟩ = 365 := by decide
example : daysBetween ⟨2024, 1, 1⟩ ⟨2025, 1, 1⟩ = 366 := by decide

-- A backwards interval saturates at zero rather than wrapping.
example : daysBetween ⟨2026, 8, 12⟩ ⟨2026, 3, 4⟩ = 0 := by decide

-- The canonical fixture's elapsed time: 2026-03-04 → 2026-08-12.
example : daysBetween ⟨2026, 3, 4⟩ ⟨2026, 8, 12⟩ = 161 := by decide

-- Month arithmetic, including end-of-month clamping.
example : addMonths ⟨2026, 3, 4⟩ 6 = ⟨2026, 9, 4⟩ := by decide
example : addMonths ⟨2026, 3, 4⟩ 9 = ⟨2026, 12, 4⟩ := by decide
example : addMonths ⟨2026, 3, 4⟩ 24 = ⟨2028, 3, 4⟩ := by decide
example : addMonths ⟨2026, 1, 31⟩ 1 = ⟨2026, 2, 28⟩ := by decide
example : addMonths ⟨2024, 1, 31⟩ 1 = ⟨2024, 2, 29⟩ := by decide
example : addMonths ⟨2026, 12, 1⟩ 1 = ⟨2027, 1, 1⟩ := by decide

-- Every date produced by the arithmetic is a valid civil date.
example : (addMonths ⟨2026, 1, 31⟩ 1).valid = true := by decide
example : (addDays ⟨2026, 12, 31⟩ 1).valid = true := by decide

end DateExamples

end Router
end SimpleProbate
