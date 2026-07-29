import SimpleProbate.Estate

namespace SimpleProbate.Examples.Valuation

open SimpleProbate

def salary (id : Nat) (current atDeath : Money) : Asset := {
  id := ⟨id⟩
  name := s!"salary-{id}"
  kind := .personal
  currentGrossValue := current
  dateOfDeathValue := atDeath
  treatment := .employmentCompensation
}

def realProperty
    (id : Nat) (current atDeath : Money) (primary : Bool) : Asset := {
  id := ⟨id⟩
  name := s!"real-{id}"
  kind := .californiaReal
  currentGrossValue := current
  dateOfDeathValue := atDeath
  treatment := .counted
  isPrimaryResidence := primary
}

def knownZeroTreatmentAsset : PartialAsset := {
  id := ⟨5⟩
  name := "irrelevant joint-tenancy asset"
  kind := .unknown
  currentGrossValue := .unknown
  dateOfDeathValue := .unknown
  encumbrances := .known 0
  treatment := .known .jointTenancy
  includedInPrimaryResidencePetition := .unknown
  isPrimaryResidence := .unknown
}

def knownZeroTreatmentEstate : PartialEstate := {
  assets := [knownZeroTreatmentAsset]
  inventoryComplete := .known true
}

def knownNonPrimaryEstate : PartialEstate := {
  assets := [{
    knownZeroTreatmentAsset with
    treatment := .unknown
    isPrimaryResidence := .known false
  }]
  inventoryComplete := .known true
}

def thresholds2026 : Thresholds := {
  familySetAside := Money.dollars 107_900
  employmentCompensationExclusion := Money.dollars 20_875
  personalPropertyAffidavit := Money.dollars 208_850
  primaryResidencePetition := Money.dollars 750_000
  smallValueRealPropertyAffidavit := Money.dollars 69_625
  survivingSpouseEarnings := Money.dollars 20_875
}

example :
    knownZeroTreatmentEstate.personalAffidavitValuation thresholds2026 = {
      lowerBound := 0
      exactValue := some 0
      missingFields := []
      needsCompleteInventory := false
    } := by decide

example :
    knownZeroTreatmentEstate.smallRealPropertyValuation = {
      lowerBound := 0
      exactValue := some 0
      missingFields := []
      needsCompleteInventory := false
    } := by decide

example :
    knownZeroTreatmentEstate.primaryResidenceValuation = {
      lowerBound := 0
      exactValue := some 0
      missingFields := []
      needsCompleteInventory := false
    } := by decide

example :
    knownNonPrimaryEstate.primaryResidenceValuation = {
      lowerBound := 0
      exactValue := some 0
      missingFields := []
      needsCompleteInventory := false
    } := by decide

example :
    ({ assets := [
      salary 1 (Money.dollars 15_000) (Money.dollars 12_000),
      salary 2 (Money.dollars 15_000) (Money.dollars 13_000)
    ] } : Estate).personalAffidavitValue ⟨2026, 1, 1⟩ =
      .ok (Money.dollars 9_125) := by decide

example :
    ({ assets := [
      salary 1 (Money.dollars 30_000) (Money.dollars 25_000)
    ] } : Estate).personalAffidavitValue ⟨2026, 1, 1⟩ =
      .ok (Money.dollars 9_125) := by decide

example :
    ({ assets := [
      realProperty 3 (Money.dollars 900_000)
        (Money.dollars 700_000) true
    ] } : Estate).primaryResidenceValue =
      Money.dollars 700_000 := by decide

example :
    ({ assets := [
      realProperty 4 (Money.dollars 80_000)
        (Money.dollars 60_000) false
    ] } : Estate).smallValueRealPropertyValue =
      Money.dollars 60_000 := by decide

end SimpleProbate.Examples.Valuation
