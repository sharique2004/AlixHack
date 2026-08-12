"""Pydantic v2 models mirroring CONTRACT.md (v2).

`CaseInput` mirrors `SimpleProbate.TransferCase` through the vendored Lean
repo's partial-information layer: EVERY fact field is nullable, and null (or an
absent key) means UNKNOWN — never false. Money is integer cents. Enums are
strict: a value that is present but outside the contract's enum is a schema
violation (HTTP 422).

Semantics beyond wire shape (civil-date validity, the 2026-12-31 snapshot end,
target_index range, negative money, route aggregation) are the Lean engine's
job — it reports them as a top-level `error` object, not an HTTP error. These
models are only the validation gate; the raw request body is forwarded to the
engines exactly as received so nulls stay intact.
"""

from __future__ import annotations

from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


# --------------------------------------------------------------------------- #
# Case-input enums (strict)
# --------------------------------------------------------------------------- #


class ValuationTreatment(str, Enum):
    """The 14 SimpleProbate.ValuationTreatment values, snake_case."""

    counted = "counted"
    joint_tenancy = "joint_tenancy"
    terminable_at_death = "terminable_at_death"
    revocable_trust = "revocable_trust"
    spouse_passage = "spouse_passage"
    multiple_party_survivor = "multiple_party_survivor"
    registered_vehicle = "registered_vehicle"
    vessel = "vessel"
    registered_home = "registered_home"
    direct_beneficiary = "direct_beneficiary"
    transfer_on_death = "transfer_on_death"
    government_benefit = "government_benefit"
    military_compensation = "military_compensation"
    employment_compensation = "employment_compensation"


class AssetKind(str, Enum):
    personal = "personal"
    california_real = "california_real"
    outside_california_real = "outside_california_real"


class Authority(str, Enum):
    no_proceeding = "no_proceeding"
    written_personal_representative_consent = (
        "written_personal_representative_consent"
    )
    blocked_by_proceeding = "blocked_by_proceeding"


class SurvivorStatus(str, Enum):
    none = "none"
    spouse = "spouse"
    registered_domestic_partner = "registered_domestic_partner"


# --------------------------------------------------------------------------- #
# Result enums (strict)
# --------------------------------------------------------------------------- #


class RouteId(str, Enum):
    """Snake_case route ids mirroring SimpleProbate.Route, in stable order."""

    direct_transfer = "direct_transfer"
    personal_property_affidavit = "personal_property_affidavit"
    small_value_real_property_affidavit = "small_value_real_property_affidavit"
    primary_residence_petition = "primary_residence_petition"
    spousal_property_petition = "spousal_property_petition"
    formal_probate_or_other_procedure = "formal_probate_or_other_procedure"


class RouteStatus(str, Enum):
    qualifies = "qualifies"
    does_not_qualify = "does_not_qualify"
    needs_information = "needs_information"


class Verdict(str, Enum):
    INCOMPLETE_INFO = "INCOMPLETE_INFO"
    ELIGIBLE = "ELIGIBLE"
    OTHER_FORM_REQUIRED = "OTHER_FORM_REQUIRED"


class Overall(str, Enum):
    simplified_routes_available = "simplified_routes_available"
    unresolved = "unresolved"
    formal_probate_or_other_procedure = "formal_probate_or_other_procedure"


class CaseErrorType(str, Enum):
    invalid_date = "invalid_date"
    after_snapshot = "after_snapshot"
    malformed_case = "malformed_case"


# --------------------------------------------------------------------------- #
# Case input
# --------------------------------------------------------------------------- #


class CivilDate(BaseModel):
    """Structured date matching SimpleProbate.CivilDate. Validity (real civil
    date, ≤ 2026-12-31 snapshot end) is checked by the Lean engine."""

    year: int
    month: int
    day: int


class Asset(BaseModel):
    name: str  # required, unique within the list (uniqueness checked by Lean)
    kind: Optional[AssetKind] = None
    gross_value_cents: Optional[int] = None  # negative ⇒ Lean malformed_case
    encumbrances_cents: Optional[int] = None  # never reduces eligibility values
    treatment: Optional[ValuationTreatment] = None
    included_in_primary_residence_petition: Optional[bool] = None
    is_primary_residence: Optional[bool] = None


class Estate(BaseModel):
    inventory_complete: Optional[bool] = None
    assets: Optional[List[Asset]] = None


class CaseInput(BaseModel):
    death_date: Optional[CivilDate] = None
    days_since_death: Optional[int] = None
    six_months_elapsed: Optional[bool] = None
    claimant_is_successor: Optional[bool] = None
    no_superior_right: Optional[bool] = None
    funeral_last_illness_and_unsecured_debts_paid: Optional[bool] = None
    authority: Optional[Authority] = None
    survivor_status: Optional[SurvivorStatus] = None
    property_passes_to_survivor: Optional[bool] = None
    property_belongs_to_survivor: Optional[bool] = None
    estate: Optional[Estate] = None
    # Required: which asset the claimant is trying to transfer. Out-of-range
    # is a Lean-side case error (malformed_case), not a 422.
    target_index: int


# --------------------------------------------------------------------------- #
# Check result (both engines return this shape)
# --------------------------------------------------------------------------- #


class CaseError(BaseModel):
    type: CaseErrorType
    detail: str


class Reason(BaseModel):
    """Stable snake_case disqualifier id with human-readable text."""

    id: str
    text: str


class RouteResult(BaseModel):
    route: RouteId
    status: RouteStatus
    reasons: List[Reason] = Field(default_factory=list)  # iff does_not_qualify
    missing_facts: List[str] = Field(default_factory=list)  # iff needs_information
    detail: str = ""
    forms: List[str] = Field(default_factory=list)


class Usage(BaseModel):
    """Per-analysis compute/token/cost metrics (CONTRACT.md v2 `usage`).

    All fields optional; the whole object is null on CheckResult when nothing
    is measurable. The Lean binary does NOT emit this — the backend attaches
    it (same as latency_ms). The LLM side derives it from Gemini's
    usageMetadata.
    """

    input_tokens: Optional[int] = None  # LLM only; null for Lean
    output_tokens: Optional[int] = None  # LLM only (includes thinking tokens)
    cpu_ms: Optional[float] = None  # Lean only: subprocess CPU (user+sys)
    estimated_cost_usd: Optional[float] = None  # estimate; null if unpriceable
    pricing_note: Optional[str] = None


class CheckResult(BaseModel):
    verdict: Optional[Verdict] = None  # null iff error is set
    error: Optional[CaseError] = None
    overall: Optional[Overall] = None  # null iff error is set
    routes: List[RouteResult] = Field(default_factory=list)
    reasoning: str = ""
    engine: str  # "lean4" | Gemini model name
    latency_ms: int
    usage: Optional[Usage] = None  # null when nothing measurable


# --------------------------------------------------------------------------- #
# Settlement router intake (CONTRACT-SETTLEMENT.md §2)
# --------------------------------------------------------------------------- #
#
# The settlement engine owns every semantic rule; these models are only a
# loose wire-shape gate on POST /api/settlement/assess. "Loose" is deliberate
# and has one hard requirement: an explicit `null` and an absent key must both
# survive as UNKNOWN. That is why the endpoint forwards the RAW request body —
# `IntakeCase` is validated and then discarded, never re-serialised, so
# Pydantic's defaults can never turn a null into `false` or `0` on the way to
# Lean.
#
# Unrecognised keys are ignored rather than rejected (pydantic's default), so a
# client that sends a field the engine understands but this gate has not
# learned yet still reaches the engine verbatim. Enum values that ARE present
# are checked, so a typo'd `title_form` is a 422 here rather than a silently
# unknown fact downstream.


class MannerOfDeath(str, Enum):
    natural = "natural"
    accident = "accident"
    suicide = "suicide"
    homicide = "homicide"
    pending = "pending"
    undetermined = "undetermined"


class WillStatus(str, Enum):
    valid_original = "valid_original"
    copy_only = "copy_only"
    holographic = "holographic"
    none = "none"
    unsure = "unsure"


class MaritalStatus(str, Enum):
    married = "married"
    single = "single"
    widowed = "widowed"
    divorced = "divorced"


class IntakeAssetKind(str, Enum):
    real_property = "real_property"
    bank = "bank"
    brokerage = "brokerage"
    retirement = "retirement"
    life_insurance = "life_insurance"
    vehicle = "vehicle"
    personal = "personal"
    business = "business"
    digital = "digital"
    employment_comp = "employment_comp"
    other = "other"


class TitleForm(str, Enum):
    sole = "sole"
    jtwros = "jtwros"
    tenancy_by_entirety = "tenancy_by_entirety"
    community_with_ros = "community_with_ros"
    tenants_in_common = "tenants_in_common"
    trust_funded = "trust_funded"
    custodial = "custodial"


class BeneficiaryDesignation(str, Enum):
    named_living = "named_living"
    named_predeceased = "named_predeceased"
    estate = "estate"
    none = "none"
    unsure = "unsure"


class DebtKind(str, Enum):
    mortgage = "mortgage"
    credit_card = "credit_card"
    medical = "medical"
    tax = "tax"
    loan = "loan"
    funeral = "funeral"
    other = "other"


class RefundClaimant(str, Enum):
    surviving_spouse_joint_return = "surviving_spouse_joint_return"
    court_appointed_representative = "court_appointed_representative"
    other = "other"


class FinalReturnKind(str, Enum):
    original = "original"
    amended = "amended"


class HeirRelationship(str, Enum):
    spouse = "spouse"
    child = "child"
    parent = "parent"
    sibling = "sibling"
    other = "other"


class IntakeDecedent(BaseModel):
    death_date: Optional[CivilDate] = None
    domicile_state: Optional[str] = None  # 2-letter; unsupported ⇒ advisory only
    marital_status: Optional[MaritalStatus] = None
    surviving_spouse: Optional[bool] = None
    manner_of_death: Optional[MannerOfDeath] = None
    death_certificate_final: Optional[bool] = None
    will_status: Optional[WillStatus] = None
    employment_related_death: Optional[bool] = None
    third_party_fault_suspected: Optional[bool] = None
    related_death_within_120h: Optional[bool] = None
    received_medicaid_ltc: Optional[bool] = None
    veteran: Optional[bool] = None
    pending_litigation: Optional[bool] = None
    # CONTRACT §2.1 — Florida
    will_directs_administration: Optional[bool] = None
    administration_pending: Optional[bool] = None
    # CONTRACT §2.1 — federal
    federal_refund_due: Optional[bool] = None
    refund_claimant: Optional[RefundClaimant] = None
    final_return_kind: Optional[FinalReturnKind] = None
    court_certificate_attached: Optional[bool] = None
    # Fully OR currently insured — 42 U.S.C. §402(i) opens on the disjunction.
    ssa_insured_at_death: Optional[bool] = None


class IntakeAsset(BaseModel):
    # Required and unique across the case — asset names are identifiers that
    # `debts[].secured_by_asset` and the response's `asset_map` refer back to.
    name: str
    kind: Optional[IntakeAssetKind] = None
    situs_state: Optional[str] = None
    gross_value_cents: Optional[int] = None
    encumbrance_cents: Optional[int] = None
    title_form: Optional[TitleForm] = None
    beneficiary_designation: Optional[BeneficiaryDesignation] = None
    is_primary_residence: Optional[bool] = None
    # §2.1 — stated exemption under Fla. Stat. §732.402. Protected homestead is
    # derived by the engine, not stated here.
    exempt_from_creditors: Optional[bool] = None


class IntakeDebt(BaseModel):
    kind: Optional[DebtKind] = None
    amount_cents: Optional[int] = None
    secured_by_asset: Optional[str] = None


class IntakeHeir(BaseModel):
    relationship: Optional[HeirRelationship] = None
    name: Optional[str] = None
    age: Optional[int] = None
    receives_means_tested_benefits: Optional[bool] = None
    is_suspect_in_death: Optional[bool] = None
    disclaimed: Optional[bool] = None
    # §2.1 — 42 U.S.C. §402(i). Entitlement is a fact, never inferred from
    # `relationship`.
    lived_in_same_household_at_death: Optional[bool] = None
    entitled_to_spouse_benefits_month_of_death: Optional[bool] = None
    entitled_to_child_benefits_month_of_death: Optional[bool] = None


class IntakeExpenses(BaseModel):
    # §2.1 — Fla. Stat. §735.301's allowance is measured against these two.
    preferred_funeral_cents: Optional[int] = None
    last_illness_medical_cents: Optional[int] = None


class IntakeCase(BaseModel):
    # The only required field. Everything else is nullable/absent = unknown.
    as_of_date: CivilDate
    decedent: Optional[IntakeDecedent] = None
    assets: Optional[List[IntakeAsset]] = None
    debts: Optional[List[IntakeDebt]] = None
    heirs: Optional[List[IntakeHeir]] = None
    conflict_signals: Optional[bool] = None
    # "Is this list of assets complete?" — gates every valuation cap test.
    inventory_complete: Optional[bool] = None
    # §2.1 — "Is this list of people complete?" — gates every negative
    # conclusion about who may claim.
    heirs_complete: Optional[bool] = None
    expenses: Optional[IntakeExpenses] = None
