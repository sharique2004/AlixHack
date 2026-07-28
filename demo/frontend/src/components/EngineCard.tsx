import { useEffect, useState } from "react";
import type { CheckResult, RouteId, RouteResult } from "../types";
import { ROUTE_ORDER } from "../types";

export const ROUTE_LABEL: Record<RouteId, { name: string; cite: string }> = {
  direct_transfer: { name: "Direct transfer", cite: "no probate" },
  personal_property_affidavit: { name: "Personal property affidavit", cite: "§13100" },
  small_value_real_property_affidavit: { name: "Small-value real property", cite: "§13200 · DE-305" },
  primary_residence_petition: { name: "Primary residence petition", cite: "§13150 · DE-310" },
  spousal_property_petition: { name: "Spousal property petition", cite: "§13650 · DE-221" },
  formal_probate_or_other_procedure: { name: "Formal probate / other", cite: "fallback · DE-111" },
};

const STATUS_TEXT: Record<string, string> = {
  qualifies: "Qualifies",
  does_not_qualify: "Ruled out",
  needs_information: "Needs info",
};

const VERDICT_TEXT: Record<string, string> = {
  ELIGIBLE: "Eligible — a simplified route qualifies",
  INCOMPLETE_INFO: "Incomplete — more information needed",
  OTHER_FORM_REQUIRED: "Another form — formal probate route",
};

export type EngineStatus = "idle" | "pending" | "done" | "unavailable";

export interface EngineState {
  status: EngineStatus;
  result: CheckResult | null;
  message?: string;
  stale?: boolean;
}

export function fmtCost(v: number | null | undefined): string {
  if (v == null) return "—";
  if (v === 0) return "$0";
  if (v >= 0.01) return `$${v.toFixed(2)}`;
  if (v >= 0.0001) return `$${v.toFixed(4)}`;
  return `$${v.toFixed(7).replace(/0+$/, "")}`;
}

function routeFor(result: CheckResult | null, id: RouteId): RouteResult | null {
  return result?.routes.find((r) => r.route === id) ?? null;
}

/** Live elapsed timer shown while a run is in flight. */
function Elapsed() {
  const [ms, setMs] = useState(0);
  useEffect(() => {
    const started = performance.now();
    const id = window.setInterval(() => setMs(performance.now() - started), 100);
    return () => window.clearInterval(id);
  }, []);
  return <span className="elapsed">{(ms / 1000).toFixed(1)}s</span>;
}

function StatusGlyph({ status }: { status: string }) {
  if (status === "qualifies")
    return (
      <svg className="row-glyph glyph-green" viewBox="0 0 16 16" aria-hidden="true">
        <circle cx="8" cy="8" r="8" opacity="0.14" />
        <path d="M4.6 8.4 7 10.8l4.6-5.2" fill="none" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  if (status === "needs_information")
    return (
      <svg className="row-glyph glyph-amber" viewBox="0 0 16 16" aria-hidden="true">
        <circle cx="8" cy="8" r="8" opacity="0.14" />
        <path d="M8 4.4v4.4M8 11.4v.4" fill="none" strokeWidth="1.9" strokeLinecap="round" />
      </svg>
    );
  return (
    <svg className="row-glyph glyph-slate" viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="8" opacity="0.12" />
      <path d="M5.4 5.4l5.2 5.2M10.6 5.4l-5.2 5.2" fill="none" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

interface EngineCardProps {
  variant: "llm" | "lean";
  title: string;
  tagline: string;
  icon: React.ReactNode;
  headerExtra?: React.ReactNode; // model select (llm) / audit chip (lean)
  state: EngineState;
  metrics: { label: string; value: string; title?: string }[];
  actions?: React.ReactNode; // run button etc.
  footerExtra?: React.ReactNode; // lean source viewer
  /** Copy for the in-flight banner — the two engines work differently. */
  pendingLabel?: string;
}

export function EngineCard({
  variant,
  title,
  tagline,
  icon,
  headerExtra,
  state,
  metrics,
  actions,
  footerExtra,
  pendingLabel = "Working…",
}: EngineCardProps) {
  const [openRoute, setOpenRoute] = useState<RouteId | null>(null);
  const [showReasoning, setShowReasoning] = useState(false);
  const { status, result } = state;
  const error = result?.error ?? null;
  const pending = status === "pending";

  useEffect(() => {
    if (pending) {
      setOpenRoute(null);
      setShowReasoning(false);
    }
  }, [pending]);

  const verdictClass = error
    ? "verdict-red"
    : result?.verdict === "ELIGIBLE"
      ? "verdict-green"
      : result?.verdict === "INCOMPLETE_INFO"
        ? "verdict-amber"
        : result?.verdict
          ? "verdict-blue"
          : "verdict-none";

  return (
    <section className={`card card-${variant}`} aria-label={title}>
      <div className="card-head">
        <div className={`icon-tile tile-${variant}`} aria-hidden="true">{icon}</div>
        <div className="card-title-block">
          <h2>{title}</h2>
          <p>{tagline}</p>
        </div>
      </div>
      {headerExtra && <div className="card-controls">{headerExtra}</div>}

      <div className="card-panel">
        {/* Verdict banner */}
        {pending ? (
          <div className="verdict verdict-pending" role="status">
            <span className="spinner" aria-hidden="true" />
            {pendingLabel} <Elapsed />
          </div>
        ) : error ? (
          <div className="verdict verdict-red" role="status">
            {error.type === "after_snapshot"
              ? "Outside supported dates — sources end 2026-12-31"
              : error.type === "invalid_date"
                ? "Invalid date in this case"
                : "Case could not be read"}
          </div>
        ) : result?.verdict ? (
          <div className={`verdict ${verdictClass}`}>
            {VERDICT_TEXT[result.verdict]}
            {state.stale && <span className="stale-chip" title="The case changed after this run">outdated</span>}
          </div>
        ) : status === "unavailable" ? (
          <div className="verdict verdict-red" role="status">{state.message}</div>
        ) : (
          <div className="verdict verdict-none">Run to see this engine's answer</div>
        )}

        {/* Route checklist */}
        <ul className="route-list">
          {ROUTE_ORDER.map((id) => {
            const row = routeFor(result, id);
            const open = openRoute === id;
            const hasDetail =
              !!row && (row.reasons.length > 0 || row.missing_facts.length > 0 || !!row.detail);
            return (
              <li key={id} className={pending ? "row-skeleton" : ""}>
                <button
                  type="button"
                  className="route-row"
                  disabled={!hasDetail}
                  aria-expanded={open}
                  onClick={() => setOpenRoute(open ? null : id)}
                >
                  {row && !pending ? <StatusGlyph status={row.status} /> : <span className="row-glyph glyph-empty" />}
                  <span className="route-name">
                    {ROUTE_LABEL[id].name}
                    <span className="route-cite">{ROUTE_LABEL[id].cite}</span>
                  </span>
                  <span
                    className={`route-status ${
                      row
                        ? row.status === "qualifies"
                          ? "status-green"
                          : row.status === "needs_information"
                            ? "status-amber"
                            : "status-slate"
                        : "status-empty"
                    }`}
                  >
                    {pending ? "" : row ? STATUS_TEXT[row.status] : result ? "—" : ""}
                  </span>
                </button>
                {open && row && (
                  <div className="route-detail">
                    {row.detail && <p>{row.detail}</p>}
                    {row.reasons.map((r) => (
                      <p key={r.id} className="detail-line">{r.text}</p>
                    ))}
                    {row.missing_facts.map((m) => (
                      <p key={m} className="detail-line">
                        Missing: <code>{m}</code>
                      </p>
                    ))}
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      </div>

      {/* Metrics + actions */}
      <div className="card-foot">
        <div className="metrics">
          {metrics.map((m) => (
            <div className="metric" key={m.label} title={m.title}>
              <span className="metric-label">{m.label}</span>
              <span className="metric-value">{m.value}</span>
            </div>
          ))}
        </div>
        {actions}
      </div>

      {(result?.reasoning || footerExtra) && (
        <div className="card-extra">
          {result?.reasoning && !error && (
            <>
              <button
                type="button"
                className="link-toggle"
                aria-expanded={showReasoning}
                onClick={() => setShowReasoning(!showReasoning)}
              >
                {showReasoning ? "Hide" : "Show"} full reasoning
              </button>
              {showReasoning && <p className="reasoning">{result.reasoning}</p>}
            </>
          )}
          {footerExtra}
        </div>
      )}
    </section>
  );
}
