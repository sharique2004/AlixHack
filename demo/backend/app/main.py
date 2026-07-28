"""FastAPI app for the LLM vs Lean4 CA probate simple-transfer demo (v2).

Per CONTRACT.md: port 8000, CORS for http://localhost:5173 and
http://127.0.0.1:5173. Content files (sample cases, Lean source under
AlixHack/) are resolved relative to the repo root at request time — they may
be written or rebuilt by another process after this server starts.

Both analyze endpoints validate the body with CaseInput (the 422 gate) and
then forward the RAW request body to the engine, so the client's JSON —
including explicit nulls and absent keys — reaches both engines exactly as
received.
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
from .schemas import CaseInput, CheckResult  # noqa: E402

SAMPLE_CASES_PATH = REPO_ROOT / "content" / "sample_cases.json"
# The Lean project is the repository root (demo/ lives inside it).
ALIXHACK_DIR = REPO_ROOT.parent

# Stable exact-engine dependency order per CONTRACT.md. Unlisted
# SimpleProbate/*.lean files (if any appear) are inserted alphabetically before
# ApiMain.lean.
LEAN_SOURCE_ORDER = [
    "SimpleProbate/Date.lean",
    "SimpleProbate/Thresholds.lean",
    "SimpleProbate/Decision.lean",
    "SimpleProbate/Estate.lean",
    "SimpleProbate/Case.lean",
    "SimpleProbate/Eligibility.lean",
    "SimpleProbate/Procedure.lean",
    "SimpleProbate/ProcedureAssessment.lean",
    "SimpleProbate/Api.lean",
    "SimpleProbate/Examples.lean",
    "ApiMain.lean",
]

app = FastAPI(title="CA Probate Simple Transfer — LLM vs Lean4")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
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
    }
