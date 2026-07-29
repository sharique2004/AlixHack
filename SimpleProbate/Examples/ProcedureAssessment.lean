import SimpleProbate.ProcedureAssessment
import SimpleProbate.Examples.Fixtures

namespace SimpleProbate.Examples.ProcedureAssessment

open SimpleProbate
open SimpleProbate.Examples

def partialContext : PartialProcedureContext :=
  baseProcedureContext.toPartial

def partialPersonal :
    PartialPacket .personalPropertyAffidavit :=
  completePersonalPacket.toPartial

example :
    assessPacket .personalPropertyAffidavit partialContext
      base2026Case.toPartial
      { partialPersonal with certifiedDeathCertificate := .unknown } =
    .ok (.incomplete {
      unresolvedFacts := [
        .packetItem .certifiedDeathCertificate
      ]
      missingRequirements := []
    }) := by decide

example :
    assessPacket .personalPropertyAffidavit partialContext
      base2026Case.toPartial
      { partialPersonal with certifiedDeathCertificate := .absent } =
    .ok (.incomplete {
      unresolvedFacts := []
      missingRequirements := [.certifiedDeathCertificate]
    }) := by decide

example :
    assessPacket .personalPropertyAffidavit partialContext
      base2026Case.toPartial partialPersonal =
    .ok .ready := by decide

end SimpleProbate.Examples.ProcedureAssessment
