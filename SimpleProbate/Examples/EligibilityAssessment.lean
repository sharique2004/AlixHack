import SimpleProbate.Eligibility

namespace SimpleProbate.Examples.EligibilityAssessment

open SimpleProbate

def personalAsset : Asset := {
  id := ⟨1⟩
  name := "account"
  kind := .personal
  currentGrossValue := Money.dollars 208_850
  dateOfDeathValue := Money.dollars 208_850
}

def personalCase : TransferCase := {
  deathDate := ⟨2026, 1, 1⟩
  estate := { assets := [personalAsset] }
  targetId := ⟨1⟩
  authority := .noProceeding
  daysSinceDeath := 40
  sixMonthsElapsed := false
  claimantIsSuccessor := true
  noSuperiorRight := true
  funeralLastIllnessAndUnsecuredDebtsPaid := true
  survivorStatus := .none
  propertyPassesToSurvivor := false
  propertyBelongsToSurvivor := false
}

example :
    assessRoute personalCase.toPartial .personalPropertyAffidavit =
      .ok .qualifies := by decide

example :
    assessRoute
      ({ personalCase with daysSinceDeath := 39 }).toPartial
      .personalPropertyAffidavit =
      .ok (.doesNotQualify [.fortyDaysNotElapsed]) := by decide

example :
    RouteEligible personalCase .personalPropertyAffidavit := by decide

example :
    assessRoute personalCase.toPartial .personalPropertyAffidavit =
        .ok .qualifies ↔
      RouteEligible personalCase .personalPropertyAffidavit := by
  exact assessRoute_ofTotal_qualifies_iff personalCase
    .personalPropertyAffidavit

end SimpleProbate.Examples.EligibilityAssessment
