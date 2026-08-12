import SimpleProbate.Partial
import SimpleProbate.FL.Eligibility

/-!
# Florida routes under partial information

Mirrors `SimpleProbate.FL.Eligibility` conjunct by conjunct over `Option`-valued
facts, reusing the generic tristate machinery from `SimpleProbate.Partial`
(`AtomicResult`, `Disqualifier`, `RouteStatus`, `aggregate`, `FactPath`,
`CaseError`, `Money.formatUSD`). Unknown is never false; a known violation beats
an unknown.

## Why Florida needs its own valuation check

California's `capCheck` compares one known subtotal against one statutory cap.
Florida's §735.201(2) test subtracts *property exempt from the claims of
creditors* before comparing, and §735.301 compares against an expense allowance
rather than a fixed figure. A single subtotal cannot express either soundly, so
this module computes two bounds over every completion of the unknown facts:

* **lower** — assets known to count, with known values. `lower > cap` is a real
  violation no matter how the unknowns resolve.
* **upper** — assets not *known* to be excluded, counted at full value with any
  unproved exemption ignored. `upper ≤ cap` is real satisfaction no matter how
  the unknowns resolve. In particular an unknown exemption never blocks
  qualification: exemptions only ever subtract.

Between the two the answer is genuinely unknown, and the facts that separate the
bounds are exactly what the caller must go and find. (`SimpleProbate.capCheck`
is `private` to the California module; this is the Florida shape, not a copy.)

## Fact paths

Contract `IntakeCase` fields: `decedent.death_date`, `decedent.will_status`,
`inventory_complete`, and per asset `kind`, `situs_state`, `gross_value_cents`,
`title_form`, `beneficiary_designation`, `is_primary_residence`.

Florida-specific additions, in the same shape:
`assets[i].exempt_from_creditors`, `decedent.will_directs_administration`,
`decedent.administration_pending`, `expenses.preferred_funeral_cents`,
`expenses.last_illness_medical_cents`.

Sources retrieved 2026-08-12: Fla. Stat. §§735.201, 735.301, 735.304,
733.707(1)(b), 732.402; Fla. Const. art. X, §4(a)(1); Fla. Stat. ch. 733;
CS/HB 1337 (2026), eff. 2026-07-01.
-/

namespace SimpleProbate.FL

/-! ## Wire vocabulary -/

/-- Stable route ids from the settlement contract. -/
inductive RouteId
  | dispositionWithoutAdministration
  | summaryAdministration
  | formalAdministration
deriving BEq, DecidableEq, Repr

def RouteId.wireName : RouteId → String
  | .dispositionWithoutAdministration => "fl_disposition_without_administration"
  | .summaryAdministration => "fl_summary_administration"
  | .formalAdministration => "fl_formal_administration"

def RouteId.label : RouteId → String
  | .dispositionWithoutAdministration =>
      "Disposition of personal property without administration"
  | .summaryAdministration => "Summary administration"
  | .formalAdministration => "Formal administration"

/-- Florida has no statewide numbered small-estate forms answering to
California's DE-series: these petitions are governed by the Florida Probate
Rules and filed on circuit-court forms that vary by county. Rather than invent
numbers, this module reports none. -/
def RouteId.forms : RouteId → List String
  | _ => []

structure Citation where
  label : String
  url : Option String := none
deriving BEq, DecidableEq, Repr

def RouteId.citations : RouteId → List Citation
  | .dispositionWithoutAdministration =>
      [⟨"Fla. Stat. §735.301", none⟩,
       ⟨"Fla. Stat. §735.304", none⟩,
       ⟨"Fla. Stat. §733.707(1)(b)", none⟩]
  | .summaryAdministration =>
      [⟨"Fla. Stat. §735.201", none⟩,
       ⟨"CS/HB 1337 (2026), eff. 2026-07-01", none⟩]
  | .formalAdministration =>
      [⟨"Fla. Stat. ch. 733", none⟩]

/-- The contract's per-jurisdiction verdict. -/
inductive Verdict
  | eligible
  | incompleteInfo
  | otherFormRequired
deriving BEq, DecidableEq, Repr

def Verdict.wireName : Verdict → String
  | .eligible => "ELIGIBLE"
  | .incompleteInfo => "INCOMPLETE_INFO"
  | .otherFormRequired => "OTHER_FORM_REQUIRED"

structure RouteReport where
  route : RouteId
  status : RouteStatus
  /-- One line, non-empty only when the route qualifies. -/
  detail : String
deriving BEq, DecidableEq, Repr

structure Assessment where
  /-- Stable order: disposition, summary, then the fallback. -/
  routes : List RouteReport
  verdict : Verdict
  unresolvedFacts : List FactPath
deriving BEq, DecidableEq, Repr

/-! ## Fact paths -/

def assetFact (index : Nat) (field : String) : FactPath :=
  s!"assets[{index}].{field}"

def deathDateFact : FactPath := "decedent.death_date"
def willStatusFact : FactPath := "decedent.will_status"
def willDirectsFact : FactPath := "decedent.will_directs_administration"
def administrationPendingFact : FactPath := "decedent.administration_pending"
def inventoryCompleteFact : FactPath := "inventory_complete"
def funeralExpenseFact : FactPath := "expenses.preferred_funeral_cents"
def lastIllnessFact : FactPath := "expenses.last_illness_medical_cents"

/-! ## Partially known inputs -/

/-- `Option`-mirror of `Asset`. `none` means unknown, never false or zero. -/
structure PartialAsset where
  name : String
  kind : Option AssetKind := none
  situsState : Option String := none
  grossValue : Option Money := none
  titleForm : Option TitleForm := none
  beneficiaryDesignation : Option BeneficiaryDesignation := none
  isPrimaryResidence : Option Bool := none
  exemptFromCreditors : Option Bool := none
deriving DecidableEq, Repr

/-- `Option`-mirror of `Expenses`. -/
structure PartialExpenses where
  funeralExpenses : Option Money := none
  lastIllnessMedicalExpenses : Option Money := none
deriving DecidableEq, Repr

/-- `Option`-mirror of `Case`. `asOfDate` is the contract's required
`as_of_date`, so it is total. -/
structure PartialCase where
  deathDate : Option CivilDate := none
  asOfDate : CivilDate
  assets : List PartialAsset := []
  expenses : PartialExpenses := {}
  willStatus : Option WillStatus := none
  willDirectsAdministration : Option Bool := none
  administrationPending : Option Bool := none
  /-- The contract's single completeness gate. Florida reads it for the asset
  list and, for §735.301/§735.304, for the expense list too: an unlisted expense
  would enlarge the allowance. -/
  inventoryComplete : Option Bool := none
deriving DecidableEq, Repr

/-! ## Derived tristate facts -/

/-- Disjunction over partially known booleans: a known `true` settles it, two
known `false`s settle it, anything else is unknown. -/
private def orOpt : Option Bool → Option Bool → Option Bool
  | some true, _ => some true
  | _, some true => some true
  | some false, some false => some false
  | _, _ => none

/-- Mirrors `Asset.subjectToAdministration`. -/
def PartialAsset.passesOutsideAdministration (asset : PartialAsset) :
    Option Bool :=
  orOpt (asset.titleForm.map TitleForm.passesOutsideAdministration)
    (asset.beneficiaryDesignation.bind
      BeneficiaryDesignation.passesOutsideAdministration)

def PartialAsset.subjectToAdministration (asset : PartialAsset) : Option Bool :=
  asset.passesOutsideAdministration.map (!·)

/-- The wire fields that would settle `subjectToAdministration`. Non-empty
exactly when it is unknown. -/
def PartialAsset.administrationFacts
    (index : Nat) (asset : PartialAsset) : List FactPath :=
  (if asset.titleForm.isNone then [assetFact index "title_form"] else []) ++
  (if asset.beneficiaryDesignation.isNone ||
      asset.beneficiaryDesignation == some .unsure then
    [assetFact index "beneficiary_designation"]
  else [])

/-- Mirrors `Asset.protectedHomestead`. -/
def PartialAsset.protectedHomestead (asset : PartialAsset) : Option Bool :=
  match asset.kind, asset.isPrimaryResidence, asset.situsState with
  | some .personal, _, _ => some false
  | _, some false, _ => some false
  | some .realProperty, some true, some situs => some (situs == "FL")
  | _, _, _ => none

/-- Mirrors `Asset.exemptFromCreditorClaims`. -/
def PartialAsset.exemptFromCreditorClaims (asset : PartialAsset) : Option Bool :=
  orOpt asset.protectedHomestead asset.exemptFromCreditors

/-- The wire fields that would settle `exemptFromCreditorClaims`. Non-empty
exactly when it is unknown. -/
def PartialAsset.exemptionFacts
    (index : Nat) (asset : PartialAsset) : List FactPath :=
  (if asset.exemptFromCreditors.isNone then
    [assetFact index "exempt_from_creditors"]
  else []) ++
  (if asset.kind.isNone then [assetFact index "kind"] else []) ++
  (if asset.isPrimaryResidence.isNone then
    [assetFact index "is_primary_residence"]
  else []) ++
  (if asset.situsState.isNone then [assetFact index "situs_state"] else [])

/-- Mirrors `Asset.inFloridaAdministration`. -/
def PartialAsset.inFloridaAdministration (asset : PartialAsset) : Option Bool :=
  asset.situsState.map (· == "FL")

/-! ## Two-sided valuation bounds -/

/-- Could still count toward the valuation: excluded only by a KNOWN fact.
`personalOnly` restricts to personal property (§735.301, §735.304); real
property that is not yet known to be real property still counts. -/
def PartialAsset.mayCount (personalOnly : Bool) (asset : PartialAsset) : Bool :=
  asset.inFloridaAdministration != some false &&
  asset.subjectToAdministration != some false &&
  asset.exemptFromCreditorClaims != some true &&
  !(personalOnly && asset.kind == some .realProperty)

/-- Certainly counts toward the valuation: every gating fact is known and
favourable. -/
def PartialAsset.mustCount (personalOnly : Bool) (asset : PartialAsset) : Bool :=
  asset.inFloridaAdministration == some true &&
  asset.subjectToAdministration == some true &&
  asset.exemptFromCreditorClaims == some false &&
  (!personalOnly || asset.kind == some .personal)

/-- The facts that separate "may count" from "must count" for one asset.
Non-empty whenever `mayCount` holds and `mustCount` does not. -/
def PartialAsset.separationFacts
    (personalOnly : Bool) (index : Nat) (asset : PartialAsset) : List FactPath :=
  (if asset.inFloridaAdministration.isNone then
    [assetFact index "situs_state"]
  else []) ++
  (if asset.subjectToAdministration.isNone then
    asset.administrationFacts index
  else []) ++
  (if asset.exemptFromCreditorClaims.isNone then
    asset.exemptionFacts index
  else []) ++
  (if personalOnly && asset.kind.isNone then [assetFact index "kind"] else [])

/-- Bounds on a Florida valuation across every completion of the unknowns. -/
structure ValueBounds where
  /-- Sum over assets that must count and whose value is known. -/
  lower : Money
  /-- Sum over assets that may count; `none` when one of their values is
  unknown. -/
  upper : Option Money
  /-- Facts blocking `upper`. Non-empty exactly when `upper` is `none`. -/
  upperFacts : List FactPath
  /-- Facts separating `lower` from `upper`. -/
  separatingFacts : List FactPath
deriving Repr

private def valueBoundsAux (personalOnly : Bool) :
    Nat → List PartialAsset → ValueBounds
  | _, [] =>
    { lower := 0, upper := some 0, upperFacts := [], separatingFacts := [] }
  | index, asset :: rest =>
    let tail := valueBoundsAux personalOnly (index + 1) rest
    if !asset.mayCount personalOnly then
      tail
    else
      let counts := asset.mustCount personalOnly
      { lower :=
          match counts, asset.grossValue with
          | true, some value => tail.lower + value
          | _, _ => tail.lower
        upper :=
          match asset.grossValue with
          | some value => tail.upper.map (· + value)
          | none => none
        upperFacts :=
          match asset.grossValue with
          | some _ => tail.upperFacts
          | none => assetFact index "gross_value_cents" :: tail.upperFacts
        separatingFacts :=
          if counts then tail.separatingFacts
          else asset.separationFacts personalOnly index ++ tail.separatingFacts }

def valueBounds (personalOnly : Bool) (assets : List PartialAsset) :
    ValueBounds :=
  valueBoundsAux personalOnly 0 assets

/-! ## Atomic checks -/

private def dq (id text : String) : Disqualifier := ⟨id, text⟩

/-- First-occurrence-preserving deduplication (mirrors the private helper in
`SimpleProbate.Partial`). -/
private def dedupAux [BEq α] (seen : List α) : List α → List α
  | [] => []
  | x :: xs => if seen.contains x then dedupAux seen xs else x :: dedupAux (x :: seen) xs

private def dedup [BEq α] (xs : List α) : List α := dedupAux [] xs

/-- The estate-valuation conjunct of a Florida route. See the module docstring
for why this is two-sided rather than a single subtotal.

`capIsExpenseAllowance` marks a cap that can only *grow* as more facts arrive
(the §735.301/§735.304 expense allowance). Satisfaction is still sound — a
growing cap only helps — but a violation additionally requires the expense list
to be complete. A statutory cap passes `false`. -/
private def valueCheck
    (bounds : ValueBounds) (cap : Option Money) (capFacts : List FactPath)
    (capIsExpenseAllowance : Bool) (inventoryComplete : Option Bool)
    (citation overCapId valueLabel : String) : AtomicResult × String :=
  match cap with
  | none => (.unknown capFacts, "")
  | some cap =>
    let inventoryFacts :=
      if inventoryComplete == some true then [] else [inventoryCompleteFact]
    let capFinalFacts := if capIsExpenseAllowance then inventoryFacts else []
    if capFinalFacts.isEmpty && bounds.lower > cap then
      (.violated (dq overCapId
        s!"{citation}: known {valueLabel} {Money.formatUSD bounds.lower} exceeds the {Money.formatUSD cap} limit"),
       "")
    else
      match bounds.upper with
      | none => (.unknown (dedup (bounds.upperFacts ++ inventoryFacts)), "")
      | some upper =>
        if upper ≤ cap then
          if inventoryFacts.isEmpty then
            (.satisfied,
             s!"{citation}: qualifying {valueLabel} {Money.formatUSD upper} ≤ {Money.formatUSD cap} limit")
          else
            (.unknown inventoryFacts, "")
        else
          let facts :=
            dedup (bounds.separatingFacts ++ inventoryFacts ++ capFinalFacts)
          if facts.isEmpty then
            -- Every fact is known and `upper` = `lower` > cap, so this is a
            -- violation. Written out so the function can never fall through to
            -- a satisfied check.
            (.violated (dq overCapId
              s!"{citation}: {valueLabel} {Money.formatUSD upper} exceeds the {Money.formatUSD cap} limit"),
             "")
          else
            (.unknown facts, "")

/-- Fla. Stat. §735.301(1) / §735.304: the estate must leave only personal
property. A single asset known to be administrable real property is a violation
even while other assets are unknown. -/
private def realPropertyAux :
    Nat → List PartialAsset → Bool × List FactPath
  | _, [] => (false, [])
  | index, asset :: rest =>
    let (violated, facts) := realPropertyAux (index + 1) rest
    match asset.kind, asset.subjectToAdministration with
    | some .personal, _ => (violated, facts)
    | _, some false => (violated, facts)
    | some .realProperty, some true => (true, facts)
    | some .realProperty, none =>
      (violated, asset.administrationFacts index ++ facts)
    | none, subject =>
      (violated,
        assetFact index "kind" ::
          ((if subject.isNone then asset.administrationFacts index else []) ++
            facts))

private def realPropertyCheck (assets : List PartialAsset) : AtomicResult :=
  let (violated, facts) := realPropertyAux 0 assets
  if violated then
    .violated (dq "estate_includes_real_property"
      "Fla. Stat. §§735.301, 735.304: the decedent left real property to be administered, so no disposition without administration is available")
  else if facts.isEmpty then
    .satisfied
  else
    .unknown (dedup facts)

/-- Statutory disjunction over atomic checks: either branch satisfying settles
it; only both branches violating disqualifies. -/
private def eitherOf
    (left right : AtomicResult) (whenBoth : Disqualifier) : AtomicResult :=
  match left, right with
  | .satisfied, _ => .satisfied
  | _, .satisfied => .satisfied
  | .violated _, .violated _ => .violated whenBoth
  | _, _ =>
    .unknown <| dedup <|
      (match left with | .unknown facts => facts | _ => []) ++
      (match right with | .unknown facts => facts | _ => [])

/-- Two alternative statutory bases for the same wire route, combined at the
status level: either qualifying qualifies the route; a branch that only needs
information keeps the route open. -/
def eitherRoute : RouteStatus → RouteStatus → RouteStatus
  | .qualifies, _ => .qualifies
  | _, .qualifies => .qualifies
  | .needsInformation a, .needsInformation b => .needsInformation (dedup (a ++ b))
  | .needsInformation a, _ => .needsInformation a
  | _, .needsInformation b => .needsInformation b
  | .doesNotQualify a, .doesNotQualify b => .doesNotQualify (dedup (a ++ b))

private def buildReport
    (route : RouteId) (checks : List AtomicResult) (qualifyingDetail : String) :
    RouteReport :=
  let status := aggregate checks
  { route := route
    status := status
    detail := if status == .qualifies then qualifyingDetail else "" }

/-! ## The assessment -/

/-- Assess Florida's three routes for a partial case. Structural problems — an
invalid or post-snapshot death date, an invalid or pre-death `as_of_date`,
duplicate asset names — are typed errors, never legal conclusions. -/
def assessRoutes (c : PartialCase) : Except CaseError Assessment := do
  -- Structural validation.
  if !c.asOfDate.valid then
    throw (CaseError.malformedCase "as_of_date is not a valid calendar date")
  match c.deathDate with
  | some date =>
    match classifyDeathDate date with
    | .error .invalidDate => throw CaseError.invalidDate
    | .error .afterSnapshot => throw CaseError.afterSnapshot
    | .ok _ =>
      if c.asOfDate.before date then
        throw (CaseError.malformedCase
          "as_of_date precedes decedent.death_date")
  | none => pure ()
  let names := c.assets.map (·.name)
  if (dedup names).length != names.length then
    throw (CaseError.malformedCase "asset names must be unique within assets")

  let thresholds? : Option Thresholds :=
    c.deathDate.bind fun date => (thresholdsFor date).toOption
  -- `SupportedDeathDate`: validity was established above, so a known date
  -- satisfies it and an unknown date leaves it unknown.
  let supportedDate : AtomicResult :=
    if c.deathDate.isSome then .satisfied else .unknown [deathDateFact]

  -- Fla. Stat. §735.201(1).
  let willCheck : AtomicResult :=
    match c.willStatus, c.willDirectsAdministration with
    | some .noWill, _ => .satisfied
    | _, some false => .satisfied
    | _, some true =>
      .violated (dq "will_directs_formal_administration"
        "Fla. Stat. §735.201(1): the decedent's will directs administration as required by chapter 733")
    | some _, none => .unknown [willDirectsFact]
    | none, none => .unknown [willStatusFact, willDirectsFact]

  -- Fla. Stat. §735.201(2), second branch. Qualifies regardless of value.
  let twoYearBranch : AtomicResult :=
    match c.deathDate with
    | none => .unknown [deathDateFact]
    | some date =>
      if deadMoreThanYears date c.asOfDate 2 then .satisfied
      else
        .violated (dq "dead_less_than_two_years"
          "Fla. Stat. §735.201(2): the decedent has not been dead for more than 2 years")

  -- Fla. Stat. §735.201(2), first branch.
  let (summaryValueBranch, summaryValueDetail) :=
    valueCheck (valueBounds false c.assets)
      (thresholds?.map (·.summaryAdministration)) [deathDateFact] false
      c.inventoryComplete "Fla. Stat. §735.201(2)"
      "estate_over_summary_administration_limit"
      "estate value subject to Florida administration net of exempt property"
  let summaryValueOrTwoYears :=
    eitherOf summaryValueBranch twoYearBranch
      (dq "over_summary_limit_and_dead_less_than_two_years"
        (match thresholds?.map (·.summaryAdministration) with
         | some cap =>
           s!"Fla. Stat. §735.201(2): the estate exceeds the {Money.formatUSD cap} limit for this date of death and the decedent has not been dead for more than 2 years"
         | none =>
           "Fla. Stat. §735.201(2): the estate exceeds the summary administration limit and the decedent has not been dead for more than 2 years"))
  let summaryDetail :=
    if summaryValueBranch == .satisfied then summaryValueDetail
    else "Fla. Stat. §735.201(2): the decedent has been dead for more than 2 years, which qualifies regardless of value"
  let summaryReport :=
    buildReport .summaryAdministration
      [supportedDate, willCheck, summaryValueOrTwoYears] summaryDetail

  -- Fla. Stat. §§735.301, 735.304 share the "only personal property" element
  -- and the expense allowance.
  let noRealProperty := realPropertyCheck c.assets
  let allowance? : Option Money :=
    match c.expenses.funeralExpenses, c.expenses.lastIllnessMedicalExpenses with
    | some funeral, some medical =>
      some (min funeral preferredFuneralExpenseCap + medical)
    | _, _ => none
  let allowanceFacts : List FactPath :=
    (if c.expenses.funeralExpenses.isNone then [funeralExpenseFact] else []) ++
    (if c.expenses.lastIllnessMedicalExpenses.isNone then [lastIllnessFact]
     else [])
  let personalBounds := valueBounds true c.assets

  let (value301, detail301) :=
    valueCheck personalBounds allowance? allowanceFacts true c.inventoryComplete
      "Fla. Stat. §735.301(1)"
      "nonexempt_personalty_over_expense_allowance"
      "nonexempt personal property"
  let status301 := aggregate [supportedDate, noRealProperty, value301]

  let intestate : AtomicResult :=
    match c.willStatus with
    | none => .unknown [willStatusFact]
    | some .noWill => .satisfied
    | some _ =>
      .violated (dq "decedent_left_a_will"
        "Fla. Stat. §735.304 reaches only an intestate estate; the decedent left a will")
  let oneYear : AtomicResult :=
    match c.deathDate with
    | none => .unknown [deathDateFact]
    | some date =>
      if deadMoreThanYears date c.asOfDate 1 then .satisfied
      else
        .violated (dq "dead_less_than_one_year"
          "Fla. Stat. §735.304: the decedent has not been dead for more than 1 year")
  let noAdministrationPending : AtomicResult :=
    match c.administrationPending with
    | none => .unknown [administrationPendingFact]
    | some false => .satisfied
    | some true =>
      .violated (dq "administration_pending"
        "Fla. Stat. §735.304: an administration of this estate is pending in Florida")
  let cap304? : Option Money :=
    match thresholds?, allowance? with
    | some thresholds, some allowance =>
      some (thresholds.intestateSmallEstateDisposition + allowance)
    | _, _ => none
  let cap304Facts :=
    (if thresholds?.isNone then [deathDateFact] else []) ++ allowanceFacts
  let (value304, detail304) :=
    valueCheck personalBounds cap304? cap304Facts true c.inventoryComplete
      "Fla. Stat. §735.304"
      "nonexempt_personalty_over_intestate_small_estate_limit"
      "nonexempt personal property"
  let status304 :=
    aggregate [supportedDate, intestate, oneYear, noAdministrationPending,
      noRealProperty, value304]

  let dispositionReport : RouteReport :=
    { route := .dispositionWithoutAdministration
      status := eitherRoute status301 status304
      detail :=
        if status301 == .qualifies then detail301
        else if status304 == .qualifies then detail304
        else "" }

  -- Fallback row and jurisdiction verdict.
  let simplified := [dispositionReport, summaryReport]
  let anyQualifies := simplified.any fun report => report.status == .qualifies
  let unresolvedFacts := dedup <| simplified.foldl
    (fun acc report =>
      match report.status with
      | .needsInformation facts => acc ++ facts
      | _ => acc)
    []
  let fallbackReport : RouteReport :=
    if anyQualifies then
      { route := .formalAdministration
        status := .doesNotQualify
          [dq "simplified_route_available"
            "At least one simplified Florida route qualifies"]
        detail := "" }
    else if unresolvedFacts.isEmpty then
      { route := .formalAdministration
        status := .qualifies
        detail := "No simplified Florida route is available; the estate requires formal administration under chapter 733" }
    else
      { route := .formalAdministration
        status := .needsInformation unresolvedFacts
        detail := "" }
  let verdict : Verdict :=
    if anyQualifies then .eligible
    else if unresolvedFacts.isEmpty then .otherFormRequired
    else .incompleteInfo
  pure
    { routes := simplified ++ [fallbackReport]
      verdict := verdict
      unresolvedFacts := unresolvedFacts }

/-- Status of one route (`none` on case error). -/
def routeStatus
    (result : Except CaseError Assessment) (route : RouteId) :
    Option RouteStatus :=
  match result with
  | .error _ => none
  | .ok assessment =>
    (assessment.routes.find? fun report => report.route == route).map (·.status)

/-- Jurisdiction verdict (`none` on case error). -/
def verdictOf : Except CaseError Assessment → Option Verdict
  | .error _ => none
  | .ok assessment => some assessment.verdict

/-- Every fact still blocking a Florida route (`none` on case error). -/
def unresolvedFactsOf : Except CaseError Assessment → Option (List FactPath)
  | .error _ => none
  | .ok assessment => some assessment.unresolvedFacts

end SimpleProbate.FL
