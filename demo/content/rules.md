# Decision Rules — CA Probate Simple Transfer Checker (v2, Lean-mirrored)

> **Authority note.** These rules are a plain-English rendering of the vendored Lean 4 formalization
> at `AlixHack/SimpleProbate/*.lean` (Date, Thresholds, Estate, Eligibility). Where this page and the
> Lean code disagree, **the Lean code wins**. The model is educational: Lean proves consequences of
> supplied facts; it does not establish their truth. Not legal advice.

> **SEMANTIC FLIP vs v1 — read this first.** In v1, the DE-305, DE-310, and DE-221 paths were
> reported as `OTHER_FORM_REQUIRED`. In v2 they are **simplified transfer routes**, so a case that
> qualifies for the DE-305 small-value real-property affidavit, the DE-310 primary-residence
> petition, or the DE-221 spousal property petition is an **ELIGIBLE** outcome.
> `OTHER_FORM_REQUIRED` now means only the formal-probate / other-procedure fallback (DE-111).

## 1. The route model

The engine does not answer a single yes/no question. It evaluates **six routes independently**
against the same case and reports a status for every route. The routes (stable ids, mirroring
`SimpleProbate.Route`):

| route id | mechanism / forms | statutes |
|---|---|---|
| `direct_transfer` | No probate at all — the target asset passes outside the estate. No forms. | Prob. Code §13050, §13500 |
| `personal_property_affidavit` | Small-estate affidavit presented to the asset holder. No court filing, no DE form. | Prob. Code §§13100–13101 |
| `small_value_real_property_affidavit` | Form **DE-305**, Affidavit re Real Property of Small Value. | Prob. Code §13200 |
| `primary_residence_petition` | Forms **DE-310 / DE-315**, Petition to Determine Succession to Real Property (primary residence). | Prob. Code §§13150–13154 (AB 2016) |
| `spousal_property_petition` | Forms **DE-221 / DE-226**, Spousal or Domestic Partner Property Petition. | Prob. Code §13500, §§13650–13656 |
| `formal_probate_or_other_procedure` | Form **DE-111** full probate, or another procedure. Fallback only. | Prob. Code Div. 7 |

Routes are non-exclusive: a case may qualify for several at once. `direct_transfer` is reported as a
single route row; when it qualifies, the row's detail names the basis (joint tenancy, named
beneficiary, revocable trust, transfer-on-death, multiple-party account, government benefit, or
spouse passage), derived from the **target asset's** `treatment` (see §5).

## 2. Route eligibility conditions (the `Eligibility.lean` conjuncts, in plain English)

Every route implicitly requires a **supported death date** (§4) and a **well-formed case** (the
target asset is part of the listed estate — guaranteed in this demo by a valid `target_index`).
Beyond that:

**`direct_transfer`** (§13050, §13500)
- The target asset's treatment maps to a direct-transfer basis (§5 table). Nothing else — no
  waiting period, no value cap, no successor test.

**`personal_property_affidavit`** (§§13100–13101)
1. The target asset is **personal property** (`kind = personal`).
2. The claimant is the decedent's successor in interest (§13006).
3. No one has a superior right to the property (§13101(a)(5)).
4. At least **40 days** have elapsed since death (§13100).
5. Summary authority permits: **no probate proceeding** is pending or conducted, or the personal
   representative has given **written consent** (§13101(a)(3)); a blocking proceeding disqualifies.
6. The estate's **personal-affidavit qualifying value** (§5) is at or under the
   personal-property limit for the death-date band (§13100 / §890 adjustments).

**`small_value_real_property_affidavit`** (§13200, form DE-305)
1. The target asset is **California real property** with treatment `counted`.
2. Claimant is the successor; no one has a superior right.
3. At least **six months** have elapsed since death (§13200(a)).
4. Summary authority permits (no proceeding, or written personal-representative consent).
5. **Funeral expenses, last-illness expenses, and all unsecured debts have been paid**
   (§13200(a)(8)).
6. The gross value of **all** counted California real property in the estate is at or under the
   small-value real-property limit for the death-date band.

**`primary_residence_petition`** (§§13150–13154, forms DE-310/DE-315)
1. The target asset is **California real property**, treatment `counted`, and **is the decedent's
   primary residence**.
2. Claimant is the successor.
3. At least **40 days** have elapsed since death.
4. Summary authority permits.
5. The gross value of all counted CA real property marked as primary residence is at or under the
   primary-residence limit for the death-date band ($750,000 for deaths on/after 2025-04-01,
   per AB 2016).
- Note: this route has **no** superior-right conjunct and no six-month wait.

**`spousal_property_petition`** (§13500, §§13650–13656, forms DE-221/DE-226)
1. A surviving **spouse or registered domestic partner** exists (`survivor_status ≠ none`).
2. The property **passes to** the survivor OR already **belongs to** the survivor (§13500).
- That is all: **no value cap and no waiting period.**

**`formal_probate_or_other_procedure`** (DE-111)
- Eligible **only** when every one of the five simplified routes above is conclusively
  disqualified. It is never recommended while any simplified route qualifies or is unresolved.

## 3. Verdicts and aggregation (partial information)

Facts may be `null` = **unknown**. Unknown is **never** treated as false.

Within one route, each conjunct evaluates to satisfied, violated, or unknown, and:

1. any **known violation** ⇒ route `does_not_qualify` (violations beat unknowns);
2. else any **unknown** needed fact ⇒ route `needs_information` (the unresolved facts are listed);
3. else all satisfied ⇒ route `qualifies`.

Across the six routes, the overall verdict is:

| precedence | condition | `verdict` | `overall` |
|---|---|---|---|
| 1 | ≥ 1 simplified route `qualifies` (even if others are unresolved) | `ELIGIBLE` | `simplified_routes_available` |
| 2 | else ≥ 1 route `needs_information` | `INCOMPLETE_INFO` | `unresolved` |
| 3 | else every simplified route `does_not_qualify` | `OTHER_FORM_REQUIRED` | `formal_probate_or_other_procedure` |

Valuation under partial information: a value-capped route (rows 2–4 of §1) computes its total
exactly as the Lean baseline when every needed asset fact is known. A **known subtotal already over
the cap disqualifies** the route even if other asset values are unknown. Otherwise any needed
unknown fact makes the value check unknown. In addition, a capped route can only **qualify** when
`estate.inventory_complete` is known `true` — an unconfirmed inventory means the total might be
larger, so the route is at best `needs_information` (but can still be disqualified by a known
over-cap subtotal).

## 4. Snapshot boundary and case errors (not verdicts)

The model is a snapshot of the law as of 2026-07-28 and supports **valid civil death dates through
2026-12-31** (`snapshotEnd` in `Date.lean`). Death-date bands and errors:

- an **unknown** death date is not an error — date-dependent checks become `needs_information`;
- a known **invalid** date (e.g. Feb 30) ⇒ case error `invalid_date`;
- a known date **after 2026-12-31** ⇒ case error `after_snapshot`;
- a structurally broken case (e.g. `target_index` out of range, negative or non-integer money) ⇒
  case error `malformed_case`.

Case errors are returned in the top-level `error` object with `verdict: null`. **A date error is an
error state, never one of the three verdicts.** No post-2026 rule is inferred.

## 5. §13050 treatment table and the three valuations (`Estate.lean`)

Money is stored as **natural-number cents** in Lean (`Money.dollars 208_850` = 20,885,000 cents);
the wire schema uses integer cents. `encumbrances_cents` (liens, mortgages) **never reduces any
eligibility value** — all caps compare gross values.

Each asset has one of 14 `treatment` values. Contributions to the three route valuations:

| treatment | personal-affidavit value | small-value RP value | primary-residence value | direct-transfer basis |
|---|---|---|---|---|
| `counted` | gross value¹ | gross if CA real | gross if CA real ∧ primary residence | — |
| `employment_compensation` | gross − min(gross, exclusion)² | 0 | 0 | — |
| `joint_tenancy` | 0 | 0 | 0 | joint_tenancy |
| `direct_beneficiary` | 0 | 0 | 0 | named_beneficiary |
| `revocable_trust` | 0 | 0 | 0 | revocable_trust |
| `transfer_on_death` | 0 | 0 | 0 | transfer_on_death |
| `multiple_party_survivor` | 0 | 0 | 0 | multiple_party_account |
| `government_benefit` | 0 | 0 | 0 | government_benefit |
| `spouse_passage` | 0 | 0 | 0 | spouse_passage |
| `terminable_at_death` | 0 | 0 | 0 | — |
| `registered_vehicle` | 0 | 0 | 0 | — |
| `vessel` | 0 | 0 | 0 | — |
| `registered_home` | 0 | 0 | 0 | — |
| `military_compensation` | 0 | 0 | 0 | — |

¹ Overrides that zero the personal-affidavit contribution regardless of treatment:
`kind = outside_california_real` (out-of-state real property, §13050) or
`included_in_primary_residence_petition = true` (asset rides in the §13151 petition instead).
Note that **counted California real property does count** toward the personal-affidavit value
(only the *target* must be personal property for that route).

² Per §13050(c), unpaid employment compensation is excluded **up to** the band's
employment-compensation exclusion; the remainder counts. The Lean baseline applies the
`min(gross, exclusion)` subtraction **per asset** — this page mirrors the code as written, not the
spec's planned aggregate correction.

A treatment with a "—" basis and 0 in all columns (e.g. `registered_vehicle`, `vessel`,
`registered_home`, `terminable_at_death`, `military_compensation`) is excluded from the valuations
by §13050 but does not, by itself, give the target a direct-transfer route.

## 6. Threshold table (`Thresholds.lean`, in dollars)

Bands keyed to the death date (Prob. Code §890 triennial adjustments; third band per AB 2016):

| threshold | death before 2022-04-01 | 2022-04-01 – 2025-03-31 | 2025-04-01 – 2026-12-31 |
|---|---|---|---|
| Personal-property affidavit limit (§13100) | $166,250 | $184,500 | $208,850 |
| Primary-residence petition limit (§13151) | $166,250 | $184,500 | $750,000 |
| Small-value real-property affidavit limit (§13200) | $55,425 | $61,500 | $69,625 |
| Employment-compensation exclusion (§13050(c)) | $16,625 | $18,450 | $20,875 |
| Family set-aside (§6602)³ | $85,900 | $95,325 | $107,900 |
| Surviving-spouse earnings (§13600)³ | $16,625 | $18,450 | $20,875 |

³ Carried in `Thresholds.lean` for completeness; no route in this checker consumes them.

In Lean these are cents: e.g. the current personal-property limit is `Money.dollars 208_850`
= **20,885,000 cents**.
