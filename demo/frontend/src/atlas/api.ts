/* Typed client for the settlement router.

   Three outcomes, and the UI must be able to tell them apart:
     ok         — the engine returned a SettlementAssessment
     rejected   — the engine returned the typed error envelope (a structural
                  answer, not a legal one: doctrine 5)
     unavailable— we never got an answer we could trust (offline, timeout,
                  wrong shape). This is never rendered as a verdict.

   Contract: CONTRACT-SETTLEMENT.md §1. */

import type {
  AssessResponse,
  ErrorEnvelope,
  IntakeCase,
  SampleCase,
  SettlementAssessment,
} from "./types";

/**
 * Where the engine lives.
 *
 * Empty in dev (Vite proxies /api → 127.0.0.1:8000) and in any deployment that
 * serves the frontend from the same origin as the API. Set VITE_API_BASE at
 * build time — e.g. https://api.atlas.example.com — when the static site and
 * the engine are hosted separately, which they must be: the engine is a ~95 MB
 * native binary and cannot run on a static/edge host.
 */
const API_BASE = (import.meta.env.VITE_API_BASE ?? "").replace(/\/$/, "");

export const ASSESS_PATH = `${API_BASE}/api/settlement/assess`;
export const SAMPLES_PATH = `${API_BASE}/api/settlement/samples`;
export const HEALTH_PATH = `${API_BASE}/api/health`;

const TIMEOUT_MS = 12_000;

export type AssessOutcome =
  | { kind: "ok"; assessment: SettlementAssessment }
  | { kind: "rejected"; error: ErrorEnvelope["error"] }
  | { kind: "unavailable"; detail: string };

export type SamplesOutcome =
  | { kind: "ok"; samples: SampleCase[] }
  | { kind: "unavailable"; detail: string };

export type EngineHealth =
  | { kind: "ok"; settlementEngine: string }
  | { kind: "unavailable"; detail: string };

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null;
}

/** An error envelope, shaped exactly as the contract defines it. */
export function isErrorEnvelope(v: unknown): v is ErrorEnvelope {
  return (
    isRecord(v) &&
    isRecord(v.error) &&
    typeof v.error.code === "string" &&
    typeof v.error.detail === "string"
  );
}

/** Structural gate. A 200 with the wrong shape is a transport failure, not a
    verdict — we would rather say "no answer" than render something we cannot
    account for. */
export function isSettlementAssessment(v: unknown): v is SettlementAssessment {
  if (!isRecord(v)) return false;
  return (
    typeof v.engine === "string" &&
    isRecord(v.snapshot) &&
    Array.isArray(v.asset_map) &&
    isRecord(v.probate_estate) &&
    Array.isArray(v.jurisdictions) &&
    Array.isArray(v.federal) &&
    Array.isArray(v.flags) &&
    Array.isArray(v.deadlines) &&
    Array.isArray(v.next_actions) &&
    Array.isArray(v.unresolved_facts) &&
    Array.isArray(v.notes)
  );
}

async function requestJSON(
  path: string,
  init: RequestInit,
  signal?: AbortSignal,
): Promise<{ kind: "json"; status: number; body: unknown } | { kind: "unavailable"; detail: string }> {
  const timer = new AbortController();
  const timeout = setTimeout(() => timer.abort(), TIMEOUT_MS);
  const onOuterAbort = () => timer.abort();
  signal?.addEventListener("abort", onOuterAbort);
  try {
    const res = await fetch(path, { ...init, signal: timer.signal });
    const text = await res.text();
    if (text.trim() === "") {
      return { kind: "unavailable", detail: `${path} returned an empty response (HTTP ${res.status}).` };
    }
    try {
      return { kind: "json", status: res.status, body: JSON.parse(text) as unknown };
    } catch {
      return {
        kind: "unavailable",
        detail: `${path} returned HTTP ${res.status} but the body was not JSON.`,
      };
    }
  } catch (e) {
    if (signal?.aborted) return { kind: "unavailable", detail: "Request cancelled." };
    const why = timer.signal.aborted
      ? `The engine did not answer within ${TIMEOUT_MS / 1000} seconds.`
      : e instanceof Error
        ? e.message
        : "Unknown network error.";
    return { kind: "unavailable", detail: why };
  } finally {
    clearTimeout(timeout);
    signal?.removeEventListener("abort", onOuterAbort);
  }
}

export async function assessCase(input: IntakeCase, signal?: AbortSignal): Promise<AssessOutcome> {
  const res = await requestJSON(
    ASSESS_PATH,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(input),
    },
    signal,
  );
  if (res.kind === "unavailable") return res;

  const body = res.body as AssessResponse | unknown;
  if (isErrorEnvelope(body)) return { kind: "rejected", error: body.error };
  if (isSettlementAssessment(body)) return { kind: "ok", assessment: body };

  // FastAPI validation failures arrive as {"detail": ...} — a structural
  // problem, surfaced as such rather than dressed up as an assessment.
  if (isRecord(body) && "detail" in body) {
    return {
      kind: "unavailable",
      detail: `The engine rejected the request (HTTP ${res.status}): ${JSON.stringify(body.detail)}`,
    };
  }
  return {
    kind: "unavailable",
    detail: `The engine returned HTTP ${res.status} in a shape this build does not recognise.`,
  };
}

export async function fetchSamples(signal?: AbortSignal): Promise<SamplesOutcome> {
  const res = await requestJSON(SAMPLES_PATH, { method: "GET" }, signal);
  if (res.kind === "unavailable") return res;
  const body = res.body;
  if (isRecord(body) && Array.isArray(body.samples)) {
    const samples = body.samples.filter(
      (s): s is SampleCase =>
        isRecord(s) && typeof s.id === "string" && typeof s.label === "string" && isRecord(s.case),
    );
    return { kind: "ok", samples };
  }
  return { kind: "unavailable", detail: `${SAMPLES_PATH} did not return a sample list.` };
}

export async function fetchEngineHealth(signal?: AbortSignal): Promise<EngineHealth> {
  const res = await requestJSON(HEALTH_PATH, { method: "GET" }, signal);
  if (res.kind === "unavailable") return res;
  const body = res.body;
  if (isRecord(body) && typeof body.settlement_engine === "string") {
    return { kind: "ok", settlementEngine: body.settlement_engine };
  }
  // The health endpoint exists but predates the settlement engine.
  if (isRecord(body)) return { kind: "unavailable", detail: "This backend does not expose a settlement engine yet." };
  return { kind: "unavailable", detail: "Health check returned an unexpected shape." };
}
