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

def invalidDateCase : TransferCase := {
  personalCase with
  deathDate := ⟨2026, 2, 29⟩
}

example :
    eligibilityChecks invalidDateCase.toPartial
      .personalPropertyAffidavit =
        .error .invalidDate := by decide

def missingTargetCase : TransferCase := {
  personalCase with
  estate := { assets := [] }
}

example :
    eligibilityChecks missingTargetCase.toPartial
      .personalPropertyAffidavit =
        .error (.malformedCase [
          .missingTargetAsset personalCase.targetId
        ]) := by decide

def unknownSuccessorCase : PartialTransferCase := {
  personalCase.toPartial with
  claimantIsSuccessor := .unknown
}

example :
    assessRoute unknownSuccessorCase .personalPropertyAffidavit =
      .ok (.needsInformation [.claimantIsSuccessor]) := by decide

def incompleteBelowCap : PartialTransferCase := {
  personalCase.toPartial with
  estate := {
    (PartialEstate.ofTotal personalCase.estate) with
    inventoryComplete := .known false
  }
}

example :
    assessRoute incompleteBelowCap .personalPropertyAffidavit =
      .ok (.needsInformation [.inventoryComplete]) := by decide

def knownOverCapAsset : Asset := {
  personalAsset with
  currentGrossValue := Money.dollars 208_850 + 1
}

def incompleteOverCap : PartialTransferCase := {
  ({ personalCase with
      estate := { assets := [knownOverCapAsset] } }).toPartial with
  estate := {
    (PartialEstate.ofTotal { assets := [knownOverCapAsset] }) with
    inventoryComplete := .known false
  }
}

example :
    assessRoute incompleteOverCap .personalPropertyAffidavit =
      .ok (.doesNotQualify [
        .personalPropertyValueOverCap
          (Money.dollars 208_850 + 1) (Money.dollars 208_850)
      ]) := by decide

example :
    (assessRoutes unknownSuccessorCase).map (·.overall) =
      .ok .unresolved := by decide

def directAsset : Asset := {
  personalAsset with
  treatment := .directBeneficiary
}

def qualifiedAndUnresolved : PartialTransferCase := {
  ({ personalCase with
      estate := { assets := [directAsset] } }).toPartial with
  claimantIsSuccessor := .unknown
}

example :
    assessRoute qualifiedAndUnresolved
      (.directTransfer .namedBeneficiary) = .ok .qualifies := by decide

example :
    assessRoute qualifiedAndUnresolved .personalPropertyAffidavit =
      .ok (.needsInformation [.claimantIsSuccessor]) := by decide

example :
    (assessRoutes qualifiedAndUnresolved).map (·.overall) =
      .ok .simplifiedRoutesAvailable := by decide

end SimpleProbate.Examples.EligibilityAssessment
