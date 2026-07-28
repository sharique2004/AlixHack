import SimpleProbate.Eligibility

namespace SimpleProbate

structure ProcedureContext where
  claimsUnderWill : Bool
  ownershipEvidenceAvailable : Bool
  hasOtherEntitledSuccessors : Bool
  knownGuardianOrConservator : Bool
  institutionRequiresNotary : Bool
  propertyAgreementExists : Bool
deriving DecidableEq, Repr

structure PersonalAffidavitPacket where
  affidavitDeclarations : Bool
  certifiedDeathCertificate : Bool
  identityProof : Bool
  ownershipEvidencePresented : Bool
  holderIndemnityAlternative : Bool
  allEntitledSuccessorsSigned : Bool
  notarized : Bool
  consentAndLettersAttached : Bool
  datedAmountListAttached : Bool
  inventoryAndAppraisalAttached : Bool
  presentedToHolder : Bool
deriving DecidableEq, Repr

structure SmallRealPropertyPacket where
  de305Statements : Bool
  notarizedAcknowledgments : Bool
  inventoryAndAppraisalAttached : Bool
  certifiedDeathCertificate : Bool
  willAttached : Bool
  consentAndLettersAttached : Bool
  datedAmountListAttached : Bool
  guardianOrConservatorDelivery : Bool
  filedInProperCourt : Bool
  clerkCertifiedCopyIssued : Bool
  recordedInPropertyCounty : Bool
deriving DecidableEq, Repr

structure PrimaryResidencePetitionPacket where
  de310VerifiedStatements : Bool
  inventoryAndAppraisalAttached : Bool
  willAttached : Bool
  consentAttached : Bool
  datedAmountListAttached : Bool
  filedInProperCourt : Bool
  heirAndDeviseeCopyWithinFiveBusinessDays : Bool
  statutoryHearingNotice : Bool
  courtFindingsMade : Bool
  de315OrderIssued : Bool
deriving DecidableEq, Repr

structure SpousalPetitionPacket where
  de221Allegations : Bool
  propertyDescriptionsAndSupportingFacts : Bool
  knownInterestedPersonsListed : Bool
  propertyAgreementDisclosed : Bool
  willAttached : Bool
  propertyAgreementAttached : Bool
  statutoryHearingNotice : Bool
  de226OrderIssued : Bool
deriving DecidableEq, Repr

def suppliedWhen (required supplied : Bool) : Prop :=
  required = false ∨ supplied = true

def needsDatedAmountList (date : CivilDate) : Bool :=
  match classifyDeathDate date with
  | .ok .beforeApr2022 => false
  | .ok _ => true
  | .error _ => true

def needsConsentAttachment (authority : SummaryAuthority) : Bool :=
  authority == .writtenPersonalRepresentativeConsent

def PersonalAffidavitReady
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) : Prop :=
  PersonalPropertyAffidavitEligible case ∧
  packet.affidavitDeclarations = true ∧
  packet.certifiedDeathCertificate = true ∧
  packet.identityProof = true ∧
  (if context.ownershipEvidenceAvailable
    then packet.ownershipEvidencePresented = true
    else packet.holderIndemnityAlternative = true) ∧
  suppliedWhen context.hasOtherEntitledSuccessors
    packet.allEntitledSuccessorsSigned ∧
  suppliedWhen context.institutionRequiresNotary packet.notarized ∧
  suppliedWhen (needsConsentAttachment case.authority)
    packet.consentAndLettersAttached ∧
  suppliedWhen (needsDatedAmountList case.deathDate)
    packet.datedAmountListAttached ∧
  suppliedWhen case.estate.containsCountedCaliforniaRealProperty
    packet.inventoryAndAppraisalAttached ∧
  packet.presentedToHolder = true

instance
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) :
    Decidable (PersonalAffidavitReady context case packet) := by
  unfold PersonalAffidavitReady suppliedWhen
  infer_instance

def SmallRealPropertyAffidavitReady
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) : Prop :=
  SmallValueRealPropertyAffidavitEligible case ∧
  packet.de305Statements = true ∧
  packet.notarizedAcknowledgments = true ∧
  packet.inventoryAndAppraisalAttached = true ∧
  packet.certifiedDeathCertificate = true ∧
  suppliedWhen context.claimsUnderWill packet.willAttached ∧
  suppliedWhen (needsConsentAttachment case.authority)
    packet.consentAndLettersAttached ∧
  suppliedWhen (needsDatedAmountList case.deathDate)
    packet.datedAmountListAttached ∧
  suppliedWhen context.knownGuardianOrConservator
    packet.guardianOrConservatorDelivery ∧
  packet.filedInProperCourt = true ∧
  packet.clerkCertifiedCopyIssued = true ∧
  packet.recordedInPropertyCounty = true

instance
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) :
    Decidable (SmallRealPropertyAffidavitReady context case packet) := by
  unfold SmallRealPropertyAffidavitReady suppliedWhen
  infer_instance

def PrimaryResidencePetitionReady
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) : Prop :=
  PrimaryResidencePetitionEligible case ∧
  packet.de310VerifiedStatements = true ∧
  packet.inventoryAndAppraisalAttached = true ∧
  suppliedWhen context.claimsUnderWill packet.willAttached ∧
  suppliedWhen (needsConsentAttachment case.authority)
    packet.consentAttached ∧
  suppliedWhen (needsDatedAmountList case.deathDate)
    packet.datedAmountListAttached ∧
  packet.filedInProperCourt = true ∧
  packet.heirAndDeviseeCopyWithinFiveBusinessDays = true ∧
  packet.statutoryHearingNotice = true ∧
  packet.courtFindingsMade = true ∧
  packet.de315OrderIssued = true

instance
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) :
    Decidable (PrimaryResidencePetitionReady context case packet) := by
  unfold PrimaryResidencePetitionReady suppliedWhen
  infer_instance

def SpousalPetitionReady
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) : Prop :=
  SpousalPropertyPetitionEligible case ∧
  packet.de221Allegations = true ∧
  packet.propertyDescriptionsAndSupportingFacts = true ∧
  packet.knownInterestedPersonsListed = true ∧
  packet.propertyAgreementDisclosed = true ∧
  suppliedWhen context.claimsUnderWill packet.willAttached ∧
  suppliedWhen context.propertyAgreementExists
    packet.propertyAgreementAttached ∧
  packet.statutoryHearingNotice = true ∧
  packet.de226OrderIssued = true

instance
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) :
    Decidable (SpousalPetitionReady context case packet) := by
  unfold SpousalPetitionReady suppliedWhen
  infer_instance

inductive Requirement
  | eligibleRoute
  | affidavitDeclarations
  | certifiedDeathCertificate
  | identityProof
  | ownershipEvidenceOrIndemnity
  | allEntitledSuccessorsSigned
  | notarization
  | consentAndLetters
  | datedAmountList
  | inventoryAndAppraisal
  | presentationToHolder
  | de305Statements
  | willAttachment
  | guardianOrConservatorDelivery
  | properCourtFiling
  | clerkCertifiedCopy
  | countyRecording
  | de310VerifiedStatements
  | heirAndDeviseeCopyWithinFiveBusinessDays
  | statutoryHearingNotice
  | courtFindings
  | de315Order
  | de221Allegations
  | propertyDescriptionsAndSupportingFacts
  | knownInterestedPersons
  | propertyAgreementDisclosure
  | propertyAgreementAttachment
  | de226Order
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

def suppliedWhenBool (required supplied : Bool) : Bool :=
  !required || supplied

def missingUnless (satisfied : Bool) (requirement : Requirement) :
    List Requirement :=
  if satisfied then [] else [requirement]

def personalAffidavitMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) : List Requirement :=
  missingUnless (decide (PersonalPropertyAffidavitEligible case)) .eligibleRoute ++
  missingUnless packet.affidavitDeclarations .affidavitDeclarations ++
  missingUnless packet.certifiedDeathCertificate .certifiedDeathCertificate ++
  missingUnless packet.identityProof .identityProof ++
  missingUnless
    (if context.ownershipEvidenceAvailable
      then packet.ownershipEvidencePresented
      else packet.holderIndemnityAlternative)
    .ownershipEvidenceOrIndemnity ++
  missingUnless
    (suppliedWhenBool context.hasOtherEntitledSuccessors
      packet.allEntitledSuccessorsSigned)
    .allEntitledSuccessorsSigned ++
  missingUnless
    (suppliedWhenBool context.institutionRequiresNotary packet.notarized)
    .notarization ++
  missingUnless
    (suppliedWhenBool (needsConsentAttachment case.authority)
      packet.consentAndLettersAttached)
    .consentAndLetters ++
  missingUnless
    (suppliedWhenBool (needsDatedAmountList case.deathDate)
      packet.datedAmountListAttached)
    .datedAmountList ++
  missingUnless
    (suppliedWhenBool case.estate.containsCountedCaliforniaRealProperty
      packet.inventoryAndAppraisalAttached)
    .inventoryAndAppraisal ++
  missingUnless packet.presentedToHolder .presentationToHolder

def smallRealPropertyAffidavitMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) : List Requirement :=
  missingUnless
    (decide (SmallValueRealPropertyAffidavitEligible case)) .eligibleRoute ++
  missingUnless packet.de305Statements .de305Statements ++
  missingUnless packet.notarizedAcknowledgments .notarization ++
  missingUnless packet.inventoryAndAppraisalAttached .inventoryAndAppraisal ++
  missingUnless packet.certifiedDeathCertificate .certifiedDeathCertificate ++
  missingUnless
    (suppliedWhenBool context.claimsUnderWill packet.willAttached)
    .willAttachment ++
  missingUnless
    (suppliedWhenBool (needsConsentAttachment case.authority)
      packet.consentAndLettersAttached)
    .consentAndLetters ++
  missingUnless
    (suppliedWhenBool (needsDatedAmountList case.deathDate)
      packet.datedAmountListAttached)
    .datedAmountList ++
  missingUnless
    (suppliedWhenBool context.knownGuardianOrConservator
      packet.guardianOrConservatorDelivery)
    .guardianOrConservatorDelivery ++
  missingUnless packet.filedInProperCourt .properCourtFiling ++
  missingUnless packet.clerkCertifiedCopyIssued .clerkCertifiedCopy ++
  missingUnless packet.recordedInPropertyCounty .countyRecording

def primaryResidencePetitionMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) : List Requirement :=
  missingUnless (decide (PrimaryResidencePetitionEligible case)) .eligibleRoute ++
  missingUnless packet.de310VerifiedStatements .de310VerifiedStatements ++
  missingUnless packet.inventoryAndAppraisalAttached .inventoryAndAppraisal ++
  missingUnless
    (suppliedWhenBool context.claimsUnderWill packet.willAttached)
    .willAttachment ++
  missingUnless
    (suppliedWhenBool (needsConsentAttachment case.authority)
      packet.consentAttached)
    .consentAndLetters ++
  missingUnless
    (suppliedWhenBool (needsDatedAmountList case.deathDate)
      packet.datedAmountListAttached)
    .datedAmountList ++
  missingUnless packet.filedInProperCourt .properCourtFiling ++
  missingUnless packet.heirAndDeviseeCopyWithinFiveBusinessDays
    .heirAndDeviseeCopyWithinFiveBusinessDays ++
  missingUnless packet.statutoryHearingNotice .statutoryHearingNotice ++
  missingUnless packet.courtFindingsMade .courtFindings ++
  missingUnless packet.de315OrderIssued .de315Order

def spousalPetitionMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) : List Requirement :=
  missingUnless (decide (SpousalPropertyPetitionEligible case)) .eligibleRoute ++
  missingUnless packet.de221Allegations .de221Allegations ++
  missingUnless packet.propertyDescriptionsAndSupportingFacts
    .propertyDescriptionsAndSupportingFacts ++
  missingUnless packet.knownInterestedPersonsListed .knownInterestedPersons ++
  missingUnless packet.propertyAgreementDisclosed .propertyAgreementDisclosure ++
  missingUnless
    (suppliedWhenBool context.claimsUnderWill packet.willAttached)
    .willAttachment ++
  missingUnless
    (suppliedWhenBool context.propertyAgreementExists
      packet.propertyAgreementAttached)
    .propertyAgreementAttachment ++
  missingUnless packet.statutoryHearingNotice .statutoryHearingNotice ++
  missingUnless packet.de226OrderIssued .de226Order

inductive WorkflowStage
  | assessEligibility
  | waitForStatutoryPeriod
  | gatherEvidence
  | obtainProbateRefereeAppraisal
  | prepareAffidavit
  | preparePetition
  | notarize
  | fileWithCourt
  | deliverNotice
  | attendHearing
  | obtainCourtOrder
  | obtainCertifiedCopy
  | presentToHolder
  | recordWithCounty
  | contactBenefitOrTitleAdministrator
  | investigateFormalProbateOrOtherProcedure
deriving BEq, DecidableEq, Repr

def workflowFor : Route → List WorkflowStage
  | .directTransfer _ =>
      [.assessEligibility, .gatherEvidence, .contactBenefitOrTitleAdministrator]
  | .personalPropertyAffidavit =>
      [.assessEligibility, .waitForStatutoryPeriod, .gatherEvidence,
       .prepareAffidavit, .presentToHolder]
  | .smallValueRealPropertyAffidavit =>
      [.assessEligibility, .waitForStatutoryPeriod, .gatherEvidence,
       .obtainProbateRefereeAppraisal, .prepareAffidavit, .notarize,
       .fileWithCourt, .obtainCertifiedCopy, .recordWithCounty]
  | .primaryResidencePetition =>
      [.assessEligibility, .waitForStatutoryPeriod, .gatherEvidence,
       .obtainProbateRefereeAppraisal, .preparePetition, .fileWithCourt,
       .deliverNotice, .attendHearing, .obtainCourtOrder]
  | .spousalPropertyPetition =>
      [.assessEligibility, .gatherEvidence, .preparePetition, .fileWithCourt,
       .deliverNotice, .attendHearing, .obtainCourtOrder]
  | .formalProbateOrOtherProcedure =>
      [.assessEligibility, .investigateFormalProbateOrOtherProcedure]

end SimpleProbate
