import SimpleProbate.FL.Partial

/-!
# Florida boundary examples, checked by the kernel at compile time

Every claim below is an `example … := by decide`. If any of them stopped being
true, this file would stop compiling.

Sources retrieved 2026-08-12: Fla. Stat. §§735.201, 735.301, 735.304,
733.707(1)(b), 732.402; Fla. Const. art. X, §4(a)(1); CS/HB 1337 (2026),
eff. 2026-07-01.
-/

namespace SimpleProbate.FL
namespace Examples

-- `decide` unfolds whole assessments, including the citation text carried by
-- every disqualifier. The default elaborator recursion budget is too small for
-- that; this only affects compile-time checking, never the compiled engine.
set_option maxRecDepth 100000

/-- The contract's `as_of_date` for these examples. -/
def asOf : CivilDate := ⟨2026, 8, 12⟩

/-- A Florida-situs, solely titled, non-exempt personal asset with every fact
known. -/
def personalAsset (name : String) (value : Money) : PartialAsset := {
  name := name
  kind := some .personal
  situsState := some "FL"
  grossValue := some value
  titleForm := some .sole
  beneficiaryDesignation := some .noDesignation
  isPrimaryResidence := some false
  exemptFromCreditors := some false
}

/-- Testate, will silent on chapter 733 administration, nothing pending, no
funeral or last-illness expenses, inventory confirmed complete. -/
def baseCase : PartialCase := {
  deathDate := some ⟨2026, 3, 1⟩
  asOfDate := asOf
  assets := []
  expenses := { funeralExpenses := some 0, lastIllnessMedicalExpenses := some 0 }
  willStatus := some .validOriginal
  willDirectsAdministration := some false
  administrationPending := some false
  inventoryComplete := some true
}

/-! ## THE FLAGSHIP CASE — one day changes the answer

Identical estates. Identical facts. The decedents died a single day apart, on
either side of CS/HB 1337's 2026-07-01 effective date. A $150,000 estate is over
the old §735.201(2) ceiling and exactly at the new one, so the same estate takes
two different routes. Both bands stay live simultaneously: nothing about the
2026-06-30 death "expires". -/

def estate150k : List PartialAsset :=
  [personalAsset "Brokerage account" (Money.dollars 150_000)]

def diedJun30_2026 : PartialCase :=
  { baseCase with deathDate := some ⟨2026, 6, 30⟩, assets := estate150k }

def diedJul01_2026 : PartialCase :=
  { baseCase with deathDate := some ⟨2026, 7, 1⟩, assets := estate150k }

-- Died 2026-06-30: over the $75,000 ceiling, and not dead 2 years.
example :
    (routeStatus (assessRoutes diedJun30_2026)
        .summaryAdministration).map (·.disqualifierIds) =
      some ["over_summary_limit_and_dead_less_than_two_years"] := by decide

-- Died 2026-07-01, one day later: exactly at the $150,000 ceiling.
example :
    routeStatus (assessRoutes diedJul01_2026) .summaryAdministration =
      some .qualifies := by decide

-- And the whole jurisdiction verdict flips with it.
example : verdictOf (assessRoutes diedJun30_2026) = some .otherFormRequired := by
  decide
example : verdictOf (assessRoutes diedJul01_2026) = some .eligible := by decide

-- The June death falls all the way through to formal administration.
example :
    routeStatus (assessRoutes diedJun30_2026) .formalAdministration =
      some .qualifies := by decide
example :
    (routeStatus (assessRoutes diedJul01_2026)
        .formalAdministration).map (·.disqualifierIds) =
      some ["simplified_route_available"] := by decide

/-! ## §735.201(2) at the cap and one cent over, in both bands -/

def band1AtCap : PartialCase :=
  { baseCase with
    deathDate := some ⟨2026, 6, 30⟩
    assets := [personalAsset "Bank account" 7_500_000] }

def band1OverCap : PartialCase :=
  { band1AtCap with assets := [personalAsset "Bank account" 7_500_001] }

def band2AtCap : PartialCase :=
  { baseCase with
    deathDate := some ⟨2026, 7, 1⟩
    assets := [personalAsset "Bank account" 15_000_000] }

def band2OverCap : PartialCase :=
  { band2AtCap with assets := [personalAsset "Bank account" 15_000_001] }

example :
    routeStatus (assessRoutes band1AtCap) .summaryAdministration =
      some .qualifies := by decide
example :
    (routeStatus (assessRoutes band1OverCap)
        .summaryAdministration).map (·.disqualifierIds) =
      some ["over_summary_limit_and_dead_less_than_two_years"] := by decide
example :
    routeStatus (assessRoutes band2AtCap) .summaryAdministration =
      some .qualifies := by decide
example :
    (routeStatus (assessRoutes band2OverCap)
        .summaryAdministration).map (·.disqualifierIds) =
      some ["over_summary_limit_and_dead_less_than_two_years"] := by decide

/-! ## §735.201(2) second branch — dead more than 2 years qualifies regardless
of value -/

def deadOverTwoYears : PartialCase :=
  { baseCase with
    deathDate := some ⟨2024, 1, 15⟩
    assets := [personalAsset "Brokerage account" (Money.dollars 2_000_000)] }

-- A $2,000,000 estate — twenty-six times the applicable ceiling — qualifies.
example :
    routeStatus (assessRoutes deadOverTwoYears) .summaryAdministration =
      some .qualifies := by decide

-- The anniversary itself is not yet "more than 2 years".
def deadExactlyTwoYears : PartialCase :=
  { deadOverTwoYears with
    deathDate := some ⟨2024, 8, 12⟩
    assets := [personalAsset "Brokerage account" (Money.dollars 2_000_000)] }

example :
    (routeStatus (assessRoutes deadExactlyTwoYears)
        .summaryAdministration).map (·.disqualifierIds) =
      some ["over_summary_limit_and_dead_less_than_two_years"] := by decide

/-! ## Property exempt from the claims of creditors is subtracted -/

/-- Protected homestead — Fla. Const. art. X, §4(a)(1). -/
def homestead : PartialAsset := {
  name := "Homestead — 12 Palm St"
  kind := some .realProperty
  situsState := some "FL"
  grossValue := some (Money.dollars 400_000)
  titleForm := some .sole
  beneficiaryDesignation := some .noDesignation
  isPrimaryResidence := some true
  exemptFromCreditors := some false
}

/-- The same house, but not the decedent's residence: no homestead protection,
so §735.201(2) counts all of it. -/
def rental : PartialAsset :=
  { homestead with name := "Rental — 9 Bay Rd", isPrimaryResidence := some false }

def homesteadCase : PartialCase :=
  { baseCase with
    assets := [homestead, personalAsset "Bank account" (Money.dollars 50_000)] }

def rentalCase : PartialCase :=
  { baseCase with
    assets := [rental, personalAsset "Bank account" (Money.dollars 50_000)] }

-- $400,000 homestead + $50,000 bank: only the bank account counts.
example :
    routeStatus (assessRoutes homesteadCase) .summaryAdministration =
      some .qualifies := by decide

-- Same numbers, non-exempt real property: $450,000 against a $75,000 ceiling.
example :
    (routeStatus (assessRoutes rentalCase)
        .summaryAdministration).map (·.disqualifierIds) =
      some ["over_summary_limit_and_dead_less_than_two_years"] := by decide

/-- Fla. Stat. §732.402 exempt property, stated on the intake. -/
def exemptVehicle : PartialAsset :=
  { (personalAsset "Vehicle" (Money.dollars 30_000)) with
    exemptFromCreditors := some true }

def statedExemptionCase : PartialCase :=
  { baseCase with
    assets :=
      [personalAsset "Bank account" (Money.dollars 70_000), exemptVehicle] }

-- $100,000 gross, $70,000 after the §732.402 exemption: under the $75,000 cap.
example :
    routeStatus (assessRoutes statedExemptionCase) .summaryAdministration =
      some .qualifies := by decide

/-! ## Unknown is never false

An unknown value blocks the answer. An unknown *exemption* does not, so long as
the estate is under the ceiling even if nothing turns out to be exempt —
exemptions only ever subtract. -/

def unknownValueCase : PartialCase :=
  { band1AtCap with
    assets :=
      [personalAsset "Bank account" 7_500_000,
       { (personalAsset "Savings account" 0) with grossValue := none }] }

example :
    routeStatus (assessRoutes unknownValueCase) .summaryAdministration =
      some (.needsInformation ["assets[1].gross_value_cents"]) := by decide

example : verdictOf (assessRoutes unknownValueCase) = some .incompleteInfo := by
  decide

/-- $100,000 against the $150,000 ceiling, with the §732.402 exemption unknown:
the exemption could only reduce the total, so it cannot change the answer. -/
def unknownExemptionUnderCap : PartialCase :=
  { baseCase with
    deathDate := some ⟨2026, 7, 1⟩
    assets :=
      [{ (personalAsset "Bank account" (Money.dollars 100_000)) with
          exemptFromCreditors := none }] }

example :
    routeStatus (assessRoutes unknownExemptionUnderCap) .summaryAdministration =
      some .qualifies := by decide

/-- Same, for an unknown title form: an asset that might pass outside
administration is counted anyway, and the total is still under the ceiling. -/
def unknownTitleUnderCap : PartialCase :=
  { baseCase with
    deathDate := some ⟨2026, 7, 1⟩
    assets :=
      [{ (personalAsset "Bank account" (Money.dollars 100_000)) with
          titleForm := none, beneficiaryDesignation := none }] }

example :
    routeStatus (assessRoutes unknownTitleUnderCap) .summaryAdministration =
      some .qualifies := by decide

/-- Now the unknown exemption straddles the ceiling: $100,000 certainly counts,
$80,000 might. The engine names the one fact that decides it. -/
def unknownExemptionStraddling : PartialCase :=
  { baseCase with
    deathDate := some ⟨2026, 7, 1⟩
    assets :=
      [personalAsset "Bank account" (Money.dollars 100_000),
       { (personalAsset "Coin collection" (Money.dollars 80_000)) with
          exemptFromCreditors := none }] }

example :
    routeStatus (assessRoutes unknownExemptionStraddling)
        .summaryAdministration =
      some (.needsInformation ["assets[1].exempt_from_creditors"]) := by decide

/-- Known violation beats unknown: $200,000 is already over the $150,000
ceiling, so a second asset of unknown value changes nothing. -/
def overCapWithUnknowns : PartialCase :=
  { baseCase with
    deathDate := some ⟨2026, 7, 1⟩
    inventoryComplete := none
    assets :=
      [personalAsset "Bank account" (Money.dollars 200_000),
       { (personalAsset "Savings account" 0) with grossValue := none }] }

example :
    (routeStatus (assessRoutes overCapWithUnknowns)
        .summaryAdministration).map (·.disqualifierIds) =
      some ["over_summary_limit_and_dead_less_than_two_years"] := by decide

/-- An unconfirmed inventory can never qualify a capped route: an unlisted asset
would raise the total. -/
def inventoryUnknown : PartialCase :=
  { band1AtCap with inventoryComplete := none }

example :
    routeStatus (assessRoutes inventoryUnknown) .summaryAdministration =
      some (.needsInformation ["inventory_complete"]) := by decide

/-! ## §735.301 — disposition without administration -/

/-- $4,000 of personalty against a $9,000 expense allowance. -/
def dispositionCase : PartialCase :=
  { baseCase with
    deathDate := some ⟨2026, 5, 1⟩
    assets := [personalAsset "Checking account" (Money.dollars 4_000)]
    expenses :=
      { funeralExpenses := some (Money.dollars 9_000)
        lastIllnessMedicalExpenses := some (Money.dollars 3_000) } }

example :
    routeStatus (assessRoutes dispositionCase)
        .dispositionWithoutAdministration = some .qualifies := by decide

/-- The Fla. Stat. §733.707(1)(b) preferred-funeral cap bites. The funeral bill
is $9,000 but only $6,000 of it is preferred, so the allowance is $9,000, not
$12,000 — and a $10,000 estate is over it. -/
def dispositionFuneralCapped : PartialCase :=
  { dispositionCase with
    assets := [personalAsset "Checking account" (Money.dollars 10_000)] }

example :
    (routeStatus (assessRoutes dispositionFuneralCapped)
        .dispositionWithoutAdministration).map (·.disqualifierIds) =
      some ["nonexempt_personalty_over_expense_allowance",
            "decedent_left_a_will", "dead_less_than_one_year"] := by decide

/-- The same $10,000 estate against $6,000 funeral + $4,000 medical: the
allowance is $10,000 and the estate qualifies. The cap, not the arithmetic, was
the difference. -/
def dispositionUnderAllowance : PartialCase :=
  { dispositionFuneralCapped with
    expenses :=
      { funeralExpenses := some (Money.dollars 6_000)
        lastIllnessMedicalExpenses := some (Money.dollars 4_000) } }

example :
    routeStatus (assessRoutes dispositionUnderAllowance)
        .dispositionWithoutAdministration = some .qualifies := by decide

/-- Unknown expenses leave the comparison open, naming both wire fields. -/
def dispositionUnknownExpenses : PartialCase :=
  { dispositionCase with expenses := {} }

example :
    routeStatus (assessRoutes dispositionUnknownExpenses)
        .dispositionWithoutAdministration =
      some (.needsInformation
        ["expenses.preferred_funeral_cents",
         "expenses.last_illness_medical_cents"]) := by decide

/-! ## §735.304 — the intestate small-estate figure, also banded -/

/-- Intestate, dead more than 1 year, nothing pending, no expenses. -/
def intestateBase : PartialCase :=
  { baseCase with
    deathDate := some ⟨2024, 5, 1⟩
    willStatus := some .noWill }

def s304Band1AtCap : PartialCase :=
  { intestateBase with
    assets := [personalAsset "Bank account" (Money.dollars 10_000)] }

def s304Band1OverCap : PartialCase :=
  { intestateBase with
    assets := [personalAsset "Bank account" (Money.dollars 10_000 + 1)] }

example :
    routeStatus (assessRoutes s304Band1AtCap)
        .dispositionWithoutAdministration = some .qualifies := by decide
example :
    (routeStatus (assessRoutes s304Band1OverCap)
        .dispositionWithoutAdministration).map (·.disqualifierIds) =
      some ["nonexempt_personalty_over_expense_allowance",
            "nonexempt_personalty_over_intestate_small_estate_limit"] := by
  decide

/-- The §735.304 band edge, seen from an `as_of_date` far enough out that the
one-year condition is met on both sides. Same $20,000 estate, deaths one day
apart. -/
def s304Band2Base : PartialCase :=
  { intestateBase with asOfDate := ⟨2027, 8, 12⟩ }

def s304DiedJun30 : PartialCase :=
  { s304Band2Base with
    deathDate := some ⟨2026, 6, 30⟩
    assets := [personalAsset "Bank account" (Money.dollars 20_000)] }

def s304DiedJul01 : PartialCase :=
  { s304Band2Base with
    deathDate := some ⟨2026, 7, 1⟩
    assets := [personalAsset "Bank account" (Money.dollars 20_000)] }

example :
    (routeStatus (assessRoutes s304DiedJun30)
        .dispositionWithoutAdministration).map (·.disqualifierIds) =
      some ["nonexempt_personalty_over_expense_allowance",
            "nonexempt_personalty_over_intestate_small_estate_limit"] := by
  decide
example :
    routeStatus (assessRoutes s304DiedJul01)
        .dispositionWithoutAdministration = some .qualifies := by decide

-- At the new figure and one cent over it.
example :
    (routeStatus (assessRoutes
        { s304DiedJul01 with
          assets := [personalAsset "Bank account" (Money.dollars 20_000 + 1)] })
        .dispositionWithoutAdministration).map (·.disqualifierIds) =
      some ["nonexempt_personalty_over_expense_allowance",
            "nonexempt_personalty_over_intestate_small_estate_limit"] := by
  decide

/-! ## "Leaving only personal property" -/

/-- Solely titled real property is administered, so no disposition is
available. -/
def realPropertyOnlyCase : PartialCase :=
  { intestateBase with assets := [homestead] }

example :
    (routeStatus (assessRoutes realPropertyOnlyCase)
        .dispositionWithoutAdministration).map (·.disqualifierIds) =
      some ["estate_includes_real_property"] := by decide

/-- The same house held tenancy by the entirety passes to the surviving spouse
by operation of law, so the decedent left no real property to administer. -/
def entiretiesCase : PartialCase :=
  { intestateBase with
    assets := [{ homestead with titleForm := some .tenancyByEntirety }] }

example :
    routeStatus (assessRoutes entiretiesCase)
        .dispositionWithoutAdministration = some .qualifies := by decide

/-- An unknown title form on real property leaves the question open rather than
answering it either way. -/
def unknownTitleRealProperty : PartialCase :=
  { intestateBase with
    assets :=
      [{ homestead with titleForm := none, beneficiaryDesignation := none }] }

example :
    routeStatus (assessRoutes unknownTitleRealProperty)
        .dispositionWithoutAdministration =
      some (.needsInformation
        ["assets[0].title_form", "assets[0].beneficiary_designation"]) := by
  decide

/-! ## Structural errors are not legal conclusions -/

example :
    assessRoutes { baseCase with deathDate := some ⟨2027, 1, 2⟩ } =
      .error .afterSnapshot := by decide

example :
    assessRoutes { baseCase with deathDate := some ⟨2026, 2, 29⟩ } =
      .error .invalidDate := by decide

example :
    assessRoutes { baseCase with deathDate := some ⟨2026, 9, 1⟩ } =
      .error (.malformedCase "as_of_date precedes decedent.death_date") := by
  decide

example :
    assessRoutes
        { baseCase with
          assets :=
            [personalAsset "Bank account" 100,
             personalAsset "Bank account" 200] } =
      .error (.malformedCase "asset names must be unique within assets") := by
  decide

example :
    assessRoutes { baseCase with asOfDate := ⟨2026, 13, 1⟩ } =
      .error (.malformedCase "as_of_date is not a valid calendar date") := by
  decide

/-! ## The partial layer agrees with the total predicates

Three fully known cases, checked against the Prop-valued eligibility predicates
in `SimpleProbate.FL.Eligibility`. -/

def totalAsset (name : String) (value : Money) : Asset := {
  name := name
  kind := .personal
  situsState := "FL"
  grossValue := value
  titleForm := .sole
  beneficiaryDesignation := .noDesignation
  isPrimaryResidence := false
  exemptFromCreditors := false
}

/-- The total mirror of `band1AtCap`. -/
def totalBand1AtCap : Case := {
  deathDate := ⟨2026, 6, 30⟩
  asOfDate := asOf
  estate := { assets := [totalAsset "Bank account" 7_500_000] }
  expenses := { funeralExpenses := 0, lastIllnessMedicalExpenses := 0 }
  willStatus := .validOriginal
  willDirectsAdministration := false
  administrationPending := false
}

def totalBand1OverCap : Case :=
  { totalBand1AtCap with
    estate := { assets := [totalAsset "Bank account" 7_500_001] } }

/-- The total mirror of `deadOverTwoYears`. -/
def totalDeadOverTwoYears : Case :=
  { totalBand1AtCap with
    deathDate := ⟨2024, 1, 15⟩
    estate :=
      { assets := [totalAsset "Brokerage account" (Money.dollars 2_000_000)] } }

example :
    (routeStatus (assessRoutes band1AtCap) .summaryAdministration =
        some .qualifies) ↔
      SummaryAdministrationEligible totalBand1AtCap := by decide

example :
    (routeStatus (assessRoutes band1OverCap) .summaryAdministration =
        some .qualifies) ↔
      SummaryAdministrationEligible totalBand1OverCap := by decide

example :
    (routeStatus (assessRoutes deadOverTwoYears) .summaryAdministration =
        some .qualifies) ↔
      SummaryAdministrationEligible totalDeadOverTwoYears := by decide

-- Route finding over the total layer, including the fallback.
example : candidateRoutes totalBand1AtCap = .ok [.summaryAdministration] := by
  decide
example : candidateRoutes totalBand1OverCap = .ok [.formalAdministration] := by
  decide
example :
    candidateRoutes { totalBand1AtCap with deathDate := ⟨2027, 1, 1⟩ } =
      .error .afterSnapshot := by decide

end Examples
end SimpleProbate.FL
