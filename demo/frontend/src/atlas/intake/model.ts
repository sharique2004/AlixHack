/* The working state behind the wizard, and the "what we still don't know"
   computation that the whole product hangs on.

   The draft carries a client-side `_id` on every repeated row so React can key
   them; `toIntakeCase` strips those so what goes over the wire is exactly the
   `IntakeCase` in CONTRACT-SETTLEMENT.md §2 and nothing else. */

import type {
  CivilDate,
  FactPath,
  IntakeAsset,
  IntakeCase,
  IntakeDebt,
  IntakeDecedent,
  IntakeExpenses,
  IntakeHeir,
} from "../types";

export interface DraftAsset extends IntakeAsset {
  _id: string;
}
export interface DraftDebt extends IntakeDebt {
  _id: string;
}
export interface DraftHeir extends IntakeHeir {
  _id: string;
}

export interface Draft {
  as_of_date: CivilDate;
  decedent: IntakeDecedent;
  assets: DraftAsset[];
  debts: DraftDebt[];
  heirs: DraftHeir[];
  conflict_signals: boolean | null;
  inventory_complete: boolean | null;
  /* CONTRACT §2.1. The wizard does not ask for these yet, but a sample case
     that supplies them must not lose them on the way back out — the Florida
     date-of-death demo turns on `decedent.will_directs_administration` and on
     `expenses`, and silently dropping a supplied fact would turn a known
     answer into a question. Nested §2.1 fields ride along inside `decedent`,
     `assets[]` and `heirs[]`, which are spread through verbatim. */
  heirs_complete: boolean | null;
  expenses: IntakeExpenses | null;
}

let seq = 0;
const nextId = () => `r${++seq}`;

export function todayCivil(): CivilDate {
  const d = new Date();
  return { year: d.getFullYear(), month: d.getMonth() + 1, day: d.getDate() };
}

export function newAsset(): DraftAsset {
  return {
    _id: nextId(),
    name: "",
    kind: null,
    situs_state: null,
    gross_value_cents: null,
    encumbrance_cents: null,
    title_form: null,
    beneficiary_designation: null,
    is_primary_residence: null,
  };
}

export function newDebt(): DraftDebt {
  return { _id: nextId(), kind: null, amount_cents: null, secured_by_asset: null };
}

export function newHeir(): DraftHeir {
  return {
    _id: nextId(),
    relationship: null,
    name: "",
    age: null,
    receives_means_tested_benefits: null,
    is_suspect_in_death: null,
    disclaimed: null,
  };
}

/** A blank draft is entirely unknown, and that is a legitimate state. */
export function emptyDraft(): Draft {
  return {
    as_of_date: todayCivil(),
    decedent: {
      death_date: null,
      domicile_state: null,
      marital_status: null,
      surviving_spouse: null,
      manner_of_death: null,
      death_certificate_final: null,
      will_status: null,
      employment_related_death: null,
      third_party_fault_suspected: null,
      related_death_within_120h: null,
      received_medicaid_ltc: null,
      veteran: null,
      pending_litigation: null,
    },
    assets: [newAsset()],
    debts: [],
    heirs: [],
    conflict_signals: null,
    inventory_complete: null,
    heirs_complete: null,
    expenses: null,
  };
}

export function fromIntakeCase(c: IntakeCase): Draft {
  const base = emptyDraft();
  return {
    as_of_date: c.as_of_date ?? base.as_of_date,
    decedent: { ...base.decedent, ...(c.decedent ?? {}) },
    assets: (c.assets ?? []).map((a) => ({ ...newAsset(), ...a })),
    debts: (c.debts ?? []).map((d) => ({ ...newDebt(), ...d })),
    heirs: (c.heirs ?? []).map((h) => ({ ...newHeir(), ...h })),
    conflict_signals: c.conflict_signals ?? null,
    inventory_complete: c.inventory_complete ?? null,
    heirs_complete: c.heirs_complete ?? null,
    expenses: c.expenses ?? null,
  };
}

export function toIntakeCase(d: Draft): IntakeCase {
  const strip = <T extends { _id: string }>({ _id, ...rest }: T) => rest;
  return {
    as_of_date: d.as_of_date,
    decedent: d.decedent,
    assets: d.assets.filter((a) => a.name.trim() !== "").map(strip) as IntakeAsset[],
    debts: d.debts.map(strip) as IntakeDebt[],
    heirs: d.heirs.map(strip) as IntakeHeir[],
    conflict_signals: d.conflict_signals,
    inventory_complete: d.inventory_complete,
    heirs_complete: d.heirs_complete,
    expenses: d.expenses,
  };
}

// ---------------------------------------------------------------- steps

export const STEPS = [
  { key: "person", title: "The person.", short: "The person" },
  { key: "will", title: "The will.", short: "The will" },
  { key: "assets", title: "What they owned.", short: "What they owned" },
  { key: "debts", title: "What they owed.", short: "What they owed" },
  { key: "family", title: "The family.", short: "The family" },
  { key: "review", title: "Review.", short: "Review" },
] as const;

export type StepKey = (typeof STEPS)[number]["key"];
export const STEP_COUNT = STEPS.length;

/** What every step receives. Steps never own state; they patch the draft. */
export interface StepProps {
  draft: Draft;
  update: (patch: Partial<Draft>) => void;
  setDecedent: (patch: Partial<IntakeDecedent>) => void;
}

// ---------------------------------------------------------------- unknowns

export interface OpenFact {
  /** Contract fact path, e.g. "assets[2].title_form". */
  path: FactPath;
  /** What a human would call it. */
  label: string;
  /** Which step edits it. */
  step: number;
}

const PERSON_FACTS: [keyof IntakeDecedent, string][] = [
  ["death_date", "The date they died"],
  ["domicile_state", "The state they lived in"],
  ["marital_status", "Whether they were married"],
  ["surviving_spouse", "Whether a spouse survived them"],
  ["manner_of_death", "How they died"],
  ["death_certificate_final", "Whether the death certificate is final"],
  ["veteran", "Whether they were a veteran"],
];

const WILL_FACTS: [keyof IntakeDecedent, string][] = [
  ["will_status", "Whether there is a will"],
  ["employment_related_death", "Whether the death was work-related"],
  ["third_party_fault_suspected", "Whether someone else may be at fault"],
  ["related_death_within_120h", "Whether another heir died within 120 hours"],
  ["received_medicaid_ltc", "Whether they received Medi-Cal long-term care"],
  ["pending_litigation", "Whether any lawsuit was pending"],
];

const ASSET_FACTS: [keyof IntakeAsset, string][] = [
  ["kind", "what kind of asset it is"],
  ["gross_value_cents", "what it is worth"],
  ["title_form", "how it was titled"],
  ["beneficiary_designation", "whether it names a beneficiary"],
  ["situs_state", "which state it sits in"],
];

/** Everything the case does not yet say, in contract fact-path form.
    This is the rail, and it is also what the engine will echo back. */
export function openFacts(d: Draft): OpenFact[] {
  const out: OpenFact[] = [];

  for (const [key, label] of PERSON_FACTS) {
    if (d.decedent[key] == null) out.push({ path: `decedent.${key}`, label, step: 0 });
  }
  for (const [key, label] of WILL_FACTS) {
    if (d.decedent[key] == null) out.push({ path: `decedent.${key}`, label, step: 1 });
  }

  d.assets.forEach((a, i) => {
    const who = a.name.trim() === "" ? `Asset ${i + 1}` : a.name.trim();
    for (const [key, label] of ASSET_FACTS) {
      if (a[key] == null) out.push({ path: `assets[${i}].${key}`, label: `${who} — ${label}`, step: 2 });
    }
    if (a.kind === "real_property" && a.is_primary_residence == null) {
      out.push({
        path: `assets[${i}].is_primary_residence`,
        label: `${who} — whether it was their home`,
        step: 2,
      });
    }
  });

  if (d.inventory_complete == null) {
    out.push({ path: "inventory_complete", label: "Whether this list of assets is complete", step: 2 });
  }

  d.heirs.forEach((h, i) => {
    const who = (h.name ?? "").trim() === "" ? `Person ${i + 1}` : (h.name ?? "").trim();
    if (h.relationship == null) {
      out.push({ path: `heirs[${i}].relationship`, label: `${who} — how they are related`, step: 4 });
    }
    if (h.relationship === "child" && h.age == null) {
      out.push({ path: `heirs[${i}].age`, label: `${who} — their age`, step: 4 });
    }
  });

  if (d.conflict_signals == null) {
    out.push({ path: "conflict_signals", label: "Whether anyone is in disagreement", step: 4 });
  }

  return out;
}

/** Which step owns a fact path — used to jump back from a result. */
export function stepForFactPath(path: FactPath): number {
  if (path.startsWith("assets") || path === "inventory_complete") return 2;
  if (path.startsWith("heirs") || path === "conflict_signals") return 4;
  if (path.startsWith("debts")) return 3;
  for (const [key] of WILL_FACTS) {
    if (path === `decedent.${key}`) return 1;
  }
  return 0;
}

// ---------------------------------------------------------------- summary

export function knownAssetTotalCents(d: Draft): number {
  return d.assets.reduce((n, a) => n + (a.gross_value_cents ?? 0), 0);
}

export function knownDebtTotalCents(d: Draft): number {
  return d.debts.reduce((n, x) => n + (x.amount_cents ?? 0), 0);
}
