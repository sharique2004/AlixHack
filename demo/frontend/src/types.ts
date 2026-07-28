// Types mirroring CONTRACT.md v2 exactly.
// The Lean model at AlixHack/SimpleProbate/*.lean is the semantic authority;
// these wire types mirror its JSON bridge. `null` (or absent) = unknown, never false.

// ---------- Verdicts & overall outcome ----------

export type Verdict = "INCOMPLETE_INFO" | "ELIGIBLE" | "OTHER_FORM_REQUIRED";

export type Overall =
  | "simplified_routes_available"
  | "unresolved"
  | "formal_probate_or_other_procedure";

// ---------- Case input (CaseInput v2, mirrors SimpleProbate.TransferCase) ----------

/** Structured civil date matching `CivilDate`. Supported range ends 2026-12-31. */
export interface CivilDate {
  year: number;
  month: number;
  day: number;
}

export type Authority =
  | "no_proceeding"
  | "written_personal_representative_consent"
  | "blocked_by_proceeding";

export type SurvivorStatus = "none" | "spouse" | "registered_domestic_partner";

export type AssetKind = "personal" | "california_real" | "outside_california_real";

/** The 14 `ValuationTreatment` values (§13050 treatment table), snake_case. */
export type ValuationTreatment =
  | "counted"
  | "joint_tenancy"
  | "terminable_at_death"
  | "revocable_trust"
  | "spouse_passage"
  | "multiple_party_survivor"
  | "registered_vehicle"
  | "vessel"
  | "registered_home"
  | "direct_beneficiary"
  | "transfer_on_death"
  | "government_benefit"
  | "military_compensation"
  | "employment_compensation";

export interface AssetInput {
  /** Required, unique within the list. */
  name: string;
  kind?: AssetKind | null;
  /** Integer cents. */
  gross_value_cents?: number | null;
  /** Integer cents; never reduces eligibility values. */
  encumbrances_cents?: number | null;
  treatment?: ValuationTreatment | null;
  included_in_primary_residence_petition?: boolean | null;
  is_primary_residence?: boolean | null;
}

export interface EstateInput {
  /**
   * If not KNOWN true, capped routes can be disqualified by a known-over-cap
   * subtotal but can never QUALIFY.
   */
  inventory_complete?: boolean | null;
  assets?: AssetInput[] | null;
}

export interface CaseInput {
  death_date?: CivilDate | null;
  /** Nat | null — supplied directly, matching the model. */
  days_since_death?: number | null;
  /** Small-value real property route. */
  six_months_elapsed?: boolean | null;
  claimant_is_successor?: boolean | null;
  no_superior_right?: boolean | null;
  funeral_last_illness_and_unsecured_debts_paid?: boolean | null;
  authority?: Authority | null;
  survivor_status?: SurvivorStatus | null;
  property_passes_to_survivor?: boolean | null;
  property_belongs_to_survivor?: boolean | null;
  estate?: EstateInput | null;
  /**
   * Required: which asset the claimant is trying to transfer.
   * Out-of-range ⇒ case error `malformed_case`.
   */
  target_index: number;
}

// ---------- Routes ----------

/** Snake_case route ids mirroring `SimpleProbate.Route`. */
export type RouteId =
  | "direct_transfer"
  | "personal_property_affidavit"
  | "small_value_real_property_affidavit"
  | "primary_residence_petition"
  | "spousal_property_petition"
  | "formal_probate_or_other_procedure";

/** Stable route order for the six-row table (per contract). */
export const ROUTE_ORDER: readonly RouteId[] = [
  "direct_transfer",
  "personal_property_affidavit",
  "small_value_real_property_affidavit",
  "primary_residence_petition",
  "spousal_property_petition",
  "formal_probate_or_other_procedure",
] as const;

export type RouteStatus = "qualifies" | "does_not_qualify" | "needs_information";

export interface RouteReason {
  /** Stable snake_case disqualifier id, e.g. "waiting_period_not_met". */
  id: string;
  /** Human-readable text. */
  text: string;
}

export interface RouteResult {
  route: RouteId;
  status: RouteStatus;
  /** Non-empty iff does_not_qualify. */
  reasons: RouteReason[];
  /** Non-empty iff needs_information: JSON paths into CaseInput. */
  missing_facts: string[];
  /** One line, may be "". */
  detail: string;
  /** e.g. ["DE-305"]; [] when none apply. */
  forms: string[];
}

// ---------- Result (CheckResult v2 — BOTH engines return this shape) ----------

export type CaseErrorType = "invalid_date" | "after_snapshot" | "malformed_case";

export interface CaseError {
  type: CaseErrorType;
  detail: string;
}

/**
 * Per-analysis compute/token/cost metrics. The whole object is null on
 * CheckResult when nothing is measurable. The Lean binary does NOT emit this —
 * the backend attaches it (same as latency_ms).
 */
export interface Usage {
  /** LLM only; null for Lean. */
  input_tokens: number | null;
  /** LLM only (includes thinking tokens); null for Lean. */
  output_tokens: number | null;
  /** Lean only: subprocess CPU time (user+sys); null for LLM. */
  cpu_ms: number | null;
  /** Both engines, estimate; null if unpriceable. */
  estimated_cost_usd: number | null;
  /** e.g. "gemini-2.5-flash @ $0.30/M in + $2.50/M out (est.)". */
  pricing_note: string | null;
}

export interface CheckResult {
  /** null iff `error` is set. */
  verdict: Verdict | null;
  error: CaseError | null;
  /** null iff `error` is set. */
  overall: Overall | null;
  /**
   * One entry per route id, always all six in stable order from the Lean
   * engine. The LLM's list may be partial — missing rows render "not assessed".
   */
  routes: RouteResult[];
  /** LLM: free-text reasoning. Lean: one-sentence summary. */
  reasoning: string;
  /** "lean4" | Gemini model name. */
  engine: string;
  latency_ms: number;
  /** null when nothing measurable. */
  usage: Usage | null;
}

// ---------- Sample cases ----------

export interface SampleCase {
  name: string;
  /** Human-readable display title for the picker. */
  title?: string;
  /** One line, shown in the picker. */
  blurb: string;
  expected_verdict: string;
  case: CaseInput;
}
