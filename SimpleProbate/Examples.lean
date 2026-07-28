import SimpleProbate.Date
import SimpleProbate.Thresholds

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

end SimpleProbate.Examples
