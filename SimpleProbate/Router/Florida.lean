import SimpleProbate.Router.California
import SimpleProbate.FL.Assess

/-!
# Florida adapter

`SimpleProbate.FL` owns Florida's three routes and their two-sided valuation
bounds; this module is the join between the contract's `IntakeCase` and that
module's `PartialCase`, and back onto the wire `JurisdictionReport`.

Two things are worth a reviewer's attention.

**Nothing is inferred across the seam.** The contract's richer `kind` enum
collapses onto Florida's real/personal distinction exactly as
`FL.AssetKind.ofWireName` does — `"other"` settles nothing and stays unknown.
`situs_state` is passed through as supplied and is *not* defaulted to the
domicile: Florida's §735.201 test is confined to the estate subject to
administration *in Florida*, so a defaulted situs would be an assumption
doing real work inside a cap test. An absent situs surfaces as
`assets[i].situs_state` in `missing_facts`, which is a question the product
can ask.

**The verdict is the Router's, not the module's.** `FL.Assessment` carries its
own verdict, which promotes a qualifying route over an open question. The
Router applies the same precedence to every jurisdiction — any
`needs_information` row means `INCOMPLETE_INFO` — so the wire verdict is
recomputed here with `verdictOf` (the CA rows' rule), and the module's own
verdict is used only inside the module's proofs. Two jurisdictions in one
response must not grade themselves on different curves.
-/

namespace SimpleProbate
namespace Router

/-! ## Intake → `FL.PartialCase` -/

/-- The contract's `assets[i].kind` as Florida reads it. `other` does not
settle real vs personal and stays unknown, never "personal". -/
private def flAssetKind : AssetKind → Option FL.AssetKind
  | .realProperty => some .realProperty
  | .bank | .brokerage | .retirement | .lifeInsurance | .vehicle
  | .personal | .business | .digital | .employmentComp => some .personal
  | .other => none

private def flTitleForm : TitleForm → FL.TitleForm
  | .sole => .sole
  | .jtwros => .jtwros
  | .tenancyByEntirety => .tenancyByEntirety
  | .communityWithRos => .communityWithRos
  | .tenantsInCommon => .tenantsInCommon
  | .trustFunded => .trustFunded
  | .custodial => .custodial

private def flBeneficiaryDesignation :
    BeneficiaryDesignation → FL.BeneficiaryDesignation
  | .namedLiving => .namedLiving
  | .namedPredeceased => .namedPredeceased
  | .estate => .estate
  | .none => .noDesignation
  | .unsure => .unsure

private def flWillStatus : WillStatus → FL.WillStatus
  | .validOriginal => .validOriginal
  | .copyOnly => .copyOnly
  | .holographic => .holographic
  | .none => .noWill
  | .unsure => .unsure

private def flAssets : List IntakeAsset → List FL.PartialAsset
  | [] => []
  | a :: rest =>
    { name := a.name
      kind := a.kind.bind flAssetKind
      situsState := a.situsState
      grossValue := a.grossValueCents
      titleForm := a.titleForm.map flTitleForm
      beneficiaryDesignation := a.beneficiaryDesignation.map flBeneficiaryDesignation
      isPrimaryResidence := a.isPrimaryResidence
      exemptFromCreditors := a.exemptFromCreditors } :: flAssets rest

def floridaCaseOf (c : IntakeCase) : FL.PartialCase :=
  { deathDate := c.decedent.deathDate
    asOfDate := c.asOfDate
    assets := flAssets c.assets
    expenses :=
      { funeralExpenses := c.expenses.preferredFuneralCents
        lastIllnessMedicalExpenses := c.expenses.lastIllnessMedicalCents }
    willStatus := c.decedent.willStatus.map flWillStatus
    willDirectsAdministration := c.decedent.willDirectsAdministration
    administrationPending := c.decedent.administrationPending
    inventoryComplete := c.inventoryComplete }

/-! ## `FL.RouteReport` → wire row -/

private def flReasonOf (d : Disqualifier) : Reason := ⟨d.id, d.text⟩

private def flRowOf (r : FL.RouteReport) : RouteRow :=
  let (rowStatus, reasons, missing) :=
    match r.status with
    | .qualifies => (RowStatus.qualifies, ([] : List Reason), ([] : List FactPath))
    | .doesNotQualify rs => (RowStatus.doesNotQualify, rs.map flReasonOf, [])
    -- Florida's fact paths are already `IntakeCase` paths, so unlike the CA
    -- adapter there is no vocabulary to translate back.
    | .needsInformation facts => (RowStatus.needsInformation, [], facts)
  { route := r.route.wireName
    label := r.route.label
    status := rowStatus
    reasons := reasons
    missingFacts := missing
    forms := r.route.forms
    citations := r.route.citations.map fun c => ⟨c.label, c.url⟩ }

/-- A route that could not be asked at all, because the intake lists no
assets. Mirrors the California adapter's row of the same name: an empty list
is not the same claim as an estate worth nothing. -/
private def flNoAssetsRow (route : FL.RouteId) : RouteRow :=
  { route := route.wireName
    label := route.label
    status := .needsInformation
    reasons := []
    missingFacts := ["assets"]
    forms := route.forms
    citations := route.citations.map fun c => ⟨c.label, c.url⟩ }

/-! ## The jurisdiction entry -/

/-- Florida's rows for a case.

The same call serves the domicile entry and an ancillary one: Florida's
valuation bounds already count only the property whose `situs_state` is
`"FL"`, because §735.201 measures the estate subject to administration *in
this state*. `role` therefore changes the label on the entry, not the law
applied to it. -/
def floridaRoutes (c : IntakeCase) : Except CaseError (List RouteRow) :=
  if c.assets.isEmpty then
    .ok [flNoAssetsRow .dispositionWithoutAdministration,
         flNoAssetsRow .summaryAdministration,
         flNoAssetsRow .formalAdministration]
  else
    (FL.assessRoutes (floridaCaseOf c)).map fun a => a.routes.map flRowOf

def floridaJurisdiction (c : IntakeCase) (role : JurisdictionRole) :
    Except CaseError JurisdictionReport := do
  let rows ← floridaRoutes c
  pure { code := "FL", role := role, verdict := verdictOf rows, routes := rows }

end Router
end SimpleProbate
