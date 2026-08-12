"""FastAPI app for the LLM vs Lean4 CA probate simple-transfer demo (v2).

Per CONTRACT.md: port 8000, CORS for http://localhost:5173 and
http://127.0.0.1:5173. Content files (sample cases, Lean source under
AlixHack/) are resolved relative to the repo root at request time — they may
be written or rebuilt by another process after this server starts.

Both analyze endpoints validate the body with CaseInput (the 422 gate) and
then forward the RAW request body to the engine, so the client's JSON —
including explicit nulls and absent keys — reaches both engines exactly as
received. `/api/settlement/assess` (CONTRACT-SETTLEMENT.md) applies the same
discipline with IntakeCase as its gate.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

BACKEND_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = BACKEND_DIR.parent  # demo/

# Load backend/.env before reading any configuration.
load_dotenv(BACKEND_DIR / ".env")

from .lean_runner import analyze_lean, lean_engine_status  # noqa: E402
from .llm import GEMINI_MODELS, analyze_llm, default_model  # noqa: E402
from .schemas import CaseInput, CheckResult, IntakeCase  # noqa: E402
from .settlement_runner import (  # noqa: E402
    assess_settlement,
    settlement_engine_status,
)

SAMPLE_CASES_PATH = REPO_ROOT / "content" / "sample_cases.json"
SETTLEMENT_SAMPLES_PATH = REPO_ROOT / "content" / "settlement_samples.json"
# The Lean project is the repository root (demo/ lives inside it).
ALIXHACK_DIR = REPO_ROOT.parent

# Stable order per CONTRACT.md: every AlixHack/SimpleProbate/*.lean, then
# ApiMain.lean. Unlisted SimpleProbate/*.lean files (if any appear) are
# inserted alphabetically before ApiMain.lean.
LEAN_SOURCE_ORDER = [
    "SimpleProbate/Date.lean",
    "SimpleProbate/Thresholds.lean",
    "SimpleProbate/Estate.lean",
    "SimpleProbate/Eligibility.lean",
    "SimpleProbate/Procedure.lean",
    "SimpleProbate/Partial.lean",
    "SimpleProbate/Api.lean",
    "SimpleProbate/Examples.lean",
    "ApiMain.lean",
]

app = FastAPI(title="CA Probate Simple Transfer — LLM vs Lean4")

# Local dev origins always; deployed origins come from the environment so the
# hostname is never baked into the source. ALLOWED_ORIGINS is comma-separated,
# e.g. "https://atlas.example.com".
_ALLOWED_ORIGINS = ["http://localhost:5173", "http://127.0.0.1:5173"] + [
    o.strip() for o in os.getenv("ALLOWED_ORIGINS", "").split(",") if o.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/api/analyze/llm", response_model=CheckResult)
async def analyze_llm_endpoint(
    case: CaseInput, request: Request, model: Optional[str] = None
) -> CheckResult:
    del case  # validation gate only — the engine gets the raw body
    return await analyze_llm(await request.body(), model_override=model)


@app.get("/api/models")
async def get_models() -> dict:
    default = default_model()
    return {
        "models": [
            {"id": m["id"], "label": m["label"], "default": m["id"] == default}
            for m in GEMINI_MODELS
        ]
    }


@app.post("/api/analyze/lean", response_model=CheckResult)
async def analyze_lean_endpoint(case: CaseInput, request: Request) -> CheckResult:
    del case  # validation gate only — the engine gets the raw body
    return await analyze_lean(await request.body())


@app.get("/api/cases")
async def get_cases() -> JSONResponse:
    if not SAMPLE_CASES_PATH.is_file():
        return JSONResponse(
            status_code=404,
            content={"detail": "content/sample_cases.json not found"},
        )
    try:
        cases = json.loads(SAMPLE_CASES_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return JSONResponse(
            status_code=404,
            content={"detail": f"content/sample_cases.json unreadable: {exc}"},
        )
    return JSONResponse(content=cases)


# --------------------------------------------------------------------------- #
# Settlement router (CONTRACT-SETTLEMENT.md)
# --------------------------------------------------------------------------- #


@app.post("/api/settlement/assess")
async def settlement_assess_endpoint(
    case: IntakeCase, request: Request
) -> JSONResponse:
    """`IntakeCase` → `SettlementAssessment | ErrorEnvelope` (both HTTP 200).

    `IntakeCase` is a wire-shape gate only and is discarded immediately: the
    RAW body goes to the engine so an explicit `null` and an absent key both
    survive as *unknown*. Re-serialising the model here would let Pydantic's
    defaults turn a null into a value, which is the one thing this product
    cannot tolerate.

    The contract's error envelope is a legitimate response body, not an HTTP
    error. Only an engine that cannot run, times out, or emits something that
    is neither contract shape produces a 503 (raised by the runner).
    """
    del case  # validation gate only — the engine gets the raw body
    body, headers = await assess_settlement(await request.body())
    return JSONResponse(content=body, headers=headers)


@app.get("/api/settlement/samples")
async def get_settlement_samples() -> JSONResponse:
    """`{samples: [{id, label, blurb, case}]}` from content/settlement_samples.json."""
    if not SETTLEMENT_SAMPLES_PATH.is_file():
        return JSONResponse(
            status_code=404,
            content={"detail": "content/settlement_samples.json not found"},
        )
    try:
        payload = json.loads(SETTLEMENT_SAMPLES_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return JSONResponse(
            status_code=404,
            content={"detail": f"content/settlement_samples.json unreadable: {exc}"},
        )
    # The response shape is exactly the contract's `{samples: [...]}` and never
    # inherits anything else the file carries (it holds an authoring `_note`).
    # A bare list is accepted and wrapped.
    samples = payload if isinstance(payload, list) else payload.get("samples", [])
    return JSONResponse(content={"samples": samples})


@app.get("/api/lean-source")
async def get_lean_source() -> JSONResponse:
    listed = set(LEAN_SOURCE_ORDER)
    extras = sorted(
        f"SimpleProbate/{path.name}"
        for path in (ALIXHACK_DIR / "SimpleProbate").glob("*.lean")
        if f"SimpleProbate/{path.name}" not in listed
    )
    ordered = LEAN_SOURCE_ORDER[:-1] + extras + LEAN_SOURCE_ORDER[-1:]

    files = []
    for name in ordered:
        path = ALIXHACK_DIR / name
        if not path.is_file():
            continue
        try:
            files.append(
                {"name": name, "content": path.read_text(encoding="utf-8")}
            )
        except OSError:
            continue
    if not files:
        return JSONResponse(
            status_code=404,
            content={"detail": "no Lean source files found under AlixHack/"},
        )
    return JSONResponse(content={"files": files})


@app.get("/api/health")
async def health() -> dict:
    return {
        "ok": True,
        "gemini_configured": bool(os.environ.get("GEMINI_API_KEY")),
        "lean_engine": lean_engine_status(),
        "settlement_engine": settlement_engine_status(),
    }


# --------------------------------------------------------------- static site
#
# In a deployment the compiled frontend is served by this same process, so the
# whole product is one origin, one container, one DNS record: no CORS, no
# build-time API URL, nothing to keep in sync. STATIC_DIR points at the Vite
# build output. When it is unset or missing (local development, where Vite
# serves the frontend on :5173 and proxies /api here) these routes simply do
# not mount and everything behaves exactly as before.
#
# Registered last on purpose: every /api route above is already bound, so the
# catch-all cannot shadow them.

_STATIC_DIR = os.getenv("STATIC_DIR", "").strip()

if _STATIC_DIR and Path(_STATIC_DIR).is_dir():
    from fastapi.responses import FileResponse
    from fastapi.staticfiles import StaticFiles

    _static_root = Path(_STATIC_DIR).resolve()
    _index = _static_root / "index.html"

    app.mount("/assets", StaticFiles(directory=str(_static_root / "assets")), name="assets")

    @app.get("/{full_path:path}", include_in_schema=False)
    async def spa(full_path: str):
        """Serve the SPA. Real files win; every other path falls back to
        index.html so client-side routes like /evidence load on a hard refresh.
        An unmatched /api/* path must still be a JSON 404, not the app shell."""
        if full_path.startswith("api/"):
            return JSONResponse(status_code=404, content={"detail": "not found"})
        candidate = (_static_root / full_path).resolve()
        if (
            full_path
            and candidate.is_file()
            and candidate.is_relative_to(_static_root)  # no path traversal
        ):
            return FileResponse(candidate)
        return FileResponse(_index)
