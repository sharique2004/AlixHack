import Std

namespace SimpleProbate

instance instDecidableEqExcept {ε α : Type} [DecidableEq ε] [DecidableEq α] :
    DecidableEq (Except ε α)
  | .ok x, .ok y =>
    if h : x = y then
      isTrue (by cases h; rfl)
    else
      isFalse (by intro hxy; apply h; cases hxy; rfl)
  | .error x, .error y =>
    if h : x = y then
      isTrue (by cases h; rfl)
    else
      isFalse (by intro hxy; apply h; cases hxy; rfl)
  | .ok _, .error _ => isFalse (by intro h; cases h)
  | .error _, .ok _ => isFalse (by intro h; cases h)

structure CivilDate where
  year : Nat
  month : Nat
  day : Nat
deriving DecidableEq, Repr

def CivilDate.key (d : CivilDate) : Nat × Nat × Nat :=
  (d.year, d.month, d.day)

def CivilDate.before (a b : CivilDate) : Bool :=
  a.year < b.year ||
  (a.year == b.year &&
    (a.month < b.month || (a.month == b.month && a.day < b.day)))

def CivilDate.atMost (a b : CivilDate) : Bool :=
  !b.before a

def CivilDate.isLeapYear (year : Nat) : Bool :=
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)

def CivilDate.daysInMonth (year month : Nat) : Nat :=
  match month with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
  | 4 | 6 | 9 | 11 => 30
  | 2 => if CivilDate.isLeapYear year then 29 else 28
  | _ => 0

def CivilDate.valid (d : CivilDate) : Bool :=
  decide (1 ≤ d.year) &&
  decide (1 ≤ d.month) &&
  decide (d.month ≤ 12) &&
  decide (1 ≤ d.day) &&
  decide (d.day ≤ CivilDate.daysInMonth d.year d.month)

inductive DateError
  | invalidDate
  | afterSnapshot
deriving DecidableEq, Repr

inductive DeathBand
  | beforeApr2022
  | apr2022ToMar2025
  | apr2025ToDec2026
deriving DecidableEq, Repr

def apr1_2022 : CivilDate := ⟨2022, 4, 1⟩
def apr1_2025 : CivilDate := ⟨2025, 4, 1⟩
def snapshotEnd : CivilDate := ⟨2026, 12, 31⟩

def classifyDeathDate (date : CivilDate) : Except DateError DeathBand :=
  if !date.valid then
    .error .invalidDate
  else if !date.atMost snapshotEnd then
    .error .afterSnapshot
  else if date.before apr1_2022 then
    .ok .beforeApr2022
  else if date.before apr1_2025 then
    .ok .apr2022ToMar2025
  else
    .ok .apr2025ToDec2026

end SimpleProbate
