"""Gemini client — plain httpx REST call to generateContent (CONTRACT.md v2).

Model from GEMINI_MODEL env (default gemini-2.5-flash), key from
GEMINI_API_KEY (503 when unset). Uses responseMimeType application/json.
The prompt = court-page markdown + the case JSON EXACTLY as received (nulls
intact) + the exact v2 result schema with the three-verdict definitions and
the six route ids, instructing the model to fill every route row.

Network failure or a non-200 Gemini response ⇒ HTTP 502. Everything after a
200 response is handled INSIDE the try: unparseable/mismatched model output
degrades to the contract's malformed_case error result (verdict null,
error.type "malformed_case", raw text in reasoning) — never an HTTP 500.
"""

from __future__ import annotations

import json
import os
import re
import time
from pathlib import Path
from typing import Any, List, Optional, Type, TypeVar

import httpx
from fastapi import HTTPException
from pydantic import ValidationError

from .schemas import (
    CaseError,
    CaseErrorType,
    CheckResult,
    Overall,
    RouteResult,
    Usage,
    Verdict,
)

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
COURT_PAGE_PATH = REPO_ROOT / "content" / "simple-transfer.md"

GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

SYSTEM_INSTRUCTION = """You are a careful California probate self-help assistant. \
You are given (1) the full markdown of the California Courts "Simple transfer" \
self-help page and (2) a structured case as JSON. In the case JSON, null (or an \
absent key) means the fact is UNKNOWN — never assume an unknown fact is false. \
Money amounts are integer CENTS. `target_index` picks which asset in \
`estate.assets` the claimant is trying to transfer. Assess every simplified \
transfer route for that target.

Respond with ONLY a JSON object of this exact shape:
{
  "verdict": "INCOMPLETE_INFO" | "ELIGIBLE" | "OTHER_FORM_REQUIRED",   // null only when "error" is set
  "error": null,                    // or {"type": "invalid_date" | "after_snapshot" | "malformed_case",
                                    //     "detail": "human-readable"} for a structurally invalid case
                                    //     (invalid civil date; death date after 2026-12-31; bad target_index)
  "overall": "simplified_routes_available" | "unresolved" | "formal_probate_or_other_procedure",  // null only when "error" is set
  "routes": [                       // EXACTLY one entry per route id, ALL SIX, in the order listed below
    {
      "route": "<route id>",
      "status": "qualifies" | "does_not_qualify" | "needs_information",
      "reasons": [{"id": "snake_case_disqualifier_id", "text": "human-readable"}],  // non-empty iff does_not_qualify
      "missing_facts": ["death_date", "estate.assets[1].gross_value_cents"],        // JSON paths into the case; non-empty iff needs_information
      "detail": "one line, may be \\"\\"",
      "forms": ["DE-305"]           // court form numbers; [] when none apply
    }
  ],
  "reasoning": "your free-text reasoning"
}

The three verdicts:
- ELIGIBLE: at least one simplified route qualifies (even if other routes are unresolved).
  Then "overall" = "simplified_routes_available".
- INCOMPLETE_INFO: no route qualifies and at least one route needs more information.
  Then "overall" = "unresolved". Unknown is NEVER treated as false.
- OTHER_FORM_REQUIRED: EVERY simplified route is known not to qualify; only formal probate or
  another procedure remains. Then "overall" = "formal_probate_or_other_procedure".

The six route ids, in this order — fill in EVERY route row:
1. "direct_transfer" — property passes with no probate at all (joint tenancy, revocable trust,
   named/direct beneficiary, transfer on death, multiple-party account to a survivor, passage to a
   surviving spouse, government benefit). When it qualifies, name the basis in "detail". Forms: [].
2. "personal_property_affidavit" — small estate affidavit for personal property
   (Prob. Code §13100–13101), presented to the asset holder; no court filing. Forms: [].
3. "small_value_real_property_affidavit" — affidavit re real property of small value
   (§13200). Forms: ["DE-305"].
4. "primary_residence_petition" — petition to succeed to the primary residence
   (§13150–13154). Forms: ["DE-310", "DE-315"].
5. "spousal_property_petition" — spousal/domestic-partner property petition
   (§13500, §13650–13656). Forms: ["DE-221", "DE-226"].
6. "formal_probate_or_other_procedure" — full probate or another procedure; the fallback when no
   simplified route works. Forms: ["DE-111"] when it is the recommended path.

Return ONLY the JSON object — no markdown fences, no extra prose."""


# Selectable Gemini models (current text-capable generateContent IDs, July 2026).
# Prices are USD per million tokens where published; None = unpriced (cost shows
# as unavailable unless the GEMINI_PRICE_* env overrides are set).
GEMINI_MODELS: List[dict] = [
    {"id": "gemini-2.5-flash", "label": "Gemini 2.5 Flash", "price_in": 0.30, "price_out": 2.50},
    {"id": "gemini-2.5-flash-lite", "label": "Gemini 2.5 Flash-Lite", "price_in": 0.10, "price_out": 0.40},
    {"id": "gemini-2.5-pro", "label": "Gemini 2.5 Pro", "price_in": 1.25, "price_out": 10.00},
    {"id": "gemini-3.5-flash", "label": "Gemini 3.5 Flash", "price_in": 1.50, "price_out": 9.00},
    {"id": "gemini-3.5-flash-lite", "label": "Gemini 3.5 Flash-Lite", "price_in": 0.30, "price_out": 2.50},
    {"id": "gemini-3.6-flash", "label": "Gemini 3.6 Flash", "price_in": 1.50, "price_out": 7.50},
]
GEMINI_MODEL_IDS = {m["id"] for m in GEMINI_MODELS}


def default_model() -> str:
    return os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")


def _price_from_env(name: str, default: str) -> tuple[float, str]:
    """(numeric value, display string) for a USD pricing env var. An unset or
    unparseable value falls back to the contract default."""
    raw = os.environ.get(name, default).strip() or default
    try:
        return float(raw), raw
    except ValueError:
        return float(default), default


def _token_count(meta: dict, key: str) -> int:
    value = meta.get(key)
    if isinstance(value, int) and not isinstance(value, bool):
        return max(value, 0)
    return 0


def _extract_usage(body: dict, model: str) -> Optional[Usage]:
    """Build the CONTRACT.md `usage` object from Gemini's usageMetadata.

    thoughtsTokenCount (thinking tokens) is folded into output_tokens because
    Google bills thinking as output. Returns None when usageMetadata is absent
    (usage may be null per contract).
    """
    meta = body.get("usageMetadata")
    if not isinstance(meta, dict):
        return None
    input_tokens = _token_count(meta, "promptTokenCount")
    output_tokens = _token_count(meta, "candidatesTokenCount") + _token_count(
        meta, "thoughtsTokenCount"
    )
    entry = next((m for m in GEMINI_MODELS if m["id"] == model), None)
    table_in = entry["price_in"] if entry else None
    table_out = entry["price_out"] if entry else None
    env_in = os.environ.get("GEMINI_PRICE_IN_PER_M")
    env_out = os.environ.get("GEMINI_PRICE_OUT_PER_M")
    # Env overrides win; otherwise the per-model table; a model with no known
    # price ships tokens with a null cost rather than a made-up number.
    if env_in or env_out:
        price_in, price_in_str = _price_from_env("GEMINI_PRICE_IN_PER_M", "0.30")
        price_out, price_out_str = _price_from_env("GEMINI_PRICE_OUT_PER_M", "2.50")
    elif table_in is not None and table_out is not None:
        price_in, price_in_str = table_in, f"{table_in:g}"
        price_out, price_out_str = table_out, f"{table_out:g}"
    else:
        return Usage(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            cpu_ms=None,
            estimated_cost_usd=None,
            pricing_note=f"{model}: pricing unavailable",
        )
    return Usage(
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        cpu_ms=None,
        estimated_cost_usd=input_tokens / 1e6 * price_in
        + output_tokens / 1e6 * price_out,
        pricing_note=(
            f"{model} @ ${price_in_str}/M in + ${price_out_str}/M out (est.)"
        ),
    )


def _read_court_page() -> str:
    try:
        return COURT_PAGE_PATH.read_text(encoding="utf-8")
    except OSError:
        return "(court page markdown not available: content/simple-transfer.md not found)"


def _extract_text(response_body: dict) -> str:
    parts = (
        response_body.get("candidates", [{}])[0]
        .get("content", {})
        .get("parts", [])
    )
    return "".join(p.get("text", "") for p in parts if isinstance(p, dict))


def _parse_model_json(text: str) -> Optional[dict]:
    """Parse the model output as a JSON object, tolerating fences/extra prose."""
    candidates = [text.strip()]
    fenced = re.search(r"```(?:json)?\s*(.*?)```", text, re.DOTALL)
    if fenced:
        candidates.append(fenced.group(1).strip())
    brace = re.search(r"\{.*\}", text, re.DOTALL)
    if brace:
        candidates.append(brace.group(0))
    for candidate in candidates:
        try:
            parsed = json.loads(candidate)
        except (json.JSONDecodeError, ValueError):
            continue
        if isinstance(parsed, dict):
            return parsed
    return None


def _malformed_result(
    engine: str, latency_ms: int, detail: str, raw_text: str
) -> CheckResult:
    """The contract's error result for unusable LLM output."""
    return CheckResult(
        verdict=None,
        error=CaseError(type=CaseErrorType.malformed_case, detail=detail),
        overall=None,
        routes=[],
        reasoning=raw_text,
        engine=engine,
        latency_ms=latency_ms,
    )


_E = TypeVar("_E")


def _coerce_enum(enum_cls: Type[_E], value: Any) -> Optional[_E]:
    try:
        return enum_cls(value)
    except (ValueError, TypeError):
        return None


def _coerce_route(entry: Any) -> Optional[RouteResult]:
    """Validate one route row; drop it on mismatch (frontend renders the
    missing row as "not assessed"). Bare-string reasons are tolerated."""
    if not isinstance(entry, dict):
        return None
    entry = dict(entry)
    reasons_raw = entry.get("reasons")
    if isinstance(reasons_raw, list):
        entry["reasons"] = [
            {"id": "llm_reason", "text": r} if isinstance(r, str) else r
            for r in reasons_raw
        ]
    if entry.get("detail") is None:
        entry["detail"] = ""
    try:
        return RouteResult.model_validate(entry)
    except ValidationError:
        return None


_OVERALL_FOR_VERDICT = {
    Verdict.ELIGIBLE: Overall.simplified_routes_available,
    Verdict.INCOMPLETE_INFO: Overall.unresolved,
    Verdict.OTHER_FORM_REQUIRED: Overall.formal_probate_or_other_procedure,
}
_VERDICT_FOR_OVERALL = {v: k for k, v in _OVERALL_FOR_VERDICT.items()}


def _coerce_result(
    parsed: dict, engine: str, latency_ms: int, raw_text: str
) -> CheckResult:
    """Lenient mapping of the parsed LLM JSON onto CheckResult, enforcing the
    contract invariant: verdict is null iff error is set."""
    verdict = _coerce_enum(Verdict, parsed.get("verdict"))
    overall = _coerce_enum(Overall, parsed.get("overall"))

    # Verdict and Overall are a bijection — recover either one from the other
    # before declaring the output malformed.
    if verdict is None and overall is not None:
        verdict = _VERDICT_FOR_OVERALL[overall]
    elif overall is None and verdict is not None:
        overall = _OVERALL_FOR_VERDICT[verdict]

    error: Optional[CaseError] = None
    error_raw = parsed.get("error")
    if isinstance(error_raw, dict):
        try:
            error = CaseError.model_validate(error_raw)
        except ValidationError:
            error = None

    routes: List[RouteResult] = []
    routes_raw = parsed.get("routes")
    if isinstance(routes_raw, list):
        for entry in routes_raw:
            row = _coerce_route(entry)
            if row is not None:
                routes.append(row)

    reasoning_raw = parsed.get("reasoning")
    reasoning = reasoning_raw if isinstance(reasoning_raw, str) else raw_text

    if verdict is not None:
        error = None  # verdict wins; verdict null iff error set
    elif error is None:
        return _malformed_result(
            engine,
            latency_ms,
            "LLM output was not valid JSON for the result schema: "
            "no recognizable verdict or error",
            raw_text,
        )
    else:
        overall = None

    return CheckResult(
        verdict=verdict,
        error=error,
        overall=overall,
        routes=routes,
        reasoning=reasoning,
        engine=engine,
        latency_ms=latency_ms,
    )


async def analyze_llm(raw_body: bytes, model_override: Optional[str] = None) -> CheckResult:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="GEMINI_API_KEY not configured")
    if model_override is not None and model_override not in GEMINI_MODEL_IDS:
        raise HTTPException(
            status_code=422,
            detail=f"Unknown model '{model_override}'. Valid: {sorted(GEMINI_MODEL_IDS)}",
        )
    model = model_override or default_model()

    # Forward the client's JSON verbatim (nulls intact) so both engines see
    # identical input.
    case_json = raw_body.decode("utf-8", errors="replace")
    user_text = (
        "COURT PAGE (markdown):\n\n"
        + _read_court_page()
        + "\n\n---\n\nCASE (JSON, exactly as submitted — null or absent means "
        "UNKNOWN):\n\n"
        + case_json
        + "\n\nReturn ONLY the JSON object described in the instructions, "
        "with all six route rows filled in."
    )
    payload = {
        "system_instruction": {"parts": [{"text": SYSTEM_INSTRUCTION}]},
        "contents": [{"role": "user", "parts": [{"text": user_text}]}],
        "generationConfig": {"responseMimeType": "application/json"},
    }

    started = time.perf_counter()
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                GEMINI_ENDPOINT.format(model=model),
                headers={"x-goog-api-key": api_key},
                json=payload,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502, detail=f"Gemini request failed: {exc}"
        ) from exc
    latency_ms = int((time.perf_counter() - started) * 1000)

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Gemini returned HTTP {response.status_code}: {response.text[:500]}",
        )

    # Everything below is inside the try: a bad Gemini payload degrades to the
    # contract's malformed_case error result, never a 500. The tokens were
    # spent on ANY 200 response, so `usage` (from usageMetadata, when present)
    # is attached to every result built here — including the malformed-output
    # fallback path.
    raw_text = ""
    usage: Optional[Usage] = None
    try:
        body = response.json()
        usage = _extract_usage(body, model)
        raw_text = _extract_text(body)
        if not raw_text.strip():
            result = _malformed_result(
                model,
                latency_ms,
                "LLM output was not valid JSON: response contained no text",
                raw_text,
            )
        else:
            parsed = _parse_model_json(raw_text)
            if parsed is None:
                result = _malformed_result(
                    model,
                    latency_ms,
                    f"LLM output was not valid JSON: {raw_text[:300]!r}",
                    raw_text,
                )
            else:
                result = _coerce_result(parsed, model, latency_ms, raw_text)
    except Exception as exc:  # noqa: BLE001 — degrade per contract, never 500
        result = _malformed_result(
            model,
            latency_ms,
            f"LLM output was not valid JSON: {str(exc)[:300]}",
            raw_text,
        )
    result.usage = usage
    return result
