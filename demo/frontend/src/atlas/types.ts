/**
 * Atlas — TypeScript mirror of CONTRACT-SETTLEMENT.md (v1, frozen 2026-08-12).
 * If this file and the contract disagree, the contract wins.
 * Owned by the orchestrator: agents import from here, they do not edit it.
 */

export interface CivilDate {
  year: number;
  month: number;
  day: number;
}

export interface Citation {
  label: string;
  url: string | null;
}

export interface Reason {
  id: string;
  text: string;
}

/** A JSON path into the IntakeCase, e.g. "assets[2].title_form". */
export type FactPath = string;

// ---------------------------------------------------------------- request

export type MannerOfDeath =
  | "natural" | "accident" | "suicide" | "homicide" | "pending" | "undetermined";
export type WillStatus =
  | "valid_original" | "copy_only" | "holographic" | "none" | "unsure";
export type MaritalStatus = "married" | "single" | "widowed" | "divorced";

export type AssetKind =
  | "real_property" | "bank" | "brokerage" | "retirement" | "life_insurance"
  | "vehicle" | "personal" | "business" | "digital" | "employment_comp" | "other";
export type TitleForm =
  | "sole" | "jtwros" | "tenancy_by_entirety" | "community_with_ros"
  | "tenants_in_common" | "trust_funded" | "custodial";
export type BeneficiaryDesignation =
  | "named_living" | "named_predeceased" | "estate" | "none" | "unsure";
/** CONTRACT §2.1 */
export type RefundClaimant =
  | "surviving_spouse_joint_return" | "court_appointed_representative" | "other";
/** CONTRACT §2.1 */
export type FinalReturnKind = "original" | "amended";

export interface IntakeDecedent {
  death_date?: CivilDate | null;
  domicile_state?: string | null;
  marital_status?: MaritalStatus | null;
  surviving_spouse?: boolean | null;
  manner_of_death?: MannerOfDeath | null;
  death_certificate_final?: boolean | null;
  will_status?: WillStatus | null;
  employment_related_death?: boolean | null;
  third_party_fault_suspected?: boolean | null;
  related_death_within_120h?: boolean | null;
  received_medicaid_ltc?: boolean | null;
  veteran?: boolean | null;
  pending_litigation?: boolean | null;
  // §2.1 — Florida
  will_directs_administration?: boolean | null;
  administration_pending?: boolean | null;
  // §2.1 — federal
  federal_refund_due?: boolean | null;
  refund_claimant?: RefundClaimant | null;
  final_return_kind?: FinalReturnKind | null;
  court_certificate_attached?: boolean | null;
  /** Fully OR currently insured — 42 U.S.C. §402(i) opens on the disjunction. */
  ssa_insured_at_death?: boolean | null;
}

export interface IntakeAsset {
  name: string;
  kind?: AssetKind | null;
  situs_state?: string | null;
  gross_value_cents?: number | null;
  encumbrance_cents?: number | null;
  title_form?: TitleForm | null;
  beneficiary_designation?: BeneficiaryDesignation | null;
  is_primary_residence?: boolean | null;
  /** §2.1 — stated exemption, Fla. Stat. §732.402. Homestead is derived. */
  exempt_from_creditors?: boolean | null;
}

export interface IntakeDebt {
  kind?: "mortgage" | "credit_card" | "medical" | "tax" | "loan" | "funeral" | "other" | null;
  amount_cents?: number | null;
  secured_by_asset?: string | null;
}

export interface IntakeHeir {
  relationship?: "spouse" | "child" | "parent" | "sibling" | "other" | null;
  name?: string | null;
  age?: number | null;
  receives_means_tested_benefits?: boolean | null;
  is_suspect_in_death?: boolean | null;
  disclaimed?: boolean | null;
  // §2.1 — 42 U.S.C. §402(i). Never inferred from `relationship`.
  lived_in_same_household_at_death?: boolean | null;
  entitled_to_spouse_benefits_month_of_death?: boolean | null;
  entitled_to_child_benefits_month_of_death?: boolean | null;
}

/** §2.1 — the two figures Fla. Stat. §735.301's allowance is measured against. */
export interface IntakeExpenses {
  preferred_funeral_cents?: number | null;
  last_illness_medical_cents?: number | null;
}

export interface IntakeCase {
  as_of_date: CivilDate;
  decedent?: IntakeDecedent | null;
  assets?: IntakeAsset[] | null;
  debts?: IntakeDebt[] | null;
  heirs?: IntakeHeir[] | null;
  conflict_signals?: boolean | null;
  /** "Is this asset list complete?" — gates every valuation cap test. */
  inventory_complete?: boolean | null;
  /** §2.1 — "Is this list of people complete?" — gates every negative
   *  conclusion about who may claim. */
  heirs_complete?: boolean | null;
  /** §2.1 */
  expenses?: IntakeExpenses | null;
}

// ---------------------------------------------------------------- response

export type Classification = "probate" | "non_probate" | "unknown";

export type ClassificationBasis =
  | "jtwros_survivorship" | "community_property_ros" | "beneficiary_designation"
  | "pod_tod" | "trust_funded" | "sole_name_no_designation"
  | "beneficiary_predeceased_falls_to_estate" | "designation_to_estate" | "unknown_title";

export interface AssetClassification {
  name: string;
  classification: Classification;
  basis: ClassificationBasis | null;
  reason: string;
  citation: Citation | null;
  missing_facts: FactPath[];
  counts_toward: string[];
  value_cents: number | null;
}

export type RouteStatus = "qualifies" | "does_not_qualify" | "needs_information";

export interface RouteReport {
  route: string;
  label: string;
  status: RouteStatus;
  reasons: Reason[];
  missing_facts: FactPath[];
  forms: string[];
  citations: Citation[];
}

export type Verdict = "ELIGIBLE" | "INCOMPLETE_INFO" | "OTHER_FORM_REQUIRED";

export interface JurisdictionReport {
  code: string;
  role: "domicile" | "ancillary";
  verdict: Verdict;
  routes: RouteReport[];
}

export type FederalStatus =
  | "required" | "not_required" | "needs_information" | "payable" | "not_payable";

export interface FederalReport {
  item: "irs_form_1310" | "ssa_lump_sum_death_payment" | string;
  label: string;
  status: FederalStatus;
  payee: "surviving_spouse" | "child" | "estate" | "none" | null;
  amount_cents: number | null;
  reasons: Reason[];
  missing_facts: FactPath[];
  citations: Citation[];
}

export type FlagSeverity = "critical" | "warning" | "info";

export interface Flag {
  id: string;
  severity: FlagSeverity;
  title: string;
  detail: string;
  citation: Citation | null;
  triggered_by: FactPath[];
  action: string;
}

export interface Deadline {
  id: string;
  label: string;
  status: "computed" | "awaiting_event" | "needs_information";
  date: CivilDate | null;
  relative_to: "letters_issued" | "date_of_death" | "first_publication" | "filing" | string;
  offset_days: number | null;
  citation: Citation | null;
}

export interface NextAction {
  id: string;
  label: string;
  blocked_by: FactPath[];
}

export interface SettlementAssessment {
  engine: string;
  snapshot: { source_as_of: string; supported_death_dates_through: string };
  asset_map: AssetClassification[];
  probate_estate: {
    known_subtotal_cents: number | null;
    status: "known" | "partial";
    missing_facts: FactPath[];
  };
  jurisdictions: JurisdictionReport[];
  federal: FederalReport[];
  flags: Flag[];
  deadlines: Deadline[];
  next_actions: NextAction[];
  unresolved_facts: FactPath[];
  notes: string[];
}

export interface ErrorEnvelope {
  error: {
    code: "invalid_date" | "after_snapshot" | "malformed_case";
    detail: string;
  };
}

export type AssessResponse = SettlementAssessment | ErrorEnvelope;

export function isError(r: AssessResponse): r is ErrorEnvelope {
  return (r as ErrorEnvelope).error !== undefined;
}

export interface SampleCase {
  id: string;
  label: string;
  blurb: string;
  case: IntakeCase;
}

/** Display helpers shared by every Atlas component. */
export const ROUTE_STATUS_TONE: Record<RouteStatus, "ok" | "wait" | "out"> = {
  qualifies: "ok",
  does_not_qualify: "out",
  needs_information: "wait",
};

export function formatUSD(cents: number | null | undefined): string {
  if (cents === null || cents === undefined) return "—";
  return (cents / 100).toLocaleString("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  });
}

export function formatDate(d: CivilDate | null | undefined): string {
  if (!d) return "—";
  const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  return `${months[d.month - 1] ?? "?"} ${d.day}, ${d.year}`;
}
