import SimpleProbate.Case

namespace SimpleProbate.Examples.Case

open SimpleProbate

def knownPersonalAsset : Asset := {
  id := ⟨1⟩
  name := "account"
  kind := .personal
  currentGrossValue := Money.dollars 10_000
  dateOfDeathValue := Money.dollars 10_000
}

def partialKnownPersonal : PartialAsset := {
  id := ⟨1⟩
  name := "account"
  kind := .known .personal
  currentGrossValue := .known (Money.dollars 10_000)
  dateOfDeathValue := .known (Money.dollars 10_000)
  encumbrances := .known 0
  treatment := .known .counted
  includedInPrimaryResidencePetition := .known false
  isPrimaryResidence := .known false
}

example : partialKnownPersonal.Completes knownPersonalAsset := by decide

example :
    ({ assets := [partialKnownPersonal]
       inventoryComplete := .known true } : PartialEstate).Completes
      { assets := [knownPersonalAsset] } := by decide

example :
    ¬({ assets := [partialKnownPersonal]
        inventoryComplete := .known true } : PartialEstate).Completes
      { assets := [
        knownPersonalAsset,
        { knownPersonalAsset with id := ⟨2⟩ }
      ] } := by decide

def malformedPrimary : PartialTransferCase := {
  deathDate := .known ⟨2026, 1, 1⟩
  estate := {
    assets := [{
      partialKnownPersonal with
      isPrimaryResidence := .known true
    }]
    inventoryComplete := .known true
  }
  targetId := .known ⟨1⟩
  authority := .known .noProceeding
  daysSinceDeath := .known 40
  sixMonthsElapsed := .known false
  claimantIsSuccessor := .known true
  noSuperiorRight := .known true
  funeralLastIllnessAndUnsecuredDebtsPaid := .known true
  survivorStatus := .known .none
  propertyPassesToSurvivor := .known false
  propertyBelongsToSurvivor := .known false
}

example :
    validatePartialCase malformedPrimary =
      .error (.malformedCase [.primaryResidenceNotCaliforniaReal ⟨1⟩]) := by
  decide

def duplicateIds : PartialTransferCase := {
  malformedPrimary with
  estate := {
    assets := [
      partialKnownPersonal,
      { partialKnownPersonal with name := "duplicate" }
    ]
    inventoryComplete := .known true
  }
}

example :
    validatePartialCase duplicateIds =
      .error (.malformedCase [.duplicateAssetId ⟨1⟩]) := by decide

end SimpleProbate.Examples.Case
