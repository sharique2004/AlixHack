# CONTRACT — Settlement Router API (v1, frozen 2026-08-12)

The single source of truth for the new product surface. Lean, FastAPI, and the
frontend all build against **this file**, not against each other. If an
implementation disagrees with this document, the implementation is wrong.

Existing `CheckResult` / `/api/analyze/{llm,lean}` contract is **unchanged** and
still serves the CA comparison (now the Evidence page). This is additive.

---

## 0. Doctrine (binding on every implementation)

1. **Unknown ≠ false.** A `null` or absent field is *unknown*. Unknowns produce
   `needs_information` with the exact missing fact paths — never a negative
   verdict, never a guess.
2. **Known violation beats unknown.** If a known fact already disqualifies a
   route, say so even when other facts are unknown.
3. **Nothing beyond the snapshot.** Death dates after `2026-12-31` return a typed
   error, not a verdict.
4. **Every legal conclusion carries a citation.** No citation, no claim.
5. **Structural errors are not legal conclusions** — malformed input returns the
   error envelope, never a verdict.

## 1. Endpoint

```
POST /api/settlement/assess     body: IntakeCase        → SettlementAssessment | ErrorEnvelope
GET  /api/settlement/samples    → { samples: [{id, label, blurb, case: IntakeCase}] }
GET  /api/health                → adds "settlement_engine": "binary"|"lake"|"unavailable"
```

Lean executable: `settlement-api` (root `SettlementMain.lean`), stdin JSON →
stdout JSON, exit 0 always, same shell-out pattern as `probate-api`.

## 2. Request — `IntakeCase`

Every field is optional/nullable unless marked **required**. Absent ≡ `null` ≡ unknown.

```jsonc
{
  "as_of_date": {"year":2026,"month":8,"day":12},        // required
  "decedent": {
    "death_date": {"year":2026,"month":3,"day":4},        // null = unknown
    "domicile_state": "CA",                               // "CA" | "FL" | other 2-letter (unsupported → advisory only)
    "marital_status": "married|single|widowed|divorced",
    "surviving_spouse": true,
    "manner_of_death": "natural|accident|suicide|homicide|pending|undetermined",
    "death_certificate_final": true,
    "will_status": "valid_original|copy_only|holographic|none|unsure",
    "employment_related_death": false,
    "third_party_fault_suspected": false,
    "related_death_within_120h": false,
    "received_medicaid_ltc": false,
    "veteran": false,
    "pending_litigation": false
  },
  "assets": [{
    "name": "Primary residence — 12 Oak St",              // required, unique
    "kind": "real_property|bank|brokerage|retirement|life_insurance|vehicle|personal|business|digital|employment_comp|other",
    "situs_state": "CA",
    "gross_value_cents": 62000000,
    "encumbrance_cents": 41000000,
    "title_form": "sole|jtwros|tenancy_by_entirety|community_with_ros|tenants_in_common|trust_funded|custodial",
    "beneficiary_designation": "named_living|named_predeceased|estate|none|unsure",
    "is_primary_residence": true
  }],
  "debts": [{"kind":"mortgage|credit_card|medical|tax|loan|funeral|other","amount_cents":4100000,"secured_by_asset":"Primary residence — 12 Oak St"}],
  "heirs": [{"relationship":"spouse|child|parent|sibling|other","name":"…","age":34,
             "receives_means_tested_benefits":false,"is_suspect_in_death":false,"disclaimed":false}],
  "conflict_signals": false,
  "inventory_complete": true                              // "is this list of assets complete?" — gates every cap test
}
```

## 2.1 Additive request fields (added 2026-08-12 by the integration pass)

§2 above is unchanged: every field it defines still means what it meant, and a
request written against §2 alone still decodes and still gets an assessment.

The three engines behind this endpoint need facts §2 did not carry. Florida's
routes turn on whether the will directs administration, whether an
administration is already pending, which assets are exempt from creditors'
claims, and the funeral and last-illness expenses; the two federal items turn
on tax facts and on Social Security entitlement. §6 states a federal *outcome*
without stating the facts that produce it, and the engines assume neither — so
those facts are named here.

Every field below is optional and defaults to unknown. Omitting them is not an
error; it produces `needs_information` on the rows that need them, naming
these exact paths.

```jsonc
{
  "decedent": {
    "will_directs_administration": false,   // Fla. Stat. §735.201(1)
    "administration_pending": false,        // Fla. Stat. §735.304
    "federal_refund_due": true,
    "refund_claimant": "surviving_spouse_joint_return|court_appointed_representative|other",
    "final_return_kind": "original|amended",
    "court_certificate_attached": false,
    "ssa_insured_at_death": true            // fully OR currently insured; §402(i) opens on the disjunction
  },
  "assets": [{
    "exempt_from_creditors": false          // stated exemption, Fla. Stat. §732.402. Protected homestead is DERIVED, not stated.
  }],
  "heirs": [{
    "lived_in_same_household_at_death": true,
    "entitled_to_spouse_benefits_month_of_death": false,
    "entitled_to_child_benefits_month_of_death": false   // §402(d) entitlement. NEVER inferred from `relationship`.
  }],
  "heirs_complete": true,                   // "is this list of people complete?" — gates every negative conclusion about who may claim
  "expenses": {"preferred_funeral_cents": 950000, "last_illness_medical_cents": 240000}
}
```

Two notes a reviewer should hold the implementation to:

* **`situs_state` is never defaulted to the domicile.** Fla. Stat. §735.201(2)
  measures the estate subject to administration *in Florida*, so a defaulted
  situs would be an assumption doing real work inside a cap test. An asset with
  no `situs_state` is counted neither in nor out and the path is reported.
* **`entitled_to_child_benefits_month_of_death` is never derived from
  `relationship`.** §402(d) entitlement does not track the probate label: an
  adult child is usually not entitled, and a step-grandchild may be.

## 3. Response — `SettlementAssessment`

```jsonc
{
  "engine": "lean4",
  "snapshot": {"source_as_of":"2026-08-12","supported_death_dates_through":"2026-12-31"},

  "asset_map": [{
    "name":"Primary residence — 12 Oak St",
    "classification":"probate|non_probate|unknown",
    "basis":"jtwros_survivorship|community_property_ros|beneficiary_designation|pod_tod|trust_funded|
             sole_name_no_designation|beneficiary_predeceased_falls_to_estate|designation_to_estate|unknown_title",
    "reason":"Held in joint tenancy with right of survivorship — passes to the surviving joint tenant by operation of law.",
    "citation":{"label":"Cal. Prob. Code §13050(b)","url":null},
    "missing_facts":["assets[0].title_form"],
    "counts_toward":["ca_personal_property_affidavit"],   // which route valuations include this asset
    "value_cents": 62000000                               // null when unknown
  }],

  "probate_estate":{"known_subtotal_cents":18450000,"status":"known|partial","missing_facts":[]},

  "jurisdictions":[{
    "code":"CA","role":"domicile|ancillary",
    // Verdict precedence, identical in every jurisdiction of a response:
    //   any route `needs_information`                        → INCOMPLETE_INFO
    //   else any NON-FALLBACK route `qualifies`              → ELIGIBLE
    //   else                                                 → OTHER_FORM_REQUIRED
    // The fallback rows (`ca_formal_probate_or_other`, `fl_formal_administration`)
    // qualify exactly when nothing simpler does, so they never make a case ELIGIBLE.
    // Same rule as the older CheckResult contract's `overall`.
    "verdict":"ELIGIBLE|INCOMPLETE_INFO|OTHER_FORM_REQUIRED",
    "routes":[{
      "route":"ca_personal_property_affidavit",           // stable snake_case id
      "label":"Affidavit for collection of personal property",
      "status":"qualifies|does_not_qualify|needs_information",
      "reasons":[{"id":"waiting_period_not_met","text":"40 days have not elapsed since the date of death."}],
      "missing_facts":["decedent.death_date"],
      "forms":["DE-300"],
      "citations":[{"label":"Cal. Prob. Code §§13100–13101","url":null}]
    }]
  }],

  "federal":[{
    "item":"irs_form_1310|ssa_lump_sum_death_payment",
    "label":"IRS Form 1310 — refund claim for a deceased taxpayer",
    "status":"required|not_required|needs_information|payable|not_payable",
    "payee":"surviving_spouse|child|estate|none",         // SSA only, else null
    "amount_cents":25500,                                 // SSA only, else null
    "reasons":[{"id":"…","text":"…"}],
    "missing_facts":[],
    "citations":[{"label":"42 U.S.C. §402(i)","url":null}]
  }],

  "flags":[{
    "id":"slayer_rule_screen",
    "severity":"critical|warning|info",
    "title":"Screen every heir under the slayer rule.",
    "detail":"Manner of death is homicide. An heir who feloniously and intentionally kills the decedent is barred from taking by will, intestacy, trust, beneficiary designation, and survivorship.",
    "citation":{"label":"UPC §2-803; Cal. Prob. Code §250","url":null},
    "triggered_by":["decedent.manner_of_death"],
    "action":"Do not distribute to any heir under investigation. Refer to counsel."
  }],

  "deadlines":[{
    "id":"ca_creditor_claim_window",
    "label":"Creditor claim window closes",
    "status":"computed|awaiting_event|needs_information",
    "date":{"year":2026,"month":9,"day":12},              // null unless status=computed
    "relative_to":"letters_issued|date_of_death|first_publication|filing",
    "offset_days":120,
    "citation":{"label":"Cal. Prob. Code §9100","url":null}
  }],

  "next_actions":[{"id":"obtain_death_certificate","label":"Obtain 10–15 certified death certificates.","blocked_by":[]}],
  "unresolved_facts":["decedent.death_date","assets[2].title_form"],
  "notes":["Domicile state FL is supported. Real property in CA triggers ancillary proceedings."]
}
```

### Error envelope
```jsonc
{"error":{"code":"invalid_date|after_snapshot|malformed_case","detail":"death_date 2027-01-02 is after the source snapshot (2026-12-31)."}}
```

## 4. Stable route ids (extend, never rename)

**California** — `ca_direct_transfer`, `ca_personal_property_affidavit` (§13100, DE-300),
`ca_small_value_real_property_affidavit` (§13200, DE-305),
`ca_primary_residence_petition` (§§13150–13154, DE-310/315),
`ca_spousal_property_petition` (§§13500, 13650, DE-221/226),
`ca_formal_probate_or_other`.

**Florida** — `fl_disposition_without_administration` (§735.301 **and**
§735.304 — the $10,000 → $20,000 figure CS/HB 1337 raised lives in §735.304,
"disposition without administration of intestate property in small estates",
not in §735.301, whose limit is entirely the preferred-funeral-plus-last-60-days-
medical allowance; both sections are disposition-without-administration and
share this one route id), `fl_summary_administration` (§735.201),
`fl_formal_administration`.
Florida threshold is **date-of-death banded**: ≤ $75,000 for deaths before
2026-07-01, ≤ $150,000 for deaths on/after (CS/HB 1337). Both bands must be live
simultaneously; the 2-year-since-death alternative qualifies regardless of value.

**Federal** — `irs_form_1310`, `ssa_lump_sum_death_payment` ($255, 42 U.S.C. §402(i),
priority ladder: spouse in same household → spouse entitled on the record →
entitled child → nobody; never the estate; 2-year claim deadline).

## 5. Flag ids (the referral layer)

`slayer_rule_screen` · `wrongful_death_vs_survival_claim` · `simultaneous_death_120h` ·
`insurance_contestability_window` · `pending_death_certificate` · `insolvent_estate` ·
`medicaid_estate_recovery` · `minor_beneficiary` · `special_needs_beneficiary` ·
`ancillary_probate_required` · `will_copy_only` · `conflict_risk` · `business_continuity` ·
`workers_comp_death_benefit` · `va_benefits`.

Each flag is a small, defensible rule over intake facts. Severity `critical` means
"stop and get a professional" — it must never fire on an unknown alone.

## 6. Canonical fixture (frontend builds against this until the engine lands)

Case: CA domicile, died 2026-03-04 (natural), married, valid original will.
Assets: home $620k JTWROS w/ spouse; Schwab brokerage $141k sole, no TOD;
401(k) $310k beneficiary = surviving spouse; car $18k sole; unknown-title savings.

Expected: home → non_probate (survivorship); 401(k) → non_probate (designation);
brokerage + car → probate ($159k known subtotal); savings → unknown, blocks the
cap test. CA verdict `INCOMPLETE_INFO`: personal-property affidavit
`needs_information` (missing `assets[4].title_form`, and inventory completeness),
spousal property petition `qualifies` for the community share.
Federal: `irs_form_1310` `not_required` (surviving spouse filing jointly),
`ssa_lump_sum_death_payment` `payable` to surviving spouse, $255.
Flags: none critical. Deadlines: final 1040 due 2027-04-15 (computed).

## 7. Ownership (who writes what tonight)

| Area | Path | Owner |
|---|---|---|
| Design tokens + TS types | `demo/frontend/src/atlas/design/tokens.css`, `atlas/types.ts` | orchestrator (done) |
| Florida module | `SimpleProbate/FL/*.lean` | agent FL |
| Federal module | `SimpleProbate/Fed/*.lean` | agent FED |
| Router + intake + flags + `settlement-api` | `SimpleProbate/Router/*.lean`, `SettlementMain.lean` | agent ROUTER |
| FastAPI endpoints + fuzz harness + audit runner | `demo/backend/app/*.py`, `tools/` | agent PY |
| Shell, intake wizard, design system | `demo/frontend/src/atlas/{App.tsx,intake/**,design/**}`, `main.tsx` | agent UI-A |
| Case file view | `demo/frontend/src/atlas/casefile/**` | agent UI-B |

No agent edits a path it does not own. `lakefile.toml` is pre-edited by the
orchestrator — do not touch it.
