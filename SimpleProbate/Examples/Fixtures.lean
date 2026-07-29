import SimpleProbate.Procedure

namespace SimpleProbate.Examples

open SimpleProbate

def countedPersonal (id : Nat) (name : String) (gross encumbrances : Money) : Asset := {
  id := ⟨id⟩
  name := name
  kind := .personal
  currentGrossValue := gross
  dateOfDeathValue := gross
  encumbrances := encumbrances
  treatment := .counted
}

def personalTarget : Asset :=
  countedPersonal 7 "account" (Money.dollars 208_850) 0

def personalTargetOverCap : Asset := {
  personalTarget with
  currentGrossValue := Money.dollars 208_850 + 1
  dateOfDeathValue := Money.dollars 208_850 + 1
}

def base2026Case : TransferCase := {
  deathDate := ⟨2026, 1, 1⟩
  estate := { assets := [personalTarget] }
  targetId := personalTarget.id
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

def smallRealTarget : Asset := {
  id := ⟨8⟩
  name := "small parcel"
  kind := .californiaReal
  currentGrossValue := Money.dollars 69_625
  dateOfDeathValue := Money.dollars 69_625
  treatment := .counted
}

def smallRealTargetOverCap : Asset := {
  smallRealTarget with
  currentGrossValue := Money.dollars 69_625 + 1
  dateOfDeathValue := Money.dollars 69_625 + 1
}

def smallReal2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [smallRealTarget] }
  targetId := smallRealTarget.id
  sixMonthsElapsed := true
}

def primaryResidenceTarget : Asset := {
  id := ⟨9⟩
  name := "primary residence"
  kind := .californiaReal
  currentGrossValue := Money.dollars 750_000
  dateOfDeathValue := Money.dollars 750_000
  treatment := .counted
  includedInPrimaryResidencePetition := true
  isPrimaryResidence := true
}

def primaryResidence2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [primaryResidenceTarget] }
  targetId := primaryResidenceTarget.id
}

def spousalTarget : Asset := {
  id := ⟨4⟩
  name := "spousal property"
  kind := .personal
  currentGrossValue := Money.dollars 1
  dateOfDeathValue := Money.dollars 1
  treatment := .spousePassage
}

def spouse2026Case : TransferCase := {
  base2026Case with
  estate := { assets := [spousalTarget] }
  targetId := spousalTarget.id
  claimantIsSuccessor := false
  noSuperiorRight := false
  survivorStatus := .spouse
  propertyPassesToSurvivor := true
}

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

end SimpleProbate.Examples
