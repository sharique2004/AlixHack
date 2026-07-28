import SimpleProbate.Estate

namespace SimpleProbate.Examples.Valuation

open SimpleProbate

def salary (id : Nat) (current atDeath : Money) : Asset := {
  id := ⟨id⟩
  name := s!"salary-{id}"
  kind := .personal
  currentGrossValue := current
  dateOfDeathValue := atDeath
  treatment := .employmentCompensation
}

def realProperty
    (id : Nat) (current atDeath : Money) (primary : Bool) : Asset := {
  id := ⟨id⟩
  name := s!"real-{id}"
  kind := .californiaReal
  currentGrossValue := current
  dateOfDeathValue := atDeath
  treatment := .counted
  isPrimaryResidence := primary
}

example :
    ({ assets := [
      salary 1 (Money.dollars 15_000) (Money.dollars 12_000),
      salary 2 (Money.dollars 15_000) (Money.dollars 13_000)
    ] } : Estate).personalAffidavitValue ⟨2026, 1, 1⟩ =
      .ok (Money.dollars 9_125) := by decide

example :
    ({ assets := [
      salary 1 (Money.dollars 30_000) (Money.dollars 25_000)
    ] } : Estate).personalAffidavitValue ⟨2026, 1, 1⟩ =
      .ok (Money.dollars 9_125) := by decide

example :
    ({ assets := [
      realProperty 3 (Money.dollars 900_000)
        (Money.dollars 700_000) true
    ] } : Estate).primaryResidenceValue =
      Money.dollars 700_000 := by decide

example :
    ({ assets := [
      realProperty 4 (Money.dollars 80_000)
        (Money.dollars 60_000) false
    ] } : Estate).smallValueRealPropertyValue =
      Money.dollars 60_000 := by decide

end SimpleProbate.Examples.Valuation
