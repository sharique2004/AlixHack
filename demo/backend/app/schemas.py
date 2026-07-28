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
