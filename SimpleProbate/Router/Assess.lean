import SimpleProbate.Router.Flags
import SimpleProbate.Router.Deadlines
import SimpleProbate.Router.Florida
import SimpleProbate.Router.Federal

/-!
# The settlement router

Assembly. An `IntakeCase` in, a `SettlementAssessment` out, or the contract's
error envelope — and nothing in between, because a structural problem is not a
legal conclusion and must never be reported as one.

Order of work:

1. **Structural validation.** An unusable `as_of_date`, a death date that is
   not a valid civil date, a death date beyond the source snapshot, a death
   date after the as-of date, duplicate asset names. Each is a typed error.
2. **Classify every asset** (`SimpleProbate.Router.Classify`) and total the
   probate estate.
3. **Route by domicile** (`SimpleProbate.Router.California`) and add an
   ancillary entry for every out-of-domicile parcel.
4. **Screen** (`SimpleProbate.Router.Flags`) and **date**
   (`SimpleProbate.Router.Deadlines`).
5. **Reconcile the unknowns.** `unresolved_facts` is the deduplicated,
   order-stable union of every missing fact path anywhere in the response.
   The product asks its next question from this list, so a path that is
   missing from it is a question the product will never ask.
-/

namespace SimpleProbate
namespace Router

/-- The legal-source snapshot this build was compiled against. `README.md` and
`Main.lean` carry the same date; it is the date the sources were read, not the
date of the request. -/
def sourceSnapshot : Snapshot :=
  { sourceAsOf := "2026-07-28", supportedDeathDatesThrough := isoDate snapshotEnd }

/-! ## Jurisdiction routing -/

/--
The domicile entry. California is routed by `californiaJurisdiction`
(`SimpleProbate.Eligibility` behind it), Florida by `floridaJurisdiction`
(`SimpleProbate.FL` behind it). The Florida threshold is date-of-death banded
(≤ $75,000 before 2026-07-01, ≤ $150,000 on or after, CS/HB 1337) and both
bands stay live at once; that banding lives in `SimpleProbate.FL.Thresholds`,
exactly as CA's lives in `SimpleProbate.Thresholds`.

An unknown domicile deliberately produces no jurisdiction at all rather than a
default one: guessing the forum is the one error that invalidates everything
downstream of it.
-/
def domicileJurisdiction (c : IntakeCase) (m : List AssetClassification) :
    Except CaseError (Option JurisdictionReport) :=
  match c.decedent.domicileState with
  | some "CA" => (californiaJurisdiction c m).map some
  | some "FL" => (floridaJurisdiction c .domicile).map some
  | _ => .ok none

/--
One `role: "ancillary"` entry per out-of-domicile situs state of real
property. Real property is administered where it sits, so a parcel outside the
domicile state needs its own proceeding there whatever the domicile state's
routes say.

A modelled state gets real routes: Florida's valuation bounds already count
only `situs_state == "FL"` property, so the ancillary entry is the same
assessment restricted to the Florida parcel. A state this build does not model
gets an entry with no routes, and the `ancillary_probate_required` flag carries
the explanation and the citation.
-/
def ancillaryEntries (c : IntakeCase) : Except CaseError (List JurisdictionReport) :=
  let build : String → Except CaseError JurisdictionReport := fun code =>
    match code with
    | "FL" => floridaJurisdiction c .ancillary
    | _ =>
      .ok { code := code, role := .ancillary, verdict := .otherFormRequired,
            routes := [] }
  (ancillaryStates c).foldl
    (fun acc code => do
      let entries ← acc
      let entry ← build code
      pure (entries ++ [entry]))
    (.ok [])

/-! ## Next actions -/

private def qualifyingRoutes (js : List JurisdictionReport) : List String :=
  concatMap
    (fun (j : JurisdictionReport) =>
      (j.routes.filter fun r => r.status == .qualifies).map (·.route))
    js

private def actionForRoute : String → Option (String × String)
  | "ca_personal_property_affidavit" =>
    some ("file_personal_property_affidavit",
      "Prepare the affidavit for collection of personal property (DE-300) and present it, with a certified death certificate, to each holder.")
  | "ca_small_value_real_property_affidavit" =>
    some ("file_small_value_real_property_affidavit",
      "File the affidavit re real property of small value (DE-305) with the court, with a probate referee's Inventory and Appraisal attached.")
  | "ca_primary_residence_petition" =>
    some ("file_primary_residence_petition",
      "File the petition to determine succession to real property (DE-310) and lodge the proposed order (DE-315).")
  | "ca_spousal_property_petition" =>
    some ("file_spousal_property_petition",
      "File the spousal or domestic partner property petition (DE-221) to confirm the property passing to the surviving spouse.")
  | "ca_formal_probate_or_other" =>
    some ("open_formal_probate",
      "Petition for probate (DE-111) and for letters, so a personal representative has authority to act.")
  | _ => none

private def routeActions : List String → List NextAction
  | [] => []
  | route :: rest =>
    match actionForRoute route with
    | some (id, label) => { id := id, label := label, blockedBy := [] } :: routeActions rest
    | none => routeActions rest

def nextActionsOf (c : IntakeCase) (m : List AssetClassification)
    (js : List JurisdictionReport) (flags : List Flag) : List NextAction :=
  let certificateBlockers : List FactPath :=
    (if c.decedent.deathCertificateFinal == some false then
      [decedentPath "death_certificate_final"] else []) ++
    (if c.decedent.mannerOfDeath == some .pending ||
        c.decedent.mannerOfDeath == some .undetermined then
      [decedentPath "manner_of_death"] else [])
  let classificationGaps :=
    dedup (concatMap
      (fun (a : AssetClassification) =>
        if a.classification == .unknown then a.missingFacts else [])
      m)
  let counselAction : List NextAction :=
    if flags.any fun f => f.severity == .critical then
      [{ id := "consult_counsel"
         label := "Stop and speak to a probate attorney before transferring anything — a critical issue is flagged below."
         blockedBy := [] }]
    else []
  let domicileAction : List NextAction :=
    if c.decedent.domicileState.isNone then
      [{ id := "provide_domicile_state"
         label := "Supply the state the decedent was domiciled in — no forum can be identified without it."
         blockedBy := [decedentPath "domicile_state"] }]
    else []
  let inventoryAction : List NextAction :=
    if c.inventoryComplete == some true then []
    else
      [{ id := "complete_asset_inventory"
         label := "Confirm the asset list is complete. Every value cap in this assessment is measured against the whole estate, so an incomplete list cannot support a qualifying answer."
         blockedBy := ["inventory_complete"] }]
  let titleAction : List NextAction :=
    if classificationGaps.isEmpty then []
    else
      [{ id := "confirm_title_and_beneficiary_designations"
         label := "Pull the title documents and beneficiary designations for the assets still unclassified — these decide what is in the probate estate at all."
         blockedBy := classificationGaps }]
  let ssaAction : List NextAction :=
    if c.decedent.survivingSpouse == some true ||
        c.heirs.any (·.relationship == some .child) then
      [{ id := "apply_for_ssa_lump_sum"
         label := "Apply to Social Security for the lump-sum death payment; the claim expires two years after the death."
         blockedBy := [] }]
    else []
  counselAction ++
  [{ id := "obtain_death_certificate"
     label := "Order 10–15 certified copies of the death certificate. Every holder of an asset will want its own."
     blockedBy := certificateBlockers }] ++
  domicileAction ++ inventoryAction ++ titleAction ++
  routeActions (qualifyingRoutes js) ++
  [{ id := "file_final_income_tax_return"
     label := "Calendar the decedent's final income tax return."
     blockedBy := if c.decedent.deathDate.isNone then [decedentPath "death_date"] else [] }] ++
  ssaAction

/-! ## Notes -/

def notesOf (c : IntakeCase) (federal : List FederalReport) : List String :=
  let domicileNote : List String :=
    match c.decedent.domicileState with
    | none =>
      ["The decedent's domicile state has not been supplied, so no state routes are reported. Domicile decides the forum, and this engine does not guess it."]
    | some "CA" =>
      ["California route eligibility reads the intake's heir list as the caller's own statement of who the successors in interest are, and `conflict_signals: false` as the statement that nobody claims a superior right. Those are the attestations the §13101 affidavit requires the signer to make under penalty of perjury; they are treated as supplied here, not as verified."]
    | some "FL" =>
      ["Florida measures summary administration against the estate subject to administration in Florida, less property exempt from creditors' claims, and the limit is set by the date of death: $75,000 before 2026-07-01 and $150,000 on or after it (CS/HB 1337). An asset with no situs_state is counted neither in nor out, because the test is confined to Florida property.",
       "Florida has no statewide numbered small-estate forms answering to California's DE-series — these are Florida Probate Rules petitions filed on circuit-court forms that vary by county — so no form numbers are reported for the Florida routes."]
    | some other =>
      [s!"Domicile state {other} is outside the jurisdictions this build models. No state routes are reported for it; the asset classification, flags and federal items above are still jurisdiction-general."]
  let valuationNote : List String :=
    if c.decedent.domicileState == some "CA" then
      ["California measures its small-estate caps by the gross value of the decedent's property, before any mortgage or lien. Encumbrances are recorded on the assets but never subtracted from a cap test."]
    else []
  let ancillaryNote : List String :=
    match ancillaryStates c with
    | [] => []
    | states =>
      [s!"Real property is administered where it sits: {String.intercalate ", " states} appears as an ancillary jurisdiction because a parcel there cannot be cleared by the domicile state's proceeding."]
  let federalNote : List String :=
    if federal.isEmpty then
      ["Federal items (IRS Form 1310 and the Social Security lump-sum death payment) are produced by a separate module that is not wired into this build."]
    else
      ["The Social Security ladder does not read heirs[i].relationship to decide entitlement to child's insurance benefits: §402(d) entitlement does not track the probate label, so heirs[i].entitled_to_child_benefits_month_of_death is used exactly as supplied and asked for when it is absent."]
  domicileNote ++ valuationNote ++ ancillaryNote ++ federalNote

/-! ## Unresolved facts

The union of every unknown in the response, in the order the reader meets
them: the two case-level facts that block everything, then the asset map, the
estate total, the routes, and the federal items. -/

def unresolvedFactsOf (c : IntakeCase) (m : List AssetClassification)
    (estate : ProbateEstate) (js : List JurisdictionReport)
    (federal : List FederalReport) : List FactPath :=
  let caseLevel : List FactPath :=
    (if c.decedent.deathDate.isNone then [decedentPath "death_date"] else []) ++
    (if c.decedent.domicileState.isNone then [decedentPath "domicile_state"] else [])
  let assetFacts := concatMap (fun (a : AssetClassification) => a.missingFacts) m
  let routeFacts :=
    concatMap
      (fun (j : JurisdictionReport) =>
        concatMap (fun (r : RouteRow) => r.missingFacts) j.routes)
      js
  let federalFacts := concatMap (fun (f : FederalReport) => f.missingFacts) federal
  dedup (caseLevel ++ assetFacts ++ estate.missingFacts ++ routeFacts ++ federalFacts)

/-! ## Structural validation -/

private def duplicateName : List String → List String → Option String
  | _, [] => none
  | seen, n :: rest => if seen.contains n then some n else duplicateName (n :: seen) rest

/-- Validate the shape of the case. These are structural facts about the
request, never conclusions about the estate. -/
def validate (c : IntakeCase) : Except RouterError Unit := do
  if !c.asOfDate.valid then
    throw ⟨"malformed_case", s!"as_of_date {isoDate c.asOfDate} is not a valid civil date."⟩
  match duplicateName [] (c.assets.map (·.name)) with
  | some n =>
    throw ⟨"malformed_case", s!"asset names must be unique within assets; '{n}' appears more than once."⟩
  | none => pure ()
  match c.decedent.deathDate with
  | none => pure ()
  | some d =>
    match classifyDeathDate d with
    | .error .invalidDate =>
      throw ⟨"invalid_date", s!"death_date {isoDate d} is not a valid civil date."⟩
    | .error .afterSnapshot =>
      throw ⟨"after_snapshot",
        s!"death_date {isoDate d} is after the source snapshot ({isoDate snapshotEnd})."⟩
    | .ok _ =>
      if !d.atMost c.asOfDate then
        throw ⟨"malformed_case",
          s!"death_date {isoDate d} is after as_of_date {isoDate c.asOfDate}."⟩

/-- Case errors escaping the CA engine. Every one of them is pre-empted by
`validate`, so this is a total fallback rather than a live path. -/
def liftCaseError : CaseError → RouterError
  | .invalidDate => ⟨"invalid_date", "The supplied death date is not a valid civil date."⟩
  | .afterSnapshot =>
    ⟨"after_snapshot",
      s!"The death date is after {isoDate snapshotEnd}, the model's supported snapshot end."⟩
  | .malformedCase detail => ⟨"malformed_case", detail⟩

/-! ## The assessment -/

def assessWith (federal : List FederalReport) (c : IntakeCase) :
    Except RouterError SettlementAssessment := do
  validate c
  let assetMap := assetMapOf c
  let estate := probateEstateOf c assetMap
  let domicile ←
    match domicileJurisdiction c assetMap with
    | .ok j => pure j
    | .error e => throw (liftCaseError e)
  let ancillary ←
    match ancillaryEntries c with
    | .ok js => pure js
    | .error e => throw (liftCaseError e)
  let jurisdictions := (match domicile with | some j => [j] | none => []) ++ ancillary
  let flags := flagsOf c assetMap estate
  pure {
    snapshot := sourceSnapshot
    assetMap := assetMap
    probateEstate := estate
    jurisdictions := jurisdictions
    federal := federal
    flags := flags
    deadlines := deadlinesOf c
    nextActions := nextActionsOf c assetMap jurisdictions flags
    unresolvedFacts := unresolvedFactsOf c assetMap estate jurisdictions federal
    notes := notesOf c federal
  }

/-- The whole assessment, federal items included. `assessWith` is kept as the
seam the regression suite drives with a fixed federal array; this is the entry
point the executable calls. -/
def assess (c : IntakeCase) : Except RouterError SettlementAssessment := do
  -- Validated first, so a structural problem is reported once, by the Router,
  -- rather than twice in two vocabularies.
  validate c
  let federal ←
    match federalRowsOf c with
    | .ok rows => pure rows
    | .error e => throw (liftCaseError e)
  assessWith federal c

end Router
end SimpleProbate
