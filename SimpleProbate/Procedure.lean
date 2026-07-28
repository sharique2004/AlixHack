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

inductive CourtRoute
  | personalPropertyAffidavit
  | smallValueRealPropertyAffidavit
  | primaryResidencePetition
  | spousalPropertyPetition
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

def CourtRoute.toSimplifiedRoute : CourtRoute → SimplifiedRoute
  | .personalPropertyAffidavit => .personalPropertyAffidavit
  | .smallValueRealPropertyAffidavit =>
      .smallValueRealPropertyAffidavit
  | .primaryResidencePetition => .primaryResidencePetition
  | .spousalPropertyPetition => .spousalPropertyPetition

def TotalPacket : CourtRoute → Type
  | .personalPropertyAffidavit => PersonalAffidavitPacket
  | .smallValueRealPropertyAffidavit => SmallRealPropertyPacket
  | .primaryResidencePetition => PrimaryResidencePetitionPacket
  | .spousalPropertyPetition => SpousalPetitionPacket

def suppliedWhen (required supplied : Bool) : Prop :=
  required = false ∨ supplied = true

def needsDatedAmountList (date : CivilDate) : Bool :=
  match classifyDeathDate date with
  | .ok .beforeApr2022 => false
  | .ok _ => true
  | .error _ => true

def needsConsentAttachment (authority : SummaryAuthority) : Bool :=
  authority == .writtenPersonalRepresentativeConsent

def noEstateProceeding (authority : SummaryAuthority) : Bool :=
  authority == .noProceeding

def needsSmallRealWillAttachment
    (context : ProcedureContext) (case : TransferCase) : Bool :=
  context.claimsUnderWill && noEstateProceeding case.authority

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
  suppliedWhen (needsSmallRealWillAttachment context case)
    packet.willAttached ∧
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

def CourtReady
    (route : CourtRoute) (context : ProcedureContext)
    (case : TransferCase) (packet : TotalPacket route) : Prop :=
  match route with
  | .personalPropertyAffidavit =>
      PersonalAffidavitReady context case packet
  | .smallValueRealPropertyAffidavit =>
      SmallRealPropertyAffidavitReady context case packet
  | .primaryResidencePetition =>
      PrimaryResidencePetitionReady context case packet
  | .spousalPropertyPetition =>
      SpousalPetitionReady context case packet

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

structure RequirementCheck where
  requirement : Requirement
  applies : Bool
  supplied : Bool
deriving DecidableEq, Repr

def RequirementCheck.isMissing (check : RequirementCheck) : Bool :=
  check.applies && !check.supplied

def missingFromChecks
    (checks : List RequirementCheck) : List Requirement :=
  checks.filterMap fun check =>
    if check.isMissing then some check.requirement else none

def personalRequirementChecks
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) : List RequirementCheck := [
  ⟨.eligibleRoute, true,
    decide (PersonalPropertyAffidavitEligible case)⟩,
  ⟨.affidavitDeclarations, true, packet.affidavitDeclarations⟩,
  ⟨.certifiedDeathCertificate, true, packet.certifiedDeathCertificate⟩,
  ⟨.identityProof, true, packet.identityProof⟩,
  ⟨.ownershipEvidenceOrIndemnity, true,
    if context.ownershipEvidenceAvailable
    then packet.ownershipEvidencePresented
    else packet.holderIndemnityAlternative⟩,
  ⟨.allEntitledSuccessorsSigned, context.hasOtherEntitledSuccessors,
    packet.allEntitledSuccessorsSigned⟩,
  ⟨.notarization, context.institutionRequiresNotary, packet.notarized⟩,
  ⟨.consentAndLetters, needsConsentAttachment case.authority,
    packet.consentAndLettersAttached⟩,
  ⟨.datedAmountList, needsDatedAmountList case.deathDate,
    packet.datedAmountListAttached⟩,
  ⟨.inventoryAndAppraisal,
    case.estate.containsCountedCaliforniaRealProperty,
    packet.inventoryAndAppraisalAttached⟩,
  ⟨.presentationToHolder, true, packet.presentedToHolder⟩
]

def smallRealPropertyRequirementChecks
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) : List RequirementCheck := [
  ⟨.eligibleRoute, true,
    decide (SmallValueRealPropertyAffidavitEligible case)⟩,
  ⟨.de305Statements, true, packet.de305Statements⟩,
  ⟨.notarization, true, packet.notarizedAcknowledgments⟩,
  ⟨.inventoryAndAppraisal, true, packet.inventoryAndAppraisalAttached⟩,
  ⟨.certifiedDeathCertificate, true, packet.certifiedDeathCertificate⟩,
  ⟨.willAttachment, needsSmallRealWillAttachment context case,
    packet.willAttached⟩,
  ⟨.consentAndLetters, needsConsentAttachment case.authority,
    packet.consentAndLettersAttached⟩,
  ⟨.datedAmountList, needsDatedAmountList case.deathDate,
    packet.datedAmountListAttached⟩,
  ⟨.guardianOrConservatorDelivery, context.knownGuardianOrConservator,
    packet.guardianOrConservatorDelivery⟩,
  ⟨.properCourtFiling, true, packet.filedInProperCourt⟩,
  ⟨.clerkCertifiedCopy, true, packet.clerkCertifiedCopyIssued⟩,
  ⟨.countyRecording, true, packet.recordedInPropertyCounty⟩
]

def primaryResidenceRequirementChecks
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) : List RequirementCheck := [
  ⟨.eligibleRoute, true,
    decide (PrimaryResidencePetitionEligible case)⟩,
  ⟨.de310VerifiedStatements, true, packet.de310VerifiedStatements⟩,
  ⟨.inventoryAndAppraisal, true, packet.inventoryAndAppraisalAttached⟩,
  ⟨.willAttachment, context.claimsUnderWill, packet.willAttached⟩,
  ⟨.consentAndLetters, needsConsentAttachment case.authority,
    packet.consentAttached⟩,
  ⟨.datedAmountList, needsDatedAmountList case.deathDate,
    packet.datedAmountListAttached⟩,
  ⟨.properCourtFiling, true, packet.filedInProperCourt⟩,
  ⟨.heirAndDeviseeCopyWithinFiveBusinessDays, true,
    packet.heirAndDeviseeCopyWithinFiveBusinessDays⟩,
  ⟨.statutoryHearingNotice, true, packet.statutoryHearingNotice⟩,
  ⟨.courtFindings, true, packet.courtFindingsMade⟩,
  ⟨.de315Order, true, packet.de315OrderIssued⟩
]

def spousalRequirementChecks
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) : List RequirementCheck := [
  ⟨.eligibleRoute, true,
    decide (SpousalPropertyPetitionEligible case)⟩,
  ⟨.de221Allegations, true, packet.de221Allegations⟩,
  ⟨.propertyDescriptionsAndSupportingFacts, true,
    packet.propertyDescriptionsAndSupportingFacts⟩,
  ⟨.knownInterestedPersons, true, packet.knownInterestedPersonsListed⟩,
  ⟨.propertyAgreementDisclosure, true, packet.propertyAgreementDisclosed⟩,
  ⟨.willAttachment, context.claimsUnderWill, packet.willAttached⟩,
  ⟨.propertyAgreementAttachment, context.propertyAgreementExists,
    packet.propertyAgreementAttached⟩,
  ⟨.statutoryHearingNotice, true, packet.statutoryHearingNotice⟩,
  ⟨.de226Order, true, packet.de226OrderIssued⟩
]

def personalAffidavitMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) : List Requirement :=
  missingFromChecks (personalRequirementChecks context case packet)

def smallRealPropertyAffidavitMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) : List Requirement :=
  missingFromChecks
    (smallRealPropertyRequirementChecks context case packet)

def primaryResidencePetitionMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) : List Requirement :=
  missingFromChecks
    (primaryResidenceRequirementChecks context case packet)

def spousalPetitionMissing
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) : List Requirement :=
  missingFromChecks (spousalRequirementChecks context case packet)

theorem mem_missingFromChecks_iff
    (checks : List RequirementCheck) (requirement : Requirement) :
    requirement ∈ missingFromChecks checks ↔
      ∃ check ∈ checks,
        check.requirement = requirement ∧
        check.applies = true ∧
        check.supplied = false := by
  induction checks with
  | nil => simp [missingFromChecks]
  | cons check rest ih =>
      cases applies : check.applies <;>
      cases supplied : check.supplied <;>
      simp_all [missingFromChecks, RequirementCheck.isMissing]
      exact or_congr eq_comm Iff.rfl

theorem mem_personalAffidavitMissing_iff
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) (requirement : Requirement) :
    requirement ∈ personalAffidavitMissing context case packet ↔
      ∃ check ∈ personalRequirementChecks context case packet,
        check.requirement = requirement ∧
        check.applies = true ∧
        check.supplied = false := by
  exact mem_missingFromChecks_iff
    (personalRequirementChecks context case packet) requirement

theorem mem_smallRealPropertyAffidavitMissing_iff
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) (requirement : Requirement) :
    requirement ∈ smallRealPropertyAffidavitMissing context case packet ↔
      ∃ check ∈ smallRealPropertyRequirementChecks context case packet,
        check.requirement = requirement ∧
        check.applies = true ∧
        check.supplied = false := by
  exact mem_missingFromChecks_iff
    (smallRealPropertyRequirementChecks context case packet) requirement

theorem mem_primaryResidencePetitionMissing_iff
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) (requirement : Requirement) :
    requirement ∈ primaryResidencePetitionMissing context case packet ↔
      ∃ check ∈ primaryResidenceRequirementChecks context case packet,
        check.requirement = requirement ∧
        check.applies = true ∧
        check.supplied = false := by
  exact mem_missingFromChecks_iff
    (primaryResidenceRequirementChecks context case packet) requirement

theorem mem_spousalPetitionMissing_iff
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) (requirement : Requirement) :
    requirement ∈ spousalPetitionMissing context case packet ↔
      ∃ check ∈ spousalRequirementChecks context case packet,
        check.requirement = requirement ∧
        check.applies = true ∧
        check.supplied = false := by
  exact mem_missingFromChecks_iff
    (spousalRequirementChecks context case packet) requirement

theorem personalAffidavitMissing_empty_iff_ready
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) :
    personalAffidavitMissing context case packet = [] ↔
      PersonalAffidavitReady context case packet := by
  cases successors : context.hasOtherEntitledSuccessors <;>
  cases notary : context.institutionRequiresNotary <;>
  cases consent : needsConsentAttachment case.authority <;>
  cases dated : needsDatedAmountList case.deathDate <;>
  cases inventory :
      case.estate.containsCountedCaliforniaRealProperty <;>
  simp [personalAffidavitMissing, personalRequirementChecks,
    missingFromChecks, RequirementCheck.isMissing,
    PersonalAffidavitReady, suppliedWhen, successors, notary,
    consent, dated, inventory]

theorem smallRealPropertyAffidavitMissing_empty_iff_ready
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) :
    smallRealPropertyAffidavitMissing context case packet = [] ↔
      SmallRealPropertyAffidavitReady context case packet := by
  cases will : needsSmallRealWillAttachment context case <;>
  cases consent : needsConsentAttachment case.authority <;>
  cases dated : needsDatedAmountList case.deathDate <;>
  cases guardian : context.knownGuardianOrConservator <;>
  simp [smallRealPropertyAffidavitMissing,
    smallRealPropertyRequirementChecks, missingFromChecks,
    RequirementCheck.isMissing, SmallRealPropertyAffidavitReady,
    suppliedWhen, will, consent, dated, guardian]

theorem primaryResidencePetitionMissing_empty_iff_ready
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) :
    primaryResidencePetitionMissing context case packet = [] ↔
      PrimaryResidencePetitionReady context case packet := by
  cases will : context.claimsUnderWill <;>
  cases consent : needsConsentAttachment case.authority <;>
  cases dated : needsDatedAmountList case.deathDate <;>
  simp [primaryResidencePetitionMissing,
    primaryResidenceRequirementChecks, missingFromChecks,
    RequirementCheck.isMissing, PrimaryResidencePetitionReady,
    suppliedWhen, will, consent, dated]

theorem spousalPetitionMissing_empty_iff_ready
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) :
    spousalPetitionMissing context case packet = [] ↔
      SpousalPetitionReady context case packet := by
  cases will : context.claimsUnderWill <;>
  cases agreement : context.propertyAgreementExists <;>
  simp [spousalPetitionMissing, spousalRequirementChecks,
    missingFromChecks, RequirementCheck.isMissing,
    SpousalPetitionReady, suppliedWhen, will, agreement]

private def checkedMissingRequirements
    (date : CivilDate) (requirements : List Requirement) :
    Except DateError (List Requirement) :=
  match classifyDeathDate date with
  | .ok _ => .ok requirements
  | .error error => .error error

def personalAffidavitMissingChecked
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket) : Except DateError (List Requirement) :=
  checkedMissingRequirements case.deathDate
    (personalAffidavitMissing context case packet)

def smallRealPropertyAffidavitMissingChecked
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket) : Except DateError (List Requirement) :=
  checkedMissingRequirements case.deathDate
    (smallRealPropertyAffidavitMissing context case packet)

def primaryResidencePetitionMissingChecked
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket) :
    Except DateError (List Requirement) :=
  checkedMissingRequirements case.deathDate
    (primaryResidencePetitionMissing context case packet)

def spousalPetitionMissingChecked
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket) : Except DateError (List Requirement) :=
  checkedMissingRequirements case.deathDate
    (spousalPetitionMissing context case packet)

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
