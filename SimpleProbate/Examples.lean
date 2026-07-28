import SimpleProbate.Date
import SimpleProbate.Thresholds
import SimpleProbate.Estate
import SimpleProbate.Eligibility
import SimpleProbate.Procedure

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

def personalTarget : Asset :=
  countedPersonal "account" (Money.dollars 208_850) 0

def base2026Case : TransferCase := {
  deathDate := ⟨2026, 1, 1⟩
  estate := { assets := [personalTarget] }
  target := personalTarget
  targetIsPartOfEstate := true
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

example : PersonalPropertyAffidavitEligible base2026Case := by decide
example : routeEligible { base2026Case with daysSinceDeath := 39 }
    .personalPropertyAffidavit = .ok false := by decide
example : routeEligible { base2026Case with
    authority := .writtenPersonalRepresentativeConsent }
    .personalPropertyAffidavit = .ok true := by decide
example : routeEligible { base2026Case with
    estate := { assets := [
      { personalTarget with grossValue := Money.dollars 208_850 + 1 }
    ] } }
    .personalPropertyAffidavit = .ok false := by decide

def smallRealTarget : Asset := {
  name := "small parcel"
  kind := .californiaReal
  grossValue := Money.dollars 69_625
  treatment := .counted
}

example : routeEligible { base2026Case with
    estate := { assets := [smallRealTarget] }
    target := smallRealTarget
    sixMonthsElapsed := true }
    .smallValueRealPropertyAffidavit = .ok true := by decide

example : routeEligible { base2026Case with
    estate := { assets := [smallRealTarget] }
    target := smallRealTarget
    sixMonthsElapsed := false }
    .smallValueRealPropertyAffidavit = .ok false := by decide

def primaryResidenceTarget : Asset := {
  name := "primary residence"
  kind := .californiaReal
  grossValue := Money.dollars 750_000
  treatment := .counted
  includedInPrimaryResidencePetition := true
  isPrimaryResidence := true
}

example : routeEligible { base2026Case with
    estate := { assets := [primaryResidenceTarget] }
    target := primaryResidenceTarget }
    .primaryResidencePetition = .ok true := by decide

example : routeEligible { base2026Case with
    estate := { assets := [
      { primaryResidenceTarget with grossValue := Money.dollars 750_000 + 1 }
    ] }
    target := { primaryResidenceTarget with
      grossValue := Money.dollars 750_000 + 1 } }
    .primaryResidencePetition = .ok false := by decide

example : routeEligible { base2026Case with
    estate := { assets := [] }
    targetIsPartOfEstate := false
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
  target := directTransferTarget
}

example :
    routeEligible postSnapshotDirectCase (.directTransfer .namedBeneficiary) =
      .error .afterSnapshot := by decide

example :
    candidateRoutes postSnapshotDirectCase = .error .afterSnapshot := by decide

def postSnapshotSpousalCase : TransferCase := {
  base2026Case with
  deathDate := ⟨2027, 1, 1⟩
  estate := { assets := [] }
  targetIsPartOfEstate := false
  claimantIsSuccessor := false
  noSuperiorRight := false
  survivorStatus := .spouse
  propertyPassesToSurvivor := true
}

example :
    routeEligible postSnapshotSpousalCase .spousalPropertyPetition =
      .error .afterSnapshot := by decide

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

def baseProcedureContext : ProcedureContext := {
  claimsUnderWill := false
  ownershipEvidenceAvailable := true
  hasOtherEntitledSuccessors := false
  knownGuardianOrConservator := false
  institutionRequiresNotary := false
  propertyAgreementExists := false
}

def completePersonalPacket : PersonalAffidavitPacket := {
  affidavitDeclarations := true
  certifiedDeathCertificate := true
  identityProof := true
  ownershipEvidencePresented := true
  holderIndemnityAlternative := false
  allEntitledSuccessorsSigned := true
  notarized := false
  consentAndLettersAttached := true
  datedAmountListAttached := true
  inventoryAndAppraisalAttached := true
  presentedToHolder := true
}

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
    PersonalAffidavitReady baseProcedureContext base2026Case
      completePersonalPacket := by decide

def smallReal2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [smallRealTarget] }
  target := smallRealTarget
  sixMonthsElapsed := true
}

def completeSmallRealPacket : SmallRealPropertyPacket := {
  de305Statements := true
  notarizedAcknowledgments := true
  inventoryAndAppraisalAttached := true
  certifiedDeathCertificate := true
  willAttached := true
  consentAndLettersAttached := true
  datedAmountListAttached := true
  guardianOrConservatorDelivery := true
  filedInProperCourt := true
  clerkCertifiedCopyIssued := true
  recordedInPropertyCounty := true
}

example :
    smallRealPropertyAffidavitMissing baseProcedureContext smallReal2026Case
      completeSmallRealPacket = [] := by decide

example :
    SmallRealPropertyAffidavitReady baseProcedureContext smallReal2026Case
      completeSmallRealPacket := by decide

def primaryResidence2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [primaryResidenceTarget] }
  target := primaryResidenceTarget
}

def completePrimaryResidencePacket : PrimaryResidencePetitionPacket := {
  de310VerifiedStatements := true
  inventoryAndAppraisalAttached := true
  willAttached := true
  consentAttached := true
  datedAmountListAttached := true
  filedInProperCourt := true
  heirAndDeviseeCopyWithinFiveBusinessDays := true
  statutoryHearingNotice := true
  courtFindingsMade := true
  de315OrderIssued := true
}

example :
    primaryResidencePetitionMissing baseProcedureContext
      primaryResidence2026Case completePrimaryResidencePacket = [] := by decide

example :
    PrimaryResidencePetitionReady baseProcedureContext primaryResidence2026Case
      completePrimaryResidencePacket := by decide

def spouse2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [] }
  targetIsPartOfEstate := false
  claimantIsSuccessor := false
  noSuperiorRight := false
  survivorStatus := .spouse
  propertyPassesToSurvivor := true
}

def completeSpousalPacket : SpousalPetitionPacket := {
  de221Allegations := true
  propertyDescriptionsAndSupportingFacts := true
  knownInterestedPersonsListed := true
  propertyAgreementDisclosed := true
  willAttached := true
  propertyAgreementAttached := true
  statutoryHearingNotice := true
  de226OrderIssued := true
}

example :
    spousalPetitionMissing baseProcedureContext spouse2026Case
      completeSpousalPacket = [] := by decide

example :
    SpousalPetitionReady baseProcedureContext spouse2026Case
      completeSpousalPacket := by decide

end SimpleProbate.Examples
