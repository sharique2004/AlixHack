import SimpleProbate.Date

/-!
# Florida death-date bands

Florida's small-estate figures are keyed on the **date of death**, not on the
date of filing, so both bands stay live simultaneously for years after the
amendment takes effect.

CS/HB 1337 (2026) was signed 2026-04-29 and took effect 2026-07-01. It raised
the Fla. Stat. §735.201 summary-administration ceiling and the Fla. Stat.
§735.304 intestate small-estate figure. Deaths before 2026-07-01 stay under the
prior figures.

These edges are Florida's own. California's `SimpleProbate.DeathBand` tracks the
Cal. Prob. Code §890 CPI adjustment calendar (2022-04-01, 2025-04-01), which has
no meaning here, so this module defines its own band type rather than reusing
it. The global source snapshot end (`snapshotEnd = 2026-12-31`) is shared:
a death after it is a typed error, not a verdict.

Sources retrieved 2026-08-12:
* Fla. Stat. §735.201 (flsenate.gov)
* CS/HB 1337 (2026), eff. 2026-07-01 — signed 2026-04-29
-/

namespace SimpleProbate.FL

/-- Florida date-of-death bands across the CS/HB 1337 edge. -/
inductive DeathBand
  | beforeJul2026
  | jul2026ToDec2026
deriving BEq, DecidableEq, Repr

/-- Effective date of CS/HB 1337 (2026). -/
def jul1_2026 : CivilDate := ⟨2026, 7, 1⟩

/-- Classify a date of death into a Florida band, or reject it. Mirrors
`SimpleProbate.classifyDeathDate` in shape and shares `snapshotEnd`. -/
def classifyDeathDate (date : CivilDate) : Except DateError DeathBand :=
  if !date.valid then
    .error .invalidDate
  else if !date.atMost snapshotEnd then
    .error .afterSnapshot
  else if date.before jul1_2026 then
    .ok .beforeJul2026
  else
    .ok .jul2026ToDec2026

/-- The same calendar day `years` years later. A day that does not exist in the
target month is clamped to the last day of that month, the ordinary civil
anniversary convention (2024-02-29 + 2 years = 2026-02-28). -/
def plusYears (date : CivilDate) (years : Nat) : CivilDate :=
  let year := date.year + years
  { year := year
    month := date.month
    day := min date.day (CivilDate.daysInMonth year date.month) }

/-- "Dead for more than `years` years" as of `asOf`: strictly past the
anniversary, so the anniversary itself is not yet *more than* `years`. Used for
the Fla. Stat. §735.201(2) two-year branch and the §735.304 one-year condition. -/
def deadMoreThanYears (death asOf : CivilDate) (years : Nat) : Bool :=
  (plusYears death years).before asOf

/-! ## Band edge, checked at compile time -/

example : classifyDeathDate ⟨2026, 6, 30⟩ = .ok .beforeJul2026 := by decide
example : classifyDeathDate ⟨2026, 7, 1⟩ = .ok .jul2026ToDec2026 := by decide
example : classifyDeathDate ⟨2026, 12, 31⟩ = .ok .jul2026ToDec2026 := by decide
example : classifyDeathDate ⟨2027, 1, 1⟩ = .error .afterSnapshot := by decide
example : classifyDeathDate ⟨2026, 2, 29⟩ = .error .invalidDate := by decide

-- The anniversary itself is not "more than" two years; the next day is.
example : deadMoreThanYears ⟨2024, 3, 15⟩ ⟨2026, 3, 15⟩ 2 = false := by decide
example : deadMoreThanYears ⟨2024, 3, 15⟩ ⟨2026, 3, 16⟩ 2 = true := by decide
-- Leap-day anniversaries clamp to 02-28.
example : deadMoreThanYears ⟨2024, 2, 29⟩ ⟨2026, 2, 28⟩ 2 = false := by decide
example : deadMoreThanYears ⟨2024, 2, 29⟩ ⟨2026, 3, 1⟩ 2 = true := by decide

end SimpleProbate.FL
