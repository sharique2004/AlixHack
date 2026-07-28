import SimpleProbate.Decision
import SimpleProbate.Estate

namespace SimpleProbate

inductive SummaryAuthority
  | noProceeding
  | writtenPersonalRepresentativeConsent
  | blockedByProceeding
deriving BEq, DecidableEq, Repr

inductive SurvivorStatus
  | none
  | spouse
  | registeredDomesticPartner
deriving BEq, DecidableEq, Repr

structure TransferCase where
  deathDate : CivilDate
  estate : Estate
  targetId : AssetId
  authority : SummaryAuthority
  daysSinceDeath : Nat
  sixMonthsElapsed : Bool
  claimantIsSuccessor : Bool
  noSuperiorRight : Bool
  funeralLastIllnessAndUnsecuredDebtsPaid : Bool
  survivorStatus : SurvivorStatus
  propertyPassesToSurvivor : Bool
  propertyBelongsToSurvivor : Bool
deriving DecidableEq, Repr

structure PartialTransferCase where
  deathDate : Knowledge CivilDate
  estate : PartialEstate
  targetId : Knowledge AssetId
  authority : Knowledge SummaryAuthority
  daysSinceDeath : Knowledge Nat
  sixMonthsElapsed : Knowledge Bool
  claimantIsSuccessor : Knowledge Bool
  noSuperiorRight : Knowledge Bool
  funeralLastIllnessAndUnsecuredDebtsPaid : Knowledge Bool
  survivorStatus : Knowledge SurvivorStatus
  propertyPassesToSurvivor : Knowledge Bool
  propertyBelongsToSurvivor : Knowledge Bool
deriving DecidableEq, Repr

def Estate.findAsset? (estate : Estate) (id : AssetId) : Option Asset :=
  estate.assets.find? (fun asset => asset.id == id)

def PartialEstate.findAsset?
    (estate : PartialEstate) (id : AssetId) : Option PartialAsset :=
  estate.assets.find? (fun asset => asset.id == id)

def TransferCase.targetAsset? (case : TransferCase) : Option Asset :=
  case.estate.findAsset? case.targetId

def PartialTransferCase.Completes
    (partialCase : PartialTransferCase) (total : TransferCase) : Prop :=
  partialCase.deathDate.Completes total.deathDate ∧
  partialCase.estate.Completes total.estate ∧
  partialCase.targetId.Completes total.targetId ∧
  partialCase.authority.Completes total.authority ∧
  partialCase.daysSinceDeath.Completes total.daysSinceDeath ∧
  partialCase.sixMonthsElapsed.Completes total.sixMonthsElapsed ∧
  partialCase.claimantIsSuccessor.Completes total.claimantIsSuccessor ∧
  partialCase.noSuperiorRight.Completes total.noSuperiorRight ∧
  partialCase.funeralLastIllnessAndUnsecuredDebtsPaid.Completes
    total.funeralLastIllnessAndUnsecuredDebtsPaid ∧
  partialCase.survivorStatus.Completes total.survivorStatus ∧
  partialCase.propertyPassesToSurvivor.Completes total.propertyPassesToSurvivor ∧
  partialCase.propertyBelongsToSurvivor.Completes total.propertyBelongsToSurvivor

instance (partialCase : PartialTransferCase) (total : TransferCase) :
    Decidable (partialCase.Completes total) := by
  unfold PartialTransferCase.Completes
  infer_instance

inductive StructuralIssue
  | duplicateAssetId (id : AssetId)
  | missingTargetAsset (id : AssetId)
  | primaryResidenceNotCaliforniaReal (id : AssetId)
  | petitionAssetNotCaliforniaReal (id : AssetId)
  | petitionAssetNotPrimaryResidence (id : AssetId)
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive CaseError
  | invalidDate
  | afterSnapshot
  | malformedCase (issues : List StructuralIssue)
deriving DecidableEq, Repr

private def duplicateAssetIds
    (assets : List PartialAsset) : List AssetId :=
  let rec go (seen duplicates : List AssetId) : List PartialAsset → List AssetId
    | [] => duplicates
    | asset :: rest =>
        if seen.contains asset.id then
          if duplicates.contains asset.id then
            go seen duplicates rest
          else
            go seen (duplicates ++ [asset.id]) rest
        else
          go (seen ++ [asset.id]) duplicates rest
  go [] [] assets

private def assetStructuralIssues (asset : PartialAsset) : List StructuralIssue :=
  let primaryIssue :=
    match asset.isPrimaryResidence, asset.kind with
    | .known true, .known .californiaReal => []
    | .known true, .known _ => [.primaryResidenceNotCaliforniaReal asset.id]
    | _, _ => []
  let petitionKindIssue :=
    match asset.includedInPrimaryResidencePetition, asset.kind with
    | .known true, .known .californiaReal => []
    | .known true, .known _ => [.petitionAssetNotCaliforniaReal asset.id]
    | _, _ => []
  let petitionResidenceIssue :=
    match asset.includedInPrimaryResidencePetition, asset.isPrimaryResidence with
    | .known true, .known false => [.petitionAssetNotPrimaryResidence asset.id]
    | _, _ => []
  primaryIssue ++ petitionKindIssue ++ petitionResidenceIssue

private def dateError? (date : Knowledge CivilDate) : Option CaseError :=
  match date with
  | .unknown => none
  | .known date =>
      match classifyDeathDate date with
      | .ok _ => none
      | .error .invalidDate => some .invalidDate
      | .error .afterSnapshot => some .afterSnapshot

def TransferCase.WellFormed (case : TransferCase) : Prop :=
  (case.estate.assets.map (·.id)).Nodup ∧
  (∃ target ∈ case.estate.assets, target.id = case.targetId) ∧
  ∀ asset ∈ case.estate.assets,
    (asset.isPrimaryResidence = true →
      asset.kind = .californiaReal) ∧
    (asset.includedInPrimaryResidencePetition = true →
      asset.kind = .californiaReal ∧
      asset.isPrimaryResidence = true)

instance (case : TransferCase) : Decidable case.WellFormed := by
  unfold TransferCase.WellFormed
  infer_instance

private def Knowledge.value? : Knowledge α → Option α
  | .unknown => none
  | .known value => some value

private def PartialAsset.toTotal? (asset : PartialAsset) : Option Asset := do
  let kind ← asset.kind.value?
  let currentGrossValue ← asset.currentGrossValue.value?
  let dateOfDeathValue ← asset.dateOfDeathValue.value?
  let encumbrances ← asset.encumbrances.value?
  let treatment ← asset.treatment.value?
  let includedInPrimaryResidencePetition ←
    asset.includedInPrimaryResidencePetition.value?
  let isPrimaryResidence ← asset.isPrimaryResidence.value?
  pure {
    id := asset.id
    name := asset.name
    kind
    currentGrossValue
    dateOfDeathValue
    encumbrances
    treatment
    includedInPrimaryResidencePetition
    isPrimaryResidence
  }

private def partialAssetsToTotal? : List PartialAsset → Option (List Asset)
  | [] => some []
  | asset :: rest => do
      let totalAsset ← asset.toTotal?
      let totalRest ← partialAssetsToTotal? rest
      pure (totalAsset :: totalRest)

private def PartialEstate.toTotal? (estate : PartialEstate) : Option Estate := do
  let inventoryComplete ← estate.inventoryComplete.value?
  if inventoryComplete then
    let assets ← partialAssetsToTotal? estate.assets
    pure { assets }
  else
    none

private def PartialTransferCase.toTotal?
    (case : PartialTransferCase) : Option TransferCase := do
  let deathDate ← case.deathDate.value?
  let estate ← case.estate.toTotal?
  let targetId ← case.targetId.value?
  let authority ← case.authority.value?
  let daysSinceDeath ← case.daysSinceDeath.value?
  let sixMonthsElapsed ← case.sixMonthsElapsed.value?
  let claimantIsSuccessor ← case.claimantIsSuccessor.value?
  let noSuperiorRight ← case.noSuperiorRight.value?
  let funeralLastIllnessAndUnsecuredDebtsPaid ←
    case.funeralLastIllnessAndUnsecuredDebtsPaid.value?
  let survivorStatus ← case.survivorStatus.value?
  let propertyPassesToSurvivor ← case.propertyPassesToSurvivor.value?
  let propertyBelongsToSurvivor ← case.propertyBelongsToSurvivor.value?
  pure {
    deathDate
    estate
    targetId
    authority
    daysSinceDeath
    sixMonthsElapsed
    claimantIsSuccessor
    noSuperiorRight
    funeralLastIllnessAndUnsecuredDebtsPaid
    survivorStatus
    propertyPassesToSurvivor
    propertyBelongsToSurvivor
  }

def validatePartialCase (partialCase : PartialTransferCase) : Except CaseError Unit :=
  match dateError? partialCase.deathDate with
  | some error => .error error
  | none =>
      let duplicateIssues :=
        (duplicateAssetIds partialCase.estate.assets).map StructuralIssue.duplicateAssetId
      let targetIssues :=
        match partialCase.estate.inventoryComplete, partialCase.targetId with
        | .known true, .known id =>
            if partialCase.estate.findAsset? id = none then
              [.missingTargetAsset id]
            else
              []
        | _, _ => []
      let assetIssues := partialCase.estate.assets.flatMap assetStructuralIssues
      let issues := duplicateIssues ++ targetIssues ++ assetIssues
      match partialCase.toTotal? with
      | some total =>
          if total.WellFormed then .ok ()
          else .error (.malformedCase issues)
      | none =>
          if issues = [] then .ok () else .error (.malformedCase issues)

def TransferCase.toPartial (case : TransferCase) : PartialTransferCase := {
  deathDate := .known case.deathDate
  estate := PartialEstate.ofTotal case.estate
  targetId := .known case.targetId
  authority := .known case.authority
  daysSinceDeath := .known case.daysSinceDeath
  sixMonthsElapsed := .known case.sixMonthsElapsed
  claimantIsSuccessor := .known case.claimantIsSuccessor
  noSuperiorRight := .known case.noSuperiorRight
  funeralLastIllnessAndUnsecuredDebtsPaid :=
    .known case.funeralLastIllnessAndUnsecuredDebtsPaid
  survivorStatus := .known case.survivorStatus
  propertyPassesToSurvivor := .known case.propertyPassesToSurvivor
  propertyBelongsToSurvivor := .known case.propertyBelongsToSurvivor
}

@[simp] private theorem partialAsset_toTotal_ofTotal
    (asset : Asset) :
    (PartialAsset.ofTotal asset).toTotal? = some asset := by
  cases asset
  rfl

@[simp] private theorem partialAssetsToTotal_ofTotal
    (assets : List Asset) :
    partialAssetsToTotal? (assets.map PartialAsset.ofTotal) = some assets := by
  induction assets with
  | nil => rfl
  | cons head tail =>
      simp [partialAssetsToTotal?, *]

@[simp] private theorem partialEstate_toTotal_ofTotal
    (estate : Estate) :
    (PartialEstate.ofTotal estate).toTotal? = some estate := by
  cases estate
  simp [PartialEstate.ofTotal, PartialEstate.toTotal?,
    Knowledge.value?]

@[simp] private theorem partialCase_toTotal_ofTotal
    (case : TransferCase) :
    case.toPartial.toTotal? = some case := by
  cases case
  simp [TransferCase.toPartial, PartialTransferCase.toTotal?,
    Knowledge.value?]

theorem validatePartialCase_toPartial_ok_iff
    (case : TransferCase) :
    validatePartialCase case.toPartial = .ok () ↔
      (∃ band, classifyDeathDate case.deathDate = .ok band) ∧
      case.WellFormed := by
  unfold validatePartialCase
  rw [partialCase_toTotal_ofTotal]
  cases dateResult : classifyDeathDate case.deathDate with
  | error error =>
      cases error <;>
        simp [TransferCase.toPartial, dateError?, dateResult]
  | ok band =>
      simp [TransferCase.toPartial, dateError?, dateResult]

theorem toPartial_completes (case : TransferCase) :
    case.toPartial.Completes case := by
  simp [TransferCase.toPartial, PartialTransferCase.Completes,
    PartialEstate.ofTotal, PartialEstate.Completes,
    PartialEstate.listedAssetsComplete, PartialEstate.sameAssetIds,
    PartialAsset.ofTotal, PartialAsset.Completes, Knowledge.Completes]
  intro asset assetMember
  exact ⟨asset, assetMember, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

end SimpleProbate
