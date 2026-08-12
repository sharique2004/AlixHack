/* Fixtures — hand-written payloads so the whole product is developable and
   demoable with the engine down.

   HONESTY RULES FOR THIS FILE (they are not negotiable):
   • Nothing here is engine output. Every consumer must render it behind a
     visible sample marker — `SampleBadge` in the design kit exists for that.
   • The canonical case is the one written into CONTRACT-SETTLEMENT.md §6, and
     the expectations there are what these objects encode.
   • Every citation below is a real statute or a real form. Where a figure is
     quoted it is either fixed by statute (the $255 SSA payment, 42 U.S.C.
     §402(i)) or given by the contract itself. No invented numbers, no invented
     section numbers, no thresholds guessed at.
   • People, addresses and account names are fictional. */

import type {
  ErrorEnvelope,
  IntakeCase,
  SampleCase,
  SettlementAssessment,
} from "./types";
import type { AssessOutcome } from "./api";

export const FIXTURE_NOTICE =
  "Sample data — written by hand against the frozen contract so this view can be built and demoed. Not a live engine result.";

const AS_OF = { year: 2026, month: 8, day: 12 };
const SNAPSHOT = { source_as_of: "2026-08-12", supported_death_dates_through: "2026-12-31" };

// ==================================================================
// 1. The canonical case — CONTRACT-SETTLEMENT.md §6
// ==================================================================

export const CANONICAL_CASE: IntakeCase = {
  as_of_date: AS_OF,
  decedent: {
    death_date: { year: 2026, month: 3, day: 4 },
    domicile_state: "CA",
    marital_status: "married",
    surviving_spouse: true,
    manner_of_death: "natural",
    death_certificate_final: true,
    will_status: "valid_original",
    employment_related_death: false,
    third_party_fault_suspected: false,
    related_death_within_120h: false,
    received_medicaid_ltc: false,
    veteran: false,
    pending_litigation: false,
  },
  assets: [
    {
      name: "Primary residence — 12 Oak St",
      kind: "real_property",
      situs_state: "CA",
      gross_value_cents: 62_000_000,
      encumbrance_cents: 41_000_000,
      title_form: "jtwros",
      beneficiary_designation: "none",
      is_primary_residence: true,
    },
    {
      name: "Brokerage account — Schwab",
      kind: "brokerage",
      situs_state: "CA",
      gross_value_cents: 14_100_000,
      encumbrance_cents: 0,
      title_form: "sole",
      beneficiary_designation: "none",
      is_primary_residence: false,
    },
    {
      name: "401(k) — Fidelity",
      kind: "retirement",
      situs_state: "CA",
      gross_value_cents: 31_000_000,
      encumbrance_cents: 0,
      title_form: "sole",
      beneficiary_designation: "named_living",
      is_primary_residence: false,
    },
    {
      name: "2019 Subaru Outback",
      kind: "vehicle",
      situs_state: "CA",
      gross_value_cents: 1_800_000,
      encumbrance_cents: 0,
      title_form: "sole",
      beneficiary_designation: "none",
      is_primary_residence: false,
    },
    {
      name: "Savings account — Wells Fargo",
      kind: "bank",
      situs_state: "CA",
      gross_value_cents: 940_000,
      encumbrance_cents: 0,
      title_form: null, // the unknown that blocks the cap test
      beneficiary_designation: null,
      is_primary_residence: false,
    },
  ],
  debts: [
    { kind: "mortgage", amount_cents: 41_000_000, secured_by_asset: "Primary residence — 12 Oak St" },
    { kind: "credit_card", amount_cents: 310_000, secured_by_asset: null },
    { kind: "funeral", amount_cents: 890_000, secured_by_asset: null },
  ],
  heirs: [
    { relationship: "spouse", name: "Ana Reyes", age: 68, receives_means_tested_benefits: false, is_suspect_in_death: false, disclaimed: false },
    { relationship: "child", name: "Daniel Reyes", age: 34, receives_means_tested_benefits: false, is_suspect_in_death: false, disclaimed: false },
  ],
  conflict_signals: false,
  inventory_complete: null, // never asserted, so every cap test stays gated
};

export const CANONICAL_ASSESSMENT: SettlementAssessment = {
  engine: "lean4",
  snapshot: SNAPSHOT,
  asset_map: [
    {
      name: "Primary residence — 12 Oak St",
      classification: "non_probate",
      basis: "jtwros_survivorship",
      reason:
        "Held in joint tenancy with right of survivorship — passes to the surviving joint tenant by operation of law, outside the estate.",
      citation: { label: "Cal. Prob. Code §13050(b)", url: null },
      missing_facts: [],
      counts_toward: [],
      value_cents: 62_000_000,
    },
    {
      name: "Brokerage account — Schwab",
      classification: "probate",
      basis: "sole_name_no_designation",
      reason:
        "Held in the decedent's sole name with no transfer-on-death designation, so it is not excluded from the estate and passes through it.",
      citation: { label: "Cal. Prob. Code §13050", url: null },
      missing_facts: [],
      counts_toward: ["ca_personal_property_affidavit"],
      value_cents: 14_100_000,
    },
    {
      name: "401(k) — Fidelity",
      classification: "non_probate",
      basis: "beneficiary_designation",
      reason:
        "A living named beneficiary takes under the plan's designation. A nonprobate transfer in an employment contract or similar instrument is valid without will formalities.",
      citation: { label: "Cal. Prob. Code §5000", url: null },
      missing_facts: [],
      counts_toward: [],
      value_cents: 31_000_000,
    },
    {
      name: "2019 Subaru Outback",
      classification: "probate",
      basis: "sole_name_no_designation",
      reason:
        "Titled in the decedent's sole name with no surviving co-owner and no beneficiary, so it is part of the estate.",
      citation: { label: "Cal. Prob. Code §13050", url: null },
      missing_facts: [],
      counts_toward: ["ca_personal_property_affidavit"],
      value_cents: 1_800_000,
    },
    {
      name: "Savings account — Wells Fargo",
      classification: "unknown",
      basis: "unknown_title",
      reason:
        "We do not know how this account was held. A joint account with right of survivorship would pass outside the estate; a sole account would not. We will not guess.",
      citation: { label: "Cal. Prob. Code §13050", url: null },
      missing_facts: ["assets[4].title_form"],
      counts_toward: [],
      value_cents: 940_000,
    },
  ],
  probate_estate: {
    known_subtotal_cents: 15_900_000,
    status: "partial",
    missing_facts: ["assets[4].title_form", "inventory_complete"],
  },
  jurisdictions: [
    {
      code: "CA",
      role: "domicile",
      verdict: "INCOMPLETE_INFO",
      routes: [
        {
          route: "ca_personal_property_affidavit",
          label: "Affidavit for collection of personal property",
          status: "needs_information",
          reasons: [
            { id: "waiting_period_met", text: "More than 40 days have elapsed since the date of death." },
            {
              id: "estate_value_unconfirmed",
              text:
                "One account's form of title is unknown and the asset list has not been confirmed complete, so the estate's value cannot be tested against the statutory limit.",
            },
          ],
          missing_facts: ["assets[4].title_form", "inventory_complete"],
          forms: ["DE-300"],
          citations: [{ label: "Cal. Prob. Code §§13100–13101", url: null }],
        },
        {
          route: "ca_direct_transfer",
          label: "Property passing to the surviving spouse without administration",
          status: "qualifies",
          reasons: [
            {
              id: "passes_to_surviving_spouse",
              text:
                "Property passing outright to a surviving spouse may be transferred without any court administration.",
            },
          ],
          missing_facts: [],
          forms: [],
          citations: [{ label: "Cal. Prob. Code §13500", url: null }],
        },
        {
          route: "ca_spousal_property_petition",
          label: "Spousal or domestic partner property petition",
          status: "qualifies",
          reasons: [
            {
              id: "spouse_may_petition",
              text:
                "The surviving spouse may ask the court to confirm which property passes to them, which is what a title holder normally wants to see before it releases an asset.",
            },
          ],
          missing_facts: [],
          forms: ["DE-221", "DE-226"],
          citations: [{ label: "Cal. Prob. Code §§13500, 13650", url: null }],
        },
        {
          route: "ca_small_value_real_property_affidavit",
          label: "Affidavit for real property of small value",
          status: "does_not_qualify",
          reasons: [
            {
              id: "no_probate_real_property",
              text:
                "The only real property is held in joint tenancy and passes by survivorship, so there is no real property in the estate to transfer by affidavit.",
            },
          ],
          missing_facts: [],
          forms: ["DE-305"],
          citations: [{ label: "Cal. Prob. Code §13200", url: null }],
        },
        {
          route: "ca_primary_residence_petition",
          label: "Petition to determine succession to real property",
          status: "does_not_qualify",
          reasons: [
            {
              id: "residence_passes_by_survivorship",
              text: "The residence passes to the surviving joint tenant, so no succession needs to be determined.",
            },
          ],
          missing_facts: [],
          forms: ["DE-310", "DE-315"],
          citations: [{ label: "Cal. Prob. Code §§13150–13154", url: null }],
        },
        {
          route: "ca_formal_probate_or_other",
          label: "Formal probate administration",
          status: "needs_information",
          reasons: [
            {
              id: "simplified_route_unresolved",
              text:
                "Formal administration is the fallback if no simplified route clears. Whether one clears depends on the two facts still open.",
            },
          ],
          missing_facts: ["assets[4].title_form", "inventory_complete"],
          forms: [],
          citations: [{ label: "Cal. Prob. Code §§13100–13101", url: null }],
        },
      ],
    },
  ],
  federal: [
    {
      item: "irs_form_1310",
      label: "IRS Form 1310 — refund claim for a deceased taxpayer",
      status: "not_required",
      payee: null,
      amount_cents: null,
      reasons: [
        {
          id: "surviving_spouse_joint_return",
          text: "A surviving spouse filing a joint return with the decedent does not file Form 1310 to claim the refund.",
        },
      ],
      missing_facts: [],
      citations: [{ label: "IRS Form 1310 instructions", url: "https://www.irs.gov/forms-pubs/about-form-1310" }],
    },
    {
      item: "ssa_lump_sum_death_payment",
      label: "Social Security lump-sum death payment",
      status: "payable",
      payee: "surviving_spouse",
      amount_cents: 25_500,
      reasons: [
        {
          id: "spouse_living_in_same_household",
          text:
            "A surviving spouse who was living in the same household as the decedent at the time of death receives the lump-sum death payment. It is $255 by statute and it is never payable to the estate.",
        },
      ],
      missing_facts: [],
      citations: [{ label: "42 U.S.C. §402(i)", url: null }],
    },
  ],
  flags: [],
  deadlines: [
    {
      id: "final_income_tax_return",
      label: "Final individual income tax return (Form 1040) due",
      status: "computed",
      date: { year: 2027, month: 4, day: 15 },
      relative_to: "date_of_death",
      offset_days: null,
      citation: { label: "26 U.S.C. §6072(a)", url: null },
    },
    {
      id: "ssa_lump_sum_claim_window",
      label: "Last day to claim the Social Security lump-sum death payment",
      status: "computed",
      date: { year: 2028, month: 3, day: 4 },
      relative_to: "date_of_death",
      offset_days: null,
      citation: { label: "42 U.S.C. §402(i)", url: null },
    },
    {
      id: "ca_creditor_claim_window",
      label: "Creditor claim window closes",
      status: "awaiting_event",
      date: null,
      relative_to: "letters_issued",
      offset_days: 120,
      citation: { label: "Cal. Prob. Code §9100", url: null },
    },
  ],
  next_actions: [
    { id: "obtain_death_certificate", label: "Order 10–15 certified copies of the death certificate.", blocked_by: [] },
    {
      id: "confirm_savings_title",
      label: "Ask Wells Fargo how the savings account was held — sole, joint, or payable on death.",
      blocked_by: ["assets[4].title_form"],
    },
    {
      id: "confirm_inventory_complete",
      label: "Confirm the asset list is complete before any value limit is tested.",
      blocked_by: ["inventory_complete"],
    },
    { id: "claim_ssa_lump_sum", label: "Claim the $255 lump-sum death payment from Social Security.", blocked_by: [] },
  ],
  unresolved_facts: ["assets[4].title_form", "inventory_complete"],
  notes: [
    "Every asset in this case sits in California, so no ancillary proceeding arises.",
    "Two facts are open. Neither of them makes the estate ineligible — they make it undecided, which is a different thing.",
  ],
};

// ==================================================================
// 2. Heavy unknowns — the state a real family is in on day three
// ==================================================================

export const HEAVY_UNKNOWNS_CASE: IntakeCase = {
  as_of_date: AS_OF,
  decedent: {
    death_date: { year: 2026, month: 7, day: 29 },
    domicile_state: "CA",
    marital_status: null,
    surviving_spouse: null,
    manner_of_death: null,
    death_certificate_final: false,
    will_status: "unsure",
    employment_related_death: null,
    third_party_fault_suspected: null,
    related_death_within_120h: null,
    received_medicaid_ltc: null,
    veteran: null,
    pending_litigation: null,
  },
  assets: [
    {
      name: "A house in Fresno",
      kind: "real_property",
      situs_state: "CA",
      gross_value_cents: null,
      encumbrance_cents: null,
      title_form: null,
      beneficiary_designation: null,
      is_primary_residence: true,
    },
    {
      name: "Some kind of bank account",
      kind: "bank",
      situs_state: null,
      gross_value_cents: null,
      encumbrance_cents: null,
      title_form: null,
      beneficiary_designation: null,
      is_primary_residence: false,
    },
  ],
  debts: [],
  heirs: [],
  conflict_signals: null,
  inventory_complete: null,
};

export const HEAVY_UNKNOWNS_ASSESSMENT: SettlementAssessment = {
  engine: "lean4",
  snapshot: SNAPSHOT,
  asset_map: [
    {
      name: "A house in Fresno",
      classification: "unknown",
      basis: "unknown_title",
      reason:
        "How the house was held decides everything about it. In joint tenancy it passes to the survivor; in the decedent's sole name it does not.",
      citation: { label: "Cal. Prob. Code §13050", url: null },
      missing_facts: ["assets[0].title_form", "assets[0].gross_value_cents"],
      counts_toward: [],
      value_cents: null,
    },
    {
      name: "Some kind of bank account",
      classification: "unknown",
      basis: "unknown_title",
      reason: "Neither the form of title nor the balance is known, so this account cannot be classified or counted.",
      citation: { label: "Cal. Prob. Code §13050", url: null },
      missing_facts: ["assets[1].title_form", "assets[1].gross_value_cents"],
      counts_toward: [],
      value_cents: null,
    },
  ],
  probate_estate: {
    known_subtotal_cents: 0,
    status: "partial",
    missing_facts: [
      "assets[0].title_form",
      "assets[0].gross_value_cents",
      "assets[1].title_form",
      "assets[1].gross_value_cents",
      "inventory_complete",
    ],
  },
  jurisdictions: [
    {
      code: "CA",
      role: "domicile",
      verdict: "INCOMPLETE_INFO",
      routes: [
        {
          route: "ca_personal_property_affidavit",
          label: "Affidavit for collection of personal property",
          status: "needs_information",
          reasons: [
            { id: "waiting_period_not_met", text: "40 days have not yet elapsed since the date of death." },
            { id: "estate_value_unknown", text: "No asset has a known value, so no value limit can be tested." },
          ],
          missing_facts: ["assets[0].gross_value_cents", "assets[1].gross_value_cents", "inventory_complete"],
          forms: ["DE-300"],
          citations: [{ label: "Cal. Prob. Code §§13100–13101", url: null }],
        },
        {
          route: "ca_spousal_property_petition",
          label: "Spousal or domestic partner property petition",
          status: "needs_information",
          reasons: [
            { id: "spouse_unknown", text: "We do not know whether there is a surviving spouse, so this route stays open." },
          ],
          missing_facts: ["decedent.surviving_spouse", "decedent.marital_status"],
          forms: ["DE-221", "DE-226"],
          citations: [{ label: "Cal. Prob. Code §§13500, 13650", url: null }],
        },
        {
          route: "ca_primary_residence_petition",
          label: "Petition to determine succession to real property",
          status: "needs_information",
          reasons: [
            {
              id: "real_property_unclassified",
              text: "Whether the house is in the estate at all depends on how it was titled.",
            },
          ],
          missing_facts: ["assets[0].title_form", "assets[0].gross_value_cents"],
          forms: ["DE-310", "DE-315"],
          citations: [{ label: "Cal. Prob. Code §§13150–13154", url: null }],
        },
      ],
    },
  ],
  federal: [
    {
      item: "irs_form_1310",
      label: "IRS Form 1310 — refund claim for a deceased taxpayer",
      status: "needs_information",
      payee: null,
      amount_cents: null,
      reasons: [
        {
          id: "filer_unknown",
          text: "Whether Form 1310 is needed depends on who files the final return and whether a refund is due.",
        },
      ],
      missing_facts: ["decedent.marital_status", "decedent.surviving_spouse"],
      citations: [{ label: "IRS Form 1310 instructions", url: "https://www.irs.gov/forms-pubs/about-form-1310" }],
    },
    {
      item: "ssa_lump_sum_death_payment",
      label: "Social Security lump-sum death payment",
      status: "needs_information",
      payee: null,
      amount_cents: null,
      reasons: [
        {
          id: "payee_unknown",
          text:
            "The $255 payment goes to a surviving spouse first, then to an entitled child, and never to the estate. We do not yet know who survives.",
        },
      ],
      missing_facts: ["decedent.surviving_spouse", "heirs"],
      citations: [{ label: "42 U.S.C. §402(i)", url: null }],
    },
  ],
  flags: [
    {
      id: "pending_death_certificate",
      severity: "info",
      title: "The death certificate is not final yet.",
      detail:
        "Almost every institution wants a certified copy before it will talk to you. Until one exists, most of this stalls no matter which route applies.",
      citation: null,
      triggered_by: ["decedent.death_certificate_final"],
      action: "Ask the funeral director or the county recorder when certified copies will be available.",
    },
  ],
  deadlines: [
    {
      id: "ca_affidavit_waiting_period",
      label: "40 days must elapse before a personal property affidavit may be used",
      status: "computed",
      date: { year: 2026, month: 9, day: 7 },
      relative_to: "date_of_death",
      offset_days: 40,
      citation: { label: "Cal. Prob. Code §13100", url: null },
    },
    {
      id: "final_income_tax_return",
      label: "Final individual income tax return (Form 1040) due",
      status: "computed",
      date: { year: 2027, month: 4, day: 15 },
      relative_to: "date_of_death",
      offset_days: null,
      citation: { label: "26 U.S.C. §6072(a)", url: null },
    },
  ],
  next_actions: [
    { id: "obtain_death_certificate", label: "Order 10–15 certified copies of the death certificate.", blocked_by: [] },
    {
      id: "pull_property_deed",
      label: "Pull the deed to the Fresno house from the county recorder — it names every owner and says how they hold it.",
      blocked_by: ["assets[0].title_form"],
    },
    {
      id: "find_the_will",
      label: "Look for an original signed will before assuming there isn't one.",
      blocked_by: ["decedent.will_status"],
    },
  ],
  unresolved_facts: [
    "decedent.marital_status",
    "decedent.surviving_spouse",
    "decedent.manner_of_death",
    "decedent.will_status",
    "assets[0].title_form",
    "assets[0].gross_value_cents",
    "assets[1].title_form",
    "assets[1].gross_value_cents",
    "assets[1].situs_state",
    "inventory_complete",
  ],
  notes: [
    "Ten facts are open. None of them is a dead end — each one is a phone call or a document, and each one is named above.",
  ],
};

// ==================================================================
// 3. The referral layer — a case that should stop and get a professional
// ==================================================================

export const FLAGGED_CASE: IntakeCase = {
  as_of_date: AS_OF,
  decedent: {
    death_date: { year: 2026, month: 5, day: 18 },
    domicile_state: "CA",
    marital_status: "widowed",
    surviving_spouse: false,
    manner_of_death: "homicide",
    death_certificate_final: false,
    will_status: "copy_only",
    employment_related_death: false,
    third_party_fault_suspected: true,
    related_death_within_120h: false,
    received_medicaid_ltc: false,
    veteran: true,
    pending_litigation: false,
  },
  assets: [
    {
      name: "Condominium — Naples, Florida",
      kind: "real_property",
      situs_state: "FL",
      gross_value_cents: 38_500_000,
      encumbrance_cents: 0,
      title_form: "sole",
      beneficiary_designation: "none",
      is_primary_residence: false,
    },
    {
      name: "Checking account — Union Bank",
      kind: "bank",
      situs_state: "CA",
      gross_value_cents: 2_400_000,
      encumbrance_cents: 0,
      title_form: "sole",
      beneficiary_designation: "none",
      is_primary_residence: false,
    },
  ],
  debts: [],
  heirs: [
    { relationship: "child", name: "Iris Lund", age: 11, receives_means_tested_benefits: false, is_suspect_in_death: false, disclaimed: false },
    { relationship: "sibling", name: "Peter Lund", age: 57, receives_means_tested_benefits: false, is_suspect_in_death: true, disclaimed: false },
  ],
  conflict_signals: true,
  inventory_complete: true,
};

export const FLAGGED_ASSESSMENT: SettlementAssessment = {
  engine: "lean4",
  snapshot: SNAPSHOT,
  asset_map: [
    {
      name: "Condominium — Naples, Florida",
      classification: "probate",
      basis: "sole_name_no_designation",
      reason:
        "Held in the decedent's sole name in Florida. Real property is administered where it sits, not where the owner lived.",
      citation: { label: "Cal. Prob. Code §12501", url: null },
      missing_facts: [],
      counts_toward: [],
      value_cents: 38_500_000,
    },
    {
      name: "Checking account — Union Bank",
      classification: "probate",
      basis: "sole_name_no_designation",
      reason: "Sole name, no payable-on-death designation, so it passes through the estate.",
      citation: { label: "Cal. Prob. Code §13050", url: null },
      missing_facts: [],
      counts_toward: ["ca_personal_property_affidavit"],
      value_cents: 2_400_000,
    },
  ],
  probate_estate: { known_subtotal_cents: 40_900_000, status: "known", missing_facts: [] },
  jurisdictions: [
    {
      code: "CA",
      role: "domicile",
      verdict: "INCOMPLETE_INFO",
      routes: [
        {
          route: "ca_personal_property_affidavit",
          label: "Affidavit for collection of personal property",
          status: "needs_information",
          reasons: [
            {
              id: "successor_identity_contested",
              text:
                "An affidavit is signed under penalty of perjury by the person entitled to the property. Who that is cannot be settled while an heir is under investigation in the death.",
            },
          ],
          missing_facts: ["heirs[1].is_suspect_in_death"],
          forms: ["DE-300"],
          citations: [{ label: "Cal. Prob. Code §§13100–13101", url: null }],
        },
      ],
    },
    {
      code: "FL",
      role: "ancillary",
      verdict: "OTHER_FORM_REQUIRED",
      routes: [
        {
          route: "fl_summary_administration",
          label: "Summary administration",
          status: "does_not_qualify",
          reasons: [
            {
              id: "value_above_band",
              text:
                "For a death on or after 1 July 2026 the summary administration ceiling is $150,000. The Florida property alone is above it.",
            },
          ],
          missing_facts: [],
          forms: [],
          citations: [{ label: "Fla. Stat. §735.201", url: null }],
        },
        {
          route: "fl_formal_administration",
          label: "Formal administration",
          status: "qualifies",
          reasons: [
            { id: "fallback_route", text: "Formal administration is available where no summary route clears." },
          ],
          missing_facts: [],
          forms: [],
          citations: [{ label: "Fla. Stat. ch. 733", url: null }],
        },
      ],
    },
  ],
  federal: [
    {
      item: "ssa_lump_sum_death_payment",
      label: "Social Security lump-sum death payment",
      status: "needs_information",
      payee: null,
      amount_cents: null,
      reasons: [
        {
          id: "child_entitlement_unknown",
          text:
            "With no surviving spouse the $255 payment can go to a child entitled to benefits on the decedent's record. Whether this child is entitled is a Social Security determination.",
        },
      ],
      missing_facts: ["heirs[0].age"],
      citations: [{ label: "42 U.S.C. §402(i)", url: null }],
    },
  ],
  flags: [
    {
      id: "slayer_rule_screen",
      severity: "critical",
      title: "Screen every heir under the slayer rule.",
      detail:
        "Manner of death is homicide and an heir is named as a suspect. An heir who feloniously and intentionally kills the decedent is barred from taking by will, intestacy, trust, beneficiary designation, and survivorship.",
      citation: { label: "UPC §2-803; Cal. Prob. Code §250", url: null },
      triggered_by: ["decedent.manner_of_death", "heirs[1].is_suspect_in_death"],
      action: "Do not distribute to any heir under investigation. Refer to counsel before anything moves.",
    },
    {
      id: "wrongful_death_vs_survival_claim",
      severity: "warning",
      title: "There may be two separate claims here, and they do not belong to the same people.",
      detail:
        "A wrongful death claim belongs to the surviving family in their own right. A survival action belongs to the estate. They are pleaded differently and the money lands in different hands.",
      citation: { label: "Cal. Code Civ. Proc. §§377.30, 377.60", url: null },
      triggered_by: ["decedent.third_party_fault_suspected"],
      action: "Speak to a litigator before signing any release.",
    },
    {
      id: "minor_beneficiary",
      severity: "warning",
      title: "A minor cannot simply be handed an inheritance.",
      detail:
        "An 11-year-old cannot take property outright. It has to go to a custodian, a guardian of the estate, or a trust.",
      citation: { label: "Cal. Prob. Code §§3900–3925 (Uniform Transfers to Minors Act)", url: null },
      triggered_by: ["heirs[0].age"],
      action: "Decide on a custodianship or guardianship before any distribution.",
    },
    {
      id: "will_copy_only",
      severity: "warning",
      title: "Only a copy of the will has been found.",
      detail:
        "When a will last known to be in the testator's possession cannot be found, California presumes the testator destroyed it with intent to revoke. That presumption can be rebutted, but it has to be rebutted.",
      citation: { label: "Cal. Prob. Code §6124", url: null },
      triggered_by: ["decedent.will_status"],
      action: "Keep searching for the original, and preserve the copy and everything about where it was found.",
    },
    {
      id: "ancillary_probate_required",
      severity: "info",
      title: "The Florida condominium needs its own proceeding.",
      detail:
        "Real property is administered in the state where it sits. A California proceeding does not move a Florida deed.",
      citation: { label: "Cal. Prob. Code §12501", url: null },
      triggered_by: ["assets[0].situs_state"],
      action: "Plan for a Florida ancillary administration alongside the California one.",
    },
  ],
  deadlines: [
    {
      id: "final_income_tax_return",
      label: "Final individual income tax return (Form 1040) due",
      status: "computed",
      date: { year: 2027, month: 4, day: 15 },
      relative_to: "date_of_death",
      offset_days: null,
      citation: { label: "26 U.S.C. §6072(a)", url: null },
    },
    {
      id: "ca_creditor_claim_window",
      label: "Creditor claim window closes",
      status: "awaiting_event",
      date: null,
      relative_to: "letters_issued",
      offset_days: 120,
      citation: { label: "Cal. Prob. Code §9100", url: null },
    },
  ],
  next_actions: [
    { id: "hold_distributions", label: "Distribute nothing until the slayer-rule question is resolved.", blocked_by: [] },
    { id: "retain_counsel", label: "Retain counsel — this case is past the point where a form does the job.", blocked_by: [] },
    { id: "plan_ancillary", label: "Open a Florida ancillary administration for the condominium.", blocked_by: [] },
  ],
  unresolved_facts: ["heirs[0].age", "heirs[1].is_suspect_in_death"],
  notes: [
    "A critical flag is not a verdict about anyone. It is a statement that this decision is above what a form can carry.",
  ],
};

// ==================================================================
// 4. The typed error envelope — a structural answer, not a legal one
// ==================================================================

export const AFTER_SNAPSHOT_CASE: IntakeCase = {
  as_of_date: AS_OF,
  decedent: {
    death_date: { year: 2027, month: 1, day: 2 },
    domicile_state: "CA",
    marital_status: "single",
    surviving_spouse: false,
  },
  assets: [
    {
      name: "Checking account",
      kind: "bank",
      situs_state: "CA",
      gross_value_cents: 1_200_000,
      title_form: "sole",
      beneficiary_designation: "none",
    },
  ],
  debts: [],
  heirs: [],
  conflict_signals: false,
  inventory_complete: true,
};

export const AFTER_SNAPSHOT_ERROR: ErrorEnvelope = {
  error: {
    code: "after_snapshot",
    detail: "death_date 2027-01-02 is after the source snapshot (2026-12-31).",
  },
};

// ==================================================================
// Registry
// ==================================================================

export interface Fixture extends SampleCase {
  /** What the engine is expected to return for this case, per the contract. */
  outcome: AssessOutcome;
}

export const FIXTURES: Fixture[] = [
  {
    id: "canonical_ca_married",
    label: "California, married, one unknown",
    blurb:
      "The contract's canonical case. A house in joint tenancy, a 401(k) with a named beneficiary, two sole-name assets — and one savings account nobody can describe yet.",
    case: CANONICAL_CASE,
    outcome: { kind: "ok", assessment: CANONICAL_ASSESSMENT },
  },
  {
    id: "heavy_unknowns",
    label: "Day three, when nothing is known yet",
    blurb:
      "A house, an account, and almost no answers. Ten open facts, each one named, none of them treated as a no.",
    case: HEAVY_UNKNOWNS_CASE,
    outcome: { kind: "ok", assessment: HEAVY_UNKNOWNS_ASSESSMENT },
  },
  {
    id: "flagged_referral",
    label: "The case that should stop and call a lawyer",
    blurb:
      "Homicide, a suspect in the family, a minor heir, a will that exists only as a photocopy, and property in another state.",
    case: FLAGGED_CASE,
    outcome: { kind: "ok", assessment: FLAGGED_ASSESSMENT },
  },
  {
    id: "after_snapshot",
    label: "A death after the source snapshot",
    blurb:
      "The law here was compiled from sources as of a fixed date. Past that date the engine refuses to answer instead of guessing.",
    case: AFTER_SNAPSHOT_CASE,
    outcome: { kind: "rejected", error: AFTER_SNAPSHOT_ERROR.error },
  },
];

export const SAMPLE_CASES: SampleCase[] = FIXTURES.map(({ id, label, blurb, case: c }) => ({
  id,
  label,
  blurb,
  case: c,
}));

/** Best-effort match of a hand-built outcome to a case, used only on the
    offline path, and only ever rendered behind a sample marker. */
export function fixtureOutcomeFor(id: string): AssessOutcome | null {
  return FIXTURES.find((f) => f.id === id)?.outcome ?? null;
}
