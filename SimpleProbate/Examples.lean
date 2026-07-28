import SimpleProbate.Date
import SimpleProbate.Thresholds
import SimpleProbate.Estate

namespace SimpleProbate.Examples

open SimpleProbate

example : classifyDeathDate ⟨2022, 3, 31⟩ = .ok .beforeApr2022 := by decide
example : classifyDeathDate ⟨2022, 4, 1⟩ = .ok .apr2022ToMar2025 := by decide
example : classifyDeathDate ⟨2025, 3, 31⟩ = .ok .apr2022ToMar2025 := by decide
example : classifyDeathDate ⟨2025, 4, 1⟩ = .ok .apr2025ToDec2026 := by decide
example : classifyDeathDate ⟨2026, 12, 31⟩ = .ok .apr2025ToDec2026 := by decide
example : classifyDeathDate ⟨2027, 1, 1⟩ = .error .afterSnapshot := by decide
example : classifyDeathDate ⟨2026, 2, 29⟩ = .error .invalidDate := by decide

example :
    thresholdsFor ⟨2026, 7, 28⟩ =
      .ok {
        familySetAside := Money.dollars 107_900
        employmentCompensationExclusion := Money.dollars 20_875
        personalPropertyAffidavit := Money.dollars 208_850
        primaryResidencePetition := Money.dollars 750_000
        smallValueRealPropertyAffidavit := Money.dollars 69_625
        survivingSpouseEarnings := Money.dollars 20_875
      } := by decide

def countedPersonal (name : String) (gross encumbrances : Money) : Asset := {
  name := name
  kind := .personal
  grossValue := gross
  encumbrances := encumbrances
  treatment := .counted
}

def estateAtPersonalCap : Estate := {
  assets := [
    countedPersonal "account" (Money.dollars 208_850) (Money.dollars 80_000)
  ]
}

example :
    estateAtPersonalCap.personalAffidavitValue ⟨2026, 7, 28⟩ =
      .ok (Money.dollars 208_850) := by decide

example :
    ({ assets := [
      countedPersonal "account" (Money.dollars 100_000) (Money.dollars 99_000),
      { countedPersonal "joint account" (Money.dollars 500_000) 0 with
        treatment := .jointTenancy }
    ] } : Estate).personalAffidavitValue ⟨2026, 7, 28⟩ =
      .ok (Money.dollars 100_000) := by decide

example :
    ({ assets := [
      { countedPersonal "salary" (Money.dollars 30_875) 0 with
        treatment := .employmentCompensation }
    ] } : Estate).personalAffidavitValue ⟨2026, 7, 28⟩ =
      .ok (Money.dollars 10_000) := by decide

example :
    ({ assets := [
      { countedPersonal "military pay" (Money.dollars 100_000) 0 with
        treatment := .militaryCompensation }
    ] } : Estate).personalAffidavitValue ⟨2026, 7, 28⟩ = .ok 0 := by decide

example :
    ({ assets := [{
      name := "California parcel"
      kind := .californiaReal
      grossValue := Money.dollars 69_625
      encumbrances := Money.dollars 60_000
      treatment := .counted
    }] } : Estate).smallValueRealPropertyValue = Money.dollars 69_625 := by decide

end SimpleProbate.Examples
