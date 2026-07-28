import SimpleProbate.Date

namespace SimpleProbate

abbrev Money := Nat

namespace Money

def dollars (amount : Nat) : Money := amount * 100

end Money

structure Thresholds where
  familySetAside : Money
  employmentCompensationExclusion : Money
  personalPropertyAffidavit : Money
  primaryResidencePetition : Money
  smallValueRealPropertyAffidavit : Money
  survivingSpouseEarnings : Money
deriving DecidableEq, Repr

def thresholdsForBand : DeathBand → Thresholds
  | .beforeApr2022 => {
      familySetAside := Money.dollars 85_900
      employmentCompensationExclusion := Money.dollars 16_625
      personalPropertyAffidavit := Money.dollars 166_250
      primaryResidencePetition := Money.dollars 166_250
      smallValueRealPropertyAffidavit := Money.dollars 55_425
      survivingSpouseEarnings := Money.dollars 16_625
    }
  | .apr2022ToMar2025 => {
      familySetAside := Money.dollars 95_325
      employmentCompensationExclusion := Money.dollars 18_450
      personalPropertyAffidavit := Money.dollars 184_500
      primaryResidencePetition := Money.dollars 184_500
      smallValueRealPropertyAffidavit := Money.dollars 61_500
      survivingSpouseEarnings := Money.dollars 18_450
    }
  | .apr2025ToDec2026 => {
      familySetAside := Money.dollars 107_900
      employmentCompensationExclusion := Money.dollars 20_875
      personalPropertyAffidavit := Money.dollars 208_850
      primaryResidencePetition := Money.dollars 750_000
      smallValueRealPropertyAffidavit := Money.dollars 69_625
      survivingSpouseEarnings := Money.dollars 20_875
    }

def thresholdsFor (date : CivilDate) : Except DateError Thresholds :=
  (classifyDeathDate date).map thresholdsForBand

end SimpleProbate
