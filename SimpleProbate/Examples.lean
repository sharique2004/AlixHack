import SimpleProbate.Date
import SimpleProbate.Thresholds
import SimpleProbate.Estate
import SimpleProbate.Eligibility
import SimpleProbate.Procedure
import SimpleProbate.Examples.Fixtures

namespace SimpleProbate.Examples

open SimpleProbate

example : classifyDeathDate ⟨2022, 3, 31⟩ = .ok .beforeApr2022 := by decide
example : classifyDeathDate ⟨2022, 4, 1⟩ = .ok .apr2022ToMar2025 := by decide
example : classifyDeathDate ⟨2025, 3, 31⟩ = .ok .apr2022ToMar2025 := by decide
example : classifyDeathDate ⟨2025, 4, 1⟩ = .ok .apr2025ToDec2026 := by decide
example : classifyDeathDate ⟨2026, 12, 31⟩ = .ok .apr2025ToDec2026 := by decide
example : classifyDeathDate ⟨2027, 1, 1⟩ = .error .afterSnapshot := by decide
example : classifyDeathDate ⟨0, 1, 1⟩ = .error .invalidDate := by decide
example : classifyDeathDate ⟨1900, 2, 29⟩ = .error .invalidDate := by decide
example : classifyDeathDate ⟨2000, 2, 29⟩ = .ok .beforeApr2022 := by decide
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

def estateAtPersonalCap : Estate := {
  assets := [
    countedPersonal 1 "account" (Money.dollars 208_850) (Money.dollars 80_000)
  ]
}

example :
    estateAtPersonalCap.personalAffidavitValue ⟨2026, 7, 28⟩ =
      .ok (Money.dollars 208_850) := by decide

example :
    ({ assets := [
      countedPersonal 2 "account" (Money.dollars 100_000) (Money.dollars 99_000),
      { countedPersonal 3 "joint account" (Money.dollars 500_000) 0 with
        treatment := .jointTenancy }
    ] } : Estate).personalAffidavitValue ⟨2026, 7, 28⟩ =
      .ok (Money.dollars 100_000) := by decide

example :
    ({ assets := [
      { countedPersonal 4 "salary" (Money.dollars 30_875) 0 with
        treatment := .employmentCompensation }
    ] } : Estate).personalAffidavitValue ⟨2026, 7, 28⟩ =
      .ok (Money.dollars 10_000) := by decide

example :
    ({ assets := [
      { countedPersonal 5 "military pay" (Money.dollars 100_000) 0 with
        treatment := .militaryCompensation }
    ] } : Estate).personalAffidavitValue ⟨2026, 7, 28⟩ = .ok 0 := by decide

example :
    ({ assets := [{
      id := ⟨6⟩
      name := "California parcel"
      kind := .californiaReal
      currentGrossValue := Money.dollars 69_625
      dateOfDeathValue := Money.dollars 69_625
      encumbrances := Money.dollars 60_000
      treatment := .counted
    }] } : Estate).smallValueRealPropertyValue = Money.dollars 69_625 := by decide

example : PersonalPropertyAffidavitEligible base2026Case := by decide
example : routeEligible { base2026Case with daysSinceDeath := 39 }
    .personalPropertyAffidavit = .ok false := by decide
example : routeEligible { base2026Case with
    authority := .writtenPersonalRepresentativeConsent }
    .personalPropertyAffidavit = .ok true := by decide
example : routeEligible { base2026Case with
    estate := { assets := [personalTargetOverCap] }
    targetId := personalTargetOverCap.id }
    .personalPropertyAffidavit = .ok false := by decide

example : routeEligible { base2026Case with
    estate := { assets := [smallRealTarget] }
    targetId := smallRealTarget.id
    sixMonthsElapsed := true }
    .smallValueRealPropertyAffidavit = .ok true := by decide

example : routeEligible { base2026Case with
    estate := { assets := [smallRealTarget] }
    targetId := smallRealTarget.id
    sixMonthsElapsed := false }
    .smallValueRealPropertyAffidavit = .ok false := by decide

example : routeEligible { base2026Case with
    estate := { assets := [smallRealTargetOverCap] }
    targetId := smallRealTargetOverCap.id
    sixMonthsElapsed := true }
    .smallValueRealPropertyAffidavit = .ok false := by decide

example : routeEligible { base2026Case with
    estate := { assets := [primaryResidenceTarget] }
    targetId := primaryResidenceTarget.id }
    .primaryResidencePetition = .ok true := by decide

example : routeEligible { base2026Case with
    estate := { assets := [
      { primaryResidenceTarget with
        currentGrossValue := Money.dollars 750_000 + 1
        dateOfDeathValue := Money.dollars 750_000 + 1 }
    ] }
    targetId := primaryResidenceTarget.id }
    .primaryResidencePetition = .ok false := by decide

def millionDollarRealTarget : Asset := {
  id := ⟨10⟩
  name := "unlisted million-dollar primary residence"
  kind := .californiaReal
  currentGrossValue := Money.dollars 1_000_000
  dateOfDeathValue := Money.dollars 1_000_000
  treatment := .counted
  isPrimaryResidence := true
}

def malformedEmptyEstateRealCase : TransferCase := {
  base2026Case with
  estate := { assets := [] }
  targetId := millionDollarRealTarget.id
  sixMonthsElapsed := true
}

example :
    routeEligible malformedEmptyEstateRealCase
      .smallValueRealPropertyAffidavit = .ok false := by decide

example :
    routeEligible malformedEmptyEstateRealCase
      .primaryResidencePetition = .ok false := by decide

example : routeEligible { base2026Case with
    estate := { assets := [spousalTarget] }
    targetId := spousalTarget.id
    claimantIsSuccessor := false
    noSuperiorRight := false
    survivorStatus := .spouse
    propertyPassesToSurvivor := true }
    .spousalPropertyPetition = .ok true := by decide

example :
    candidateRoutes { base2026Case with
      authority := .blockedByProceeding
      daysSinceDeath := 0
      claimantIsSuccessor := false
      noSuperiorRight := false } =
      .ok [.formalProbateOrOtherProcedure] := by decide

def directTransferTarget : Asset := {
  personalTarget with
  treatment := .directBeneficiary
}

def postSnapshotDirectCase : TransferCase := {
  base2026Case with
  deathDate := ⟨2027, 1, 1⟩
  estate := { assets := [directTransferTarget] }
  targetId := directTransferTarget.id
}

example :
    routeEligible postSnapshotDirectCase (.directTransfer .namedBeneficiary) =
      .error .afterSnapshot := by decide

example :
    ¬DirectTransferEligible postSnapshotDirectCase .namedBeneficiary := by decide

example :
    candidateRoutes postSnapshotDirectCase = .error .afterSnapshot := by decide

example :
    ¬LegacyRouteEligible postSnapshotDirectCase
      .formalProbateOrOtherProcedure := by decide

def postSnapshotSpousalCase : TransferCase := {
  base2026Case with
  deathDate := ⟨2027, 1, 1⟩
  estate := { assets := [spousalTarget] }
  targetId := spousalTarget.id
  claimantIsSuccessor := false
  noSuperiorRight := false
  survivorStatus := .spouse
  propertyPassesToSurvivor := true
}

example :
    routeEligible postSnapshotSpousalCase .spousalPropertyPetition =
      .error .afterSnapshot := by decide

example : ¬SpousalPropertyPetitionEligible postSnapshotSpousalCase := by decide

example :
    candidateRoutes postSnapshotSpousalCase = .error .afterSnapshot := by decide

def invalidDateCase : TransferCase := {
  base2026Case with
  deathDate := ⟨2026, 2, 29⟩
}

example :
    routeEligible invalidDateCase .personalPropertyAffidavit =
      .error .invalidDate := by decide

example :
    candidateRoutes invalidDateCase = .error .invalidDate := by decide

example :
    ¬LegacyRouteEligible invalidDateCase
      .formalProbateOrOtherProcedure := by decide

example :
    PersonalAffidavitReady baseProcedureContext base2026Case
      completePersonalPacket := by decide

example :
    ¬PersonalAffidavitReady baseProcedureContext base2026Case
      { completePersonalPacket with certifiedDeathCertificate := false } := by decide

example :
    .certifiedDeathCertificate ∈
      personalAffidavitMissing baseProcedureContext base2026Case
        { completePersonalPacket with certifiedDeathCertificate := false } := by decide

example :
    PersonalAffidavitReady
      { baseProcedureContext with institutionRequiresNotary := false }
      base2026Case
      { completePersonalPacket with notarized := false } := by decide

example :
    ¬PersonalAffidavitReady
      { baseProcedureContext with institutionRequiresNotary := true }
      base2026Case
      { completePersonalPacket with notarized := false } := by decide

example :
    workflowFor .smallValueRealPropertyAffidavit = [
      .assessEligibility,
      .waitForStatutoryPeriod,
      .gatherEvidence,
      .obtainProbateRefereeAppraisal,
      .prepareAffidavit,
      .notarize,
      .fileWithCourt,
      .obtainCertifiedCopy,
      .recordWithCounty
    ] := by decide

example :
    personalAffidavitMissing baseProcedureContext base2026Case
      completePersonalPacket = [] := by decide

example :
    personalAffidavitMissingChecked baseProcedureContext base2026Case
      completePersonalPacket = .ok [] := by decide

example :
    personalAffidavitMissingChecked baseProcedureContext invalidDateCase
      completePersonalPacket = .error .invalidDate := by decide

example :
    PersonalAffidavitReady baseProcedureContext base2026Case
      completePersonalPacket := by decide

example :
    smallRealPropertyAffidavitMissing baseProcedureContext smallReal2026Case
      completeSmallRealPacket = [] := by decide

example :
    smallRealPropertyAffidavitMissingChecked baseProcedureContext
      smallReal2026Case completeSmallRealPacket = .ok [] := by decide

example :
    SmallRealPropertyAffidavitReady baseProcedureContext smallReal2026Case
      completeSmallRealPacket := by decide

example :
    primaryResidencePetitionMissing baseProcedureContext
      primaryResidence2026Case completePrimaryResidencePacket = [] := by decide

example :
    primaryResidencePetitionMissingChecked baseProcedureContext
      primaryResidence2026Case completePrimaryResidencePacket = .ok [] := by decide

example :
    PrimaryResidencePetitionReady baseProcedureContext primaryResidence2026Case
      completePrimaryResidencePacket := by decide

example :
    spousalPetitionMissing baseProcedureContext spouse2026Case
      completeSpousalPacket = [] := by decide

example :
    spousalPetitionMissingChecked baseProcedureContext spouse2026Case
      completeSpousalPacket = .ok [] := by decide

example :
    SpousalPetitionReady baseProcedureContext spouse2026Case
      completeSpousalPacket := by decide

example :
    ¬SpousalPetitionReady baseProcedureContext postSnapshotSpousalCase
      completeSpousalPacket := by decide

example :
    spousalPetitionMissingChecked baseProcedureContext postSnapshotSpousalCase
      completeSpousalPacket = .error .afterSnapshot := by decide

example :
    ({ assets := [
      { personalTarget with treatment := .jointTenancy },
      { countedPersonal 11 "ordinary account" (Money.dollars 208_850) 0 with
        includedInPrimaryResidencePetition := false }
    ] } : Estate).personalAffidavitValue ⟨2026, 12, 31⟩ =
      .ok (Money.dollars 208_850) := by decide

example : routeEligible { base2026Case with
    estate := { assets := [{
      primaryResidenceTarget with
        currentGrossValue := Money.dollars 750_000
        dateOfDeathValue := Money.dollars 750_000
        isPrimaryResidence := false
    }] }
    targetId := primaryResidenceTarget.id }
    .primaryResidencePetition = .ok false := by decide

example :
    routeEligible { base2026Case with authority := .noProceeding }
      .personalPropertyAffidavit =
    routeEligible { base2026Case with
      authority := .writtenPersonalRepresentativeConsent }
      .personalPropertyAffidavit := by decide

example :
    routeEligible { base2026Case with
      estate := { assets := [spousalTarget] }
      targetId := spousalTarget.id
      claimantIsSuccessor := false
      noSuperiorRight := false
      survivorStatus := .registeredDomesticPartner
      propertyBelongsToSurvivor := true }
      .spousalPropertyPetition = .ok true := by decide

end SimpleProbate.Examples
