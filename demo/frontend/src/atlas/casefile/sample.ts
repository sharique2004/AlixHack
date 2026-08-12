/**
 * A complete, contract-valid SettlementAssessment for developing and reviewing
 * the case file standalone. This is a *fixture*, not engine output: the facts
 * of the estate are invented, but every statute, form number, and dollar figure
 * that is not a fact of this fictional case is real —
 *
 *   · the SSA lump-sum death payment is $255 (42 U.S.C. §402(i));
 *   · Florida's summary-administration band is date-of-death banded at $75,000
 *     before 2026-07-01 and $150,000 on or after (CS/HB 1337), per the contract;
 *   · no California valuation cap is asserted anywhere, because this file does
 *     not have a sourced figure for one. The route reports the cap as untested.
 *
 * The case: died 2026-02-11 in California, homicide under investigation, a
 * surviving spouse, an adult child who is a suspect, and a minor child. Most of
 * the estate passes by survivorship and designation; one savings account has
 * unknown title and blocks the value test; a Sarasota condominium drags Florida
 * in as an ancillary jurisdiction.
 */

import type { SettlementAssessment } from "../types";

export const sampleAssessment: SettlementAssessment = {
  engine: "lean4",
  snapshot: {
    source_as_of: "2026-08-12",
    supported_death_dates_through: "2026-12-31",
  },

  asset_map: [
    {
      name: "Primary residence — 12 Oak Street, Oakland",
      classification: "non_probate",
      basis: "jtwros_survivorship",
      reason:
        "Held in joint tenancy with right of survivorship with the surviving spouse. It passes to the surviving joint tenant by operation of law and never enters the probate estate.",
      citation: { label: "Cal. Prob. Code §13050(b)", url: null },
      missing_facts: [],
      counts_toward: [],
      value_cents: 62000000,
    },
    {
      name: "Schwab brokerage — account ending 4417",
      classification: "probate",
      basis: "sole_name_no_designation",
      reason:
        "Held in the decedent's sole name with no transfer-on-death designation on file, so it is administered as part of the estate.",
      citation: { label: "Cal. Prob. Code §13050", url: null },
      missing_facts: [],
      counts_toward: ["ca_personal_property_affidavit"],
      value_cents: 9640000,
    },
    {
      name: "401(k) — Meridian Health Systems",
      classification: "non_probate",
      basis: "beneficiary_designation",
      reason:
        "A living named beneficiary is on file. The plan pays that beneficiary directly under the contract; the estate is not in the chain.",
      citation: { label: "Cal. Prob. Code §5000", url: null },
      missing_facts: [],
      counts_toward: [],
      value_cents: 31000000,
    },
    {
      name: "2019 Subaru Outback",
      classification: "probate",
      basis: "sole_name_no_designation",
      reason:
        "Titled in the decedent's sole name with no beneficiary on the title, so it is part of the probate estate.",
      citation: { label: "Cal. Prob. Code §13050", url: null },
      missing_facts: [],
      counts_toward: ["ca_personal_property_affidavit"],
      value_cents: 1840000,
    },
    {
      name: "Wells Fargo savings — account ending 2210",
      classification: "unknown",
      basis: "unknown_title",
      reason:
        "How this account is titled is not on the record. If it is held jointly with right of survivorship it leaves the estate entirely; if it is in the decedent's sole name it counts against every value test below. Until that is answered it is neither — and it is not treated as a no.",
      citation: null,
      missing_facts: ["assets[4].title_form"],
      counts_toward: ["ca_personal_property_affidavit"],
      value_cents: 2760000,
    },
    {
      name: "Group term life — Meridian Health Systems",
      classification: "probate",
      basis: "beneficiary_predeceased_falls_to_estate",
      reason:
        "The named beneficiary predeceased the decedent and no contingent beneficiary is on file, so under the policy's own terms the proceeds are payable to the estate and are administered with it.",
      citation: null,
      missing_facts: [],
      counts_toward: ["ca_personal_property_affidavit"],
      value_cents: 4000000,
    },
    {
      name: "Condominium — 4118 Gulfview Court, Sarasota",
      classification: "probate",
      basis: "sole_name_no_designation",
      reason:
        "Florida real property held in the decedent's sole name. It is part of the probate estate, but only a Florida proceeding can transfer it.",
      citation: { label: "Fla. Stat. §734.102", url: null },
      missing_facts: [],
      counts_toward: ["fl_summary_administration", "fl_formal_administration"],
      value_cents: 20500000,
    },
  ],

  probate_estate: {
    known_subtotal_cents: 35980000,
    status: "partial",
    missing_facts: ["assets[4].title_form"],
  },

  jurisdictions: [
    {
      code: "CA",
      role: "domicile",
      verdict: "INCOMPLETE_INFO",
      routes: [
        {
          route: "ca_spousal_property_petition",
          label: "Spousal property petition",
          status: "qualifies",
          reasons: [
            {
              id: "surviving_spouse_on_record",
              text: "A surviving spouse is on the record. Property passing to a surviving spouse can be confirmed by petition rather than administered, whatever the other routes do.",
            },
          ],
          missing_facts: [],
          forms: ["DE-221", "DE-226"],
          citations: [{ label: "Cal. Prob. Code §§13500, 13650", url: null }],
        },
        {
          route: "ca_formal_probate_or_other",
          label: "Formal administration",
          status: "qualifies",
          reasons: [
            {
              id: "always_available",
              text: "A formal administration is available whatever the simplified routes do, and becomes necessary if a value test fails.",
            },
          ],
          missing_facts: [],
          forms: ["DE-111", "DE-121"],
          citations: [{ label: "Cal. Prob. Code §8000", url: null }],
        },
        {
          route: "ca_personal_property_affidavit",
          label: "Affidavit for collection of personal property",
          status: "needs_information",
          reasons: [
            {
              id: "waiting_period_met",
              text: "More than 40 days have elapsed since the date of death, so the waiting period is satisfied.",
            },
            {
              id: "value_test_untested",
              text: "The value test cannot be run yet: one asset is still unclassified, and the asset list has not been confirmed complete.",
            },
          ],
          missing_facts: ["assets[4].title_form", "inventory_complete"],
          forms: ["DE-300"],
          citations: [{ label: "Cal. Prob. Code §§13100–13101", url: null }],
        },
        {
          route: "ca_small_value_real_property_affidavit",
          label: "Affidavit for real property of small value",
          status: "does_not_qualify",
          reasons: [
            {
              id: "no_ca_real_property_in_estate",
              text: "No California real property is in the probate estate — the Oakland residence passes to the surviving joint tenant by survivorship.",
            },
          ],
          missing_facts: [],
          forms: ["DE-305"],
          citations: [{ label: "Cal. Prob. Code §13200", url: null }],
        },
        {
          route: "ca_primary_residence_petition",
          label: "Petition to determine succession to a primary residence",
          status: "does_not_qualify",
          reasons: [
            {
              id: "no_ca_real_property_in_estate",
              text: "The primary residence is not in the probate estate, so there is nothing for this petition to determine succession to.",
            },
          ],
          missing_facts: [],
          forms: ["DE-310", "DE-315"],
          citations: [{ label: "Cal. Prob. Code §§13150–13154", url: null }],
        },
      ],
    },
    {
      code: "FL",
      role: "ancillary",
      verdict: "OTHER_FORM_REQUIRED",
      routes: [
        {
          route: "fl_formal_administration",
          label: "Ancillary formal administration",
          status: "qualifies",
          reasons: [
            {
              id: "fl_real_property_requires_administration",
              text: "Florida real property held in the decedent's sole name is reached through an administration opened in Florida, whatever California does.",
            },
          ],
          missing_facts: [],
          forms: [],
          citations: [{ label: "Fla. Stat. §734.102", url: null }],
        },
        {
          route: "fl_summary_administration",
          label: "Summary administration",
          status: "does_not_qualify",
          reasons: [
            {
              id: "value_exceeds_band",
              text: "The decedent died before July 1, 2026, so the $75,000 band applies. The Florida property alone is above it.",
            },
            {
              id: "two_year_alternative_not_met",
              text: "Fewer than two years have passed since the date of death, so the alternative that ignores value is not open either.",
            },
          ],
          missing_facts: [],
          forms: [],
          citations: [
            { label: "Fla. Stat. §735.201", url: null },
            { label: "CS/HB 1337 (2026)", url: null },
          ],
        },
        {
          route: "fl_disposition_without_administration",
          label: "Disposition without administration",
          status: "does_not_qualify",
          reasons: [
            {
              id: "non_exempt_property_present",
              text: "The estate includes non-exempt property, so disposition without administration is not available.",
            },
          ],
          missing_facts: [],
          forms: [],
          citations: [{ label: "Fla. Stat. §735.301", url: null }],
        },
      ],
    },
  ],

  federal: [
    {
      item: "ssa_lump_sum_death_payment",
      label: "Social Security lump-sum death payment",
      status: "payable",
      payee: "surviving_spouse",
      amount_cents: 25500,
      reasons: [
        {
          id: "spouse_same_household",
          text: "A surviving spouse living in the same household at the time of death is first on the priority ladder. The payment is never made to the estate.",
        },
      ],
      missing_facts: [],
      citations: [{ label: "42 U.S.C. §402(i)", url: null }],
    },
    {
      item: "irs_form_1310",
      label: "IRS Form 1310 — refund claim for a deceased taxpayer",
      status: "not_required",
      payee: null,
      amount_cents: null,
      reasons: [
        {
          id: "surviving_spouse_joint_return",
          text: "A surviving spouse filing a joint return for the year of death claims the refund on that return, so no separate Form 1310 is filed.",
        },
      ],
      missing_facts: [],
      citations: [{ label: "IRS Form 1310 instructions", url: null }],
    },
  ],

  flags: [
    {
      id: "pending_death_certificate",
      severity: "info",
      title: "The death certificate is not final.",
      detail:
        "The manner of death is under investigation, so the certificate on file may still be amended. Financial institutions generally will not act on an interim certificate, and an amended manner of death can change what this assessment concludes.",
      citation: null,
      triggered_by: ["decedent.death_certificate_final", "decedent.manner_of_death"],
      action: "Re-run this assessment when the final certificate issues.",
    },
    {
      id: "minor_beneficiary",
      severity: "warning",
      title: "A minor cannot take property directly.",
      detail:
        "One heir on the record is under 18. Property passing to a minor is held by a custodian or by a court-supervised guardian of the estate — a transfer made straight to the minor is not effective.",
      citation: { label: "Cal. Prob. Code §§3900–3925 (CUTMA)", url: null },
      triggered_by: ["heirs[2].age"],
      action:
        "Name a custodian under CUTMA, or petition for a guardian of the estate, before distributing this share.",
    },
    {
      id: "slayer_rule_screen",
      severity: "critical",
      title: "Screen every heir under the slayer rule before anything moves.",
      detail:
        "The manner of death is recorded as homicide and one heir is recorded as a suspect. An heir who feloniously and intentionally kills the decedent takes nothing — not by will, not by intestacy, not by trust, not by beneficiary designation, and not by survivorship. The estate is distributed as though that heir had predeceased.",
      citation: { label: "Cal. Prob. Code §250; UPC §2-803", url: null },
      triggered_by: ["decedent.manner_of_death", "heirs[1].is_suspect_in_death"],
      action:
        "Distribute nothing to the heir under investigation and refer this case to counsel now.",
    },
    {
      id: "ancillary_probate_required",
      severity: "warning",
      title: "The Florida condominium needs its own proceeding.",
      detail:
        "Real property is governed by the law of the state where it sits. The Sarasota condominium is held in the decedent's sole name, so no California order can transfer it — Florida has to open an ancillary administration.",
      citation: { label: "Fla. Stat. §734.102", url: null },
      triggered_by: ["assets[6].situs_state", "assets[6].title_form"],
      action:
        "Engage Florida counsel to open the ancillary administration in the county where the condominium sits.",
    },
    {
      id: "wrongful_death_vs_survival_claim",
      severity: "warning",
      title: "A wrongful death claim is not an asset of this estate.",
      detail:
        "Third-party fault is suspected. A survival action belongs to the estate and is administered with it; a wrongful death claim belongs to the statutory heirs personally and never enters the estate. They are pleaded together and allocated apart, and confusing the two changes who is paid.",
      citation: { label: "Cal. Code Civ. Proc. §§377.30, 377.60", url: null },
      triggered_by: ["decedent.third_party_fault_suspected", "decedent.manner_of_death"],
      action:
        "Have counsel separate the survival claim from the wrongful death claim before any settlement is allocated.",
    },
  ],

  deadlines: [
    {
      id: "ca_affidavit_waiting_period",
      label: "40-day waiting period for the personal property affidavit ends",
      status: "computed",
      date: { year: 2026, month: 3, day: 23 },
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
    {
      id: "ssa_lump_sum_claim_deadline",
      label: "Last day to claim the Social Security lump-sum death payment",
      status: "computed",
      date: { year: 2028, month: 2, day: 11 },
      relative_to: "date_of_death",
      offset_days: 730,
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
    {
      id: "federal_estate_tax_return",
      label: "Federal estate tax return (Form 706), if one is required",
      status: "needs_information",
      date: null,
      relative_to: "date_of_death",
      offset_days: null,
      citation: { label: "26 U.S.C. §6075(a)", url: null },
    },
  ],

  next_actions: [
    {
      id: "refer_slayer_screen",
      label: "Refer the slayer-rule question to counsel before any distribution.",
      blocked_by: [],
    },
    {
      id: "confirm_savings_title",
      label: "Confirm how the Wells Fargo savings account is titled.",
      blocked_by: [],
    },
    {
      id: "confirm_inventory_complete",
      label: "Confirm that the asset list is complete.",
      blocked_by: [],
    },
    {
      id: "claim_ssa_lump_sum",
      label: "Claim the Social Security lump-sum death payment for the surviving spouse.",
      blocked_by: [],
    },
    {
      id: "open_fl_ancillary",
      label: "Open the Florida ancillary administration for the Sarasota condominium.",
      blocked_by: [],
    },
    {
      id: "file_ca_personal_property_affidavit",
      label: "Prepare the affidavit for collection of personal property (DE-300).",
      blocked_by: ["assets[4].title_form", "inventory_complete"],
    },
    {
      id: "reassess_on_final_certificate",
      label: "Re-run this assessment when the final death certificate issues.",
      blocked_by: ["decedent.death_certificate_final"],
    },
  ],

  unresolved_facts: [
    "assets[4].title_form",
    "inventory_complete",
    "decedent.death_certificate_final",
  ],

  notes: [
    "California is the state of domicile. The Sarasota condominium is Florida real property and is reported here as an ancillary matter.",
    "Values are as supplied at intake. The engine proves what follows from those facts; it does not verify them.",
  ],
};

export default sampleAssessment;
