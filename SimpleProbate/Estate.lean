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
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

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
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

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
deriving BEq, ReflBEq, LawfulBEq, DecidableEq, Repr

structure Estate where
  assets : List Asset
deriving DecidableEq, Repr

structure PartialEstate where
  assets : List PartialAsset
  inventoryComplete : Knowledge Bool
deriving DecidableEq, Repr

structure PartialValuation where
  lowerBound : Money
  exactValue : Option Money
  missingFields : List (AssetId × AssetField)
  needsCompleteInventory : Bool
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

private def missingField
    (asset : PartialAsset) (field : AssetField) :
    List (AssetId × AssetField) :=
  [(asset.id, field)]

private def PartialAsset.personalOrdinaryLowerBound
    (asset : PartialAsset) : Money :=
  match asset.kind, asset.includedInPrimaryResidencePetition with
  | .known .outsideCaliforniaReal, _ => 0
  | _, .known true => 0
  | .known _, .known false =>
      match asset.treatment, asset.currentGrossValue with
      | .known .counted, .known value => value
      | _, _ => 0
  | _, _ => 0

private def PartialAsset.employmentLowerBound
    (asset : PartialAsset) : Money :=
  match asset.kind, asset.includedInPrimaryResidencePetition with
  | .known .outsideCaliforniaReal, _ => 0
  | _, .known true => 0
  | .known _, .known false =>
      match asset.treatment, asset.currentGrossValue with
      | .known .employmentCompensation, .known value => value
      | _, _ => 0
  | _, _ => 0

private def PartialAsset.personalValuationMissing
    (asset : PartialAsset) : List (AssetId × AssetField) :=
  match asset.kind, asset.includedInPrimaryResidencePetition with
  | .known .outsideCaliforniaReal, _ => []
  | _, .known true => []
  | .known _, .known false =>
      match asset.treatment with
      | .unknown => missingField asset .treatment
      | .known .counted | .known .employmentCompensation =>
          match asset.currentGrossValue with
          | .unknown => missingField asset .currentGrossValue
          | .known _ => []
      | .known _ => []
  | .unknown, .unknown =>
      missingField asset .kind ++
        missingField asset .primaryPetitionInclusion
  | .unknown, .known false => missingField asset .kind
  | .known _, .unknown => missingField asset .primaryPetitionInclusion

private def PartialAsset.smallRealLowerBound
    (asset : PartialAsset) : Money :=
  match asset.kind with
  | .known .californiaReal =>
      match asset.treatment, asset.dateOfDeathValue with
      | .known .counted, .known value => value
      | _, _ => 0
  | _ => 0

private def PartialAsset.smallRealValuationMissing
    (asset : PartialAsset) : List (AssetId × AssetField) :=
  match asset.kind with
  | .unknown => missingField asset .kind
  | .known .californiaReal =>
      match asset.treatment with
      | .unknown => missingField asset .treatment
      | .known .counted =>
          match asset.dateOfDeathValue with
          | .unknown => missingField asset .dateOfDeathValue
          | .known _ => []
      | .known _ => []
  | .known _ => []

private def PartialAsset.primaryResidenceLowerBound
    (asset : PartialAsset) : Money :=
  match asset.kind, asset.treatment, asset.isPrimaryResidence,
      asset.dateOfDeathValue with
  | .known .californiaReal, .known .counted, .known true, .known value => value
  | _, _, _, _ => 0

private def PartialAsset.primaryResidenceValuationMissing
    (asset : PartialAsset) : List (AssetId × AssetField) :=
  match asset.kind with
  | .unknown => missingField asset .kind
  | .known .californiaReal =>
      match asset.treatment with
      | .unknown => missingField asset .treatment
      | .known .counted =>
          match asset.isPrimaryResidence with
          | .unknown => missingField asset .primaryResidence
          | .known true =>
              match asset.dateOfDeathValue with
              | .unknown => missingField asset .dateOfDeathValue
              | .known _ => []
          | .known false => []
      | .known _ => []
  | .known _ => []

private def PartialEstate.valuation
    (estate : PartialEstate)
    (lowerBound : Money)
    (missing : List (AssetId × AssetField)) :
    PartialValuation :=
  let missingFields := dedupStable missing
  match estate.inventoryComplete with
  | .known true => {
      lowerBound
      exactValue :=
        if missingFields.isEmpty then some lowerBound else none
      missingFields
      needsCompleteInventory := false
    }
  | _ => {
      lowerBound
      exactValue := none
      missingFields
      needsCompleteInventory := true
    }

def PartialEstate.personalAffidavitValuation
    (estate : PartialEstate) (thresholds : Thresholds) :
    PartialValuation :=
  let ordinary := estate.assets.foldl
    (fun total asset => total + asset.personalOrdinaryLowerBound) 0
  let employment := estate.assets.foldl
    (fun total asset => total + asset.employmentLowerBound) 0
  let lowerBound :=
    ordinary +
      (employment -
        min employment thresholds.employmentCompensationExclusion)
  estate.valuation lowerBound
    (estate.assets.flatMap PartialAsset.personalValuationMissing)

def PartialEstate.smallRealPropertyValuation
    (estate : PartialEstate) : PartialValuation :=
  let lowerBound := estate.assets.foldl
    (fun total asset => total + asset.smallRealLowerBound) 0
  estate.valuation lowerBound
    (estate.assets.flatMap PartialAsset.smallRealValuationMissing)

def PartialEstate.primaryResidenceValuation
    (estate : PartialEstate) : PartialValuation :=
  let lowerBound := estate.assets.foldl
    (fun total asset => total + asset.primaryResidenceLowerBound) 0
  estate.valuation lowerBound
    (estate.assets.flatMap PartialAsset.primaryResidenceValuationMissing)

private theorem excludedAmount_mono
    {left right cap : Money} (le : left ≤ right) :
    left - min left cap ≤ right - min right cap := by
  by_cases leftWithin : left ≤ cap
  · rw [Nat.min_eq_left leftWithin, Nat.sub_self]
    exact Nat.zero_le _
  · have capLeLeft : cap ≤ left := Nat.le_of_lt (Nat.lt_of_not_ge leftWithin)
    have capLeRight : cap ≤ right := Nat.le_trans capLeLeft le
    rw [Nat.min_eq_right capLeLeft, Nat.min_eq_right capLeRight]
    exact Nat.sub_le_sub_right le cap

private theorem sum_eq_of_perm {left right : List Money}
    (permuted : left.Perm right) : left.sum = right.sum := by
  induction permuted with
  | nil => rfl
  | cons head permuted ih => simp [ih]
  | swap left right tail =>
      simp [Nat.add_left_comm]
  | trans first second ihFirst ihSecond => exact ihFirst.trans ihSecond

@[simp] private theorem foldl_add_eq_sum_map
    (values : List α) (value : α → Money) :
    values.foldl (fun total item => total + value item) 0 =
      (values.map value).sum := by
  rw [List.sum_eq_foldl, List.foldl_map]

private theorem sum_map_le_sum_map_of_unique_matches
    [BEq β] [LawfulBEq β]
    {partials : List α} {totals : List β}
    (partialId : α → AssetId) (totalId : β → AssetId)
    (partialValue : α → Money) (totalValue : β → Money)
    (partialUnique : (partials.map partialId).Nodup)
    (matching :
      ∀ item ∈ partials,
        ∃ completed ∈ totals,
          partialId item = totalId completed ∧
          partialValue item ≤ totalValue completed) :
    (partials.map partialValue).sum ≤ (totals.map totalValue).sum := by
  induction partials generalizing totals with
  | nil => simp
  | cons head tail ih =>
      simp only [List.map_cons, List.nodup_cons] at partialUnique
      obtain ⟨completed, completedMember, sameId, valueLe⟩ :=
        matching head (by simp)
      have tailMatches :
          ∀ item ∈ tail,
            ∃ remainder ∈ totals.erase completed,
              partialId item = totalId remainder ∧
              partialValue item ≤ totalValue remainder := by
        intro item itemMember
        obtain ⟨remainder, remainderMember, remainderId, remainderLe⟩ :=
          matching item (by simp [itemMember])
        have different : remainder ≠ completed := by
          intro equal
          subst remainder
          apply partialUnique.1
          simp only [List.mem_map]
          exact ⟨item, itemMember, remainderId.trans sameId.symm⟩
        exact ⟨remainder,
          (List.mem_erase_of_ne different).2 remainderMember,
          remainderId, remainderLe⟩
      have tailLe :=
        ih partialUnique.2 tailMatches
      have totalSum :
          (totals.map totalValue).sum =
            totalValue completed +
              ((totals.erase completed).map totalValue).sum := by
        have permuted :=
          (List.perm_cons_erase completedMember).map totalValue
        simpa using sum_eq_of_perm permuted
      rw [totalSum]
      simpa using Nat.add_le_add valueLe tailLe

private theorem sum_map_eq_sum_map_of_unique_matches
    [BEq α] [LawfulBEq α] [BEq β] [LawfulBEq β]
    {partials : List α} {totals : List β}
    (partialId : α → AssetId) (totalId : β → AssetId)
    (partialValue : α → Money) (totalValue : β → Money)
    (partialUnique : (partials.map partialId).Nodup)
    (totalUnique : (totals.map totalId).Nodup)
    (forward :
      ∀ item ∈ partials,
        ∃ completed ∈ totals,
          partialId item = totalId completed ∧
          partialValue item = totalValue completed)
    (reverse :
      ∀ completed ∈ totals,
        ∃ item ∈ partials,
          totalId completed = partialId item ∧
          totalValue completed = partialValue item) :
    (partials.map partialValue).sum = (totals.map totalValue).sum := by
  apply Nat.le_antisymm
  · exact sum_map_le_sum_map_of_unique_matches
      partialId totalId partialValue totalValue
      partialUnique
      (by
        intro item itemMember
        obtain ⟨completed, completedMember, sameId, sameValue⟩ :=
          forward item itemMember
        exact ⟨completed, completedMember, sameId, Nat.le_of_eq sameValue⟩)
  · exact sum_map_le_sum_map_of_unique_matches
      totalId partialId totalValue partialValue
      totalUnique
      (by
        intro completed completedMember
        obtain ⟨item, itemMember, sameId, sameValue⟩ :=
          reverse completed completedMember
        exact ⟨item, itemMember, sameId, Nat.le_of_eq sameValue⟩)

private theorem asset_eq_of_mem_of_id_eq
    {assets : List Asset} {left right : Asset}
    (unique : (assets.map (·.id)).Nodup)
    (leftMember : left ∈ assets) (rightMember : right ∈ assets)
    (sameId : left.id = right.id) :
    left = right := by
  induction assets with
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
        · exact ih unique.2 leftMember rightMember

private theorem total_asset_has_completion
    {partialEstate : PartialEstate} {totalEstate : Estate}
    (listed :
      partialEstate.listedAssetsComplete totalEstate)
    (sameIds : partialEstate.sameAssetIds totalEstate)
    (totalUnique : (totalEstate.assets.map (·.id)).Nodup)
    {totalAsset : Asset} (totalMember : totalAsset ∈ totalEstate.assets) :
    ∃ partialAsset ∈ partialEstate.assets,
      partialAsset.Completes totalAsset := by
  have totalIdMember :
      totalAsset.id ∈ totalEstate.assets.map (·.id) := by
    simp only [List.mem_map]
    exact ⟨totalAsset, totalMember, rfl⟩
  have partialIdMember :
      totalAsset.id ∈ partialEstate.assets.map (·.id) :=
    (sameIds totalAsset.id).mpr totalIdMember
  obtain ⟨partialAsset, partialMember, partialId⟩ :=
    List.mem_map.mp partialIdMember
  obtain ⟨completed, completedMember, completion⟩ :=
    listed partialAsset partialMember
  have completedEq : completed = totalAsset :=
    asset_eq_of_mem_of_id_eq totalUnique
      completedMember totalMember
      (completion.1.symm.trans partialId)
  subst completed
  exact ⟨partialAsset, partialMember, completion⟩

private theorem valuation_exact_components
    {estate : PartialEstate} {lowerBound value : Money}
    {missing : List (AssetId × AssetField)}
    (exact : (estate.valuation lowerBound missing).exactValue = some value) :
    estate.inventoryComplete = .known true ∧
      dedupStable missing = [] ∧
      lowerBound = value := by
  cases inventory : estate.inventoryComplete with
  | unknown => simp [PartialEstate.valuation, inventory] at exact
  | known complete =>
      cases complete with
      | false => simp [PartialEstate.valuation, inventory] at exact
      | true =>
          cases missingEmpty : (dedupStable missing).isEmpty with
          | false =>
              simp [PartialEstate.valuation, inventory, missingEmpty] at exact
          | true =>
              have noMissing : dedupStable missing = [] :=
                List.isEmpty_iff.mp missingEmpty
              simp [PartialEstate.valuation, inventory, missingEmpty] at exact
              exact ⟨rfl, noMissing, exact⟩

@[simp] private theorem valuation_lowerBound
    (estate : PartialEstate) (lowerBound : Money)
    (missing : List (AssetId × AssetField)) :
    (estate.valuation lowerBound missing).lowerBound = lowerBound := by
  cases estate with
  | mk assets inventory =>
      cases inventory with
      | unknown => simp [PartialEstate.valuation]
      | known complete =>
          cases complete <;> simp [PartialEstate.valuation]

private theorem valuation_coherent
    (estate : PartialEstate) (lowerBound : Money)
    (missing : List (AssetId × AssetField)) :
    (estate.valuation lowerBound missing).exactValue = none →
      (estate.valuation lowerBound missing).missingFields ≠ [] ∨
      (estate.valuation lowerBound missing).needsCompleteInventory = true := by
  cases estate with
  | mk assets inventory =>
      cases inventory with
      | unknown => simp [PartialEstate.valuation]
      | known complete =>
          cases complete with
          | false => simp [PartialEstate.valuation]
          | true =>
              by_cases noMissing : dedupStable missing = []
              · simp [PartialEstate.valuation, noMissing]
              · simp [PartialEstate.valuation, noMissing]

private theorem dedupStable_eq_nil_iff
    [BEq α] [LawfulBEq α] (values : List α) :
    dedupStable values = [] ↔ values = [] := by
  constructor
  · intro dedupEmpty
    rw [List.eq_nil_iff_forall_not_mem]
    intro value valueMember
    have dedupMember :=
      (mem_dedupStable value values).mpr valueMember
    simp [dedupEmpty] at dedupMember
  · rintro rfl
    rfl

@[simp] private theorem personalOrdinaryLowerBound_ofTotal
    (asset : Asset) :
    (PartialAsset.ofTotal asset).personalOrdinaryLowerBound =
      asset.personalOrdinaryValue := by
  cases asset with
  | mk id name kind current death encumbrances treatment included primary =>
      cases kind <;> cases treatment <;> cases included <;>
        simp [PartialAsset.ofTotal,
          PartialAsset.personalOrdinaryLowerBound,
          Asset.personalOrdinaryValue]

@[simp] private theorem employmentLowerBound_ofTotal
    (asset : Asset) :
    (PartialAsset.ofTotal asset).employmentLowerBound =
      asset.qualifyingEmploymentCompensation := by
  cases asset with
  | mk id name kind current death encumbrances treatment included primary =>
      cases kind <;> cases treatment <;> cases included <;>
        simp [PartialAsset.ofTotal,
          PartialAsset.employmentLowerBound,
          Asset.qualifyingEmploymentCompensation]

@[simp] private theorem personalValuationMissing_ofTotal
    (asset : Asset) :
    (PartialAsset.ofTotal asset).personalValuationMissing = [] := by
  cases asset with
  | mk id name kind current death encumbrances treatment included primary =>
      cases kind <;> cases treatment <;> cases included <;>
        simp [PartialAsset.ofTotal,
          PartialAsset.personalValuationMissing]

@[simp] private theorem smallRealLowerBound_ofTotal
    (asset : Asset) :
    (PartialAsset.ofTotal asset).smallRealLowerBound =
      asset.countedCaliforniaRealValue := by
  cases asset with
  | mk id name kind current death encumbrances treatment included primary =>
      cases kind <;> cases treatment <;>
        simp [PartialAsset.ofTotal,
          PartialAsset.smallRealLowerBound,
          Asset.countedCaliforniaRealValue]

@[simp] private theorem smallRealValuationMissing_ofTotal
    (asset : Asset) :
    (PartialAsset.ofTotal asset).smallRealValuationMissing = [] := by
  cases asset with
  | mk id name kind current death encumbrances treatment included primary =>
      cases kind <;> cases treatment <;>
        simp [PartialAsset.ofTotal,
          PartialAsset.smallRealValuationMissing]

@[simp] private theorem primaryResidenceLowerBound_ofTotal
    (asset : Asset) :
    (PartialAsset.ofTotal asset).primaryResidenceLowerBound =
      asset.countedPrimaryResidenceValue := by
  cases asset with
  | mk id name kind current death encumbrances treatment included primary =>
      cases kind <;> cases treatment <;> cases primary <;>
        simp [PartialAsset.ofTotal,
          PartialAsset.primaryResidenceLowerBound,
          Asset.countedPrimaryResidenceValue]

@[simp] private theorem primaryResidenceValuationMissing_ofTotal
    (asset : Asset) :
    (PartialAsset.ofTotal asset).primaryResidenceValuationMissing = [] := by
  cases asset with
  | mk id name kind current death encumbrances treatment included primary =>
      cases kind <;> cases treatment <;> cases primary <;>
        simp [PartialAsset.ofTotal,
          PartialAsset.primaryResidenceValuationMissing]

private theorem personalOrdinaryLowerBound_le_of_completes
    {partialAsset : PartialAsset} {totalAsset : Asset}
    (completion : partialAsset.Completes totalAsset) :
    partialAsset.personalOrdinaryLowerBound ≤
      totalAsset.personalOrdinaryValue := by
  cases partialAsset with
  | mk pid pname pkind pcurrent pdeath pencumbrances ptreatment
      pincluded pprimary =>
    cases totalAsset with
    | mk tid tname tkind tcurrent tdeath tencumbrances ttreatment
        tincluded tprimary =>
      simp only [PartialAsset.Completes] at completion
      rcases completion with
        ⟨_, _, kind, current, _, _, treatment, included, _⟩
      cases pkind <;> cases pincluded <;>
        cases ptreatment <;> cases pcurrent <;>
        cases tkind <;> cases tincluded <;> cases ttreatment <;>
        simp_all [Knowledge.Completes,
          PartialAsset.personalOrdinaryLowerBound,
          Asset.personalOrdinaryValue]

private theorem employmentLowerBound_le_of_completes
    {partialAsset : PartialAsset} {totalAsset : Asset}
    (completion : partialAsset.Completes totalAsset) :
    partialAsset.employmentLowerBound ≤
      totalAsset.qualifyingEmploymentCompensation := by
  cases partialAsset with
  | mk pid pname pkind pcurrent pdeath pencumbrances ptreatment
      pincluded pprimary =>
    cases totalAsset with
    | mk tid tname tkind tcurrent tdeath tencumbrances ttreatment
        tincluded tprimary =>
      simp only [PartialAsset.Completes] at completion
      rcases completion with
        ⟨_, _, kind, current, _, _, treatment, included, _⟩
      cases pkind <;> cases pincluded <;>
        cases ptreatment <;> cases pcurrent <;>
        cases tkind <;> cases tincluded <;> cases ttreatment <;>
        simp_all [Knowledge.Completes,
          PartialAsset.employmentLowerBound,
          Asset.qualifyingEmploymentCompensation]

private theorem smallRealLowerBound_le_of_completes
    {partialAsset : PartialAsset} {totalAsset : Asset}
    (completion : partialAsset.Completes totalAsset) :
    partialAsset.smallRealLowerBound ≤
      totalAsset.countedCaliforniaRealValue := by
  cases partialAsset with
  | mk pid pname pkind pcurrent pdeath pencumbrances ptreatment
      pincluded pprimary =>
    cases totalAsset with
    | mk tid tname tkind tcurrent tdeath tencumbrances ttreatment
        tincluded tprimary =>
      simp only [PartialAsset.Completes] at completion
      rcases completion with
        ⟨_, _, kind, _, death, _, treatment, _, _⟩
      cases pkind <;> cases ptreatment <;> cases pdeath <;>
        cases tkind <;> cases ttreatment <;>
        simp_all [Knowledge.Completes,
          PartialAsset.smallRealLowerBound,
          Asset.countedCaliforniaRealValue]

private theorem primaryResidenceLowerBound_le_of_completes
    {partialAsset : PartialAsset} {totalAsset : Asset}
    (completion : partialAsset.Completes totalAsset) :
    partialAsset.primaryResidenceLowerBound ≤
      totalAsset.countedPrimaryResidenceValue := by
  cases partialAsset with
  | mk pid pname pkind pcurrent pdeath pencumbrances ptreatment
      pincluded pprimary =>
    cases totalAsset with
    | mk tid tname tkind tcurrent tdeath tencumbrances ttreatment
        tincluded tprimary =>
      simp only [PartialAsset.Completes] at completion
      rcases completion with
        ⟨_, _, kind, _, death, _, treatment, _, primary⟩
      cases pkind <;> cases ptreatment <;>
        cases pprimary <;> cases pdeath <;>
        cases tkind <;> cases ttreatment <;> cases tprimary <;>
        simp_all [Knowledge.Completes,
          PartialAsset.primaryResidenceLowerBound,
          Asset.countedPrimaryResidenceValue]

set_option maxHeartbeats 800000 in
private theorem personalLowerBounds_eq_of_complete_fields
    {partialAsset : PartialAsset} {totalAsset : Asset}
    (completion : partialAsset.Completes totalAsset)
    (completeFields : partialAsset.personalValuationMissing = []) :
    partialAsset.personalOrdinaryLowerBound =
        totalAsset.personalOrdinaryValue ∧
      partialAsset.employmentLowerBound =
        totalAsset.qualifyingEmploymentCompensation := by
  cases partialAsset with
  | mk pid pname pkind pcurrent pdeath pencumbrances ptreatment
      pincluded pprimary =>
    cases totalAsset with
    | mk tid tname tkind tcurrent tdeath tencumbrances ttreatment
        tincluded tprimary =>
      simp only [PartialAsset.Completes] at completion
      rcases completion with
        ⟨_, _, kind, current, _, _, treatment, included, _⟩
      cases pkind <;> cases pincluded <;>
        cases ptreatment <;> cases pcurrent <;>
        cases tkind <;> cases tincluded <;> cases ttreatment <;>
        simp_all [Knowledge.Completes,
          PartialAsset.personalValuationMissing,
          PartialAsset.personalOrdinaryLowerBound,
          PartialAsset.employmentLowerBound,
          Asset.personalOrdinaryValue,
          Asset.qualifyingEmploymentCompensation,
          missingField]

set_option maxHeartbeats 800000 in
private theorem smallRealLowerBound_eq_of_complete_fields
    {partialAsset : PartialAsset} {totalAsset : Asset}
    (completion : partialAsset.Completes totalAsset)
    (completeFields : partialAsset.smallRealValuationMissing = []) :
    partialAsset.smallRealLowerBound =
      totalAsset.countedCaliforniaRealValue := by
  cases partialAsset with
  | mk pid pname pkind pcurrent pdeath pencumbrances ptreatment
      pincluded pprimary =>
    cases totalAsset with
    | mk tid tname tkind tcurrent tdeath tencumbrances ttreatment
        tincluded tprimary =>
      simp only [PartialAsset.Completes] at completion
      rcases completion with
        ⟨_, _, kind, _, death, _, treatment, _, _⟩
      cases pkind <;> cases ptreatment <;> cases pdeath <;>
        cases tkind <;> cases ttreatment <;>
        simp_all [Knowledge.Completes,
          PartialAsset.smallRealValuationMissing,
          PartialAsset.smallRealLowerBound,
          Asset.countedCaliforniaRealValue,
          missingField]

set_option maxHeartbeats 800000 in
private theorem primaryResidenceLowerBound_eq_of_complete_fields
    {partialAsset : PartialAsset} {totalAsset : Asset}
    (completion : partialAsset.Completes totalAsset)
    (completeFields :
      partialAsset.primaryResidenceValuationMissing = []) :
    partialAsset.primaryResidenceLowerBound =
      totalAsset.countedPrimaryResidenceValue := by
  cases partialAsset with
  | mk pid pname pkind pcurrent pdeath pencumbrances ptreatment
      pincluded pprimary =>
    cases totalAsset with
    | mk tid tname tkind tcurrent tdeath tencumbrances ttreatment
        tincluded tprimary =>
      simp only [PartialAsset.Completes] at completion
      rcases completion with
        ⟨_, _, kind, _, death, _, treatment, _, primary⟩
      cases pkind <;> cases ptreatment <;>
        cases pprimary <;> cases pdeath <;>
        cases tkind <;> cases ttreatment <;> cases tprimary <;>
        simp_all [Knowledge.Completes,
          PartialAsset.primaryResidenceValuationMissing,
          PartialAsset.primaryResidenceLowerBound,
          Asset.countedPrimaryResidenceValue,
          missingField]

theorem personalValuation_lowerBound_le
    {partialEstate : PartialEstate} {totalEstate : Estate}
    (completion : partialEstate.Completes totalEstate)
    (partialUnique :
      (partialEstate.assets.map (·.id)).Nodup)
    (thresholds : Thresholds) :
    (partialEstate.personalAffidavitValuation thresholds).lowerBound ≤
      totalEstate.personalAffidavitValueWith thresholds := by
  have ordinaryLe :=
    sum_map_le_sum_map_of_unique_matches
      (fun asset : PartialAsset => asset.id)
      (fun asset : Asset => asset.id)
      PartialAsset.personalOrdinaryLowerBound
      Asset.personalOrdinaryValue
      partialUnique
      (by
        intro partialAsset partialMember
        obtain ⟨totalAsset, totalMember, assetCompletion⟩ :=
          completion.1 partialAsset partialMember
        exact ⟨totalAsset, totalMember, assetCompletion.1,
          personalOrdinaryLowerBound_le_of_completes assetCompletion⟩)
  have employmentLe :=
    sum_map_le_sum_map_of_unique_matches
      (fun asset : PartialAsset => asset.id)
      (fun asset : Asset => asset.id)
      PartialAsset.employmentLowerBound
      Asset.qualifyingEmploymentCompensation
      partialUnique
      (by
        intro partialAsset partialMember
        obtain ⟨totalAsset, totalMember, assetCompletion⟩ :=
          completion.1 partialAsset partialMember
        exact ⟨totalAsset, totalMember, assetCompletion.1,
          employmentLowerBound_le_of_completes assetCompletion⟩)
  have excludedLe := excludedAmount_mono
    (cap := thresholds.employmentCompensationExclusion) employmentLe
  simpa [PartialEstate.personalAffidavitValuation,
      Estate.personalAffidavitValueWith,
      Estate.aggregateEmploymentCompensation] using
        Nat.add_le_add ordinaryLe excludedLe

theorem personalValuation_coherent
    (estate : PartialEstate) (thresholds : Thresholds) :
    (estate.personalAffidavitValuation thresholds).exactValue = none →
      (estate.personalAffidavitValuation thresholds).missingFields ≠ [] ∨
      (estate.personalAffidavitValuation thresholds).needsCompleteInventory =
        true := by
  exact valuation_coherent estate _ _

theorem smallRealValuation_lowerBound_le
    {partialEstate : PartialEstate} {totalEstate : Estate}
    (completion : partialEstate.Completes totalEstate)
    (partialUnique :
      (partialEstate.assets.map (·.id)).Nodup) :
    partialEstate.smallRealPropertyValuation.lowerBound ≤
      totalEstate.smallValueRealPropertyValue := by
  have valueLe :=
    sum_map_le_sum_map_of_unique_matches
      (fun asset : PartialAsset => asset.id)
      (fun asset : Asset => asset.id)
      PartialAsset.smallRealLowerBound
      Asset.countedCaliforniaRealValue
      partialUnique
      (by
        intro partialAsset partialMember
        obtain ⟨totalAsset, totalMember, assetCompletion⟩ :=
          completion.1 partialAsset partialMember
        exact ⟨totalAsset, totalMember, assetCompletion.1,
          smallRealLowerBound_le_of_completes assetCompletion⟩)
  simpa [PartialEstate.smallRealPropertyValuation,
      Estate.smallValueRealPropertyValue] using valueLe

theorem smallRealValuation_coherent (estate : PartialEstate) :
    estate.smallRealPropertyValuation.exactValue = none →
      estate.smallRealPropertyValuation.missingFields ≠ [] ∨
      estate.smallRealPropertyValuation.needsCompleteInventory = true := by
  exact valuation_coherent estate _ _

theorem primaryResidenceValuation_lowerBound_le
    {partialEstate : PartialEstate} {totalEstate : Estate}
    (completion : partialEstate.Completes totalEstate)
    (partialUnique :
      (partialEstate.assets.map (·.id)).Nodup) :
    partialEstate.primaryResidenceValuation.lowerBound ≤
      totalEstate.primaryResidenceValue := by
  have valueLe :=
    sum_map_le_sum_map_of_unique_matches
      (fun asset : PartialAsset => asset.id)
      (fun asset : Asset => asset.id)
      PartialAsset.primaryResidenceLowerBound
      Asset.countedPrimaryResidenceValue
      partialUnique
      (by
        intro partialAsset partialMember
        obtain ⟨totalAsset, totalMember, assetCompletion⟩ :=
          completion.1 partialAsset partialMember
        exact ⟨totalAsset, totalMember, assetCompletion.1,
          primaryResidenceLowerBound_le_of_completes assetCompletion⟩)
  simpa [PartialEstate.primaryResidenceValuation,
      Estate.primaryResidenceValue] using valueLe

theorem primaryResidenceValuation_coherent (estate : PartialEstate) :
    estate.primaryResidenceValuation.exactValue = none →
      estate.primaryResidenceValuation.missingFields ≠ [] ∨
      estate.primaryResidenceValuation.needsCompleteInventory = true := by
  exact valuation_coherent estate _ _

theorem personalValuation_exact_eq
    {partialEstate : PartialEstate} {totalEstate : Estate}
    {value : Money}
    (completion : partialEstate.Completes totalEstate)
    (partialUnique :
      (partialEstate.assets.map (·.id)).Nodup)
    (totalUnique :
      (totalEstate.assets.map (·.id)).Nodup)
    (thresholds : Thresholds)
    (exact :
      (partialEstate.personalAffidavitValuation thresholds).exactValue =
        some value) :
    totalEstate.personalAffidavitValueWith thresholds = value := by
  let ordinary :=
    (partialEstate.assets.map
      PartialAsset.personalOrdinaryLowerBound).sum
  let employment :=
    (partialEstate.assets.map PartialAsset.employmentLowerBound).sum
  let missing :=
    partialEstate.assets.flatMap PartialAsset.personalValuationMissing
  have exact' :
      (partialEstate.valuation
        (ordinary +
          (employment -
            min employment thresholds.employmentCompensationExclusion))
        missing).exactValue = some value := by
    simpa [ordinary, employment, missing,
      PartialEstate.personalAffidavitValuation] using exact
  have components := valuation_exact_components exact'
  have missingAll : missing = [] :=
    (dedupStable_eq_nil_iff missing).mp components.2.1
  have sameIds : partialEstate.sameAssetIds totalEstate := by
    have inventory := components.1
    unfold PartialEstate.Completes at completion
    rw [inventory] at completion
    exact completion.2
  have ordinaryEq :=
    sum_map_eq_sum_map_of_unique_matches
      (fun asset : PartialAsset => asset.id)
      (fun asset : Asset => asset.id)
      PartialAsset.personalOrdinaryLowerBound
      Asset.personalOrdinaryValue
      partialUnique totalUnique
      (by
        intro partialAsset partialMember
        obtain ⟨totalAsset, totalMember, assetCompletion⟩ :=
          completion.1 partialAsset partialMember
        have completeFields :
            partialAsset.personalValuationMissing = [] :=
          (List.flatMap_eq_nil_iff.mp missingAll)
            partialAsset partialMember
        exact ⟨totalAsset, totalMember, assetCompletion.1,
          (personalLowerBounds_eq_of_complete_fields
            assetCompletion completeFields).1⟩)
      (by
        intro totalAsset totalMember
        obtain ⟨partialAsset, partialMember, assetCompletion⟩ :=
          total_asset_has_completion completion.1 sameIds totalUnique totalMember
        have completeFields :
            partialAsset.personalValuationMissing = [] :=
          (List.flatMap_eq_nil_iff.mp missingAll)
            partialAsset partialMember
        exact ⟨partialAsset, partialMember, assetCompletion.1.symm,
          (personalLowerBounds_eq_of_complete_fields
            assetCompletion completeFields).1.symm⟩)
  have employmentEq :=
    sum_map_eq_sum_map_of_unique_matches
      (fun asset : PartialAsset => asset.id)
      (fun asset : Asset => asset.id)
      PartialAsset.employmentLowerBound
      Asset.qualifyingEmploymentCompensation
      partialUnique totalUnique
      (by
        intro partialAsset partialMember
        obtain ⟨totalAsset, totalMember, assetCompletion⟩ :=
          completion.1 partialAsset partialMember
        have completeFields :
            partialAsset.personalValuationMissing = [] :=
          (List.flatMap_eq_nil_iff.mp missingAll)
            partialAsset partialMember
        exact ⟨totalAsset, totalMember, assetCompletion.1,
          (personalLowerBounds_eq_of_complete_fields
            assetCompletion completeFields).2⟩)
      (by
        intro totalAsset totalMember
        obtain ⟨partialAsset, partialMember, assetCompletion⟩ :=
          total_asset_has_completion completion.1 sameIds totalUnique totalMember
        have completeFields :
            partialAsset.personalValuationMissing = [] :=
          (List.flatMap_eq_nil_iff.mp missingAll)
            partialAsset partialMember
        exact ⟨partialAsset, partialMember, assetCompletion.1.symm,
          (personalLowerBounds_eq_of_complete_fields
            assetCompletion completeFields).2.symm⟩)
  calc
    totalEstate.personalAffidavitValueWith thresholds =
        ordinary +
          (employment -
            min employment thresholds.employmentCompensationExclusion) := by
      simp [Estate.personalAffidavitValueWith,
        Estate.aggregateEmploymentCompensation,
        ordinary, employment,
        ordinaryEq, employmentEq]
    _ = value := components.2.2

theorem smallRealValuation_exact_eq
    {partialEstate : PartialEstate} {totalEstate : Estate}
    {value : Money}
    (completion : partialEstate.Completes totalEstate)
    (partialUnique :
      (partialEstate.assets.map (·.id)).Nodup)
    (totalUnique :
      (totalEstate.assets.map (·.id)).Nodup)
    (exact :
      partialEstate.smallRealPropertyValuation.exactValue =
        some value) :
    totalEstate.smallValueRealPropertyValue = value := by
  let lowerBound :=
    (partialEstate.assets.map PartialAsset.smallRealLowerBound).sum
  let missing :=
    partialEstate.assets.flatMap PartialAsset.smallRealValuationMissing
  have exact' :
      (partialEstate.valuation lowerBound missing).exactValue = some value := by
    simpa [lowerBound, missing,
      PartialEstate.smallRealPropertyValuation] using exact
  have components := valuation_exact_components exact'
  have missingAll : missing = [] :=
    (dedupStable_eq_nil_iff missing).mp components.2.1
  have sameIds : partialEstate.sameAssetIds totalEstate := by
    have inventory := components.1
    unfold PartialEstate.Completes at completion
    rw [inventory] at completion
    exact completion.2
  have valueEq :=
    sum_map_eq_sum_map_of_unique_matches
      (fun asset : PartialAsset => asset.id)
      (fun asset : Asset => asset.id)
      PartialAsset.smallRealLowerBound
      Asset.countedCaliforniaRealValue
      partialUnique totalUnique
      (by
        intro partialAsset partialMember
        obtain ⟨totalAsset, totalMember, assetCompletion⟩ :=
          completion.1 partialAsset partialMember
        have completeFields :
            partialAsset.smallRealValuationMissing = [] :=
          (List.flatMap_eq_nil_iff.mp missingAll)
            partialAsset partialMember
        exact ⟨totalAsset, totalMember, assetCompletion.1,
          smallRealLowerBound_eq_of_complete_fields
            assetCompletion completeFields⟩)
      (by
        intro totalAsset totalMember
        obtain ⟨partialAsset, partialMember, assetCompletion⟩ :=
          total_asset_has_completion completion.1 sameIds totalUnique totalMember
        have completeFields :
            partialAsset.smallRealValuationMissing = [] :=
          (List.flatMap_eq_nil_iff.mp missingAll)
            partialAsset partialMember
        exact ⟨partialAsset, partialMember, assetCompletion.1.symm,
          (smallRealLowerBound_eq_of_complete_fields
            assetCompletion completeFields).symm⟩)
  calc
    totalEstate.smallValueRealPropertyValue = lowerBound := by
      simpa [Estate.smallValueRealPropertyValue, lowerBound,
        foldl_add_eq_sum_map] using valueEq.symm
    _ = value := components.2.2

theorem primaryResidenceValuation_exact_eq
    {partialEstate : PartialEstate} {totalEstate : Estate}
    {value : Money}
    (completion : partialEstate.Completes totalEstate)
    (partialUnique :
      (partialEstate.assets.map (·.id)).Nodup)
    (totalUnique :
      (totalEstate.assets.map (·.id)).Nodup)
    (exact :
      partialEstate.primaryResidenceValuation.exactValue =
        some value) :
    totalEstate.primaryResidenceValue = value := by
  let lowerBound :=
    (partialEstate.assets.map PartialAsset.primaryResidenceLowerBound).sum
  let missing :=
    partialEstate.assets.flatMap
      PartialAsset.primaryResidenceValuationMissing
  have exact' :
      (partialEstate.valuation lowerBound missing).exactValue = some value := by
    simpa [lowerBound, missing,
      PartialEstate.primaryResidenceValuation] using exact
  have components := valuation_exact_components exact'
  have missingAll : missing = [] :=
    (dedupStable_eq_nil_iff missing).mp components.2.1
  have sameIds : partialEstate.sameAssetIds totalEstate := by
    have inventory := components.1
    unfold PartialEstate.Completes at completion
    rw [inventory] at completion
    exact completion.2
  have valueEq :=
    sum_map_eq_sum_map_of_unique_matches
      (fun asset : PartialAsset => asset.id)
      (fun asset : Asset => asset.id)
      PartialAsset.primaryResidenceLowerBound
      Asset.countedPrimaryResidenceValue
      partialUnique totalUnique
      (by
        intro partialAsset partialMember
        obtain ⟨totalAsset, totalMember, assetCompletion⟩ :=
          completion.1 partialAsset partialMember
        have completeFields :
            partialAsset.primaryResidenceValuationMissing = [] :=
          (List.flatMap_eq_nil_iff.mp missingAll)
            partialAsset partialMember
        exact ⟨totalAsset, totalMember, assetCompletion.1,
          primaryResidenceLowerBound_eq_of_complete_fields
            assetCompletion completeFields⟩)
      (by
        intro totalAsset totalMember
        obtain ⟨partialAsset, partialMember, assetCompletion⟩ :=
          total_asset_has_completion completion.1 sameIds totalUnique totalMember
        have completeFields :
            partialAsset.primaryResidenceValuationMissing = [] :=
          (List.flatMap_eq_nil_iff.mp missingAll)
            partialAsset partialMember
        exact ⟨partialAsset, partialMember, assetCompletion.1.symm,
          (primaryResidenceLowerBound_eq_of_complete_fields
            assetCompletion completeFields).symm⟩)
  calc
    totalEstate.primaryResidenceValue = lowerBound := by
      simpa [Estate.primaryResidenceValue, lowerBound,
        foldl_add_eq_sum_map] using valueEq.symm
    _ = value := components.2.2

@[simp] private theorem personalOrdinaryFold_ofTotal
    (assets : List Asset) (initial : Money) :
    (assets.map PartialAsset.ofTotal).foldl
        (fun total asset => total + asset.personalOrdinaryLowerBound)
        initial =
      assets.foldl
        (fun total asset => total + asset.personalOrdinaryValue)
        initial := by
  induction assets generalizing initial with
  | nil => rfl
  | cons head tail ih =>
      simp only [List.map_cons, List.foldl_cons,
        personalOrdinaryLowerBound_ofTotal]
      exact ih _

@[simp] private theorem employmentFold_ofTotal
    (assets : List Asset) (initial : Money) :
    (assets.map PartialAsset.ofTotal).foldl
        (fun total asset => total + asset.employmentLowerBound)
        initial =
      assets.foldl
        (fun total asset => total + asset.qualifyingEmploymentCompensation)
        initial := by
  induction assets generalizing initial with
  | nil => rfl
  | cons head tail ih =>
      simp only [List.map_cons, List.foldl_cons,
        employmentLowerBound_ofTotal]
      exact ih _

@[simp] private theorem personalMissing_ofTotal
    (assets : List Asset) :
    (assets.map PartialAsset.ofTotal).flatMap
        PartialAsset.personalValuationMissing = [] := by
  induction assets with
  | nil => rfl
  | cons head tail ih =>
      simp [ih]

@[simp] private theorem smallRealFold_ofTotal
    (assets : List Asset) (initial : Money) :
    (assets.map PartialAsset.ofTotal).foldl
        (fun total asset => total + asset.smallRealLowerBound)
        initial =
      assets.foldl
        (fun total asset => total + asset.countedCaliforniaRealValue)
        initial := by
  induction assets generalizing initial with
  | nil => rfl
  | cons head tail ih =>
      simp only [List.map_cons, List.foldl_cons,
        smallRealLowerBound_ofTotal]
      exact ih _

@[simp] private theorem smallRealMissing_ofTotal
    (assets : List Asset) :
    (assets.map PartialAsset.ofTotal).flatMap
        PartialAsset.smallRealValuationMissing = [] := by
  induction assets with
  | nil => rfl
  | cons head tail ih =>
      simp [ih]

@[simp] private theorem primaryResidenceFold_ofTotal
    (assets : List Asset) (initial : Money) :
    (assets.map PartialAsset.ofTotal).foldl
        (fun total asset => total + asset.primaryResidenceLowerBound)
        initial =
      assets.foldl
        (fun total asset => total + asset.countedPrimaryResidenceValue)
        initial := by
  induction assets generalizing initial with
  | nil => rfl
  | cons head tail ih =>
      simp only [List.map_cons, List.foldl_cons,
        primaryResidenceLowerBound_ofTotal]
      exact ih _

@[simp] private theorem primaryResidenceMissing_ofTotal
    (assets : List Asset) :
    (assets.map PartialAsset.ofTotal).flatMap
        PartialAsset.primaryResidenceValuationMissing = [] := by
  induction assets with
  | nil => rfl
  | cons head tail ih =>
      simp [ih]

theorem personalValuation_ofTotal_exact
    (estate : Estate) (thresholds : Thresholds) :
    (PartialEstate.ofTotal estate).personalAffidavitValuation thresholds = {
      lowerBound := estate.personalAffidavitValueWith thresholds
      exactValue := some (estate.personalAffidavitValueWith thresholds)
      missingFields := []
      needsCompleteInventory := false
    } := by
  simp [PartialEstate.ofTotal,
    PartialEstate.personalAffidavitValuation,
    PartialEstate.valuation,
    Estate.personalAffidavitValueWith,
    Estate.aggregateEmploymentCompensation,
    List.map_map, Function.comp_def,
    dedupStable]

theorem smallRealPropertyValuation_ofTotal_exact
    (estate : Estate) :
    (PartialEstate.ofTotal estate).smallRealPropertyValuation = {
      lowerBound := estate.smallValueRealPropertyValue
      exactValue := some estate.smallValueRealPropertyValue
      missingFields := []
      needsCompleteInventory := false
    } := by
  simp [PartialEstate.ofTotal,
    PartialEstate.smallRealPropertyValuation,
    PartialEstate.valuation,
    Estate.smallValueRealPropertyValue,
    List.map_map, Function.comp_def,
    dedupStable]

theorem primaryResidenceValuation_ofTotal_exact
    (estate : Estate) :
    (PartialEstate.ofTotal estate).primaryResidenceValuation = {
      lowerBound := estate.primaryResidenceValue
      exactValue := some estate.primaryResidenceValue
      missingFields := []
      needsCompleteInventory := false
    } := by
  simp [PartialEstate.ofTotal,
    PartialEstate.primaryResidenceValuation,
    PartialEstate.valuation,
    Estate.primaryResidenceValue,
    List.map_map, Function.comp_def,
    dedupStable]

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
