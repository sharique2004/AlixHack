import SimpleProbate.Examples.Fixtures

namespace SimpleProbate.Examples.ProcedureExactness

open SimpleProbate
open SimpleProbate.Examples

def claimsUnderWillWithConsent : ProcedureContext := {
  baseProcedureContext with
  claimsUnderWill := true
}

def consentSmallRealCase : TransferCase := {
  smallReal2026Case with
  authority := .writtenPersonalRepresentativeConsent
}

def noWillSmallRealPacket : SmallRealPropertyPacket := {
  completeSmallRealPacket with
  willAttached := false
}

example :
    SmallRealPropertyAffidavitReady
      claimsUnderWillWithConsent consentSmallRealCase
      noWillSmallRealPacket := by decide

example :
    smallRealPropertyAffidavitMissing
      claimsUnderWillWithConsent consentSmallRealCase
      noWillSmallRealPacket = [] := by decide

example :
    ¬SmallRealPropertyAffidavitReady
      claimsUnderWillWithConsent smallReal2026Case
      noWillSmallRealPacket := by decide

example :
    .willAttachment ∈
      smallRealPropertyAffidavitMissing
        claimsUnderWillWithConsent smallReal2026Case
        noWillSmallRealPacket := by decide

example :
    personalAffidavitMissing baseProcedureContext base2026Case
        completePersonalPacket = [] ↔
      PersonalAffidavitReady baseProcedureContext base2026Case
        completePersonalPacket :=
  personalAffidavitMissing_empty_iff_ready
    baseProcedureContext base2026Case completePersonalPacket

example :
    smallRealPropertyAffidavitMissing baseProcedureContext
        smallReal2026Case completeSmallRealPacket = [] ↔
      SmallRealPropertyAffidavitReady baseProcedureContext
        smallReal2026Case completeSmallRealPacket :=
  smallRealPropertyAffidavitMissing_empty_iff_ready
    baseProcedureContext smallReal2026Case completeSmallRealPacket

example :
    primaryResidencePetitionMissing baseProcedureContext
        primaryResidence2026Case completePrimaryResidencePacket = [] ↔
      PrimaryResidencePetitionReady baseProcedureContext
        primaryResidence2026Case completePrimaryResidencePacket :=
  primaryResidencePetitionMissing_empty_iff_ready
    baseProcedureContext primaryResidence2026Case
      completePrimaryResidencePacket

example :
    spousalPetitionMissing baseProcedureContext spouse2026Case
        completeSpousalPacket = [] ↔
      SpousalPetitionReady baseProcedureContext spouse2026Case
        completeSpousalPacket :=
  spousalPetitionMissing_empty_iff_ready
    baseProcedureContext spouse2026Case completeSpousalPacket
