import SimpleProbate.Api

namespace SimpleProbate.Examples.Api

open Lean (Json)
open SimpleProbate
open SimpleProbate.Api

private def parse! (input : String) : Json :=
  match Json.parse input with
  | .ok json => json
  | .error _ => Json.null

private def decode! (input : String) : PartialTransferCase :=
  match decodeCase (parse! input) with
  | .ok transferCase => transferCase
  | .error _ => {
      deathDate := .unknown
      estate := { assets := [], inventoryComplete := .unknown }
      targetId := .unknown
      authority := .unknown
      daysSinceDeath := .unknown
      sixMonthsElapsed := .unknown
      claimantIsSuccessor := .unknown
      noSuperiorRight := .unknown
      funeralLastIllnessAndUnsecuredDebtsPaid := .unknown
      survivorStatus := .unknown
      propertyPassesToSurvivor := .unknown
      propertyBelongsToSurvivor := .unknown
    }

def legacyCase : PartialTransferCase := decode!
  "{\"estate\":{\"assets\":[{\"name\":\"account\",\"gross_value_cents\":12345},{\"name\":\"house\",\"gross_value_cents\":999}]},\"target_index\":1}"

example :
    legacyCase.estate.assets.map
      (fun asset => (asset.id, asset.currentGrossValue, asset.dateOfDeathValue)) =
      [
        (⟨0⟩, .known 12345, .known 12345),
        (⟨1⟩, .known 999, .known 999)
      ] := by native_decide

example : legacyCase.targetId = .known ⟨1⟩ := by native_decide

def explicitValuesCase : PartialTransferCase := decode!
  "{\"estate\":{\"inventory_complete\":null,\"assets\":[{\"name\":\"house\",\"gross_value_cents\":100,\"current_gross_value_cents\":200,\"date_of_death_value_cents\":300,\"encumbrances_cents\":null}]},\"target_index\":0}"

example :
    explicitValuesCase.estate.assets.map
      (fun asset =>
        (asset.currentGrossValue, asset.dateOfDeathValue, asset.encumbrances)) =
      [(.known 200, .known 300, .unknown)] := by native_decide

example :
    explicitValuesCase.estate.inventoryComplete = .unknown := by native_decide

def independentFallbackCase : PartialTransferCase := decode!
  "{\"estate\":{\"assets\":[{\"name\":\"house\",\"gross_value_cents\":100,\"current_gross_value_cents\":200}]},\"target_index\":0}"

example :
    independentFallbackCase.estate.assets.map
      (fun asset => (asset.currentGrossValue, asset.dateOfDeathValue)) =
      [(.known 200, .known 100)] := by native_decide

def unknownValuesCase : PartialTransferCase := decode!
  "{\"estate\":{\"assets\":[{\"name\":\"unknown\",\"current_gross_value_cents\":null}]},\"target_index\":0}"

example :
    unknownValuesCase.estate.assets.map
      (fun asset =>
        (asset.kind, asset.currentGrossValue, asset.dateOfDeathValue)) =
      [(.unknown, .unknown, .unknown)] := by native_decide

example :
    unknownValuesCase.estate.assets.map
      (fun asset => (asset.treatment, asset.isPrimaryResidence)) =
      [(.unknown, .unknown)] := by native_decide

example :
    decodeCase (parse! "{\"estate\":{\"assets\":[]},\"target_index\":0}") =
      .error "target_index 0 is out of range for estate.assets (length 0)" := by
  native_decide

example :
    factPath (.assetField ⟨3⟩ .currentGrossValue) =
      "estate.assets[3].current_gross_value_cents" := by decide

example :
    factPath (.assetField ⟨3⟩ .dateOfDeathValue) =
      "estate.assets[3].date_of_death_value_cents" := by decide

private def directReports
    (statuses :
      List (DecisionStatus EligibilityFact EligibilityFailure)) :
    List RouteReport :=
  (directTransferBases.zip statuses).map fun (basis, status) =>
    { route := .directTransfer basis, status := status }

private def disqualifiedDirect : List RouteReport :=
  directReports (directTransferBases.map fun basis =>
    .doesNotQualify [.directTransferBasisAbsent basis])

private def courtReports
    (status : DecisionStatus EligibilityFact EligibilityFailure) :
    List RouteReport := [
  { route := .personalPropertyAffidavit, status := status },
  { route := .smallValueRealPropertyAffidavit, status := status },
  { route := .primaryResidencePetition, status := status },
  { route := .spousalPropertyPetition, status := status }
]

def directQualifyingProjection : WireRouteReport :=
  directReport <| directReports [
    .doesNotQualify [.directTransferBasisAbsent .governmentBenefit],
    .qualifies,
    .doesNotQualify [.directTransferBasisAbsent .revocableTrust],
    .qualifies,
    .doesNotQualify [.directTransferBasisAbsent .transferOnDeath],
    .doesNotQualify [.directTransferBasisAbsent .multiplePartyAccount],
    .doesNotQualify [.directTransferBasisAbsent .spousePassage]
  ]

example :
    directQualifyingProjection = {
      route := .directTransfer
      status := .qualifies
      detail := "named_beneficiary, joint_tenancy"
      forms := []
    } := by decide

def directUnresolvedProjection : WireRouteReport :=
  directReport <| directReports [
    .doesNotQualify [.directTransferBasisAbsent .governmentBenefit],
    .needsInformation [
      .assetField ⟨0⟩ .treatment,
      .assetField ⟨0⟩ .currentGrossValue
    ],
    .needsInformation [
      .assetField ⟨0⟩ .treatment,
      .assetField ⟨0⟩ .dateOfDeathValue
    ],
    .doesNotQualify [.directTransferBasisAbsent .jointTenancy],
    .doesNotQualify [.directTransferBasisAbsent .transferOnDeath],
    .doesNotQualify [.directTransferBasisAbsent .multiplePartyAccount],
    .doesNotQualify [.directTransferBasisAbsent .spousePassage]
  ]

example :
    directUnresolvedProjection.status = .needsInformation [
      "estate.assets[0].treatment",
      "estate.assets[0].current_gross_value_cents",
      "estate.assets[0].date_of_death_value_cents"
    ] := by decide

example :
    (directReport disqualifiedDirect).status =
      .doesNotQualify [{
        id := "no_direct_transfer_basis"
        text := "The target asset has no qualifying direct-transfer basis"
      }] := by decide

private def baseAssessment (overall : OverallOutcome) : CaseAssessment := {
  routes := disqualifiedDirect ++ courtReports
    (.doesNotQualify [.claimantNotSuccessor])
  overall := overall
}

example :
    (fallbackReport (baseAssessment .formalProbateOrOtherProcedure)).status =
      .qualifies := by decide

example :
    (fallbackReport {
      routes := disqualifiedDirect ++ courtReports
        (.needsInformation [.claimantIsSuccessor, .claimantIsSuccessor])
      overall := .unresolved
    }).status =
      .needsInformation ["claimant_is_successor"] := by decide

example :
    (fallbackReport (baseAssessment .simplifiedRoutesAvailable)).status =
      .doesNotQualify [{
        id := "simplified_route_available"
        text := "At least one simplified transfer route qualifies"
      }] := by decide

example :
    structuralIssueDetail (.duplicateAssetId ⟨4⟩) =
      "duplicate asset id 4" := by decide

example :
    structuralIssueDetail (.petitionAssetNotPrimaryResidence ⟨2⟩) =
      "asset 2 is included in a primary-residence petition but is not marked as the primary residence" := by
  decide

example :
    (resultJson (.error (.malformedCase [
      .duplicateAssetId ⟨4⟩,
      .petitionAssetNotPrimaryResidence ⟨2⟩
    ]))).compress =
      (errorResultJson "malformed_case"
        "duplicate asset id 4; asset 2 is included in a primary-residence petition but is not marked as the primary residence").compress := by
  native_decide

example :
    (projectAssessment (baseAssessment .formalProbateOrOtherProcedure)).map
      (fun report => report.route) = [
        .directTransfer,
        .personalPropertyAffidavit,
        .smallValueRealPropertyAffidavit,
        .primaryResidencePetition,
        .spousalPropertyPetition,
        .formalProbateOrOtherProcedure
      ] := by decide

private def getField? (json : Json) (key : String) : Option Json :=
  match json.getObjVal? key with
  | .ok value => some value
  | .error _ => none

example :
    (getField? (run
      "{\"death_date\":{\"year\":2026,\"month\":1,\"day\":1},\"estate\":{\"inventory_complete\":true,\"assets\":[{\"name\":\"account\",\"kind\":\"personal\",\"gross_value_cents\":100000,\"encumbrances_cents\":0,\"treatment\":\"counted\",\"included_in_primary_residence_petition\":false,\"is_primary_residence\":false}]},\"target_index\":0,\"authority\":\"no_proceeding\",\"days_since_death\":40,\"six_months_elapsed\":false,\"claimant_is_successor\":true,\"no_superior_right\":true,\"funeral_last_illness_and_unsecured_debts_paid\":true,\"survivor_status\":\"none\",\"property_passes_to_survivor\":false,\"property_belongs_to_survivor\":false}")
      "routes").bind (fun routes =>
        match routes with
        | .arr values => some values.size
        | _ => none) = some 6 := by
  native_decide

end SimpleProbate.Examples.Api
