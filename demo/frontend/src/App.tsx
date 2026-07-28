import { useCallback, useEffect, useRef, useState } from "react";
import type { CaseInput, CheckResult, SampleCase } from "./types";
import {
  EngineCard,
  fmtCost,
  type EngineState,
} from "./components/EngineCard";
import { Slides } from "./components/Slides";

interface ModelInfo {
  id: string;
  label: string;
  default: boolean;
}

/** Fallback so the model selector can never render empty (e.g. venue Wi-Fi). */
const FALLBACK_MODELS: ModelInfo[] = [
  { id: "gemini-2.5-flash", label: "Gemini 2.5 Flash", default: true },
  { id: "gemini-2.5-flash-lite", label: "Gemini 2.5 Flash-Lite", default: false },
  { id: "gemini-2.5-pro", label: "Gemini 2.5 Pro", default: false },
  { id: "gemini-3.5-flash", label: "Gemini 3.5 Flash", default: false },
  { id: "gemini-3.5-flash-lite", label: "Gemini 3.5 Flash-Lite", default: false },
  { id: "gemini-3.6-flash", label: "Gemini 3.6 Flash", default: false },
];

async function post(path: string, body: CaseInput): Promise<CheckResult> {
  const res = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    let detail = `HTTP ${res.status}`;
    try {
      const data = await res.json();
      if (typeof data.detail === "string") detail = data.detail;
      else if (Array.isArray(data.detail))
        detail = data.detail
          .map((e: { loc?: unknown[]; msg?: string }) =>
            e.loc ? `${e.loc.slice(1).join(".")}: ${e.msg}` : String(e.msg),
          )
          .join("; ");
    } catch {
      /* keep status text */
    }
    throw new Error(detail);
  }
  return (await res.json()) as CheckResult;
}

function targetValueCents(c: CaseInput): number | null {
  const assets = c.estate?.assets ?? [];
  return assets[c.target_index]?.gross_value_cents ?? null;
}

function withTargetValue(c: CaseInput, cents: number): CaseInput {
  const assets = (c.estate?.assets ?? []).map((a, i) =>
    i === c.target_index ? { ...a, gross_value_cents: cents } : a,
  );
  return { ...c, estate: { ...(c.estate ?? {}), assets } };
}

function fmtDuration(ms: number): string {
  return ms >= 1000 ? `${(ms / 1000).toFixed(1)}s` : `${ms}ms`;
}

function fmtRatio(r: number): string {
  const rounded = r >= 100 ? Math.round(r / 10) * 10 : Math.round(r);
  return `${rounded.toLocaleString()}×`;
}

/** The head-to-head box: compares the two engines on the current case. */
function CompareBox({ llm, lean }: { llm: EngineState; lean: EngineState }) {
  const ready =
    llm.status === "done" &&
    !llm.stale &&
    !!llm.result &&
    !llm.result.error &&
    lean.status === "done" &&
    !!lean.result &&
    !lean.result.error;

  if (!ready) {
    return (
      <section className="compare compare-empty" aria-label="Head to head">
        <h3>Head to head</h3>
        <p className="muted">
          {llm.status === "pending"
            ? "Waiting for the LLM run to finish…"
            : llm.stale
              ? "The case changed. Run the LLM again to compare on this exact case."
              : "Run the LLM on this case to see the head-to-head."}
        </p>
      </section>
    );
  }

  const l = llm.result!;
  const k = lean.result!;
  const lTokens = (l.usage?.input_tokens ?? 0) + (l.usage?.output_tokens ?? 0);
  const lCost = l.usage?.estimated_cost_usd ?? null;
  const kCost = k.usage?.estimated_cost_usd ?? null;
  const timeRatio = k.latency_ms > 0 ? l.latency_ms / k.latency_ms : null;
  const costRatio = lCost != null && kCost != null && kCost > 0 ? lCost / kCost : null;
  const agree = l.verdict === k.verdict;

  const rows = [
    {
      label: "Time",
      llm: fmtDuration(l.latency_ms),
      lean: fmtDuration(k.latency_ms),
      chip: timeRatio && timeRatio > 1 ? `${fmtRatio(timeRatio)} faster` : null,
    },
    {
      label: "Tokens",
      llm: lTokens > 0 ? lTokens.toLocaleString() : "—",
      lean: "0",
      chip: lTokens > 0 ? "zero tokens" : null,
    },
    {
      label: "Est. cost",
      llm: fmtCost(lCost),
      lean: fmtCost(kCost),
      chip: costRatio && costRatio > 1 ? `${fmtRatio(costRatio)} cheaper` : null,
    },
  ];

  return (
    <section className="compare" aria-label="Head to head">
      <div className="compare-head">
        <h3>Head to head on this case</h3>
        <span className={`chip ${agree ? "chip-green" : "chip-amber"}`}>
          {agree ? "Same verdict" : "Different verdicts"}
        </span>
      </div>
      <div className="compare-grid">
        {rows.map((r) => (
          <div className="compare-cell" key={r.label}>
            <span className="metric-label">{r.label}</span>
            <div className="compare-pair">
              <span className="compare-engine">LLM</span>
              <span className="compare-llm">{r.llm}</span>
            </div>
            <div className="compare-pair">
              <span className="compare-engine">Lean</span>
              <span className="compare-lean">{r.lean}</span>
            </div>
            {r.chip && <span className="chip chip-blue compare-chip">{r.chip}</span>}
          </div>
        ))}
      </div>
    </section>
  );
}

/** Lazily-loaded Lean source, tucked under the compiled card. */
function LeanSource() {
  const [open, setOpen] = useState(false);
  const [files, setFiles] = useState<{ name: string; content: string }[] | null>(null);
  const [active, setActive] = useState(0);
  useEffect(() => {
    if (!open || files) return;
    fetch("/api/lean-source")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .then((d) => setFiles(d.files))
      .catch(() => setFiles([]));
  }, [open, files]);
  return (
    <div className="lean-source">
      <button type="button" className="link-toggle" onClick={() => setOpen(!open)} aria-expanded={open}>
        {open ? "Hide" : "View"} the compiled Lean source
      </button>
      {open && files && files.length > 0 && (
        <>
          <div className="source-tabs" role="tablist">
            {files.map((f, i) => (
              <button
                key={f.name}
                type="button"
                role="tab"
                aria-selected={i === active}
                className={i === active ? "tab-active" : ""}
                onClick={() => setActive(i)}
              >
                {f.name.replace("SimpleProbate/", "").replace(".lean", "")}
              </button>
            ))}
          </div>
          <pre className="source-code">{files[active].content}</pre>
        </>
      )}
      {open && files && files.length === 0 && <p className="muted">Source unavailable.</p>}
    </div>
  );
}

export default function App() {
  const [samples, setSamples] = useState<SampleCase[]>([]);
  const [models, setModels] = useState<ModelInfo[]>(FALLBACK_MODELS);
  const [model, setModel] = useState<string>(FALLBACK_MODELS[0].id);
  const [activeTicket, setActiveTicket] = useState<string | null>(null);
  const [caseObj, setCaseObj] = useState<CaseInput | null>(null);
  const [lean, setLean] = useState<EngineState>({ status: "idle", result: null });
  const [llm, setLlm] = useState<EngineState>({ status: "idle", result: null });
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [editorText, setEditorText] = useState("");
  const [dialMax, setDialMax] = useState(30_000_000);
  const [slidesOpen, setSlidesOpen] = useState(false);
  const leanSeq = useRef(0);
  const llmSeq = useRef(0);
  const dialTimer = useRef<number | null>(null);

  const runLean = useCallback((c: CaseInput) => {
    const seq = ++leanSeq.current;
    setLean((s) => ({ ...s, status: "pending" }));
    post("/api/analyze/lean", c)
      .then((r) => {
        if (seq === leanSeq.current) setLean({ status: "done", result: r });
      })
      .catch((e: Error) => {
        if (seq === leanSeq.current)
          setLean({ status: "unavailable", result: null, message: e.message });
      });
  }, []);

  const runLlm = useCallback(
    (c: CaseInput) => {
      const seq = ++llmSeq.current;
      setLlm({ status: "pending", result: null });
      const q = model ? `?model=${encodeURIComponent(model)}` : "";
      post(`/api/analyze/llm${q}`, c)
        .then((r) => {
          if (seq === llmSeq.current) setLlm({ status: "done", result: r, stale: false });
        })
        .catch((e: Error) => {
          if (seq === llmSeq.current)
            setLlm({ status: "unavailable", result: null, message: e.message });
        });
    },
    [model],
  );

  // The compiled engine re-answers on every case change. Any in-flight LLM run
  // is cancelled (seq bump) so an old case's answer can never land as fresh.
  const slotCase = useCallback(
    (c: CaseInput, name: string | null) => {
      llmSeq.current += 1;
      setCaseObj(c);
      setActiveTicket(name);
      setEditorText(JSON.stringify(c, null, 2));
      // Freeze the slider range for this case so the track doesn't grow mid-drag.
      const v = targetValueCents(c);
      setDialMax(Math.max(30_000_000, v == null ? 0 : v * 2));
      setLlm((s) =>
        s.status === "done" ? { ...s, stale: true } : { status: "idle", result: null },
      );
      runLean(c);
    },
    [runLean],
  );

  useEffect(() => {
    fetch("/api/cases")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .then((data: SampleCase[]) => {
        setSamples(data);
        if (data.length > 0) slotCase(data[0].case, data[0].name);
      })
      .catch(() => setSamples([]));
    fetch("/api/models")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .then((d: { models: ModelInfo[] }) => {
        const list = d.models.length > 0 ? d.models : FALLBACK_MODELS;
        setModels(list);
        setModel(list.find((m) => m.default)?.id ?? list[0].id);
      })
      .catch(() => {
        /* fallback list already in state */
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const dialCents = caseObj ? targetValueCents(caseObj) : null;
  const onDial = (cents: number) => {
    if (!caseObj) return;
    const next = withTargetValue(caseObj, cents);
    llmSeq.current += 1; // cancel any in-flight run — the case just changed
    setCaseObj(next);
    // Don't clobber unsaved JSON edits while the drawer is open.
    if (!drawerOpen) setEditorText(JSON.stringify(next, null, 2));
    setLlm((s) =>
      s.status === "done"
        ? { ...s, stale: true }
        : s.status === "pending"
          ? { status: "idle", result: null }
          : s,
    );
    if (dialTimer.current) window.clearTimeout(dialTimer.current);
    dialTimer.current = window.setTimeout(() => runLean(next), 140);
  };

  let editorValid = true;
  try {
    JSON.parse(editorText || "{}");
  } catch {
    editorValid = false;
  }

  const activeSample = samples.find((s) => s.name === activeTicket) ?? null;
  const leanUsage = lean.result?.usage;
  const llmUsage = llm.result?.usage;

  return (
    <div className="page">
      <header className="intro">
        <span className="pill">Why compile the law?</span>
        <h1>
          Same Case,
          <br />
          Two Ways to Answer
        </h1>
        <p className="intro-sub">
          Pick a probate case below. An LLM reads the statute on every query. The
          compiled, proof-checked Lean code was written once and answers instantly.
        </p>
      </header>

      <section className="toolbar" aria-label="Case controls">
        <label className="control">
          <span className="control-label">Case</span>
          <select
            value={activeTicket ?? ""}
            onChange={(e) => {
              const s = samples.find((x) => x.name === e.target.value);
              if (s) slotCase(s.case, s.name);
            }}
            aria-label="Sample case"
          >
            {activeTicket === null && <option value="">Custom case</option>}
            {samples.map((s) => (
              <option key={s.name} value={s.name}>
                {s.title ?? s.name.replace(/-/g, " ")}
              </option>
            ))}
          </select>
        </label>
        <label className="control control-grow">
          <span className="control-label">Estate value</span>
          {dialCents != null ? (
            <div className="slider-wrap">
              <input
                type="range"
                min={0}
                max={dialMax}
                step={500_00}
                value={dialCents}
                onChange={(e) => onDial(Number(e.target.value))}
                aria-label="Target asset value in dollars. The compiled engine re-answers live."
              />
              <span className="slider-value">
                ${Math.round(dialCents / 100).toLocaleString()}
              </span>
            </div>
          ) : (
            <span className="muted">Unknown in this case</span>
          )}
        </label>
        <button
          type="button"
          className="btn-ghost"
          aria-expanded={drawerOpen}
          onClick={() => setDrawerOpen(!drawerOpen)}
        >
          {drawerOpen ? "Close JSON" : "Edit JSON"}
        </button>
        <button type="button" className="btn-dark" onClick={() => setSlidesOpen(true)}>
          PPT
        </button>
      </section>
      {slidesOpen && <Slides onClose={() => setSlidesOpen(false)} />}
      {activeSample && <p className="case-blurb">{activeSample.blurb}</p>}

      {drawerOpen && (
        <section className="editor">
          <textarea
            value={editorText}
            onChange={(e) => setEditorText(e.target.value)}
            spellCheck={false}
            aria-label="Case JSON"
          />
          <div className="editor-actions">
            <span className={`dot ${editorValid ? "dot-ok" : "dot-bad"}`} />
            <span className="muted">{editorValid ? "Valid JSON" : "Invalid JSON"}</span>
            <button
              type="button"
              className="btn-dark"
              disabled={!editorValid}
              onClick={() => {
                try {
                  slotCase(JSON.parse(editorText) as CaseInput, null);
                } catch {
                  /* indicator already shows invalid */
                }
              }}
            >
              Apply case
            </button>
          </div>
        </section>
      )}

      <main className="cards">
        <EngineCard
          variant="llm"
          title="Ask an LLM Every Time."
          tagline="Gemini re-reads the whole statute for every single case."
          icon={
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path
                d="M12 3.5c.5 3.6 1.9 5 5.5 5.5-3.6.5-5 1.9-5.5 5.5-.5-3.6-1.9-5-5.5-5.5 3.6-.5 5-1.9 5.5-5.5zM18.5 13c.3 2 1 2.8 3 3-2 .3-2.7 1-3 3-.3-2-1-2.7-3-3 2-.2 2.7-1 3-3zM6 14.5c.3 1.6.9 2.2 2.5 2.5-1.6.3-2.2.9-2.5 2.5-.3-1.6-.9-2.2-2.5-2.5 1.6-.3 2.2-.9 2.5-2.5z"
                fill="currentColor"
              />
            </svg>
          }
          headerExtra={
            <div className="llm-controls">
              <label className="control">
                <span className="control-label">Model</span>
                <select
                  value={model}
                  onChange={(e) => {
                    setModel(e.target.value);
                    setLlm((s) => (s.status === "done" ? { ...s, stale: true } : s));
                  }}
                  aria-label="Gemini model"
                >
                  {models.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.label}
                    </option>
                  ))}
                </select>
              </label>
              <span
                className="chip chip-amber"
                title="Ground-truth audit: 23 of 36 Gemini runs matched the verified answer (3 runs per case)"
              >
                23/36 runs correct
              </span>
            </div>
          }
          state={llm}
          pendingLabel="Reading the statute…"
          metrics={[
            {
              label: "Time",
              value: llm.result ? `${(llm.result.latency_ms / 1000).toFixed(1)}s` : "—",
            },
            {
              label: "Tokens",
              value:
                llmUsage?.input_tokens != null
                  ? `${((llmUsage.input_tokens + (llmUsage.output_tokens ?? 0)) / 1000).toFixed(1)}k`
                  : "—",
            },
            {
              label: "Est. cost",
              value: fmtCost(llmUsage?.estimated_cost_usd),
              title: llmUsage?.pricing_note ?? undefined,
            },
          ]}
          actions={
            <button
              type="button"
              className="btn-dark"
              disabled={!caseObj || llm.status === "pending"}
              onClick={() => caseObj && runLlm(caseObj)}
            >
              {llm.status === "pending"
                ? "Running…"
                : llm.result || llm.status === "unavailable"
                  ? "Run again"
                  : "Run this case"}
            </button>
          }
        />

        <EngineCard
          variant="lean"
          title="Or Run the Compiled Law."
          tagline="Written once in Lean 4, proof-checked, run forever."
          icon={
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path
                d="M12 2.8 5 5.6v5.2c0 4.4 3 8.4 7 9.6 4-1.2 7-5.2 7-9.6V5.6l-7-2.8z"
                fill="currentColor"
                opacity="0.22"
              />
              <path
                d="M8.6 11.8l2.4 2.5 4.6-5"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.9"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          }
          headerExtra={
            <div className="llm-controls">
              <span
                className="chip chip-green"
                title="435,456 fuzzed cases with zero disagreement against the statutory predicates; 12/12 ground-truth audit"
              >
                Verified · 435,456 cases · 12/12 audit
              </span>
              <span className="chip chip-blue">Re-answers live as you drag</span>
            </div>
          }
          state={lean}
          pendingLabel="Running the compiled law…"
          metrics={[
            {
              label: "Time",
              value: lean.result ? `${lean.result.latency_ms}ms` : "—",
            },
            { label: "Tokens", value: lean.result ? "0" : "—" },
            {
              label: "Est. cost",
              value: fmtCost(leanUsage?.estimated_cost_usd),
              title: leanUsage?.pricing_note ?? undefined,
            },
          ]}
          footerExtra={<LeanSource />}
        />

        <CompareBox llm={llm} lean={lean} />
      </main>

      <footer className="page-foot">
        <p>
          Demo only, not legal advice. All cases are fictional. Sources: the CA Courts
          self-help guide as of 2026-07-28, death dates supported through 2026-12-31. Lean
          proves consequences of supplied facts, not their truth.
        </p>
      </footer>
    </div>
  );
}
