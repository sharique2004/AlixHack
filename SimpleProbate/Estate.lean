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
