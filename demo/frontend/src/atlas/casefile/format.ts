/**
 * Case file — derivation and copy helpers.
 *
 * Everything here reads the assessment and says something honest about it.
 * Nothing here invents a number, a date, or a legal claim: if a value is
 * unknown the helper returns null and the UI renders the unknown state.
 */

import type {
  AssetClassification,
  CivilDate,
  Deadline,
  FactPath,
  JurisdictionReport,
  RouteReport,
  RouteStatus,
  SettlementAssessment,
} from "../types";

// ------------------------------------------------------------------ numbers

const COUNT_WORDS = [
  "zero", "one", "two", "three", "four", "five",
  "six", "seven", "eight", "nine", "ten",
];

/** "two facts" reads better than "2 facts" in a serif sentence. */
export function countWord(n: number): string {
  return COUNT_WORDS[n] ?? String(n);
}

export function pluralize(n: number, one: string, many: string): string {
  return n === 1 ? one : many;
}

export function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// ------------------------------------------------------------------- naming

/** Two-letter jurisdiction code → state name. Falls back to the code itself. */
const STATE_NAMES: Record<string, string> = {
  AL: "Alabama", AK: "Alaska", AZ: "Arizona", AR: "Arkansas", CA: "California",
  CO: "Colorado", CT: "Connecticut", DE: "Delaware", DC: "District of Columbia",
  FL: "Florida", GA: "Georgia", HI: "Hawaii", ID: "Idaho", IL: "Illinois",
  IN: "Indiana", IA: "Iowa", KS: "Kansas", KY: "Kentucky", LA: "Louisiana",
  ME: "Maine", MD: "Maryland", MA: "Massachusetts", MI: "Michigan",
  MN: "Minnesota", MS: "Mississippi", MO: "Missouri", MT: "Montana",
  NE: "Nebraska", NV: "Nevada", NH: "New Hampshire", NJ: "New Jersey",
  NM: "New Mexico", NY: "New York", NC: "North Carolina", ND: "North Dakota",
  OH: "Ohio", OK: "Oklahoma", OR: "Oregon", PA: "Pennsylvania",
  RI: "Rhode Island", SC: "South Carolina", SD: "South Dakota",
  TN: "Tennessee", TX: "Texas", UT: "Utah", VT: "Vermont", VA: "Virginia",
  WA: "Washington", WV: "West Virginia", WI: "Wisconsin", WY: "Wyoming",
};

export function stateName(code: string): string {
  return STATE_NAMES[code.toUpperCase()] ?? code;
}

/** snake_case id → "Sentence case words". Never used where a real label exists. */
export function humanizeId(id: string): string {
  const words = id.replace(/_/g, " ").trim();
  return words.charAt(0).toUpperCase() + words.slice(1);
}

/** Lowercase a label's first letter so it can sit mid-sentence. */
export function lowerFirst(s: string): string {
  if (!s) return s;
  // Leave acronyms alone: "IRS Form 1310" must not become "iRS Form 1310".
  if (s.length > 1 && s[1] === s[1].toUpperCase() && /[A-Z]/.test(s[1])) return s;
  return s.charAt(0).toLowerCase() + s.slice(1);
}

/** Drop a trailing period so labels compose into our own sentences. */
export function unperiod(s: string): string {
  return s.endsWith(".") ? s.slice(0, -1) : s;
}

// ------------------------------------------------------------- fact paths

const FIELD_LABELS: Record<string, string> = {
  death_date: "Date of death",
  domicile_state: "State of domicile",
  marital_status: "Marital status",
  surviving_spouse: "Surviving spouse",
  manner_of_death: "Manner of death",
  death_certificate_final: "Death certificate final",
  will_status: "Will status",
  employment_related_death: "Employment-related death",
  third_party_fault_suspected: "Third-party fault suspected",
  related_death_within_120h: "Related death within 120 hours",
  received_medicaid_ltc: "Received Medicaid long-term care",
  veteran: "Veteran",
  pending_litigation: "Pending litigation",
  kind: "Kind of asset",
  situs_state: "State where it sits",
  gross_value_cents: "Gross value",
  encumbrance_cents: "Amount owed against it",
  title_form: "How it is titled",
  beneficiary_designation: "Beneficiary designation",
  is_primary_residence: "Primary residence",
  amount_cents: "Amount",
  secured_by_asset: "Secured by",
  relationship: "Relationship",
  name: "Name",
  age: "Age",
  receives_means_tested_benefits: "Receives means-tested benefits",
  is_suspect_in_death: "Suspect in the death",
  disclaimed: "Disclaimed",
  conflict_signals: "Signs of family conflict",
  inventory_complete: "Is the asset list complete?",
  // CONTRACT §2.1 — without these the humanizer produces "Ssa insured at death".
  heirs_complete: "Is the list of people complete?",
  will_directs_administration: "Does the will direct administration?",
  administration_pending: "Is an administration already open?",
  federal_refund_due: "Is a federal tax refund due?",
  refund_claimant: "Who is claiming the refund?",
  final_return_kind: "Original or amended final return",
  court_certificate_attached: "Court certificate of appointment attached",
  ssa_insured_at_death: "Insured under Social Security at death",
  exempt_from_creditors: "Exempt from creditors' claims",
  preferred_funeral_cents: "Funeral expenses",
  last_illness_medical_cents: "Medical costs of the last illness",
  lived_in_same_household_at_death: "Lived in the same household at death",
  entitled_to_spouse_benefits_month_of_death: "Entitled to spouse's benefits that month",
  entitled_to_child_benefits_month_of_death: "Entitled to child's benefits that month",
};

function fieldLabel(field: string): string {
  return FIELD_LABELS[field] ?? humanizeId(field.replace(/_cents$/, ""));
}

export interface FactDescription {
  /** The exact contract path, always shown so the claim stays checkable. */
  path: FactPath;
  /** What is being asked, in plain English. */
  label: string;
  /** Whose fact it is — an asset name, "The decedent", or null. */
  owner: string | null;
}

/**
 * Turn "assets[4].title_form" into something a human can act on, resolving the
 * index against the asset map when it lines up. If the path does not parse we
 * show it verbatim rather than guessing.
 */
export function describeFact(
  path: FactPath,
  assets: AssetClassification[] = [],
): FactDescription {
  const indexed = /^(assets|heirs|debts)\[(\d+)\]\.(.+)$/.exec(path);
  if (indexed) {
    const [, group, rawIndex, field] = indexed;
    const i = Number(rawIndex);
    let owner: string;
    if (group === "assets") owner = assets[i]?.name ?? `Asset ${i + 1}`;
    else if (group === "heirs") owner = `Heir ${i + 1}`;
    else owner = `Debt ${i + 1}`;
    return { path, label: fieldLabel(field), owner };
  }

  const scoped = /^(decedent|snapshot)\.(.+)$/.exec(path);
  if (scoped) {
    return { path, label: fieldLabel(scoped[2]), owner: "The decedent" };
  }

  if (/^[a-z0-9_]+$/.test(path)) {
    return { path, label: fieldLabel(path), owner: null };
  }
  return { path, label: path, owner: null };
}

/** Order-stable dedup, mirroring the engine's own aggregation. */
export function dedupe(paths: FactPath[]): FactPath[] {
  const seen = new Set<string>();
  const out: FactPath[] = [];
  for (const p of paths) {
    if (!seen.has(p)) {
      seen.add(p);
      out.push(p);
    }
  }
  return out;
}

/**
 * Everything in the assessment that is waiting on one fact. Derived purely from
 * the missing_facts the engine reported — nothing is inferred.
 */
export function whatWaitsOn(a: SettlementAssessment, path: FactPath): string[] {
  const out: string[] = [];
  for (const asset of a.asset_map) {
    if (asset.missing_facts.includes(path)) out.push(`Placing ${asset.name}`);
  }
  if (a.probate_estate.missing_facts.includes(path)) {
    out.push("The probate-estate subtotal");
  }
  for (const j of a.jurisdictions) {
    for (const r of j.routes) {
      if (r.missing_facts.includes(path)) out.push(`${unperiod(r.label)} (${j.code})`);
    }
  }
  for (const f of a.federal) {
    if (f.missing_facts.includes(path)) out.push(unperiod(f.label));
  }
  return dedupe(out);
}

// ------------------------------------------------------------------ assets

export interface EstateSplit {
  nonProbate: AssetClassification[];
  probate: AssetClassification[];
  unknown: AssetClassification[];
  /** Sum of known values only. null when nothing in the column has a value. */
  nonProbateKnownCents: number | null;
  probateKnownCents: number | null;
  unknownKnownCents: number | null;
  /** Assets in each column whose value is not yet known. */
  nonProbateUnvalued: number;
  probateUnvalued: number;
}

function sumKnown(assets: AssetClassification[]): number | null {
  const valued = assets.filter((a) => a.value_cents !== null);
  if (valued.length === 0) return null;
  return valued.reduce((t, a) => t + (a.value_cents ?? 0), 0);
}

export function splitEstate(assetMap: AssetClassification[]): EstateSplit {
  const nonProbate = assetMap.filter((a) => a.classification === "non_probate");
  const probate = assetMap.filter((a) => a.classification === "probate");
  const unknown = assetMap.filter((a) => a.classification === "unknown");
  return {
    nonProbate,
    probate,
    unknown,
    nonProbateKnownCents: sumKnown(nonProbate),
    probateKnownCents: sumKnown(probate),
    unknownKnownCents: sumKnown(unknown),
    nonProbateUnvalued: nonProbate.filter((a) => a.value_cents === null).length,
    probateUnvalued: probate.filter((a) => a.value_cents === null).length,
  };
}

export const CLASSIFICATION_LABEL: Record<AssetClassification["classification"], string> = {
  probate: "In the probate estate",
  non_probate: "Passes outside probate",
  unknown: "Not yet classified",
};

/** Build route id → human label from whatever the assessment actually reports. */
export function routeLabels(a: SettlementAssessment): Record<string, string> {
  const out: Record<string, string> = {};
  for (const j of a.jurisdictions) {
    for (const r of j.routes) out[r.route] = r.label;
  }
  return out;
}

// -------------------------------------------------------------- jurisdictions

/** Domicile first, then ancillary; stable within each group. */
export function orderJurisdictions(js: JurisdictionReport[]): JurisdictionReport[] {
  return [...js].sort((x, y) => rank(x.role) - rank(y.role));
  function rank(role: JurisdictionReport["role"]): number {
    return role === "domicile" ? 0 : 1;
  }
}

const ROUTE_ORDER: Record<RouteStatus, number> = {
  qualifies: 0,
  needs_information: 1,
  does_not_qualify: 2,
};

/** What is open, then what is one question away, then what is ruled out. */
export function orderRoutes(rs: RouteReport[]): RouteReport[] {
  return [...rs].sort((x, y) => ROUTE_ORDER[x.status] - ROUTE_ORDER[y.status]);
}

export const VERDICT_LABEL: Record<JurisdictionReport["verdict"], string> = {
  ELIGIBLE: "A simplified route is open",
  INCOMPLETE_INFO: "Waiting on facts",
  OTHER_FORM_REQUIRED: "Another form is required",
};

export const ROUTE_STATUS_LABEL: Record<RouteStatus, string> = {
  qualifies: "Qualifies",
  does_not_qualify: "Ruled out",
  needs_information: "Needs information",
};

// ------------------------------------------------------------ verdict header

/** The single needs_information route closest to being answered. */
function closestToAnswered(routes: RouteReport[]): RouteReport | null {
  const needing = routes.filter((r) => r.status === "needs_information");
  if (needing.length === 0) return null;
  return needing.reduce((best, r) =>
    r.missing_facts.length < best.missing_facts.length ? r : best,
  );
}

/**
 * The plain-sentence verdict. Two sentences at most: what kind of estate this
 * is, and what the domicile jurisdiction says about the rest. Every hedge here
 * is load-bearing — the copy weakens itself whenever the data is incomplete.
 */
export function verdictSentences(a: SettlementAssessment): string[] {
  const out: string[] = [];
  const split = splitEstate(a.asset_map);
  const np = split.nonProbateKnownCents ?? 0;
  const pr = split.probateKnownCents ?? 0;
  const total = np + pr;
  const incomplete =
    split.unknown.length > 0 ||
    split.nonProbateUnvalued > 0 ||
    split.probateUnvalued > 0;
  const hedge = incomplete ? "On what's known so far, " : "";

  if (a.asset_map.length === 0) {
    out.push("No assets have been entered yet, so there is nothing to classify.");
  } else if (total === 0) {
    out.push(
      split.unknown.length > 0
        ? "How this estate passes is still unresolved — no asset has been classified with a value yet."
        : "Nothing in this estate has a value on record yet.",
    );
  } else {
    const share = np / total;
    let clause: string;
    if (np === 0) {
      clause = "everything with a value on record sits inside the probate estate";
    } else if (pr === 0) {
      clause = "everything with a value on record passes outside probate";
    } else if (share >= 0.6) {
      clause = "most of this estate passes outside probate";
    } else if (share <= 0.4) {
      clause = "most of this estate sits inside the probate estate";
    } else {
      clause = "this estate divides about evenly between what passes outside probate and what does not";
    }
    out.push(
      hedge
        ? `${hedge}${clause}.`
        : `${clause.charAt(0).toUpperCase()}${clause.slice(1)}.`,
    );
  }

  const home =
    a.jurisdictions.find((j) => j.role === "domicile") ?? a.jurisdictions[0];
  if (home) {
    const where = stateName(home.code);
    const qualifying = home.routes.filter((r) => r.status === "qualifies");
    const closest = closestToAnswered(home.routes);
    if (home.verdict === "ELIGIBLE" && qualifying[0]) {
      out.push(
        `What's left qualifies in ${where} — ${lowerFirst(unperiod(qualifying[0].label))}.`,
      );
    } else if (home.verdict === "INCOMPLETE_INFO" && closest) {
      const n = dedupe(closest.missing_facts).length;
      const route = lowerFirst(unperiod(closest.label));
      out.push(
        n === 0
          ? `What's left may qualify in ${where} — ${route}, once the open questions are answered.`
          : `What's left may qualify in ${where} — ${route}, once ${countWord(n)} ${pluralize(n, "fact is", "facts are")} confirmed.`,
      );
    } else if (qualifying[0]) {
      out.push(
        `No simplified route fits in ${where}; the open path is ${lowerFirst(unperiod(qualifying[0].label))}.`,
      );
    } else {
      out.push(`No route in ${where} is open on these facts yet.`);
    }
  }

  return out;
}

// ---------------------------------------------------------------- deadlines

const RELATIVE_TO_PHRASE: Record<string, string> = {
  letters_issued: "letters issue",
  date_of_death: "the date of death",
  first_publication: "first publication",
  filing: "the filing",
};

export function relativeToPhrase(rel: string): string {
  return RELATIVE_TO_PHRASE[rel] ?? humanizeId(rel).toLowerCase();
}

/** "120 days after the date of death" / "after letters issue" when no offset. */
export function offsetPhrase(d: Deadline): string {
  const anchor = relativeToPhrase(d.relative_to);
  if (d.offset_days === null) return `Measured from ${anchor}`;
  return `${d.offset_days} ${pluralize(d.offset_days, "day", "days")} after ${anchor}`;
}

function toOrdinal(d: CivilDate): number {
  return d.year * 10000 + d.month * 100 + d.day;
}

/** Parse the snapshot's "YYYY-MM-DD" stamp. Returns null if it is not one. */
export function parseIsoDate(iso: string): CivilDate | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso.trim());
  if (!m) return null;
  return { year: Number(m[1]), month: Number(m[2]), day: Number(m[3]) };
}

/** true only when both dates are real and the deadline is strictly earlier. */
export function isPast(date: CivilDate | null, asOf: string): boolean {
  const now = parseIsoDate(asOf);
  if (!date || !now) return false;
  return toOrdinal(date) < toOrdinal(now);
}

const DEADLINE_ORDER: Record<Deadline["status"], number> = {
  computed: 0,
  awaiting_event: 1,
  needs_information: 2,
};

/** Datable items in date order, then the honestly undatable ones. */
export function orderDeadlines(ds: Deadline[]): Deadline[] {
  return [...ds].sort((x, y) => {
    const byStatus = DEADLINE_ORDER[x.status] - DEADLINE_ORDER[y.status];
    if (byStatus !== 0) return byStatus;
    if (x.date && y.date) return toOrdinal(x.date) - toOrdinal(y.date);
    return 0;
  });
}

// -------------------------------------------------------------------- flags

const SEVERITY_ORDER = { critical: 0, warning: 1, info: 2 } as const;

export function orderFlags<T extends { severity: keyof typeof SEVERITY_ORDER }>(
  flags: T[],
): T[] {
  return [...flags].sort((x, y) => SEVERITY_ORDER[x.severity] - SEVERITY_ORDER[y.severity]);
}

export const SEVERITY_LABEL = {
  critical: "Stop — get a professional",
  warning: "Worth a closer look",
  info: "Good to know",
} as const;

// ------------------------------------------------------------------ federal

export const PAYEE_LABEL: Record<string, string> = {
  surviving_spouse: "Surviving spouse",
  child: "Entitled child",
  estate: "The estate",
  none: "Nobody is eligible",
};

export const FEDERAL_STATUS_LABEL: Record<string, string> = {
  required: "Required",
  not_required: "Not required",
  needs_information: "Needs information",
  payable: "Payable",
  not_payable: "Not payable",
};
