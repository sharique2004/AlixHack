/* The words. Kept in one file because the words are the product here.

   Rules: plain declarative sentences, no jargon without a gloss, and never a
   sentence that implies not knowing something is a failure. The reader may have
   buried a parent last week. Assume they have never heard "joint tenancy". */

import type { Choice } from "../design/primitives";
import type {
  AssetKind,
  BeneficiaryDesignation,
  MannerOfDeath,
  MaritalStatus,
  TitleForm,
  WillStatus,
} from "../types";

export const MARITAL_STATUS: Choice<MaritalStatus>[] = [
  { value: "married", label: "Married" },
  { value: "single", label: "Single" },
  { value: "widowed", label: "Widowed" },
  { value: "divorced", label: "Divorced" },
];

export const MANNER_OF_DEATH: Choice<MannerOfDeath>[] = [
  { value: "natural", label: "Natural causes" },
  { value: "accident", label: "An accident" },
  { value: "suicide", label: "Suicide" },
  { value: "homicide", label: "Homicide" },
  { value: "pending", label: "The coroner hasn't decided yet" },
  { value: "undetermined", label: "The coroner closed it as undetermined" },
];

export const WILL_STATUS: Choice<WillStatus>[] = [
  {
    value: "valid_original",
    label: "Yes, and we have the signed original",
    explain: "The actual signed document, not a scan. Courts want the original.",
  },
  {
    value: "copy_only",
    label: "We only have a copy",
    explain: "A photocopy, a scan, or a PDF, but the signed original hasn't turned up.",
  },
  {
    value: "holographic",
    label: "It's handwritten",
    explain: "Written and signed in their own hand, with no witnesses. California recognises these; most states are stricter.",
  },
  { value: "none", label: "There is no will", explain: "Then state law decides who inherits." },
];

export const ASSET_KINDS: Choice<AssetKind>[] = [
  { value: "real_property", label: "Real property — a house, a condo, land" },
  { value: "bank", label: "Bank account" },
  { value: "brokerage", label: "Brokerage or investment account" },
  { value: "retirement", label: "Retirement account — 401(k), IRA, pension" },
  { value: "life_insurance", label: "Life insurance policy" },
  { value: "vehicle", label: "Vehicle" },
  { value: "personal", label: "Personal belongings" },
  { value: "business", label: "A business, or a share of one" },
  { value: "digital", label: "Digital assets" },
  { value: "employment_comp", label: "Unpaid wages or employment compensation" },
  { value: "other", label: "Something else" },
];

/** The single most consequential question in the whole intake, and the one
    ordinary people are least equipped to answer. Every option gets a sentence. */
export const TITLE_FORMS: Choice<TitleForm>[] = [
  {
    value: "sole",
    label: "In their name only",
    explain: "Nobody else was an owner.",
  },
  {
    value: "jtwros",
    label: "Joint tenancy with right of survivorship",
    explain:
      "Owned with someone else, and when one owner dies the other automatically owns all of it. Deeds and statements often say “JTWROS” or “as joint tenants”.",
  },
  {
    value: "community_with_ros",
    label: "Community property with right of survivorship",
    explain: "A married-couple form used in California. The surviving spouse takes it automatically.",
  },
  {
    value: "tenancy_by_entirety",
    label: "Tenancy by the entirety",
    explain:
      "A married-couple form used in some states — Florida among them, California not. The survivor takes it automatically.",
  },
  {
    value: "tenants_in_common",
    label: "Tenants in common",
    explain:
      "Owned with someone else, but each share is separate. The decedent's share does not go to the co-owner — it goes through the estate.",
  },
  {
    value: "trust_funded",
    label: "Owned by a living trust",
    explain: "It was retitled into a trust while they were alive, so the trust owns it, not the estate.",
  },
  {
    value: "custodial",
    label: "Held for someone else",
    explain: "A custodial account — for example one held for a child.",
  },
];

export const TITLE_FORM_GLOSS =
  "“How it was titled” means whose names were on it and in what way. It is the fact that decides whether an asset goes through probate at all, and it is written on the deed, the account statement, or the title certificate.";

export const BENEFICIARY_DESIGNATIONS: Choice<BeneficiaryDesignation>[] = [
  { value: "named_living", label: "Yes, and that person is alive" },
  { value: "named_predeceased", label: "Yes, but that person died first" },
  { value: "estate", label: "Yes — the estate itself is named" },
  { value: "none", label: "No beneficiary was named" },
];

export const BENEFICIARY_GLOSS =
  "A beneficiary designation is the form you fill in with a bank, insurer, or retirement plan naming who gets the money when you die. It is separate from the will, and it beats the will. Bank accounts call it “payable on death”; brokerages call it “transfer on death”.";

export const DEBT_KINDS: Choice<
  "mortgage" | "credit_card" | "medical" | "tax" | "loan" | "funeral" | "other"
>[] = [
  { value: "mortgage", label: "Mortgage" },
  { value: "credit_card", label: "Credit card" },
  { value: "medical", label: "Medical bills" },
  { value: "tax", label: "Taxes" },
  { value: "loan", label: "A loan" },
  { value: "funeral", label: "Funeral expenses" },
  { value: "other", label: "Something else" },
];

export const RELATIONSHIPS: Choice<"spouse" | "child" | "parent" | "sibling" | "other">[] = [
  { value: "spouse", label: "Spouse or registered partner" },
  { value: "child", label: "Child" },
  { value: "parent", label: "Parent" },
  { value: "sibling", label: "Sibling" },
  { value: "other", label: "Someone else" },
];

export const STATES: Choice<string>[] = [
  "AL","AK","AZ","AR","CA","CO","CT","DE","DC","FL","GA","HI","ID","IL","IN","IA","KS","KY",
  "LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH",
  "OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY",
].map((s) => ({ value: s, label: s }));

/** Shown once, at the top of the wizard. It sets the contract with the reader. */
export const NOT_SURE_PROMISE =
  "Every question here can be answered “not sure”. Nothing is assumed to be no. Anything you leave open comes back at the end as a named, specific thing to go and find out.";
