import SimpleProbate.Thresholds
import SimpleProbate.FL.Bands

/-!
# Florida small-estate figures, banded by date of death

Every figure below carries its statutory source. Money is integer **cents**
(`SimpleProbate.Money`), written with `Money.dollars`.

Sources retrieved 2026-08-12:
* Fla. Stat. §735.201(2) — "the value of the entire estate subject to
  administration in this state, less the value of property exempt from the
  claims of creditors, does not exceed $75,000 or … the decedent has been dead
  for more than 2 years" (flsenate.gov, 2024 statutes).
* Fla. Stat. §735.304 — disposition without administration of intestate
  property in small estates; nonexempt personal property not exceeding the sum
  of $10,000 and the preferred funeral expenses and the reasonable and
  necessary medical and hospital expenses of the last 60 days of the last
  illness (flsenate.gov).
* Fla. Stat. §733.707(1)(b) — class 2, "reasonable funeral, interment, and
  grave marker expenses … not to exceed the aggregate of $6,000".
* CS/HB 1337 (2026), signed 2026-04-29, eff. 2026-07-01 — §735.201 ceiling
  $75,000 → $150,000; §735.304 figure $10,000 → $20,000.
-/

namespace SimpleProbate.FL

/-- Florida figures that CS/HB 1337 moved. Both are keyed on date of death. -/
structure Thresholds where
  /-- Fla. Stat. §735.201(2): ceiling on the value of the entire estate subject
  to administration in Florida, less property exempt from creditors' claims. -/
  summaryAdministration : Money
  /-- Fla. Stat. §735.304: the fixed component of the intestate small-estate
  disposition figure, added to the §735.301 expense allowance. -/
  intestateSmallEstateDisposition : Money
deriving DecidableEq, Repr

def thresholdsForBand : DeathBand → Thresholds
  | .beforeJul2026 => {
      -- Fla. Stat. §735.201(2) as it stood before CS/HB 1337.
      summaryAdministration := Money.dollars 75_000
      -- Fla. Stat. §735.304 as it stood before CS/HB 1337.
      intestateSmallEstateDisposition := Money.dollars 10_000
    }
  | .jul2026ToDec2026 => {
      -- Fla. Stat. §735.201(2) as amended by CS/HB 1337 (2026), eff. 2026-07-01.
      summaryAdministration := Money.dollars 150_000
      -- Fla. Stat. §735.304 as amended by CS/HB 1337 (2026), eff. 2026-07-01.
      intestateSmallEstateDisposition := Money.dollars 20_000
    }

def thresholdsFor (date : CivilDate) : Except DateError Thresholds :=
  (classifyDeathDate date).map thresholdsForBand

/-- Fla. Stat. §733.707(1)(b): the *preferred* class of funeral, interment, and
grave-marker expenses is capped at $6,000 in the aggregate. Fla. Stat. §735.301
and §735.304 allow only that preferred amount, so a larger funeral bill does
not enlarge the allowance. CS/HB 1337 did not move this figure, so it is not
banded. -/
def preferredFuneralExpenseCap : Money := Money.dollars 6_000

/-! ## The figures, checked at compile time -/

-- The centerpiece: one day apart, two different ceilings.
example : (thresholdsFor ⟨2026, 6, 30⟩).map (·.summaryAdministration) =
    .ok 7_500_000 := by decide
example : (thresholdsFor ⟨2026, 7, 1⟩).map (·.summaryAdministration) =
    .ok 15_000_000 := by decide
example : (thresholdsFor ⟨2026, 6, 30⟩).map (·.intestateSmallEstateDisposition) =
    .ok 1_000_000 := by decide
example : (thresholdsFor ⟨2026, 7, 1⟩).map (·.intestateSmallEstateDisposition) =
    .ok 2_000_000 := by decide
example : preferredFuneralExpenseCap = 600_000 := by decide

end SimpleProbate.FL
