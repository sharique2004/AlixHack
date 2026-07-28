import SimpleProbate.Thresholds

namespace SimpleProbate

inductive PropertyKind
  | personal
  | californiaReal
  | outsideCaliforniaReal
deriving BEq, DecidableEq, Repr

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
deriving BEq, DecidableEq, Repr

inductive DirectTransferBasis
  | governmentBenefit
  | namedBeneficiary
  | revocableTrust
  | jointTenancy
  | transferOnDeath
  | multiplePartyAccount
  | spousePassage
deriving BEq, DecidableEq, Repr

structure Asset where
  name : String
  kind : PropertyKind
  grossValue : Money
  encumbrances : Money := 0
  treatment : ValuationTreatment := .counted
  includedInPrimaryResidencePetition : Bool := false
  isPrimaryResidence : Bool := false
deriving DecidableEq, Repr

structure Estate where
  assets : List Asset
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

def Asset.personalAffidavitValue
    (thresholds : Thresholds) (asset : Asset) : Money :=
  if asset.kind == .outsideCaliforniaReal ||
      asset.includedInPrimaryResidencePetition then
    0
  else
    match asset.treatment with
    | .counted => asset.grossValue
    | .employmentCompensation =>
        asset.grossValue - min asset.grossValue thresholds.employmentCompensationExclusion
    | _ => 0

def Estate.personalAffidavitValue
    (estate : Estate) (date : CivilDate) : Except DateError Money := do
  let thresholds ← thresholdsFor date
  pure <| estate.assets.foldl
    (fun total asset => total + asset.personalAffidavitValue thresholds) 0

def Asset.countedCaliforniaRealValue (asset : Asset) : Money :=
  if asset.kind == .californiaReal && asset.treatment == .counted then
    asset.grossValue
  else
    0

def Estate.smallValueRealPropertyValue (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset => total + asset.countedCaliforniaRealValue) 0

def Asset.countedPrimaryResidenceValue (asset : Asset) : Money :=
  if asset.kind == .californiaReal &&
      asset.treatment == .counted &&
      asset.isPrimaryResidence then
    asset.grossValue
  else
    0

def Estate.primaryResidenceValue (estate : Estate) : Money :=
  estate.assets.foldl
    (fun total asset => total + asset.countedPrimaryResidenceValue) 0

def Estate.containsCountedCaliforniaRealProperty (estate : Estate) : Bool :=
  estate.assets.any
    (fun asset => asset.kind == .californiaReal && asset.treatment == .counted)

end SimpleProbate
