import SimpleProbate.Procedure

namespace SimpleProbate

inductive PacketItemState
  | unknown
  | absent
  | present
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure PartialProcedureContext where
  claimsUnderWill : Knowledge Bool
  ownershipEvidenceAvailable : Knowledge Bool
  hasOtherEntitledSuccessors : Knowledge Bool
  knownGuardianOrConservator : Knowledge Bool
  institutionRequiresNotary : Knowledge Bool
  propertyAgreementExists : Knowledge Bool
deriving DecidableEq, Repr

structure PartialPersonalAffidavitPacket where
  affidavitDeclarations : PacketItemState
  certifiedDeathCertificate : PacketItemState
  identityProof : PacketItemState
  ownershipEvidencePresented : PacketItemState
  holderIndemnityAlternative : PacketItemState
  allEntitledSuccessorsSigned : PacketItemState
  notarized : PacketItemState
  consentAndLettersAttached : PacketItemState
  datedAmountListAttached : PacketItemState
  inventoryAndAppraisalAttached : PacketItemState
  presentedToHolder : PacketItemState
deriving DecidableEq, Repr

structure PartialSmallRealPropertyPacket where
  de305Statements : PacketItemState
  notarizedAcknowledgments : PacketItemState
  inventoryAndAppraisalAttached : PacketItemState
  certifiedDeathCertificate : PacketItemState
  willAttached : PacketItemState
  consentAndLettersAttached : PacketItemState
  datedAmountListAttached : PacketItemState
  guardianOrConservatorDelivery : PacketItemState
  filedInProperCourt : PacketItemState
  clerkCertifiedCopyIssued : PacketItemState
  recordedInPropertyCounty : PacketItemState
deriving DecidableEq, Repr

structure PartialPrimaryResidencePetitionPacket where
  de310VerifiedStatements : PacketItemState
  inventoryAndAppraisalAttached : PacketItemState
  willAttached : PacketItemState
  consentAttached : PacketItemState
  datedAmountListAttached : PacketItemState
  filedInProperCourt : PacketItemState
  heirAndDeviseeCopyWithinFiveBusinessDays : PacketItemState
  statutoryHearingNotice : PacketItemState
  courtFindingsMade : PacketItemState
  de315OrderIssued : PacketItemState
deriving DecidableEq, Repr

structure PartialSpousalPetitionPacket where
  de221Allegations : PacketItemState
  propertyDescriptionsAndSupportingFacts : PacketItemState
  knownInterestedPersonsListed : PacketItemState
  propertyAgreementDisclosed : PacketItemState
  willAttached : PacketItemState
  propertyAgreementAttached : PacketItemState
  statutoryHearingNotice : PacketItemState
  de226OrderIssued : PacketItemState
deriving DecidableEq, Repr

def PartialPacket : CourtRoute → Type
  | .personalPropertyAffidavit => PartialPersonalAffidavitPacket
  | .smallValueRealPropertyAffidavit => PartialSmallRealPropertyPacket
  | .primaryResidencePetition => PartialPrimaryResidencePetitionPacket
  | .spousalPropertyPetition => PartialSpousalPetitionPacket

private def PacketItemState.ofBool : Bool → PacketItemState
  | false => .absent
  | true => .present

def ProcedureContext.toPartial
    (context : ProcedureContext) : PartialProcedureContext := {
  claimsUnderWill := .known context.claimsUnderWill
  ownershipEvidenceAvailable := .known context.ownershipEvidenceAvailable
  hasOtherEntitledSuccessors := .known context.hasOtherEntitledSuccessors
  knownGuardianOrConservator := .known context.knownGuardianOrConservator
  institutionRequiresNotary := .known context.institutionRequiresNotary
  propertyAgreementExists := .known context.propertyAgreementExists
}

def PersonalAffidavitPacket.toPartial
    (packet : PersonalAffidavitPacket) : PartialPersonalAffidavitPacket := {
  affidavitDeclarations := .ofBool packet.affidavitDeclarations
  certifiedDeathCertificate := .ofBool packet.certifiedDeathCertificate
  identityProof := .ofBool packet.identityProof
  ownershipEvidencePresented := .ofBool packet.ownershipEvidencePresented
  holderIndemnityAlternative := .ofBool packet.holderIndemnityAlternative
  allEntitledSuccessorsSigned := .ofBool packet.allEntitledSuccessorsSigned
  notarized := .ofBool packet.notarized
  consentAndLettersAttached := .ofBool packet.consentAndLettersAttached
  datedAmountListAttached := .ofBool packet.datedAmountListAttached
  inventoryAndAppraisalAttached :=
    .ofBool packet.inventoryAndAppraisalAttached
  presentedToHolder := .ofBool packet.presentedToHolder
}

def SmallRealPropertyPacket.toPartial
    (packet : SmallRealPropertyPacket) : PartialSmallRealPropertyPacket := {
  de305Statements := .ofBool packet.de305Statements
  notarizedAcknowledgments := .ofBool packet.notarizedAcknowledgments
  inventoryAndAppraisalAttached :=
    .ofBool packet.inventoryAndAppraisalAttached
  certifiedDeathCertificate := .ofBool packet.certifiedDeathCertificate
  willAttached := .ofBool packet.willAttached
  consentAndLettersAttached := .ofBool packet.consentAndLettersAttached
  datedAmountListAttached := .ofBool packet.datedAmountListAttached
  guardianOrConservatorDelivery :=
    .ofBool packet.guardianOrConservatorDelivery
  filedInProperCourt := .ofBool packet.filedInProperCourt
  clerkCertifiedCopyIssued := .ofBool packet.clerkCertifiedCopyIssued
  recordedInPropertyCounty := .ofBool packet.recordedInPropertyCounty
}

def PrimaryResidencePetitionPacket.toPartial
    (packet : PrimaryResidencePetitionPacket) :
    PartialPrimaryResidencePetitionPacket := {
  de310VerifiedStatements := .ofBool packet.de310VerifiedStatements
  inventoryAndAppraisalAttached :=
    .ofBool packet.inventoryAndAppraisalAttached
  willAttached := .ofBool packet.willAttached
  consentAttached := .ofBool packet.consentAttached
  datedAmountListAttached := .ofBool packet.datedAmountListAttached
  filedInProperCourt := .ofBool packet.filedInProperCourt
  heirAndDeviseeCopyWithinFiveBusinessDays :=
    .ofBool packet.heirAndDeviseeCopyWithinFiveBusinessDays
  statutoryHearingNotice := .ofBool packet.statutoryHearingNotice
  courtFindingsMade := .ofBool packet.courtFindingsMade
  de315OrderIssued := .ofBool packet.de315OrderIssued
}

def SpousalPetitionPacket.toPartial
    (packet : SpousalPetitionPacket) : PartialSpousalPetitionPacket := {
  de221Allegations := .ofBool packet.de221Allegations
  propertyDescriptionsAndSupportingFacts :=
    .ofBool packet.propertyDescriptionsAndSupportingFacts
  knownInterestedPersonsListed :=
    .ofBool packet.knownInterestedPersonsListed
  propertyAgreementDisclosed := .ofBool packet.propertyAgreementDisclosed
  willAttached := .ofBool packet.willAttached
  propertyAgreementAttached := .ofBool packet.propertyAgreementAttached
  statutoryHearingNotice := .ofBool packet.statutoryHearingNotice
  de226OrderIssued := .ofBool packet.de226OrderIssued
}

def TotalPacket.toPartial
    (route : CourtRoute) : TotalPacket route → PartialPacket route :=
  match route with
  | .personalPropertyAffidavit =>
      PersonalAffidavitPacket.toPartial
  | .smallValueRealPropertyAffidavit =>
      SmallRealPropertyPacket.toPartial
  | .primaryResidencePetition =>
      PrimaryResidencePetitionPacket.toPartial
  | .spousalPropertyPetition =>
      SpousalPetitionPacket.toPartial

inductive ProcedureContextField
  | claimsUnderWill
  | ownershipEvidenceAvailable
  | hasOtherEntitledSuccessors
  | knownGuardianOrConservator
  | institutionRequiresNotary
  | propertyAgreementExists
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive ProcedureFact
  | eligibility (fact : EligibilityFact)
  | context (field : ProcedureContextField)
  | packetItem (requirement : Requirement)
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure ReadinessGaps where
  unresolvedFacts : List ProcedureFact
  missingRequirements : List Requirement
deriving DecidableEq, Repr

inductive ReadinessAssessment
  | ineligible (reasons : List EligibilityFailure)
  | incomplete (gaps : ReadinessGaps)
  | ready
deriving DecidableEq, Repr

structure PartialRequirementCheck where
  requirement : Requirement
  applicabilityFacts : List ProcedureFact
  supplyFact : ProcedureFact
  applies : Knowledge Bool
  item : PacketItemState
deriving DecidableEq, Repr

def PartialRequirementCheck.unresolvedFacts
    (check : PartialRequirementCheck) : List ProcedureFact :=
  match check.applies with
  | .unknown => check.applicabilityFacts
  | .known false => []
  | .known true =>
      if check.item == .unknown then [check.supplyFact] else []

def PartialRequirementCheck.missingRequirement
    (check : PartialRequirementCheck) : List Requirement :=
  match check.applies, check.item with
  | .known true, .absent => [check.requirement]
  | _, _ => []

private def contextApplicability
    (fact : ProcedureContextField) (value : Knowledge Bool) :
    Knowledge Bool × List ProcedureFact :=
  match value with
  | .unknown => (.unknown, [.context fact])
  | .known applies => (.known applies, [])

private def consentApplicability
    (authority : Knowledge SummaryAuthority) :
    Knowledge Bool × List ProcedureFact :=
  match authority with
  | .unknown => (.unknown, [.eligibility .authority])
  | .known .writtenPersonalRepresentativeConsent => (.known true, [])
  | .known _ => (.known false, [])

@[simp] private theorem consentApplicability_ofKnown
    (authority : SummaryAuthority) :
    consentApplicability (.known authority) =
      (.known (needsConsentAttachment authority), []) := by
  cases authority <;> rfl

private def datedListApplicability
    (date : Knowledge CivilDate) :
    Knowledge Bool × List ProcedureFact :=
  match date with
  | .unknown => (.unknown, [.eligibility .deathDate])
  | .known date => (.known (needsDatedAmountList date), [])

private def partialAssetCountedRealStatus
    (asset : PartialAsset) : Knowledge Bool :=
  match asset.kind with
  | .known .californiaReal =>
      match asset.treatment with
      | .known .counted => .known true
      | .known _ => .known false
      | .unknown => .unknown
  | .known _ => .known false
  | .unknown =>
      match asset.treatment with
      | .known .counted => .unknown
      | .known _ => .known false
      | .unknown => .unknown

private def partialAssetCountedRealFacts
    (asset : PartialAsset) : List ProcedureFact :=
  match asset.kind with
  | .known .californiaReal =>
      match asset.treatment with
      | .known _ => []
      | .unknown =>
          [.eligibility (.assetField asset.id .treatment)]
  | .known _ => []
  | .unknown =>
      match asset.treatment with
      | .known .counted =>
          [.eligibility (.assetField asset.id .kind)]
      | .known _ => []
      | .unknown => [
          .eligibility (.assetField asset.id .kind),
          .eligibility (.assetField asset.id .treatment)
        ]

private def anyKnownCountedReal : List PartialAsset → Bool
  | [] => false
  | asset :: rest =>
      match partialAssetCountedRealStatus asset with
      | .known true => true
      | _ => anyKnownCountedReal rest

private def allKnownNotCountedReal : List PartialAsset → Bool
  | [] => true
  | asset :: rest =>
      match partialAssetCountedRealStatus asset with
      | .known false => allKnownNotCountedReal rest
      | _ => false

private def inventoryApplicabilityFacts
    (estate : PartialEstate) : List ProcedureFact :=
  estate.assets.flatMap partialAssetCountedRealFacts ++
    match estate.inventoryComplete with
    | .known true => []
    | _ => [.eligibility .inventoryComplete]

private def inventoryApplicability
    (estate : PartialEstate) :
    Knowledge Bool × List ProcedureFact :=
  if anyKnownCountedReal estate.assets then
    (.known true, [])
  else
    match estate.inventoryComplete with
    | .known true =>
        if allKnownNotCountedReal estate.assets then
          (.known false, [])
        else
          (.unknown, inventoryApplicabilityFacts estate)
    | _ => (.unknown, inventoryApplicabilityFacts estate)

@[simp] private theorem anyKnownCountedReal_ofTotal
    (assets : List Asset) :
    anyKnownCountedReal (assets.map PartialAsset.ofTotal) =
      assets.any
        (fun asset =>
          asset.kind == .californiaReal &&
            asset.treatment == .counted) := by
  induction assets with
  | nil => rfl
  | cons asset rest ih =>
      cases asset with
      | mk id name kind current death encumbrances treatment included primary =>
          cases kind <;> cases treatment <;>
            simp [anyKnownCountedReal, partialAssetCountedRealStatus,
              PartialAsset.ofTotal, ih]

@[simp] private theorem allKnownNotCountedReal_ofTotal
    (assets : List Asset) :
    allKnownNotCountedReal (assets.map PartialAsset.ofTotal) =
      !(assets.any
        (fun asset =>
          asset.kind == .californiaReal &&
            asset.treatment == .counted)) := by
  induction assets with
  | nil => rfl
  | cons asset rest ih =>
      cases asset with
      | mk id name kind current death encumbrances treatment included primary =>
          cases kind <;> cases treatment <;>
            simp [allKnownNotCountedReal, partialAssetCountedRealStatus,
              PartialAsset.ofTotal, ih]

@[simp] private theorem inventoryApplicability_ofTotal
    (estate : Estate) :
    inventoryApplicability (PartialEstate.ofTotal estate) =
      (.known estate.containsCountedCaliforniaRealProperty, []) := by
  cases estate with
  | mk assets =>
      cases present :
        assets.any
          (fun asset =>
            asset.kind == .californiaReal &&
              asset.treatment == .counted) <;>
        simp [inventoryApplicability, PartialEstate.ofTotal,
          Estate.containsCountedCaliforniaRealProperty, present]

private theorem partialAssetCountedRealStatus_completes
    {partialAsset : PartialAsset} {totalAsset : Asset}
    (completion : partialAsset.Completes totalAsset) :
    (partialAssetCountedRealStatus partialAsset).Completes
      (totalAsset.kind == .californiaReal &&
        totalAsset.treatment == .counted) := by
  rcases completion with
    ⟨sameId, sameName, kindCompletion, currentCompletion,
      deathCompletion, encumbrancesCompletion, treatmentCompletion,
      includedCompletion, primaryCompletion⟩
  cases kindEq : partialAsset.kind with
  | unknown =>
      cases treatmentEq : partialAsset.treatment with
      | unknown =>
          simp [partialAssetCountedRealStatus, kindEq, treatmentEq,
            Knowledge.Completes]
      | known treatment =>
          simp [Knowledge.Completes, treatmentEq] at treatmentCompletion
          cases treatment <;>
            rw [← treatmentCompletion] <;>
            simp [partialAssetCountedRealStatus, kindEq, treatmentEq,
              Knowledge.Completes]
  | known kind =>
      cases kind with
      | personal =>
          simp [Knowledge.Completes, kindEq] at kindCompletion
          rw [← kindCompletion]
          simp [partialAssetCountedRealStatus, kindEq,
            Knowledge.Completes]
      | outsideCaliforniaReal =>
          simp [Knowledge.Completes, kindEq] at kindCompletion
          rw [← kindCompletion]
          simp [partialAssetCountedRealStatus, kindEq,
            Knowledge.Completes]
      | californiaReal =>
          cases treatmentEq : partialAsset.treatment with
          | unknown =>
              simp [Knowledge.Completes, kindEq] at kindCompletion
              rw [← kindCompletion]
              simp [partialAssetCountedRealStatus, kindEq, treatmentEq,
                Knowledge.Completes]
          | known treatment =>
              simp [Knowledge.Completes, kindEq] at kindCompletion
              simp [Knowledge.Completes, treatmentEq] at treatmentCompletion
              cases treatment <;>
                rw [← kindCompletion, ← treatmentCompletion] <;>
                simp [partialAssetCountedRealStatus, kindEq, treatmentEq,
                  Knowledge.Completes]

private theorem anyKnownCountedReal_sound
    {partialAssets : List PartialAsset} {totalEstate : Estate}
    (listed :
      ∀ partialAsset ∈ partialAssets,
        ∃ totalAsset ∈ totalEstate.assets,
          partialAsset.Completes totalAsset)
    (knownPresent : anyKnownCountedReal partialAssets = true) :
    totalEstate.containsCountedCaliforniaRealProperty = true := by
  revert listed knownPresent
  induction partialAssets with
  | nil =>
      intro listed knownPresent
      simp [anyKnownCountedReal] at knownPresent
  | cons asset rest ih =>
      intro listed knownPresent
      cases status : partialAssetCountedRealStatus asset with
      | unknown =>
          apply ih
          · intro partialAsset partialMember
            exact listed partialAsset (by simp [partialMember])
          · simpa [anyKnownCountedReal, status] using knownPresent
      | known value =>
          cases value with
          | false =>
              apply ih
              · intro partialAsset partialMember
                exact listed partialAsset (by simp [partialMember])
              · simpa [anyKnownCountedReal, status] using knownPresent
          | true =>
              obtain ⟨totalAsset, totalMember, completion⟩ :=
                listed asset (by simp)
              have statusCompletion :=
                partialAssetCountedRealStatus_completes completion
              rw [status] at statusCompletion
              have predicateTrue :
                  (totalAsset.kind == .californiaReal &&
                    totalAsset.treatment == .counted) = true := by
                simpa [Knowledge.Completes] using statusCompletion
              unfold Estate.containsCountedCaliforniaRealProperty
              exact List.any_eq_true.mpr
                ⟨totalAsset, totalMember, predicateTrue⟩

private theorem allKnownNotCountedReal_member
    {assets : List PartialAsset}
    (allKnown : allKnownNotCountedReal assets = true)
    {asset : PartialAsset} (member : asset ∈ assets) :
    partialAssetCountedRealStatus asset = .known false := by
  induction assets with
  | nil => simp at member
  | cons head rest ih =>
      cases status : partialAssetCountedRealStatus head with
      | unknown =>
          simp [allKnownNotCountedReal, status] at allKnown
      | known value =>
          cases value with
          | true =>
              simp [allKnownNotCountedReal, status] at allKnown
          | false =>
              simp only [List.mem_cons] at member
              rcases member with rfl | member
              · exact status
              · exact ih
                  (by simpa [allKnownNotCountedReal, status] using allKnown)
                  member

private theorem asset_eq_of_mem_of_id_eq
    {assets : List Asset} {left right : Asset}
    (unique : (assets.map (·.id)).Nodup)
    (leftMember : left ∈ assets) (rightMember : right ∈ assets)
    (sameId : left.id = right.id) :
    left = right := by
  induction assets generalizing left right with
  | nil => simp at leftMember
  | cons head tail ih =>
      simp only [List.map_cons, List.nodup_cons] at unique
      simp only [List.mem_cons] at leftMember rightMember
      rcases leftMember with rfl | leftMember
      · rcases rightMember with rfl | rightMember
        · rfl
        · exfalso
          apply unique.1
          simp only [List.mem_map]
          exact ⟨right, rightMember, sameId.symm⟩
      · rcases rightMember with rfl | rightMember
        · exfalso
          apply unique.1
          simp only [List.mem_map]
          exact ⟨left, leftMember, sameId⟩
        · exact ih unique.2 leftMember rightMember sameId

private theorem allKnownNotCountedReal_sound
    {partialEstate : PartialEstate} {totalEstate : Estate}
    (completion : partialEstate.Completes totalEstate)
    (inventoryKnown : partialEstate.inventoryComplete = .known true)
    (allKnown : allKnownNotCountedReal partialEstate.assets = true)
    (totalUnique : (totalEstate.assets.map (·.id)).Nodup) :
    totalEstate.containsCountedCaliforniaRealProperty = false := by
  have sameIds : partialEstate.sameAssetIds totalEstate := by
    unfold PartialEstate.Completes at completion
    rw [inventoryKnown] at completion
    exact completion.2
  unfold Estate.containsCountedCaliforniaRealProperty
  apply List.any_eq_false.mpr
  intro totalAsset totalMember
  have totalIdMember :
      totalAsset.id ∈ totalEstate.assets.map (·.id) := by
    simp only [List.mem_map]
    exact ⟨totalAsset, totalMember, rfl⟩
  have partialIdMember :
      totalAsset.id ∈ partialEstate.assets.map (·.id) :=
    (sameIds totalAsset.id).mpr totalIdMember
  obtain ⟨partialAsset, partialMember, partialId⟩ :=
    List.mem_map.mp partialIdMember
  obtain ⟨completedAsset, completedMember, assetCompletion⟩ :=
    completion.1 partialAsset partialMember
  have completedEq : completedAsset = totalAsset :=
    asset_eq_of_mem_of_id_eq totalUnique completedMember totalMember
      (assetCompletion.1.symm.trans partialId)
  subst completedAsset
  have statusFalse :=
    allKnownNotCountedReal_member allKnown partialMember
  have statusCompletion :=
    partialAssetCountedRealStatus_completes assetCompletion
  rw [statusFalse] at statusCompletion
  simpa [Knowledge.Completes] using statusCompletion

private theorem unknownStatus_has_facts
    (asset : PartialAsset)
    (unknownStatus :
      partialAssetCountedRealStatus asset = .unknown) :
    partialAssetCountedRealFacts asset ≠ [] := by
  cases kindEq : asset.kind with
  | unknown =>
      cases treatmentEq : asset.treatment with
      | unknown =>
          simp [partialAssetCountedRealFacts, kindEq, treatmentEq]
      | known treatment =>
          cases treatment <;>
            simp [partialAssetCountedRealStatus, partialAssetCountedRealFacts,
              kindEq, treatmentEq] at unknownStatus ⊢
  | known kind =>
      cases kind with
      | personal =>
          simp [partialAssetCountedRealStatus, kindEq] at unknownStatus
      | outsideCaliforniaReal =>
          simp [partialAssetCountedRealStatus, kindEq] at unknownStatus
      | californiaReal =>
          cases treatmentEq : asset.treatment with
          | unknown =>
              simp [partialAssetCountedRealFacts, kindEq, treatmentEq]
          | known treatment =>
              cases treatment <;>
                simp [partialAssetCountedRealStatus,
                  kindEq, treatmentEq] at unknownStatus ⊢

private theorem unknownStatus_of_scans
    {assets : List PartialAsset}
    (noneKnown : anyKnownCountedReal assets = false)
    (notAllFalse : allKnownNotCountedReal assets = false) :
    ∃ asset ∈ assets,
      partialAssetCountedRealStatus asset = .unknown := by
  induction assets with
  | nil => simp [allKnownNotCountedReal] at notAllFalse
  | cons asset rest ih =>
      cases status : partialAssetCountedRealStatus asset with
      | unknown => exact ⟨asset, by simp, status⟩
      | known value =>
          cases value with
          | true =>
              simp [anyKnownCountedReal, status] at noneKnown
          | false =>
              obtain ⟨found, foundMember, foundStatus⟩ :=
                ih
                  (by simpa [anyKnownCountedReal, status] using noneKnown)
                  (by simpa [allKnownNotCountedReal, status] using
                    notAllFalse)
              exact ⟨found, by simp [foundMember], foundStatus⟩

private theorem inventoryApplicability_unknown_facts
    (estate : PartialEstate)
    (unknownApplicability :
      (inventoryApplicability estate).1 = .unknown) :
    (inventoryApplicability estate).2 ≠ [] := by
  cases anyResult : anyKnownCountedReal estate.assets with
  | true =>
      simp [inventoryApplicability, anyResult] at unknownApplicability
  | false =>
      cases inventoryResult : estate.inventoryComplete with
      | unknown =>
          simp [inventoryApplicability, inventoryApplicabilityFacts,
            anyResult, inventoryResult]
      | known complete =>
          cases complete with
          | false =>
              simp [inventoryApplicability, inventoryApplicabilityFacts,
                anyResult, inventoryResult]
          | true =>
              cases allResult :
                  allKnownNotCountedReal estate.assets with
              | true =>
                  simp [inventoryApplicability, anyResult,
                    inventoryResult, allResult] at unknownApplicability
              | false =>
                  have unknownAsset :=
                    unknownStatus_of_scans anyResult allResult
                  obtain ⟨asset, assetMember, statusUnknown⟩ :=
                    unknownAsset
                  have assetFacts :=
                    unknownStatus_has_facts asset statusUnknown
                  have flattened :
                      estate.assets.flatMap
                        partialAssetCountedRealFacts ≠ [] := by
                    intro flattenedEmpty
                    have allEmpty :=
                      List.flatMap_eq_nil_iff.mp flattenedEmpty
                    exact assetFacts (allEmpty asset assetMember)
                  simpa [inventoryApplicability, inventoryApplicabilityFacts,
                    anyResult, inventoryResult, allResult] using flattened

private theorem inventoryApplicability_completes
    {partialEstate : PartialEstate} {totalEstate : Estate}
    (completion : partialEstate.Completes totalEstate)
    (totalUnique : (totalEstate.assets.map (·.id)).Nodup) :
    (inventoryApplicability partialEstate).1.Completes
      totalEstate.containsCountedCaliforniaRealProperty := by
  cases anyResult : anyKnownCountedReal partialEstate.assets with
  | true =>
      have present :=
        anyKnownCountedReal_sound completion.1 anyResult
      simp [inventoryApplicability, anyResult,
        Knowledge.Completes, present]
  | false =>
      cases inventoryResult : partialEstate.inventoryComplete with
      | unknown =>
          simp [inventoryApplicability, anyResult,
            inventoryResult, Knowledge.Completes]
      | known complete =>
          cases complete with
          | false =>
              simp [inventoryApplicability, anyResult,
                inventoryResult, Knowledge.Completes]
          | true =>
              cases allResult :
                  allKnownNotCountedReal partialEstate.assets with
              | false =>
                  simp [inventoryApplicability, anyResult,
                    inventoryResult, allResult, Knowledge.Completes]
              | true =>
                  have absent :=
                    allKnownNotCountedReal_sound completion
                      inventoryResult allResult totalUnique
                  simp [inventoryApplicability, anyResult,
                    inventoryResult, allResult,
                    Knowledge.Completes, absent]

private def smallRealWillApplicability
    (claimsUnderWill : Knowledge Bool)
    (authority : Knowledge SummaryAuthority) :
    Knowledge Bool × List ProcedureFact :=
  match claimsUnderWill, authority with
  | .known false, _ => (.known false, [])
  | _, .known .writtenPersonalRepresentativeConsent => (.known false, [])
  | _, .known .blockedByProceeding => (.known false, [])
  | .known true, .known .noProceeding => (.known true, [])
  | .known true, .unknown =>
      (.unknown, [.eligibility .authority])
  | .unknown, .known .noProceeding =>
      (.unknown, [.context .claimsUnderWill])
  | .unknown, .unknown =>
      (.unknown, [
        .context .claimsUnderWill,
        .eligibility .authority
      ])

@[simp] private theorem smallRealWillApplicability_ofKnown
    (claimsUnderWill : Bool) (authority : SummaryAuthority) :
    smallRealWillApplicability (.known claimsUnderWill) (.known authority) =
      (.known
        (claimsUnderWill && noEstateProceeding authority), []) := by
  cases claimsUnderWill <;> cases authority <;> rfl

private def partialCheck
    (requirement : Requirement)
    (applicability : Knowledge Bool × List ProcedureFact)
    (item : PacketItemState) : PartialRequirementCheck := {
  requirement
  applicabilityFacts := applicability.2
  supplyFact := .packetItem requirement
  applies := applicability.1
  item
}

private def totalCheckToPartial
    (check : RequirementCheck) : PartialRequirementCheck :=
  partialCheck check.requirement (.known check.applies, [])
    (.ofBool check.supplied)

@[simp] private theorem totalCheckToPartial_unresolved
    (check : RequirementCheck) :
    (totalCheckToPartial check).unresolvedFacts = [] := by
  cases check with
  | mk requirement applies supplied =>
      cases applies <;> cases supplied <;>
        rfl

private def ownershipCheckData
    (availability : Knowledge Bool)
    (ownershipEvidencePresented holderIndemnityAlternative :
      PacketItemState) :
    (Knowledge Bool × List ProcedureFact) × PacketItemState :=
  match availability with
  | .known true => ((.known true, []), ownershipEvidencePresented)
  | .known false => ((.known true, []), holderIndemnityAlternative)
  | .unknown =>
      ((.unknown, [.context .ownershipEvidenceAvailable]),
        ownershipEvidencePresented)

def personalPartialRequirementChecks
    (context : PartialProcedureContext) (case : PartialTransferCase)
    (packet : PartialPersonalAffidavitPacket) :
    List PartialRequirementCheck :=
  let ownership := ownershipCheckData
    context.ownershipEvidenceAvailable
    packet.ownershipEvidencePresented
    packet.holderIndemnityAlternative
  [
    partialCheck .eligibleRoute (.known true, []) .present,
    partialCheck .affidavitDeclarations (.known true, [])
      packet.affidavitDeclarations,
    partialCheck .certifiedDeathCertificate (.known true, [])
      packet.certifiedDeathCertificate,
    partialCheck .identityProof (.known true, []) packet.identityProof,
    partialCheck .ownershipEvidenceOrIndemnity ownership.1 ownership.2,
    partialCheck .allEntitledSuccessorsSigned
      (contextApplicability .hasOtherEntitledSuccessors
        context.hasOtherEntitledSuccessors)
      packet.allEntitledSuccessorsSigned,
    partialCheck .notarization
      (contextApplicability .institutionRequiresNotary
        context.institutionRequiresNotary)
      packet.notarized,
    partialCheck .consentAndLetters
      (consentApplicability case.authority)
      packet.consentAndLettersAttached,
    partialCheck .datedAmountList
      (datedListApplicability case.deathDate)
      packet.datedAmountListAttached,
    partialCheck .inventoryAndAppraisal
      (inventoryApplicability case.estate)
      packet.inventoryAndAppraisalAttached,
    partialCheck .presentationToHolder (.known true, [])
      packet.presentedToHolder
  ]

def smallRealPartialRequirementChecks
    (context : PartialProcedureContext) (case : PartialTransferCase)
    (packet : PartialSmallRealPropertyPacket) :
    List PartialRequirementCheck := [
  partialCheck .eligibleRoute (.known true, []) .present,
  partialCheck .de305Statements (.known true, []) packet.de305Statements,
  partialCheck .notarization (.known true, [])
    packet.notarizedAcknowledgments,
  partialCheck .inventoryAndAppraisal (.known true, [])
    packet.inventoryAndAppraisalAttached,
  partialCheck .certifiedDeathCertificate (.known true, [])
    packet.certifiedDeathCertificate,
  partialCheck .willAttachment
    (smallRealWillApplicability context.claimsUnderWill case.authority)
    packet.willAttached,
  partialCheck .consentAndLetters
    (consentApplicability case.authority)
    packet.consentAndLettersAttached,
  partialCheck .datedAmountList
    (datedListApplicability case.deathDate)
    packet.datedAmountListAttached,
  partialCheck .guardianOrConservatorDelivery
    (contextApplicability .knownGuardianOrConservator
      context.knownGuardianOrConservator)
    packet.guardianOrConservatorDelivery,
  partialCheck .properCourtFiling (.known true, [])
    packet.filedInProperCourt,
  partialCheck .clerkCertifiedCopy (.known true, [])
    packet.clerkCertifiedCopyIssued,
  partialCheck .countyRecording (.known true, [])
    packet.recordedInPropertyCounty
]

def primaryPartialRequirementChecks
    (context : PartialProcedureContext) (case : PartialTransferCase)
    (packet : PartialPrimaryResidencePetitionPacket) :
    List PartialRequirementCheck := [
  partialCheck .eligibleRoute (.known true, []) .present,
  partialCheck .de310VerifiedStatements (.known true, [])
    packet.de310VerifiedStatements,
  partialCheck .inventoryAndAppraisal (.known true, [])
    packet.inventoryAndAppraisalAttached,
  partialCheck .willAttachment
    (contextApplicability .claimsUnderWill context.claimsUnderWill)
    packet.willAttached,
  partialCheck .consentAndLetters
    (consentApplicability case.authority)
    packet.consentAttached,
  partialCheck .datedAmountList
    (datedListApplicability case.deathDate)
    packet.datedAmountListAttached,
  partialCheck .properCourtFiling (.known true, [])
    packet.filedInProperCourt,
  partialCheck .heirAndDeviseeCopyWithinFiveBusinessDays (.known true, [])
    packet.heirAndDeviseeCopyWithinFiveBusinessDays,
  partialCheck .statutoryHearingNotice (.known true, [])
    packet.statutoryHearingNotice,
  partialCheck .courtFindings (.known true, []) packet.courtFindingsMade,
  partialCheck .de315Order (.known true, []) packet.de315OrderIssued
]

def spousalPartialRequirementChecks
    (context : PartialProcedureContext) (_case : PartialTransferCase)
    (packet : PartialSpousalPetitionPacket) :
    List PartialRequirementCheck := [
  partialCheck .eligibleRoute (.known true, []) .present,
  partialCheck .de221Allegations (.known true, []) packet.de221Allegations,
  partialCheck .propertyDescriptionsAndSupportingFacts (.known true, [])
    packet.propertyDescriptionsAndSupportingFacts,
  partialCheck .knownInterestedPersons (.known true, [])
    packet.knownInterestedPersonsListed,
  partialCheck .propertyAgreementDisclosure (.known true, [])
    packet.propertyAgreementDisclosed,
  partialCheck .willAttachment
    (contextApplicability .claimsUnderWill context.claimsUnderWill)
    packet.willAttached,
  partialCheck .propertyAgreementAttachment
    (contextApplicability .propertyAgreementExists
      context.propertyAgreementExists)
    packet.propertyAgreementAttached,
  partialCheck .statutoryHearingNotice (.known true, [])
    packet.statutoryHearingNotice,
  partialCheck .de226Order (.known true, []) packet.de226OrderIssued
]

structure PacketCheckSummary where
  unresolvedFacts : List ProcedureFact
  missingRequirements : List Requirement
deriving DecidableEq, Repr

def summarizePartialChecks
    (checks : List PartialRequirementCheck) : PacketCheckSummary := {
  unresolvedFacts :=
    dedupStable (checks.flatMap (·.unresolvedFacts))
  missingRequirements :=
    dedupStable (checks.flatMap (·.missingRequirement))
}

def personalPacketChecks
    (context : PartialProcedureContext) (case : PartialTransferCase)
    (packet : PartialPersonalAffidavitPacket) : PacketCheckSummary :=
  summarizePartialChecks <|
    personalPartialRequirementChecks context case packet

def smallRealPacketChecks
    (context : PartialProcedureContext) (case : PartialTransferCase)
    (packet : PartialSmallRealPropertyPacket) : PacketCheckSummary :=
  summarizePartialChecks <|
    smallRealPartialRequirementChecks context case packet

def primaryPacketChecks
    (context : PartialProcedureContext) (case : PartialTransferCase)
    (packet : PartialPrimaryResidencePetitionPacket) : PacketCheckSummary :=
  summarizePartialChecks <|
    primaryPartialRequirementChecks context case packet

def spousalPacketChecks
    (context : PartialProcedureContext) (case : PartialTransferCase)
    (packet : PartialSpousalPetitionPacket) : PacketCheckSummary :=
  summarizePartialChecks <|
    spousalPartialRequirementChecks context case packet

def packetChecks
    (route : CourtRoute) (context : PartialProcedureContext)
    (case : PartialTransferCase) (packet : PartialPacket route) :
    PacketCheckSummary :=
  match route with
  | .personalPropertyAffidavit =>
      personalPacketChecks context case packet
  | .smallValueRealPropertyAffidavit =>
      smallRealPacketChecks context case packet
  | .primaryResidencePetition =>
      primaryPacketChecks context case packet
  | .spousalPropertyPetition =>
      spousalPacketChecks context case packet

def assessPacket
    (route : CourtRoute) (context : PartialProcedureContext)
    (case : PartialTransferCase) (packet : PartialPacket route) :
    Except CaseError ReadinessAssessment := do
  let routeStatus ← assessRoute case route.toSimplifiedRoute
  match routeStatus with
  | .doesNotQualify reasons =>
      pure <| .ineligible reasons
  | .qualifies =>
      let summary := packetChecks route context case packet
      if summary.unresolvedFacts = [] ∧
          summary.missingRequirements = [] then
        pure .ready
      else
        pure <| .incomplete {
          unresolvedFacts := dedupStable summary.unresolvedFacts
          missingRequirements :=
            dedupStable summary.missingRequirements
        }
  | .needsInformation facts =>
      let summary := packetChecks route context case packet
      pure <| .incomplete {
        unresolvedFacts :=
          dedupStable (facts.map ProcedureFact.eligibility ++
            summary.unresolvedFacts)
        missingRequirements :=
          dedupStable summary.missingRequirements
      }

private theorem assessPacket_ready_iff
    (route : CourtRoute) (context : PartialProcedureContext)
    (case : PartialTransferCase) (packet : PartialPacket route) :
    assessPacket route context case packet = .ok .ready ↔
      assessRoute case route.toSimplifiedRoute = .ok .qualifies ∧
      (packetChecks route context case packet).unresolvedFacts = [] ∧
      (packetChecks route context case packet).missingRequirements = [] := by
  cases routeResult : assessRoute case route.toSimplifiedRoute with
  | error error =>
      simp [assessPacket, routeResult, Bind.bind, Except.bind]
  | ok status =>
      cases status with
      | qualifies =>
          by_cases noGaps :
              (packetChecks route context case packet).unresolvedFacts = [] ∧
                (packetChecks route context case packet).missingRequirements = []
          · simp [assessPacket, routeResult, noGaps,
              Bind.bind, Pure.pure,
              Except.bind, Except.pure]
          · simp [assessPacket, routeResult, noGaps,
              Bind.bind, Pure.pure,
              Except.bind, Except.pure]
      | doesNotQualify reasons =>
          simp [assessPacket, routeResult, Bind.bind, Pure.pure,
            Except.bind, Except.pure]
      | needsInformation facts =>
          simp [assessPacket, routeResult, Bind.bind, Pure.pure,
            Except.bind, Except.pure]

def PacketItemState.Completes : PacketItemState → Bool → Prop
  | .unknown, _ => True
  | .absent, supplied => supplied = false
  | .present, supplied => supplied = true

@[simp] private theorem PacketItemState.ofBool_completes
    (supplied : Bool) :
    (PacketItemState.ofBool supplied).Completes supplied := by
  cases supplied <;> rfl

@[simp] private theorem PacketItemState.ofBool_beq_unknown
    (supplied : Bool) :
    (PacketItemState.ofBool supplied == .unknown) = false := by
  cases supplied <;> rfl

private def ApplicabilitySound
    (partialApplicability : Knowledge Bool × List ProcedureFact)
    (totalApplies : Bool) : Prop :=
  partialApplicability.1.Completes totalApplies ∧
  (partialApplicability.1 = .unknown →
    partialApplicability.2 ≠ [])

private theorem unconditionalApplicability_sound :
    ApplicabilitySound (.known true, []) true := by
  simp [ApplicabilitySound, Knowledge.Completes]

private theorem contextApplicability_sound
    (field : ProcedureContextField)
    {partialValue : Knowledge Bool} {totalValue : Bool}
    (completion : partialValue.Completes totalValue) :
    ApplicabilitySound
      (contextApplicability field partialValue) totalValue := by
  cases partialValue <;>
    simp_all [ApplicabilitySound, contextApplicability,
      Knowledge.Completes]

private theorem consentApplicability_sound
    {partialAuthority : Knowledge SummaryAuthority}
    {totalAuthority : SummaryAuthority}
    (completion : partialAuthority.Completes totalAuthority) :
    ApplicabilitySound
      (consentApplicability partialAuthority)
      (needsConsentAttachment totalAuthority) := by
  cases partialAuthority with
  | unknown =>
      cases totalAuthority <;>
        simp [ApplicabilitySound, consentApplicability,
          needsConsentAttachment, Knowledge.Completes]
  | known authority =>
      simp [Knowledge.Completes] at completion
      subst authority
      cases totalAuthority <;>
        simp [ApplicabilitySound, consentApplicability,
          needsConsentAttachment, Knowledge.Completes] <;>
        decide

private theorem datedListApplicability_sound
    {partialDate : Knowledge CivilDate} {totalDate : CivilDate}
    (completion : partialDate.Completes totalDate) :
    ApplicabilitySound
      (datedListApplicability partialDate)
      (needsDatedAmountList totalDate) := by
  cases partialDate with
  | unknown =>
      simp [ApplicabilitySound, datedListApplicability,
        Knowledge.Completes]
  | known date =>
      simp [Knowledge.Completes] at completion
      subst date
      simp [ApplicabilitySound, datedListApplicability,
        Knowledge.Completes]

private theorem smallRealWillApplicability_sound
    {partialClaims : Knowledge Bool}
    {partialAuthority : Knowledge SummaryAuthority}
    {totalClaims : Bool} {totalAuthority : SummaryAuthority}
    (claimsCompletion : partialClaims.Completes totalClaims)
    (authorityCompletion :
      partialAuthority.Completes totalAuthority) :
    ApplicabilitySound
      (smallRealWillApplicability partialClaims partialAuthority)
      (totalClaims && noEstateProceeding totalAuthority) := by
  cases partialClaims with
  | unknown =>
      cases partialAuthority with
      | unknown =>
          cases totalClaims <;> cases totalAuthority <;>
            simp [ApplicabilitySound, smallRealWillApplicability,
              noEstateProceeding, Knowledge.Completes] <;>
            decide
      | known authority =>
          simp [Knowledge.Completes] at authorityCompletion
          subst authority
          cases totalClaims <;> cases totalAuthority <;>
            simp [ApplicabilitySound, smallRealWillApplicability,
              noEstateProceeding, Knowledge.Completes] <;>
            decide
  | known claims =>
      simp [Knowledge.Completes] at claimsCompletion
      subst claims
      cases partialAuthority with
      | unknown =>
          cases totalClaims <;> cases totalAuthority <;>
            simp [ApplicabilitySound, smallRealWillApplicability,
              noEstateProceeding, Knowledge.Completes] <;>
            decide
      | known authority =>
          simp [Knowledge.Completes] at authorityCompletion
          subst authority
          cases totalClaims <;> cases totalAuthority <;>
            simp [ApplicabilitySound, smallRealWillApplicability,
              noEstateProceeding, Knowledge.Completes] <;>
            decide

private theorem inventoryApplicability_sound
    {partialEstate : PartialEstate} {totalEstate : Estate}
    (completion : partialEstate.Completes totalEstate)
    (totalUnique : (totalEstate.assets.map (·.id)).Nodup) :
    ApplicabilitySound
      (inventoryApplicability partialEstate)
      totalEstate.containsCountedCaliforniaRealProperty :=
  ⟨inventoryApplicability_completes completion totalUnique,
    inventoryApplicability_unknown_facts partialEstate⟩

private def PartialRequirementCheck.Supports
    (partialCheck : PartialRequirementCheck)
    (totalCheck : RequirementCheck) : Prop :=
  partialCheck.requirement = totalCheck.requirement ∧
  partialCheck.applies.Completes totalCheck.applies ∧
  (partialCheck.applies = .known true →
    partialCheck.item.Completes totalCheck.supplied) ∧
  (partialCheck.applies = .unknown →
    partialCheck.applicabilityFacts ≠ [])

private theorem partialCheck_supports
    (requirement : Requirement)
    (partialApplicability : Knowledge Bool × List ProcedureFact)
    (item : PacketItemState) (totalApplies totalSupplied : Bool)
    (applicabilitySound :
      ApplicabilitySound partialApplicability totalApplies)
    (itemSound :
      partialApplicability.1 = .known true →
        item.Completes totalSupplied) :
    (partialCheck requirement partialApplicability item).Supports {
      requirement
      applies := totalApplies
      supplied := totalSupplied
    } := by
  exact ⟨rfl, applicabilitySound.1, itemSound,
    applicabilitySound.2⟩

private theorem ownershipCheck_supports
    {partialAvailability : Knowledge Bool}
    {totalAvailability : Bool}
    {partialPresented partialIndemnity : PacketItemState}
    {totalPresented totalIndemnity : Bool}
    (availabilityCompletion :
      partialAvailability.Completes totalAvailability)
    (presentedCompletion :
      partialPresented.Completes totalPresented)
    (indemnityCompletion :
      partialIndemnity.Completes totalIndemnity) :
    (partialCheck .ownershipEvidenceOrIndemnity
      (ownershipCheckData partialAvailability
        partialPresented partialIndemnity).1
      (ownershipCheckData partialAvailability
        partialPresented partialIndemnity).2).Supports {
      requirement := .ownershipEvidenceOrIndemnity
      applies := true
      supplied :=
        if totalAvailability then totalPresented else totalIndemnity
    } := by
  cases partialAvailability with
  | unknown =>
      cases totalAvailability <;>
        simp [PartialRequirementCheck.Supports, partialCheck,
          ownershipCheckData, Knowledge.Completes]
  | known available =>
      simp [Knowledge.Completes] at availabilityCompletion
      subst available
      cases totalAvailability <;>
        simp_all [PartialRequirementCheck.Supports, partialCheck,
          ownershipCheckData, Knowledge.Completes]

private inductive ChecksSupport :
    List PartialRequirementCheck → List RequirementCheck → Prop
  | nil : ChecksSupport [] []
  | cons {partialCheck totalCheck partialRest totalRest} :
      partialCheck.Supports totalCheck →
      ChecksSupport partialRest totalRest →
      ChecksSupport (partialCheck :: partialRest)
        (totalCheck :: totalRest)

private theorem checksSupport_matching
    {partialChecks : List PartialRequirementCheck}
    {totalChecks : List RequirementCheck}
    (relation : ChecksSupport partialChecks totalChecks) :
    ∀ totalCheck ∈ totalChecks,
      ∃ partialCheck ∈ partialChecks,
        partialCheck.Supports totalCheck := by
  intro totalCheck totalMember
  induction relation with
  | nil => simp at totalMember
  | cons headSupport tailSupport ih =>
      simp only [List.mem_cons] at totalMember
      rcases totalMember with rfl | totalMember
      · exact ⟨_, by simp, headSupport⟩
      · obtain ⟨partialCheck, partialMember, support⟩ :=
          ih totalMember
        exact ⟨partialCheck, by simp [partialMember], support⟩

def PartialProcedureContext.Completes
    (partialContext : PartialProcedureContext)
    (total : ProcedureContext) : Prop :=
  partialContext.claimsUnderWill.Completes total.claimsUnderWill ∧
  partialContext.ownershipEvidenceAvailable.Completes
    total.ownershipEvidenceAvailable ∧
  partialContext.hasOtherEntitledSuccessors.Completes
    total.hasOtherEntitledSuccessors ∧
  partialContext.knownGuardianOrConservator.Completes
    total.knownGuardianOrConservator ∧
  partialContext.institutionRequiresNotary.Completes
    total.institutionRequiresNotary ∧
  partialContext.propertyAgreementExists.Completes
    total.propertyAgreementExists

def PartialPersonalAffidavitPacket.Completes
    (partialPacket : PartialPersonalAffidavitPacket)
    (total : PersonalAffidavitPacket) : Prop :=
  partialPacket.affidavitDeclarations.Completes total.affidavitDeclarations ∧
  partialPacket.certifiedDeathCertificate.Completes
    total.certifiedDeathCertificate ∧
  partialPacket.identityProof.Completes total.identityProof ∧
  partialPacket.ownershipEvidencePresented.Completes
    total.ownershipEvidencePresented ∧
  partialPacket.holderIndemnityAlternative.Completes
    total.holderIndemnityAlternative ∧
  partialPacket.allEntitledSuccessorsSigned.Completes
    total.allEntitledSuccessorsSigned ∧
  partialPacket.notarized.Completes total.notarized ∧
  partialPacket.consentAndLettersAttached.Completes
    total.consentAndLettersAttached ∧
  partialPacket.datedAmountListAttached.Completes
    total.datedAmountListAttached ∧
  partialPacket.inventoryAndAppraisalAttached.Completes
    total.inventoryAndAppraisalAttached ∧
  partialPacket.presentedToHolder.Completes total.presentedToHolder

def PartialSmallRealPropertyPacket.Completes
    (partialPacket : PartialSmallRealPropertyPacket)
    (total : SmallRealPropertyPacket) : Prop :=
  partialPacket.de305Statements.Completes total.de305Statements ∧
  partialPacket.notarizedAcknowledgments.Completes
    total.notarizedAcknowledgments ∧
  partialPacket.inventoryAndAppraisalAttached.Completes
    total.inventoryAndAppraisalAttached ∧
  partialPacket.certifiedDeathCertificate.Completes
    total.certifiedDeathCertificate ∧
  partialPacket.willAttached.Completes total.willAttached ∧
  partialPacket.consentAndLettersAttached.Completes
    total.consentAndLettersAttached ∧
  partialPacket.datedAmountListAttached.Completes
    total.datedAmountListAttached ∧
  partialPacket.guardianOrConservatorDelivery.Completes
    total.guardianOrConservatorDelivery ∧
  partialPacket.filedInProperCourt.Completes total.filedInProperCourt ∧
  partialPacket.clerkCertifiedCopyIssued.Completes
    total.clerkCertifiedCopyIssued ∧
  partialPacket.recordedInPropertyCounty.Completes
    total.recordedInPropertyCounty

def PartialPrimaryResidencePetitionPacket.Completes
    (partialPacket : PartialPrimaryResidencePetitionPacket)
    (total : PrimaryResidencePetitionPacket) : Prop :=
  partialPacket.de310VerifiedStatements.Completes
    total.de310VerifiedStatements ∧
  partialPacket.inventoryAndAppraisalAttached.Completes
    total.inventoryAndAppraisalAttached ∧
  partialPacket.willAttached.Completes total.willAttached ∧
  partialPacket.consentAttached.Completes total.consentAttached ∧
  partialPacket.datedAmountListAttached.Completes
    total.datedAmountListAttached ∧
  partialPacket.filedInProperCourt.Completes total.filedInProperCourt ∧
  partialPacket.heirAndDeviseeCopyWithinFiveBusinessDays.Completes
    total.heirAndDeviseeCopyWithinFiveBusinessDays ∧
  partialPacket.statutoryHearingNotice.Completes
    total.statutoryHearingNotice ∧
  partialPacket.courtFindingsMade.Completes total.courtFindingsMade ∧
  partialPacket.de315OrderIssued.Completes total.de315OrderIssued

def PartialSpousalPetitionPacket.Completes
    (partialPacket : PartialSpousalPetitionPacket)
    (total : SpousalPetitionPacket) : Prop :=
  partialPacket.de221Allegations.Completes total.de221Allegations ∧
  partialPacket.propertyDescriptionsAndSupportingFacts.Completes
    total.propertyDescriptionsAndSupportingFacts ∧
  partialPacket.knownInterestedPersonsListed.Completes
    total.knownInterestedPersonsListed ∧
  partialPacket.propertyAgreementDisclosed.Completes
    total.propertyAgreementDisclosed ∧
  partialPacket.willAttached.Completes total.willAttached ∧
  partialPacket.propertyAgreementAttached.Completes
    total.propertyAgreementAttached ∧
  partialPacket.statutoryHearingNotice.Completes
    total.statutoryHearingNotice ∧
  partialPacket.de226OrderIssued.Completes total.de226OrderIssued

def PartialPacketCompletes
    (route : CourtRoute) (partialPacket : PartialPacket route)
    (total : TotalPacket route) : Prop :=
  match route with
  | .personalPropertyAffidavit =>
      PartialPersonalAffidavitPacket.Completes partialPacket total
  | .smallValueRealPropertyAffidavit =>
      PartialSmallRealPropertyPacket.Completes partialPacket total
  | .primaryResidencePetition =>
      PartialPrimaryResidencePetitionPacket.Completes partialPacket total
  | .spousalPropertyPetition =>
      PartialSpousalPetitionPacket.Completes partialPacket total

theorem partialPersonal_ofTotal_completes
    (packet : PersonalAffidavitPacket) :
    packet.toPartial.Completes packet := by
  cases packet <;>
    simp [PersonalAffidavitPacket.toPartial,
      PartialPersonalAffidavitPacket.Completes]

theorem partialSmallReal_ofTotal_completes
    (packet : SmallRealPropertyPacket) :
    packet.toPartial.Completes packet := by
  cases packet <;>
    simp [SmallRealPropertyPacket.toPartial,
      PartialSmallRealPropertyPacket.Completes]

theorem partialPrimaryResidence_ofTotal_completes
    (packet : PrimaryResidencePetitionPacket) :
    packet.toPartial.Completes packet := by
  cases packet <;>
    simp [PrimaryResidencePetitionPacket.toPartial,
      PartialPrimaryResidencePetitionPacket.Completes]

theorem partialSpousal_ofTotal_completes
    (packet : SpousalPetitionPacket) :
    packet.toPartial.Completes packet := by
  cases packet <;>
    simp [SpousalPetitionPacket.toPartial,
      PartialSpousalPetitionPacket.Completes]

theorem partialProcedureContext_ofTotal_completes
    (context : ProcedureContext) :
    context.toPartial.Completes context := by
  cases context <;>
    simp [ProcedureContext.toPartial,
      PartialProcedureContext.Completes, Knowledge.Completes]

private theorem mem_check_unresolved_iff
    (check : PartialRequirementCheck) (fact : ProcedureFact) :
    fact ∈ check.unresolvedFacts ↔
      (check.applies = .unknown ∧
        fact ∈ check.applicabilityFacts) ∨
      (check.applies = .known true ∧
        check.item = .unknown ∧
        check.supplyFact = fact) := by
  cases check with
  | mk requirement applicabilityFacts supplyFact applies item =>
      cases applies with
      | unknown =>
          cases item <;>
            simp [PartialRequirementCheck.unresolvedFacts]
      | known value =>
          cases value <;> cases item <;>
            simp [PartialRequirementCheck.unresolvedFacts] <;>
            exact eq_comm

private theorem mem_check_missing_iff
    (check : PartialRequirementCheck) (requirement : Requirement) :
    requirement ∈ check.missingRequirement ↔
      check.requirement = requirement ∧
      check.applies = .known true ∧
      check.item = .absent := by
  cases check with
  | mk checkRequirement applicabilityFacts supplyFact applies item =>
      cases applies with
      | unknown =>
          cases item <;>
            simp [PartialRequirementCheck.missingRequirement]
      | known value =>
          cases value <;> cases item <;>
            simp [PartialRequirementCheck.missingRequirement] <;>
            exact eq_comm

private theorem mem_summary_unresolved_iff
    (checks : List PartialRequirementCheck) (fact : ProcedureFact) :
    fact ∈ (summarizePartialChecks checks).unresolvedFacts ↔
      ∃ check ∈ checks,
        (check.applies = .unknown ∧
          fact ∈ check.applicabilityFacts) ∨
        (check.applies = .known true ∧
          check.item = .unknown ∧
          check.supplyFact = fact) := by
  simp only [summarizePartialChecks, mem_dedupStable,
    List.mem_flatMap]
  constructor
  · rintro ⟨check, checkMember, factMember⟩
    exact ⟨check, checkMember,
      (mem_check_unresolved_iff check fact).mp factMember⟩
  · rintro ⟨check, checkMember, condition⟩
    exact ⟨check, checkMember,
      (mem_check_unresolved_iff check fact).mpr condition⟩

private theorem mem_summary_missing_iff
    (checks : List PartialRequirementCheck) (requirement : Requirement) :
    requirement ∈ (summarizePartialChecks checks).missingRequirements ↔
      ∃ check ∈ checks,
        check.requirement = requirement ∧
        check.applies = .known true ∧
        check.item = .absent := by
  simp only [summarizePartialChecks, mem_dedupStable,
    List.mem_flatMap]
  constructor
  · rintro ⟨check, checkMember, requirementMember⟩
    exact ⟨check, checkMember,
      (mem_check_missing_iff check requirement).mp requirementMember⟩
  · rintro ⟨check, checkMember, condition⟩
    exact ⟨check, checkMember,
      (mem_check_missing_iff check requirement).mpr condition⟩

private theorem check_unresolved_empty_of_summary
    {checks : List PartialRequirementCheck}
    {check : PartialRequirementCheck} (checkMember : check ∈ checks)
    (summaryEmpty :
      (summarizePartialChecks checks).unresolvedFacts = []) :
    check.unresolvedFacts = [] := by
  apply List.eq_nil_iff_forall_not_mem.mpr
  intro fact factMember
  have summaryMember :
      fact ∈ (summarizePartialChecks checks).unresolvedFacts :=
    (mem_summary_unresolved_iff checks fact).mpr
      ⟨check, checkMember,
        (mem_check_unresolved_iff check fact).mp factMember⟩
  simp [summaryEmpty] at summaryMember

private theorem check_missing_empty_of_summary
    {checks : List PartialRequirementCheck}
    {check : PartialRequirementCheck} (checkMember : check ∈ checks)
    (summaryEmpty :
      (summarizePartialChecks checks).missingRequirements = []) :
    check.missingRequirement = [] := by
  apply List.eq_nil_iff_forall_not_mem.mpr
  intro requirement requirementMember
  have summaryMember :
      requirement ∈
        (summarizePartialChecks checks).missingRequirements :=
    (mem_summary_missing_iff checks requirement).mpr
      ⟨check, checkMember,
        (mem_check_missing_iff check requirement).mp
          requirementMember⟩
  simp [summaryEmpty] at summaryMember

private theorem supported_check_not_missing
    (partialCheck : PartialRequirementCheck)
    (totalCheck : RequirementCheck)
    (support : partialCheck.Supports totalCheck)
    (unresolvedEmpty : partialCheck.unresolvedFacts = [])
    (missingEmpty : partialCheck.missingRequirement = []) :
    ¬(totalCheck.applies = true ∧ totalCheck.supplied = false) := by
  cases partialCheck with
  | mk partialRequirement applicabilityFacts supplyFact applies item =>
      cases totalCheck with
      | mk totalRequirement totalApplies totalSupplied =>
          cases applies with
          | unknown =>
              cases totalApplies <;> cases totalSupplied <;>
                simp_all [PartialRequirementCheck.Supports,
                  PartialRequirementCheck.unresolvedFacts,
                  PartialRequirementCheck.missingRequirement,
                  Knowledge.Completes, PacketItemState.Completes]
          | known applies =>
              cases applies <;> cases item <;>
                cases totalApplies <;> cases totalSupplied <;>
                simp_all [PartialRequirementCheck.Supports,
                  PartialRequirementCheck.unresolvedFacts,
                  PartialRequirementCheck.missingRequirement,
                  Knowledge.Completes, PacketItemState.Completes]

private theorem totalMissing_empty_of_supported
    (partialChecks : List PartialRequirementCheck)
    (totalChecks : List RequirementCheck)
    (unresolvedEmpty :
      (summarizePartialChecks partialChecks).unresolvedFacts = [])
    (missingEmpty :
      (summarizePartialChecks partialChecks).missingRequirements = [])
    (supported :
      ∀ totalCheck ∈ totalChecks,
        ∃ partialCheck ∈ partialChecks,
          partialCheck.Supports totalCheck) :
    missingFromChecks totalChecks = [] := by
  apply List.eq_nil_iff_forall_not_mem.mpr
  intro requirement requirementMember
  obtain ⟨totalCheck, totalMember, requirementEq,
      appliesEq, suppliedEq⟩ :=
    (mem_missingFromChecks_iff totalChecks requirement).mp
      requirementMember
  obtain ⟨partialCheck, partialMember, support⟩ :=
    supported totalCheck totalMember
  exact supported_check_not_missing partialCheck totalCheck support
    (check_unresolved_empty_of_summary partialMember unresolvedEmpty)
    (check_missing_empty_of_summary partialMember missingEmpty)
    ⟨appliesEq, suppliedEq⟩

private theorem personalChecks_support
    {partialContext : PartialProcedureContext}
    {totalContext : ProcedureContext}
    {partialCase : PartialTransferCase}
    {totalCase : TransferCase}
    {partialPacket : PartialPersonalAffidavitPacket}
    {totalPacket : PersonalAffidavitPacket}
    (eligible : PersonalPropertyAffidavitEligible totalCase)
    (contextCompletion : partialContext.Completes totalContext)
    (caseCompletion : partialCase.Completes totalCase)
    (packetCompletion : partialPacket.Completes totalPacket)
    (wellFormed : TransferCase.WellFormed totalCase) :
    ChecksSupport
      (personalPartialRequirementChecks partialContext partialCase
        partialPacket)
      (personalRequirementChecks totalContext totalCase totalPacket) := by
  rcases contextCompletion with
    ⟨claimsCompletion, ownershipCompletion, successorsCompletion,
      guardianCompletion, notaryCompletion, agreementCompletion⟩
  rcases caseCompletion with
    ⟨dateCompletion, estateCompletion, targetCompletion,
      authorityCompletion, daysCompletion, sixMonthsCompletion,
      successorCompletion, superiorCompletion, debtsCompletion,
      survivorCompletion, passesCompletion, belongsCompletion⟩
  rcases packetCompletion with
    ⟨declarationsCompletion, certificateCompletion, identityCompletion,
      ownershipPresentedCompletion, indemnityCompletion,
      signaturesCompletion, notarizedCompletion, consentCompletion,
      datedCompletion, inventoryCompletion, presentedCompletion⟩
  unfold personalPartialRequirementChecks personalRequirementChecks
  dsimp only
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      simp [PacketItemState.Completes, eligible]
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact declarationsCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact certificateCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact identityCompletion
  apply ChecksSupport.cons
  · exact ownershipCheck_supports ownershipCompletion
      ownershipPresentedCompletion indemnityCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact contextApplicability_sound
        .hasOtherEntitledSuccessors successorsCompletion
    · intro _
      exact signaturesCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact contextApplicability_sound
        .institutionRequiresNotary notaryCompletion
    · intro _
      exact notarizedCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact consentApplicability_sound authorityCompletion
    · intro _
      exact consentCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact datedListApplicability_sound dateCompletion
    · intro _
      exact datedCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact inventoryApplicability_sound estateCompletion wellFormed.1
    · intro _
      exact inventoryCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact presentedCompletion
  exact ChecksSupport.nil

private theorem smallRealChecks_support
    {partialContext : PartialProcedureContext}
    {totalContext : ProcedureContext}
    {partialCase : PartialTransferCase}
    {totalCase : TransferCase}
    {partialPacket : PartialSmallRealPropertyPacket}
    {totalPacket : SmallRealPropertyPacket}
    (eligible : SmallValueRealPropertyAffidavitEligible totalCase)
    (contextCompletion : partialContext.Completes totalContext)
    (caseCompletion : partialCase.Completes totalCase)
    (packetCompletion : partialPacket.Completes totalPacket) :
    ChecksSupport
      (smallRealPartialRequirementChecks partialContext partialCase
        partialPacket)
      (smallRealPropertyRequirementChecks totalContext totalCase
        totalPacket) := by
  rcases contextCompletion with
    ⟨claimsCompletion, ownershipCompletion, successorsCompletion,
      guardianCompletion, notaryCompletion, agreementCompletion⟩
  rcases caseCompletion with
    ⟨dateCompletion, estateCompletion, targetCompletion,
      authorityCompletion, daysCompletion, sixMonthsCompletion,
      successorCompletion, superiorCompletion, debtsCompletion,
      survivorCompletion, passesCompletion, belongsCompletion⟩
  rcases packetCompletion with
    ⟨statementsCompletion, notarizedCompletion, inventoryCompletion,
      certificateCompletion, willCompletion, consentCompletion,
      datedCompletion, guardianDeliveryCompletion, filingCompletion,
      certifiedCopyCompletion, recordingCompletion⟩
  unfold smallRealPartialRequirementChecks
    smallRealPropertyRequirementChecks
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      simp [PacketItemState.Completes, eligible]
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact statementsCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact notarizedCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact inventoryCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact certificateCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · simpa [needsSmallRealWillAttachment] using
        smallRealWillApplicability_sound claimsCompletion
          authorityCompletion
    · intro _
      exact willCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact consentApplicability_sound authorityCompletion
    · intro _
      exact consentCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact datedListApplicability_sound dateCompletion
    · intro _
      exact datedCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact contextApplicability_sound
        .knownGuardianOrConservator guardianCompletion
    · intro _
      exact guardianDeliveryCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact filingCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact certifiedCopyCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact recordingCompletion
  exact ChecksSupport.nil

private theorem primaryChecks_support
    {partialContext : PartialProcedureContext}
    {totalContext : ProcedureContext}
    {partialCase : PartialTransferCase}
    {totalCase : TransferCase}
    {partialPacket : PartialPrimaryResidencePetitionPacket}
    {totalPacket : PrimaryResidencePetitionPacket}
    (eligible : PrimaryResidencePetitionEligible totalCase)
    (contextCompletion : partialContext.Completes totalContext)
    (caseCompletion : partialCase.Completes totalCase)
    (packetCompletion : partialPacket.Completes totalPacket) :
    ChecksSupport
      (primaryPartialRequirementChecks partialContext partialCase
        partialPacket)
      (primaryResidenceRequirementChecks totalContext totalCase
        totalPacket) := by
  rcases contextCompletion with
    ⟨claimsCompletion, ownershipCompletion, successorsCompletion,
      guardianCompletion, notaryCompletion, agreementCompletion⟩
  rcases caseCompletion with
    ⟨dateCompletion, estateCompletion, targetCompletion,
      authorityCompletion, daysCompletion, sixMonthsCompletion,
      successorCompletion, superiorCompletion, debtsCompletion,
      survivorCompletion, passesCompletion, belongsCompletion⟩
  rcases packetCompletion with
    ⟨statementsCompletion, inventoryCompletion, willCompletion,
      consentCompletion, datedCompletion, filingCompletion,
      copyCompletion, noticeCompletion, findingsCompletion,
      orderCompletion⟩
  unfold primaryPartialRequirementChecks
    primaryResidenceRequirementChecks
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      simp [PacketItemState.Completes, eligible]
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact statementsCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact inventoryCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact contextApplicability_sound .claimsUnderWill claimsCompletion
    · intro _
      exact willCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact consentApplicability_sound authorityCompletion
    · intro _
      exact consentCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact datedListApplicability_sound dateCompletion
    · intro _
      exact datedCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact filingCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact copyCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact noticeCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact findingsCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact orderCompletion
  exact ChecksSupport.nil

private theorem spousalChecks_support
    {partialContext : PartialProcedureContext}
    {totalContext : ProcedureContext}
    {partialCase : PartialTransferCase}
    {totalCase : TransferCase}
    {partialPacket : PartialSpousalPetitionPacket}
    {totalPacket : SpousalPetitionPacket}
    (eligible : SpousalPropertyPetitionEligible totalCase)
    (contextCompletion : partialContext.Completes totalContext)
    (packetCompletion : partialPacket.Completes totalPacket) :
    ChecksSupport
      (spousalPartialRequirementChecks partialContext partialCase
        partialPacket)
      (spousalRequirementChecks totalContext totalCase totalPacket) := by
  rcases contextCompletion with
    ⟨claimsCompletion, ownershipCompletion, successorsCompletion,
      guardianCompletion, notaryCompletion, agreementCompletion⟩
  rcases packetCompletion with
    ⟨allegationsCompletion, descriptionsCompletion,
      interestedCompletion, disclosureCompletion, willCompletion,
      agreementAttachmentCompletion, noticeCompletion, orderCompletion⟩
  unfold spousalPartialRequirementChecks spousalRequirementChecks
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      simp [PacketItemState.Completes, eligible]
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact allegationsCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact descriptionsCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact interestedCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact disclosureCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact contextApplicability_sound .claimsUnderWill claimsCompletion
    · intro _
      exact willCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact contextApplicability_sound
        .propertyAgreementExists agreementCompletion
    · intro _
      exact agreementAttachmentCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact noticeCompletion
  apply ChecksSupport.cons
  · apply partialCheck_supports
    · exact unconditionalApplicability_sound
    · intro _
      exact orderCompletion
  exact ChecksSupport.nil

private theorem summary_totalChecks_unresolved
    (checks : List RequirementCheck) :
    (summarizePartialChecks
      (checks.map totalCheckToPartial)).unresolvedFacts = [] := by
  have flattened :
      (checks.map totalCheckToPartial).flatMap
          (·.unresolvedFacts) = [] := by
    induction checks with
    | nil => rfl
    | cons check rest ih =>
        simp only [List.map_cons, List.flatMap_cons,
          totalCheckToPartial_unresolved, List.nil_append, ih]
  simp [summarizePartialChecks, flattened, dedupStable]

private theorem mem_summary_totalChecks_missing_iff
    (checks : List RequirementCheck) (requirement : Requirement) :
    requirement ∈
        (summarizePartialChecks
          (checks.map totalCheckToPartial)).missingRequirements ↔
      requirement ∈ missingFromChecks checks := by
  rw [mem_summary_missing_iff, mem_missingFromChecks_iff]
  constructor
  · rintro ⟨partialCheck, partialMember, requirementEq,
      appliesEq, itemEq⟩
    obtain ⟨totalCheck, totalMember, totalEq⟩ :=
      List.mem_map.mp partialMember
    subst partialCheck
    refine ⟨totalCheck, totalMember, ?_, ?_, ?_⟩
    · simpa [totalCheckToPartial, partialCheck] using requirementEq
    · simpa [totalCheckToPartial, partialCheck] using appliesEq
    · cases suppliedEq : totalCheck.supplied with
      | false => rfl
      | true =>
          simp [totalCheckToPartial, partialCheck,
            PacketItemState.ofBool, suppliedEq] at itemEq
  · rintro ⟨totalCheck, totalMember, requirementEq,
      appliesEq, suppliedEq⟩
    refine ⟨totalCheckToPartial totalCheck,
      List.mem_map.mpr ⟨totalCheck, totalMember, rfl⟩, ?_, ?_, ?_⟩
    · simpa [totalCheckToPartial, partialCheck] using requirementEq
    · simp [totalCheckToPartial, partialCheck, appliesEq]
    · simp [totalCheckToPartial, partialCheck, suppliedEq,
        PacketItemState.ofBool]

private theorem summary_totalChecks_missing_empty_iff
    (checks : List RequirementCheck) :
    (summarizePartialChecks
        (checks.map totalCheckToPartial)).missingRequirements = [] ↔
      missingFromChecks checks = [] := by
  constructor
  · intro partialEmpty
    apply List.eq_nil_iff_forall_not_mem.mpr
    intro requirement requirementMember
    have partialMember :
        requirement ∈
          (summarizePartialChecks
            (checks.map totalCheckToPartial)).missingRequirements :=
      (mem_summary_totalChecks_missing_iff checks requirement).mpr
        requirementMember
    simp [partialEmpty] at partialMember
  · intro totalEmpty
    apply List.eq_nil_iff_forall_not_mem.mpr
    intro requirement requirementMember
    have totalMember : requirement ∈ missingFromChecks checks :=
      (mem_summary_totalChecks_missing_iff checks requirement).mp
        requirementMember
    simp [totalEmpty] at totalMember

private theorem personalPartialChecks_ofTotal
    (context : ProcedureContext) (case : TransferCase)
    (packet : PersonalAffidavitPacket)
    (eligible : PersonalPropertyAffidavitEligible case) :
    personalPartialRequirementChecks context.toPartial case.toPartial
        packet.toPartial =
      (personalRequirementChecks context case packet).map
        totalCheckToPartial := by
  cases ownership : context.ownershipEvidenceAvailable <;>
    simp [personalPartialRequirementChecks, personalRequirementChecks,
      ProcedureContext.toPartial, TransferCase.toPartial,
      PersonalAffidavitPacket.toPartial, totalCheckToPartial,
      partialCheck, ownershipCheckData, contextApplicability,
      datedListApplicability,
      inventoryApplicability_ofTotal, PacketItemState.ofBool,
      ownership, eligible]

private theorem smallRealPartialChecks_ofTotal
    (context : ProcedureContext) (case : TransferCase)
    (packet : SmallRealPropertyPacket)
    (eligible : SmallValueRealPropertyAffidavitEligible case) :
    smallRealPartialRequirementChecks context.toPartial case.toPartial
        packet.toPartial =
      (smallRealPropertyRequirementChecks context case packet).map
        totalCheckToPartial := by
  simp [smallRealPartialRequirementChecks,
    smallRealPropertyRequirementChecks,
    ProcedureContext.toPartial, TransferCase.toPartial,
    SmallRealPropertyPacket.toPartial, totalCheckToPartial,
    partialCheck, contextApplicability, datedListApplicability,
    needsSmallRealWillAttachment, PacketItemState.ofBool, eligible]

private theorem primaryPartialChecks_ofTotal
    (context : ProcedureContext) (case : TransferCase)
    (packet : PrimaryResidencePetitionPacket)
    (eligible : PrimaryResidencePetitionEligible case) :
    primaryPartialRequirementChecks context.toPartial case.toPartial
        packet.toPartial =
      (primaryResidenceRequirementChecks context case packet).map
        totalCheckToPartial := by
  simp [primaryPartialRequirementChecks,
    primaryResidenceRequirementChecks,
    ProcedureContext.toPartial, TransferCase.toPartial,
    PrimaryResidencePetitionPacket.toPartial, totalCheckToPartial,
    partialCheck, contextApplicability, datedListApplicability,
    PacketItemState.ofBool, eligible]

private theorem spousalPartialChecks_ofTotal
    (context : ProcedureContext) (case : TransferCase)
    (packet : SpousalPetitionPacket)
    (eligible : SpousalPropertyPetitionEligible case) :
    spousalPartialRequirementChecks context.toPartial case.toPartial
        packet.toPartial =
      (spousalRequirementChecks context case packet).map
        totalCheckToPartial := by
  simp [spousalPartialRequirementChecks, spousalRequirementChecks,
    ProcedureContext.toPartial,
    SpousalPetitionPacket.toPartial, totalCheckToPartial,
    partialCheck, contextApplicability, PacketItemState.ofBool, eligible]

theorem mem_personalPacket_unresolved_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialPersonalAffidavitPacket)
    (fact : ProcedureFact) :
    fact ∈
      (personalPacketChecks context case packet).unresolvedFacts ↔
    ∃ check ∈ personalPartialRequirementChecks context case packet,
      (check.applies = .unknown ∧
        fact ∈ check.applicabilityFacts) ∨
      (check.applies = .known true ∧
        check.item = .unknown ∧
        check.supplyFact = fact) := by
  exact mem_summary_unresolved_iff
    (personalPartialRequirementChecks context case packet) fact

theorem mem_personalPacket_missing_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialPersonalAffidavitPacket)
    (requirement : Requirement) :
    requirement ∈
      (personalPacketChecks context case packet).missingRequirements ↔
    ∃ check ∈ personalPartialRequirementChecks context case packet,
      check.requirement = requirement ∧
      check.applies = .known true ∧
      check.item = .absent := by
  exact mem_summary_missing_iff
    (personalPartialRequirementChecks context case packet) requirement

theorem mem_smallRealPacket_unresolved_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialSmallRealPropertyPacket)
    (fact : ProcedureFact) :
    fact ∈
      (smallRealPacketChecks context case packet).unresolvedFacts ↔
    ∃ check ∈ smallRealPartialRequirementChecks context case packet,
      (check.applies = .unknown ∧
        fact ∈ check.applicabilityFacts) ∨
      (check.applies = .known true ∧
        check.item = .unknown ∧
        check.supplyFact = fact) := by
  exact mem_summary_unresolved_iff
    (smallRealPartialRequirementChecks context case packet) fact

theorem mem_smallRealPacket_missing_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialSmallRealPropertyPacket)
    (requirement : Requirement) :
    requirement ∈
      (smallRealPacketChecks context case packet).missingRequirements ↔
    ∃ check ∈ smallRealPartialRequirementChecks context case packet,
      check.requirement = requirement ∧
      check.applies = .known true ∧
      check.item = .absent := by
  exact mem_summary_missing_iff
    (smallRealPartialRequirementChecks context case packet) requirement

theorem mem_primaryPacket_unresolved_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialPrimaryResidencePetitionPacket)
    (fact : ProcedureFact) :
    fact ∈
      (primaryPacketChecks context case packet).unresolvedFacts ↔
    ∃ check ∈ primaryPartialRequirementChecks context case packet,
      (check.applies = .unknown ∧
        fact ∈ check.applicabilityFacts) ∨
      (check.applies = .known true ∧
        check.item = .unknown ∧
        check.supplyFact = fact) := by
  exact mem_summary_unresolved_iff
    (primaryPartialRequirementChecks context case packet) fact

theorem mem_primaryPacket_missing_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialPrimaryResidencePetitionPacket)
    (requirement : Requirement) :
    requirement ∈
      (primaryPacketChecks context case packet).missingRequirements ↔
    ∃ check ∈ primaryPartialRequirementChecks context case packet,
      check.requirement = requirement ∧
      check.applies = .known true ∧
      check.item = .absent := by
  exact mem_summary_missing_iff
    (primaryPartialRequirementChecks context case packet) requirement

theorem mem_spousalPacket_unresolved_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialSpousalPetitionPacket)
    (fact : ProcedureFact) :
    fact ∈
      (spousalPacketChecks context case packet).unresolvedFacts ↔
    ∃ check ∈ spousalPartialRequirementChecks context case packet,
      (check.applies = .unknown ∧
        fact ∈ check.applicabilityFacts) ∨
      (check.applies = .known true ∧
        check.item = .unknown ∧
        check.supplyFact = fact) := by
  exact mem_summary_unresolved_iff
    (spousalPartialRequirementChecks context case packet) fact

theorem mem_spousalPacket_missing_iff
    (context : PartialProcedureContext)
    (case : PartialTransferCase)
    (packet : PartialSpousalPetitionPacket)
    (requirement : Requirement) :
    requirement ∈
      (spousalPacketChecks context case packet).missingRequirements ↔
    ∃ check ∈ spousalPartialRequirementChecks context case packet,
      check.requirement = requirement ∧
      check.applies = .known true ∧
      check.item = .absent := by
  exact mem_summary_missing_iff
    (spousalPartialRequirementChecks context case packet) requirement

theorem assessPacket_ofTotal_ready_iff
    (route : CourtRoute) (context : ProcedureContext)
    (case : TransferCase) (packet : TotalPacket route) :
    assessPacket route context.toPartial case.toPartial
        (TotalPacket.toPartial route packet) = .ok .ready ↔
      CourtReady route context case packet := by
  cases route with
  | personalPropertyAffidavit =>
      change PersonalAffidavitPacket at packet
      constructor
      · intro result
        obtain ⟨routeResult, unresolved, missing⟩ :=
          (assessPacket_ready_iff
            .personalPropertyAffidavit context.toPartial case.toPartial
            packet.toPartial).mp result
        have eligible : PersonalPropertyAffidavitEligible case :=
          (assessRoute_ofTotal_qualifies_iff case
            .personalPropertyAffidavit).mp routeResult
        change
          (summarizePartialChecks
            (personalPartialRequirementChecks context.toPartial
              case.toPartial packet.toPartial)).missingRequirements = []
          at missing
        rw [personalPartialChecks_ofTotal context case packet eligible]
          at missing
        exact (personalAffidavitMissing_empty_iff_ready
          context case packet).mp
            ((summary_totalChecks_missing_empty_iff
              (personalRequirementChecks context case packet)).mp missing)
      · intro ready
        have eligible : PersonalPropertyAffidavitEligible case := ready.1
        have routeResult :
            assessRoute case.toPartial .personalPropertyAffidavit =
              .ok .qualifies :=
          (assessRoute_ofTotal_qualifies_iff case
            .personalPropertyAffidavit).mpr eligible
        have totalMissing :
            personalAffidavitMissing context case packet = [] :=
          (personalAffidavitMissing_empty_iff_ready
            context case packet).mpr ready
        have partialMissing :=
          (summary_totalChecks_missing_empty_iff
            (personalRequirementChecks context case packet)).mpr
              totalMissing
        have unresolved :=
          summary_totalChecks_unresolved
            (personalRequirementChecks context case packet)
        rw [← personalPartialChecks_ofTotal context case packet eligible]
          at partialMissing unresolved
        exact (assessPacket_ready_iff
          .personalPropertyAffidavit context.toPartial case.toPartial
          packet.toPartial).mpr
            ⟨routeResult, unresolved, partialMissing⟩
  | smallValueRealPropertyAffidavit =>
      change SmallRealPropertyPacket at packet
      constructor
      · intro result
        obtain ⟨routeResult, unresolved, missing⟩ :=
          (assessPacket_ready_iff
            .smallValueRealPropertyAffidavit context.toPartial
            case.toPartial packet.toPartial).mp result
        have eligible : SmallValueRealPropertyAffidavitEligible case :=
          (assessRoute_ofTotal_qualifies_iff case
            .smallValueRealPropertyAffidavit).mp routeResult
        change
          (summarizePartialChecks
            (smallRealPartialRequirementChecks context.toPartial
              case.toPartial packet.toPartial)).missingRequirements = []
          at missing
        rw [smallRealPartialChecks_ofTotal context case packet eligible]
          at missing
        exact (smallRealPropertyAffidavitMissing_empty_iff_ready
          context case packet).mp
            ((summary_totalChecks_missing_empty_iff
              (smallRealPropertyRequirementChecks
                context case packet)).mp missing)
      · intro ready
        have eligible : SmallValueRealPropertyAffidavitEligible case :=
          ready.1
        have routeResult :
            assessRoute case.toPartial .smallValueRealPropertyAffidavit =
              .ok .qualifies :=
          (assessRoute_ofTotal_qualifies_iff case
            .smallValueRealPropertyAffidavit).mpr eligible
        have totalMissing :
            smallRealPropertyAffidavitMissing context case packet = [] :=
          (smallRealPropertyAffidavitMissing_empty_iff_ready
            context case packet).mpr ready
        have partialMissing :=
          (summary_totalChecks_missing_empty_iff
            (smallRealPropertyRequirementChecks
              context case packet)).mpr totalMissing
        have unresolved :=
          summary_totalChecks_unresolved
            (smallRealPropertyRequirementChecks context case packet)
        rw [← smallRealPartialChecks_ofTotal
          context case packet eligible] at partialMissing unresolved
        exact (assessPacket_ready_iff
          .smallValueRealPropertyAffidavit context.toPartial
          case.toPartial packet.toPartial).mpr
            ⟨routeResult, unresolved, partialMissing⟩
  | primaryResidencePetition =>
      change PrimaryResidencePetitionPacket at packet
      constructor
      · intro result
        obtain ⟨routeResult, unresolved, missing⟩ :=
          (assessPacket_ready_iff
            .primaryResidencePetition context.toPartial case.toPartial
            packet.toPartial).mp result
        have eligible : PrimaryResidencePetitionEligible case :=
          (assessRoute_ofTotal_qualifies_iff case
            .primaryResidencePetition).mp routeResult
        change
          (summarizePartialChecks
            (primaryPartialRequirementChecks context.toPartial
              case.toPartial packet.toPartial)).missingRequirements = []
          at missing
        rw [primaryPartialChecks_ofTotal context case packet eligible]
          at missing
        exact (primaryResidencePetitionMissing_empty_iff_ready
          context case packet).mp
            ((summary_totalChecks_missing_empty_iff
              (primaryResidenceRequirementChecks
                context case packet)).mp missing)
      · intro ready
        have eligible : PrimaryResidencePetitionEligible case := ready.1
        have routeResult :
            assessRoute case.toPartial .primaryResidencePetition =
              .ok .qualifies :=
          (assessRoute_ofTotal_qualifies_iff case
            .primaryResidencePetition).mpr eligible
        have totalMissing :
            primaryResidencePetitionMissing context case packet = [] :=
          (primaryResidencePetitionMissing_empty_iff_ready
            context case packet).mpr ready
        have partialMissing :=
          (summary_totalChecks_missing_empty_iff
            (primaryResidenceRequirementChecks
              context case packet)).mpr totalMissing
        have unresolved :=
          summary_totalChecks_unresolved
            (primaryResidenceRequirementChecks context case packet)
        rw [← primaryPartialChecks_ofTotal
          context case packet eligible] at partialMissing unresolved
        exact (assessPacket_ready_iff
          .primaryResidencePetition context.toPartial case.toPartial
          packet.toPartial).mpr
            ⟨routeResult, unresolved, partialMissing⟩
  | spousalPropertyPetition =>
      change SpousalPetitionPacket at packet
      constructor
      · intro result
        obtain ⟨routeResult, unresolved, missing⟩ :=
          (assessPacket_ready_iff
            .spousalPropertyPetition context.toPartial case.toPartial
            packet.toPartial).mp result
        have eligible : SpousalPropertyPetitionEligible case :=
          (assessRoute_ofTotal_qualifies_iff case
            .spousalPropertyPetition).mp routeResult
        change
          (summarizePartialChecks
            (spousalPartialRequirementChecks context.toPartial
              case.toPartial packet.toPartial)).missingRequirements = []
          at missing
        rw [spousalPartialChecks_ofTotal context case packet eligible]
          at missing
        exact (spousalPetitionMissing_empty_iff_ready
          context case packet).mp
            ((summary_totalChecks_missing_empty_iff
              (spousalRequirementChecks context case packet)).mp missing)
      · intro ready
        have eligible : SpousalPropertyPetitionEligible case := ready.1
        have routeResult :
            assessRoute case.toPartial .spousalPropertyPetition =
              .ok .qualifies :=
          (assessRoute_ofTotal_qualifies_iff case
            .spousalPropertyPetition).mpr eligible
        have totalMissing :
            spousalPetitionMissing context case packet = [] :=
          (spousalPetitionMissing_empty_iff_ready
            context case packet).mpr ready
        have partialMissing :=
          (summary_totalChecks_missing_empty_iff
            (spousalRequirementChecks context case packet)).mpr
              totalMissing
        have unresolved :=
          summary_totalChecks_unresolved
            (spousalRequirementChecks context case packet)
        rw [← spousalPartialChecks_ofTotal
          context case packet eligible] at partialMissing unresolved
        exact (assessPacket_ready_iff
          .spousalPropertyPetition context.toPartial case.toPartial
          packet.toPartial).mpr
            ⟨routeResult, unresolved, partialMissing⟩

theorem assessPacket_ready_all_completions
    {route : CourtRoute}
    {partialContext : PartialProcedureContext}
    {partialCase : PartialTransferCase}
    {partialPacket : PartialPacket route}
    (result :
      assessPacket route partialContext partialCase
        partialPacket = .ok .ready) :
    ∀ totalContext totalCase (totalPacket : TotalPacket route),
      partialContext.Completes totalContext →
      partialCase.Completes totalCase →
      PartialPacketCompletes route partialPacket totalPacket →
      TransferCase.WellFormed totalCase →
      CourtReady route totalContext totalCase totalPacket := by
  cases route with
  | personalPropertyAffidavit =>
      intro totalContext totalCase totalPacket contextCompletion
        caseCompletion packetCompletion wellFormed
      change PartialPersonalAffidavitPacket at partialPacket
      change PersonalAffidavitPacket at totalPacket
      obtain ⟨routeResult, unresolved, missing⟩ :=
        (assessPacket_ready_iff .personalPropertyAffidavit
          partialContext partialCase partialPacket).mp result
      have eligible : PersonalPropertyAffidavitEligible totalCase :=
        assessRoute_qualifies_all_completions routeResult totalCase
          caseCompletion wellFormed
      change
        (summarizePartialChecks
          (personalPartialRequirementChecks partialContext partialCase
            partialPacket)).unresolvedFacts = []
        at unresolved
      change
        (summarizePartialChecks
          (personalPartialRequirementChecks partialContext partialCase
            partialPacket)).missingRequirements = []
        at missing
      have totalMissing :
          personalAffidavitMissing totalContext totalCase totalPacket = [] :=
        totalMissing_empty_of_supported
          (personalPartialRequirementChecks partialContext partialCase
            partialPacket)
          (personalRequirementChecks totalContext totalCase totalPacket)
          unresolved missing
          (checksSupport_matching
            (personalChecks_support eligible contextCompletion
              caseCompletion packetCompletion wellFormed))
      exact (personalAffidavitMissing_empty_iff_ready
        totalContext totalCase totalPacket).mp totalMissing
  | smallValueRealPropertyAffidavit =>
      intro totalContext totalCase totalPacket contextCompletion
        caseCompletion packetCompletion wellFormed
      change PartialSmallRealPropertyPacket at partialPacket
      change SmallRealPropertyPacket at totalPacket
      obtain ⟨routeResult, unresolved, missing⟩ :=
        (assessPacket_ready_iff .smallValueRealPropertyAffidavit
          partialContext partialCase partialPacket).mp result
      have eligible : SmallValueRealPropertyAffidavitEligible totalCase :=
        assessRoute_qualifies_all_completions routeResult totalCase
          caseCompletion wellFormed
      change
        (summarizePartialChecks
          (smallRealPartialRequirementChecks partialContext partialCase
            partialPacket)).unresolvedFacts = []
        at unresolved
      change
        (summarizePartialChecks
          (smallRealPartialRequirementChecks partialContext partialCase
            partialPacket)).missingRequirements = []
        at missing
      have totalMissing :
          smallRealPropertyAffidavitMissing totalContext totalCase
            totalPacket = [] :=
        totalMissing_empty_of_supported
          (smallRealPartialRequirementChecks partialContext partialCase
            partialPacket)
          (smallRealPropertyRequirementChecks totalContext totalCase
            totalPacket)
          unresolved missing
          (checksSupport_matching
            (smallRealChecks_support eligible contextCompletion
              caseCompletion packetCompletion))
      exact (smallRealPropertyAffidavitMissing_empty_iff_ready
        totalContext totalCase totalPacket).mp totalMissing
  | primaryResidencePetition =>
      intro totalContext totalCase totalPacket contextCompletion
        caseCompletion packetCompletion wellFormed
      change PartialPrimaryResidencePetitionPacket at partialPacket
      change PrimaryResidencePetitionPacket at totalPacket
      obtain ⟨routeResult, unresolved, missing⟩ :=
        (assessPacket_ready_iff .primaryResidencePetition
          partialContext partialCase partialPacket).mp result
      have eligible : PrimaryResidencePetitionEligible totalCase :=
        assessRoute_qualifies_all_completions routeResult totalCase
          caseCompletion wellFormed
      change
        (summarizePartialChecks
          (primaryPartialRequirementChecks partialContext partialCase
            partialPacket)).unresolvedFacts = []
        at unresolved
      change
        (summarizePartialChecks
          (primaryPartialRequirementChecks partialContext partialCase
            partialPacket)).missingRequirements = []
        at missing
      have totalMissing :
          primaryResidencePetitionMissing totalContext totalCase
            totalPacket = [] :=
        totalMissing_empty_of_supported
          (primaryPartialRequirementChecks partialContext partialCase
            partialPacket)
          (primaryResidenceRequirementChecks totalContext totalCase
            totalPacket)
          unresolved missing
          (checksSupport_matching
            (primaryChecks_support eligible contextCompletion
              caseCompletion packetCompletion))
      exact (primaryResidencePetitionMissing_empty_iff_ready
        totalContext totalCase totalPacket).mp totalMissing
  | spousalPropertyPetition =>
      intro totalContext totalCase totalPacket contextCompletion
        caseCompletion packetCompletion wellFormed
      change PartialSpousalPetitionPacket at partialPacket
      change SpousalPetitionPacket at totalPacket
      obtain ⟨routeResult, unresolved, missing⟩ :=
        (assessPacket_ready_iff .spousalPropertyPetition
          partialContext partialCase partialPacket).mp result
      have eligible : SpousalPropertyPetitionEligible totalCase :=
        assessRoute_qualifies_all_completions routeResult totalCase
          caseCompletion wellFormed
      change
        (summarizePartialChecks
          (spousalPartialRequirementChecks partialContext partialCase
            partialPacket)).unresolvedFacts = []
        at unresolved
      change
        (summarizePartialChecks
          (spousalPartialRequirementChecks partialContext partialCase
            partialPacket)).missingRequirements = []
        at missing
      have totalMissing :
          spousalPetitionMissing totalContext totalCase totalPacket = [] :=
        totalMissing_empty_of_supported
          (spousalPartialRequirementChecks partialContext partialCase
            partialPacket)
          (spousalRequirementChecks totalContext totalCase totalPacket)
          unresolved missing
          (checksSupport_matching
            (spousalChecks_support eligible contextCompletion
              packetCompletion))
      exact (spousalPetitionMissing_empty_iff_ready
        totalContext totalCase totalPacket).mp totalMissing

end SimpleProbate
