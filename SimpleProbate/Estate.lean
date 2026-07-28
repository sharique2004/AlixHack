import SimpleProbate.Decision
import SimpleProbate.Thresholds

namespace SimpleProbate

inductive PropertyKind
  | personal
  | californiaReal
  | outsideCaliforniaReal
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive ValuationTreatment
  | counted
  | jointTenancy
  | terminableAtDeath
  | revocableTrust
  | spousePassage
  | multiplePartySurvivor
  | registeredVehicle
  | vessel
  | registeredHome
  | directBeneficiary
  | transferOnDeath
  | governmentBenefit
  | militaryCompensation
  | employmentCompensation
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive DirectTransferBasis
  | governmentBenefit
  | namedBeneficiary
  | revocableTrust
  | jointTenancy
  | transferOnDeath
  | multiplePartyAccount
  | spousePassage
deriving BEq, DecidableEq, Repr

structure AssetId where
  value : Nat
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

inductive AssetField
  | kind
  | currentGrossValue
  | dateOfDeathValue
  | treatment
  | primaryResidence
  | primaryPetitionInclusion
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure Asset where
  id : AssetId
  name : String
  kind : PropertyKind
  currentGrossValue : Money
  dateOfDeathValue : Money
  encumbrances : Money := 0
  treatment : ValuationTreatment := .counted
  includedInPrimaryResidencePetition : Bool := false
  isPrimaryResidence : Bool := false
deriving DecidableEq, Repr

structure PartialAsset where
  id : AssetId
  name : String
  kind : Knowledge PropertyKind
  currentGrossValue : Knowledge Money
  dateOfDeathValue : Knowledge Money
  encumbrances : Knowledge Money
  treatment : Knowledge ValuationTreatment
  includedInPrimaryResidencePetition : Knowledge Bool
  isPrimaryResidence : Knowledge Bool
deriving DecidableEq, Repr

structure Estate where
  assets : List Asset
deriving DecidableEq, Repr

structure PartialEstate where
  assets : List PartialAsset
  inventoryComplete : Knowledge Bool
deriving DecidableEq, Repr

def PartialAsset.Completes
    (partialAsset : PartialAsset) (total : Asset) : Prop :=
  partialAsset.id = total.id ∧
  partialAsset.name = total.name ∧
  partialAsset.kind.Completes total.kind ∧
  partialAsset.currentGrossValue.Completes total.currentGrossValue ∧
  partialAsset.dateOfDeathValue.Completes total.dateOfDeathValue ∧
  partialAsset.encumbrances.Completes total.encumbrances ∧
  partialAsset.treatment.Completes total.treatment ∧
  partialAsset.includedInPrimaryResidencePetition.Completes
    total.includedInPrimaryResidencePetition ∧
  partialAsset.isPrimaryResidence.Completes total.isPrimaryResidence

def PartialEstate.listedAssetsComplete
    (partialEstate : PartialEstate) (total : Estate) : Prop :=
  ∀ partialAsset ∈ partialEstate.assets,
    ∃ totalAsset ∈ total.assets, partialAsset.Completes totalAsset

def PartialEstate.sameAssetIds
    (partialEstate : PartialEstate) (total : Estate) : Prop :=
  ∀ id,
    id ∈ partialEstate.assets.map (·.id) ↔
      id ∈ total.assets.map (·.id)

def PartialEstate.hasAdditionalAsset
    (partialEstate : PartialEstate) (total : Estate) : Prop :=
  ∃ asset ∈ total.assets, asset.id ∉ partialEstate.assets.map (·.id)

def PartialEstate.Completes
    (partialEstate : PartialEstate) (total : Estate) : Prop :=
  partialEstate.listedAssetsComplete total ∧
  match partialEstate.inventoryComplete with
  | .known true => partialEstate.sameAssetIds total
  | .known false => partialEstate.hasAdditionalAsset total
  | .unknown => True

instance (partialAsset : PartialAsset) (total : Asset) :
    Decidable (partialAsset.Completes total) := by
  unfold PartialAsset.Completes
  infer_instance

private def listedAssetsCompleteB
    (partialEstate : PartialEstate) (total : Estate) : Bool :=
  partialEstate.assets.all fun partialAsset =>
    total.assets.any fun totalAsset => decide (partialAsset.Completes totalAsset)

private def sameAssetIdsB
    (partialEstate : PartialEstate) (total : Estate) : Bool :=
  let partialIds := partialEstate.assets.map (·.id)
  let totalIds := total.assets.map (·.id)
  partialIds.all totalIds.contains && totalIds.all partialIds.contains

private def hasAdditionalAssetB
    (partialEstate : PartialEstate) (total : Estate) : Bool :=
  total.assets.any fun asset => !(partialEstate.assets.map (·.id)).contains asset.id

private theorem listedAssetsComplete_iff
    (partialEstate : PartialEstate) (total : Estate) :
    partialEstate.listedAssetsComplete total ↔
      listedAssetsCompleteB partialEstate total = true := by
  induction partialEstate.assets with
  | nil => simp [PartialEstate.listedAssetsComplete, listedAssetsCompleteB]
  | cons head tail ih =>
      simp [PartialEstate.listedAssetsComplete, listedAssetsCompleteB]

private theorem sameAssetIds_iff
    (partialEstate : PartialEstate) (total : Estate) :
    partialEstate.sameAssetIds total ↔ sameAssetIdsB partialEstate total = true := by
  simp only [PartialEstate.sameAssetIds, sameAssetIdsB, List.mem_map,
    List.all_eq_true, Bool.and_eq_true]
  constructor
  · intro sameIds
    constructor
    · intro id partialMember
      simpa using (sameIds id).mp (by simpa using partialMember)
    · intro id totalMember
      simpa using (sameIds id).mpr (by simpa using totalMember)
  · rintro ⟨partialToTotal, totalToPartial⟩ id
    constructor
    · intro partialMember
      exact (by simpa using partialToTotal id partialMember)
    · intro totalMember
      exact (by simpa using totalToPartial id totalMember)

private theorem hasAdditionalAsset_iff
    (partialEstate : PartialEstate) (total : Estate) :
    partialEstate.hasAdditionalAsset total ↔
      hasAdditionalAssetB partialEstate total = true := by
  simp [PartialEstate.hasAdditionalAsset, hasAdditionalAssetB]

instance (partialEstate : PartialEstate) (total : Estate) :
    Decidable (partialEstate.Completes total) :=
  match partialEstate with
  | { assets := assets, inventoryComplete := .unknown } =>
      decidable_of_iff
        (listedAssetsCompleteB { assets := assets, inventoryComplete := .unknown }
          total = true) (by
        simp [PartialEstate.Completes, listedAssetsComplete_iff])
  | { assets := assets, inventoryComplete := .known false } =>
      decidable_of_iff
        (listedAssetsCompleteB { assets := assets, inventoryComplete := .known false }
          total = true ∧
          hasAdditionalAssetB { assets := assets, inventoryComplete := .known false }
            total = true) (by
          simp [PartialEstate.Completes, listedAssetsComplete_iff,
            hasAdditionalAsset_iff])
  | { assets := assets, inventoryComplete := .known true } =>
      decidable_of_iff
        (listedAssetsCompleteB { assets := assets, inventoryComplete := .known true }
          total = true ∧
          sameAssetIdsB { assets := assets, inventoryComplete := .known true }
            total = true) (by
          simp [PartialEstate.Completes, listedAssetsComplete_iff,
            sameAssetIds_iff])

def PartialAsset.ofTotal (asset : Asset) : PartialAsset := {
  id := asset.id
  name := asset.name
  kind := .known asset.kind
  currentGrossValue := .known asset.currentGrossValue
  dateOfDeathValue := .known asset.dateOfDeathValue
  encumbrances := .known asset.encumbrances
  treatment := .known asset.treatment
  includedInPrimaryResidencePetition :=
    .known asset.includedInPrimaryResidencePetition
  isPrimaryResidence := .known asset.isPrimaryResidence
}

def PartialEstate.ofTotal (estate : Estate) : PartialEstate := {
  assets := estate.assets.map PartialAsset.ofTotal
  inventoryComplete := .known true
}

def Asset.directTransferBasis (asset : Asset) : Option DirectTransferBasis :=
  match asset.treatment with
  | .governmentBenefit => some .governmentBenefit
  | .directBeneficiary => some .namedBeneficiary
  | .revocableTrust => some .revocableTrust
  | .jointTenancy => some .jointTenancy
  | .transferOnDeath => some .transferOnDeath
  | .multiplePartySurvivor => some .multiplePartyAccount
  | .spousePassage => some .spousePassage
  | _ => none

def Asset.personalOrdinaryValue (asset : Asset) : Money :=
  if asset.kind == .outsideCaliforniaReal ||
      asset.includedInPrimaryResidencePetition then
    0
  else
    match asset.treatment with
    | .counted => asset.currentGrossValue
    | _ => 0

def Asset.qualifyingEmploymentCompensation (asset : Asset) : Money :=
  if asset.kind == .outsideCaliforniaReal ||
      asset.includedInPrimaryResidencePetition then
    0
  else if asset.treatment == .employmentCompensation then
    asset.currentGrossValue
  else
    0

def Estate.aggregateEmploymentCompensation (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset =>
      total + asset.qualifyingEmploymentCompensation) 0

def Estate.personalAffidavitValueWith
    (estate : Estate) (thresholds : Thresholds) : Money :=
  let ordinary := estate.assets.foldl
    (fun total asset => total + asset.personalOrdinaryValue) 0
  let employment := estate.aggregateEmploymentCompensation
  ordinary +
    (employment -
      min employment thresholds.employmentCompensationExclusion)

def Estate.personalAffidavitValue
    (estate : Estate) (date : CivilDate) : Except DateError Money := do
  let thresholds ← thresholdsFor date
  pure <| estate.personalAffidavitValueWith thresholds

def Asset.countedCaliforniaRealValue (asset : Asset) : Money :=
  if asset.kind == .californiaReal && asset.treatment == .counted then
    asset.dateOfDeathValue
  else
    0

def Estate.smallValueRealPropertyValue (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset => total + asset.countedCaliforniaRealValue) 0

def Asset.countedPrimaryResidenceValue (asset : Asset) : Money :=
  if asset.kind == .californiaReal &&
      asset.treatment == .counted &&
      asset.isPrimaryResidence then
    asset.dateOfDeathValue
  else
    0

def Estate.primaryResidenceValue (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset => total + asset.countedPrimaryResidenceValue) 0

def Estate.containsCountedCaliforniaRealProperty (estate : Estate) : Bool :=
  estate.assets.any
    (fun asset => asset.kind == .californiaReal && asset.treatment == .counted)

def theoremEmploymentAsset (id : Nat) (value : Money) : Asset := {
  id := ⟨id⟩
  name := s!"employment-{id}"
  kind := .personal
  currentGrossValue := value
  dateOfDeathValue := value
  treatment := .employmentCompensation
}

theorem aggregateEmployment_split_invariant
    (thresholds : Thresholds) (left right : Money) :
    ({ assets := [
      theoremEmploymentAsset 1 left,
      theoremEmploymentAsset 2 right
    ] } : Estate).personalAffidavitValueWith thresholds =
    ({ assets := [
      theoremEmploymentAsset 1 (left + right)
    ] } : Estate).personalAffidavitValueWith thresholds := by
  simp [Estate.personalAffidavitValueWith,
    Estate.aggregateEmploymentCompensation,
    Asset.personalOrdinaryValue,
    Asset.qualifyingEmploymentCompensation,
    theoremEmploymentAsset]

theorem personalAffidavitValueWith_ignores_encumbrances
    (estate : Estate) (thresholds : Thresholds) (asset : Asset) :
    ({ assets := asset :: estate.assets } : Estate).personalAffidavitValueWith
        thresholds =
      ({ assets := { asset with encumbrances := 0 } :: estate.assets } :
        Estate).personalAffidavitValueWith thresholds := by
  simp [Estate.personalAffidavitValueWith,
    Estate.aggregateEmploymentCompensation,
    Asset.personalOrdinaryValue,
    Asset.qualifyingEmploymentCompensation]

end SimpleProbate
