import Std

namespace SimpleProbate

inductive Knowledge (α : Type)
  | unknown
  | known (value : α)
deriving DecidableEq, Repr

namespace Knowledge

def Completes : Knowledge α → α → Prop
  | .unknown, _ => True
  | .known expected, actual => expected = actual

instance [DecidableEq α] (knowledge : Knowledge α) (value : α) :
    Decidable (knowledge.Completes value) := by
  cases knowledge <;> simp [Completes] <;> infer_instance

def ofValue (value : α) : Knowledge α := .known value

end Knowledge

inductive CheckResult (fact reason : Type)
  | satisfied
  | violated (reason : reason)
  | unknown (fact : fact)
deriving DecidableEq, Repr

inductive DecisionStatus (fact reason : Type)
  | qualifies
  | doesNotQualify (reasons : List reason)
  | needsInformation (facts : List fact)
deriving DecidableEq, Repr

private def violatedReasons :
    List (CheckResult fact reason) → List reason
  | [] => []
  | .violated reason :: rest => reason :: violatedReasons rest
  | _ :: rest => violatedReasons rest

private def unknownFacts :
    List (CheckResult fact reason) → List fact
  | [] => []
  | .unknown fact :: rest => fact :: unknownFacts rest
  | _ :: rest => unknownFacts rest

def dedupStable [BEq α] (values : List α) : List α :=
  values.foldl
    (fun result value =>
      if result.contains value then result else result ++ [value]) []

def aggregateChecks
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    (checks : List (CheckResult fact reason)) :
    DecisionStatus fact reason :=
  match dedupStable (violatedReasons checks) with
  | reason :: reasons => .doesNotQualify (reason :: reasons)
  | [] =>
      match dedupStable (unknownFacts checks) with
      | fact :: facts => .needsInformation (fact :: facts)
      | [] => .qualifies

private theorem mem_dedupStable_fold
    [BEq α] [LawfulBEq α]
    (value : α) (values result : List α) :
    value ∈ values.foldl
      (fun current candidate =>
        if current.contains candidate
        then current
        else current ++ [candidate]) result ↔
      value ∈ result ∨ value ∈ values := by
  induction values generalizing result with
  | nil => simp
  | cons head tail ih =>
      simp only [List.foldl]
      rw [ih]
      by_cases present : result.contains head = true
      · rw [if_pos present]
        simp only [List.mem_cons]
        have headMember : head ∈ result := by simpa using present
        constructor
        · intro member
          cases member with
          | inl member => exact Or.inl member
          | inr member => exact Or.inr (Or.inr member)
        · intro member
          rcases member with member | member | member
          · exact Or.inl member
          · rw [member]
            exact Or.inl headMember
          · exact Or.inr member
      · rw [if_neg present]
        simp [List.mem_append]
        constructor
        · intro member
          rcases member with (member | member) | member
          · exact Or.inl member
          · exact Or.inr (Or.inl member)
          · exact Or.inr (Or.inr member)
        · intro member
          rcases member with member | member | member
          · exact Or.inl (Or.inl member)
          · exact Or.inl (Or.inr member)
          · exact Or.inr member

theorem mem_dedupStable
    [BEq α] [LawfulBEq α] (value : α) (values : List α) :
    value ∈ dedupStable values ↔ value ∈ values := by
  simpa [dedupStable] using
    mem_dedupStable_fold value values []

theorem dedupStable_nodup
    [BEq α] [LawfulBEq α] (values : List α) :
    (dedupStable values).Nodup := by
  unfold dedupStable
  have preservesNodup :
      ∀ (remaining result : List α), result.Nodup →
        (remaining.foldl
          (fun current candidate =>
            if current.contains candidate then current else current ++ [candidate])
          result).Nodup := by
    intro remaining
    induction remaining with
    | nil => simp
    | cons head tail ih =>
        intro result resultNodup
        simp only [List.foldl]
        split <;> rename_i containsHead
        · exact ih result resultNodup
        · apply ih
          rw [List.nodup_append]
          constructor
          · exact resultNodup
          constructor
          · simp
          · intro value member other otherMember
            simp only [List.mem_singleton] at otherMember
            subst other
            intro equalHead
            exact containsHead (by simpa [equalHead] using member)
  simpa using preservesNodup values [] (by simp)

private theorem dedupStable_ne_nil_of_mem
    [BEq α] [LawfulBEq α] {value : α} {values : List α}
    (member : value ∈ values) :
    dedupStable values ≠ [] := by
  intro empty
  have : value ∈ dedupStable values := (mem_dedupStable value values).mpr member
  simp [empty] at this

private theorem mem_violatedReasons
    {fact reason : Type} (target : reason) (checks : List (CheckResult fact reason)) :
    target ∈ violatedReasons checks ↔ .violated target ∈ checks := by
  induction checks with
  | nil => simp [violatedReasons]
  | cons check rest ih =>
      cases check <;> simp [violatedReasons, ih]

private theorem mem_unknownFacts
    {fact reason : Type} (target : fact) (checks : List (CheckResult fact reason)) :
    target ∈ unknownFacts checks ↔ .unknown target ∈ checks := by
  induction checks with
  | nil => simp [unknownFacts]
  | cons check rest ih =>
      cases check <;> simp [unknownFacts, ih]

theorem aggregateChecks_qualifies_iff
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    (checks : List (CheckResult fact reason)) :
    aggregateChecks checks = .qualifies ↔
      ∀ check ∈ checks, check = .satisfied := by
  induction checks with
  | nil => simp [aggregateChecks, violatedReasons, unknownFacts, dedupStable]
  | cons check rest ih =>
      cases check with
      | satisfied =>
          simpa [aggregateChecks, violatedReasons, unknownFacts] using ih
      | violated reason =>
          have nonempty : dedupStable (reason :: violatedReasons rest) ≠ [] :=
            dedupStable_ne_nil_of_mem (value := reason) (by simp)
          cases reasonsResult : dedupStable (reason :: violatedReasons rest) with
          | nil => exact (nonempty reasonsResult).elim
          | cons head tail =>
              simp [aggregateChecks, violatedReasons, reasonsResult]
      | unknown fact =>
          cases reasonsResult : dedupStable (violatedReasons rest) with
          | cons head tail =>
              simp [aggregateChecks, violatedReasons, reasonsResult]
          | nil =>
              have nonempty : dedupStable (fact :: unknownFacts rest) ≠ [] :=
                dedupStable_ne_nil_of_mem (value := fact) (by simp)
              cases factsResult : dedupStable (fact :: unknownFacts rest) with
              | nil => exact (nonempty factsResult).elim
              | cons head tail =>
                  simp [aggregateChecks, violatedReasons, unknownFacts,
                    reasonsResult, factsResult]

theorem aggregateChecks_disqualified_nonempty
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    {checks : List (CheckResult fact reason)} {reasons : List reason}
    (result : aggregateChecks checks = .doesNotQualify reasons) :
    reasons ≠ [] := by
  unfold aggregateChecks at result
  cases reasonsResult : dedupStable (violatedReasons checks) with
  | nil =>
      cases factsResult : dedupStable (unknownFacts checks) with
      | nil => simp [reasonsResult, factsResult] at result
      | cons head tail => simp [reasonsResult, factsResult] at result
  | cons head tail =>
      simp [reasonsResult] at result
      subst reasons
      simp

theorem aggregateChecks_information_nonempty
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    {checks : List (CheckResult fact reason)} {facts : List fact}
    (result : aggregateChecks checks = .needsInformation facts) :
    facts ≠ [] := by
  unfold aggregateChecks at result
  cases reasonsResult : dedupStable (violatedReasons checks) with
  | cons head tail => simp [reasonsResult] at result
  | nil =>
      cases factsResult : dedupStable (unknownFacts checks) with
      | nil => simp [reasonsResult, factsResult] at result
      | cons head tail =>
          simp [reasonsResult, factsResult] at result
          subst facts
          simp

theorem mem_disqualifier_of_aggregate
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    {checks : List (CheckResult fact reason)} {reasons : List reason}
    (result : aggregateChecks checks = .doesNotQualify reasons)
    (reason : reason) :
    reason ∈ reasons ↔ .violated reason ∈ checks := by
  unfold aggregateChecks at result
  cases reasonsResult : dedupStable (violatedReasons checks) with
  | nil =>
      cases factsResult : dedupStable (unknownFacts checks) with
      | nil => simp [reasonsResult, factsResult] at result
      | cons head tail => simp [reasonsResult, factsResult] at result
  | cons head tail =>
      simp [reasonsResult] at result
      subst reasons
      rw [← reasonsResult, mem_dedupStable]
      exact mem_violatedReasons reason checks

theorem mem_requiredFact_of_aggregate
    [BEq fact] [LawfulBEq fact] [BEq reason] [LawfulBEq reason]
    {checks : List (CheckResult fact reason)} {facts : List fact}
    (result : aggregateChecks checks = .needsInformation facts)
    (fact : fact) :
    fact ∈ facts ↔ .unknown fact ∈ checks := by
  unfold aggregateChecks at result
  cases reasonsResult : dedupStable (violatedReasons checks) with
  | cons head tail => simp [reasonsResult] at result
  | nil =>
      cases factsResult : dedupStable (unknownFacts checks) with
      | nil => simp [reasonsResult, factsResult] at result
      | cons head tail =>
          simp [reasonsResult, factsResult] at result
          subst facts
          rw [← factsResult, mem_dedupStable]
          exact mem_unknownFacts fact checks

end SimpleProbate
