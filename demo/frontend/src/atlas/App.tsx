/* Atlas — the product shell.

   The pitch, stated once and then not repeated: an intake form that ends in
   "an advisor will call you" has thrown your answers away. This one ends in a
   settlement map you can check line by line against the statute.

   Layout: hero → why → wizard → result → footer. The result slot is agent
   UI-B's `CaseFile`, mounted if that module exists and gracefully replaced by a
   built-in summary if it does not. */

import { useCallback, useEffect, useRef, useState } from "react";
import {
  Button,
  Chip,
  CitationLine,
  FramedCard,
  SampleBadge,
  scrollToEl,
  Section,
  StatusGlyph,
} from "./design/primitives";
import {
  assessCase,
  fetchEngineHealth,
  fetchSamples,
  type AssessOutcome,
} from "./api";
import { FIXTURES, fixtureOutcomeFor, SAMPLE_CASES } from "./fixtures";
import { Wizard } from "./intake/Wizard";
import {
  emptyDraft,
  fromIntakeCase,
  toIntakeCase,
  type Draft,
} from "./intake/model";
import {
  formatDate,
  formatUSD,
  ROUTE_STATUS_TONE,
  type SampleCase,
  type SettlementAssessment,
} from "./types";

// The agreed seam with agent UI-B. `import.meta.glob` resolves to {} when the
// module has not been written yet, so this file builds and renders either way.
const CASEFILE_MODULES = import.meta.glob("./casefile/CaseFile.tsx");

interface CaseFileProps {
  assessment: SettlementAssessment;
  onEditFact?: (path: string) => void;
}
type CaseFileComponent = (props: CaseFileProps) => JSX.Element | null;

type Provenance = "engine" | "sample";

export default function AtlasApp() {
  const [draft, setDraftState] = useState<Draft>(() => emptyDraft());
  const [busy, setBusy] = useState(false);
  const [outcome, setOutcome] = useState<AssessOutcome | null>(null);
  const [provenance, setProvenance] = useState<Provenance | null>(null);
  const [offlineDetail, setOfflineDetail] = useState<string | null>(null);
  const [engineLabel, setEngineLabel] = useState<string | null>(null);
  const [samples, setSamples] = useState<SampleCase[]>(SAMPLE_CASES);
  const [samplesAreLocal, setSamplesAreLocal] = useState(true);
  const [loadedSampleId, setLoadedSampleId] = useState<string | null>(null);
  const [focusFact, setFocusFact] = useState<{ path: string; nonce: number } | null>(null);
  const [CaseFile, setCaseFile] = useState<CaseFileComponent | null>(null);

  const resultRef = useRef<HTMLDivElement>(null);
  const wizardRef = useRef<HTMLDivElement>(null);

  // ---- the case-file seam ------------------------------------------------
  useEffect(() => {
    const key = Object.keys(CASEFILE_MODULES).find((k) => k.endsWith("/CaseFile.tsx"));
    if (!key) return;
    let alive = true;
    void CASEFILE_MODULES[key]()
      .then((mod) => {
        const exported = (mod as { CaseFile?: unknown }).CaseFile;
        if (alive && typeof exported === "function") {
          setCaseFile(() => exported as CaseFileComponent);
        }
      })
      .catch(() => {
        /* the seam is optional by design */
      });
    return () => {
      alive = false;
    };
  }, []);

  // ---- engine + samples --------------------------------------------------
  useEffect(() => {
    const ac = new AbortController();
    void fetchEngineHealth(ac.signal).then((h) => {
      if (!ac.signal.aborted) setEngineLabel(h.kind === "ok" ? h.settlementEngine : null);
    });
    void fetchSamples(ac.signal).then((s) => {
      if (ac.signal.aborted) return;
      if (s.kind === "ok" && s.samples.length > 0) {
        setSamples(s.samples);
        setSamplesAreLocal(false);
      }
    });
    return () => ac.abort();
  }, []);

  const setDraft = useCallback((d: Draft) => {
    setDraftState(d);
    setLoadedSampleId(null); // it is the user's case now, not a sample
  }, []);

  const run = useCallback(
    async (d: Draft, sampleId: string | null) => {
      setBusy(true);
      setOutcome(null);
      setOfflineDetail(null);
      const res = await assessCase(toIntakeCase(d));
      if (res.kind === "unavailable") {
        // Graceful offline path. A hand-written fixture may stand in for a
        // sample case — never for a case the user typed, and never unlabelled.
        const fallback = sampleId ? fixtureOutcomeFor(sampleId) : null;
        if (fallback) {
          setOutcome(fallback);
          setProvenance("sample");
        } else {
          setOutcome(res);
          setProvenance(null);
        }
        setOfflineDetail(res.detail);
      } else {
        setOutcome(res);
        setProvenance("engine");
      }
      setBusy(false);
      window.setTimeout(() => scrollToEl(resultRef.current), 0);
    },
    [],
  );

  const loadSample = useCallback(
    (id: string) => {
      const found = samples.find((s) => s.id === id);
      if (!found) return;
      const d = fromIntakeCase(found.case);
      setDraftState(d);
      setLoadedSampleId(id);
      void run(d, id);
    },
    [samples, run],
  );

  const editFact = useCallback((path: string) => {
    setFocusFact((prev) => ({ path, nonce: (prev?.nonce ?? 0) + 1 }));
    window.setTimeout(() => scrollToEl(wizardRef.current), 0);
  }, []);

  const showSampleResult = useCallback(() => {
    const first = FIXTURES[0];
    setDraftState(fromIntakeCase(first.case));
    setLoadedSampleId(first.id);
    setOutcome(first.outcome);
    setProvenance("sample");
    window.setTimeout(() => scrollToEl(resultRef.current), 0);
  }, []);

  return (
    <div className="atlas">
      <div className="atlas-shell">
        <div className="atlas-stack">
          {/* ------------------------------------------------------ hero */}
          <Section tone="ink">
            <nav className="ax-nav" aria-label="Primary">
              <span className="ax-nav__brand">
                <span className="ax-nav__mark">Atlas</span>
                <span className="ax-nav__sub">settlement map for a simple estate</span>
              </span>
              <span className="ax-nav__links">
                <a className="ax-nav__link" href="/evidence">
                  Evidence
                </a>
              </span>
            </nav>

            <div className="ax-hero">
              <div>
                <h1>When someone dies, the law has already decided most of what happens next.</h1>
                <p className="ax-hero__lede lede">
                  Families rarely get to see that decision. Answer a set of questions about the estate and
                  you get the map: every asset marked probate or non-probate with the statute behind it, the
                  transfer routes that are open, the things that need a professional, and the deadlines.
                  Anything we don't know, we name.
                </p>
                <div className="ax-row ax-hero__cta">
                  <Button
                    variant="onDark"
                    onClick={() => scrollToEl(wizardRef.current)}
                  >
                    Start
                  </Button>
                  <Button variant="onDark" onClick={() => loadSample(samples[0]?.id ?? "")}>
                    See it on a sample case
                  </Button>
                </div>
                <p className="ax-hero__note">
                  {engineLabel
                    ? `Engine: ${engineLabel}. Death dates supported through 2026-12-31.`
                    : "The engine is not reachable from this browser right now. Everything below still works; sample results are labelled as samples."}
                </p>
              </div>

              <FramedCard tone="cyan" className="ax-getback">
                <h4>What you get back.</h4>
                <ul>
                  <li>
                    <StatusGlyph tone="ok" label="" />
                    <span>Every asset marked probate or non-probate, with the statute that decides it.</span>
                  </li>
                  <li>
                    <StatusGlyph tone="ok" label="" />
                    <span>The transfer routes the estate qualifies for, and the ones it is ruled out of.</span>
                  </li>
                  <li>
                    <StatusGlyph tone="wait" label="" />
                    <span>Exactly which facts are still unknown, and what each one is blocking.</span>
                  </li>
                  <li>
                    <StatusGlyph tone="crit" label="" />
                    <span>The points where a form is not enough and a professional is.</span>
                  </li>
                </ul>
              </FramedCard>
            </div>
          </Section>

          {/* ------------------------------------------------------ wizard */}
          <div ref={wizardRef}>
            <Section
              tone="bone"
              title="Tell us about the estate."
              lede="Answer what you know. Anything you skip comes back named, not guessed."
            >
              <Wizard
                draft={draft}
                setDraft={setDraft}
                onSubmit={() => void run(draft, loadedSampleId)}
                busy={busy}
                samples={samples}
                onLoadSample={loadSample}
                focusFact={focusFact}
              />
              {samplesAreLocal && samples.length > 0 && (
                <p className="meta" style={{ marginTop: 16 }}>
                  Sample cases are the ones written into the frozen contract; they load from this build, not
                  from the engine.
                </p>
              )}
            </Section>
          </div>

          {/* ------------------------------------------------------ result */}
          <div ref={resultRef}>
            {busy && (
              <Section tone="paper">
                <p className="lede">Working through the statute…</p>
              </Section>
            )}

            {!busy && outcome && (
              <ResultRegion
                outcome={outcome}
                provenance={provenance}
                offlineDetail={offlineDetail}
                CaseFile={CaseFile}
                onEditFact={editFact}
                onShowSample={showSampleResult}
              />
            )}
          </div>

          {/* ------------------------------------------------------ footer */}
          <footer className="ax-foot">
            <p>
              Independent prototype by Sharique Khatri. Not affiliated with, endorsed by, or connected to
              Alix. Design language referenced for evaluation purposes.
            </p>
            <p>
              Demo only, not legal advice. All cases are fictional. Death dates are supported through
              2026-12-31; past that the engine returns an error rather than a verdict. The engine proves
              consequences of supplied facts, not their truth.
            </p>
            <p>
              The comparison that this work grew out of — one case, two engines — is on the{" "}
              <a href="/evidence">evidence page</a>.
            </p>
          </footer>
        </div>
      </div>
    </div>
  );
}

// ====================================================================
// Result region
// ====================================================================

function ResultRegion({
  outcome,
  provenance,
  offlineDetail,
  CaseFile,
  onEditFact,
  onShowSample,
}: {
  outcome: AssessOutcome;
  provenance: Provenance | null;
  offlineDetail: string | null;
  CaseFile: CaseFileComponent | null;
  onEditFact: (path: string) => void;
  onShowSample: () => void;
}) {
  if (outcome.kind === "unavailable") {
    return (
      <Section tone="paper" title="We could not get an answer.">
        <div className="ax-error">
          <p className="lede" style={{ maxWidth: "62ch" }}>
            The engine did not respond, so there is nothing to show. We will not fill the gap with a guess.
          </p>
          <p className="ax-quiet" style={{ fontSize: 13 }}>{outcome.detail}</p>
          <div className="ax-row" style={{ marginTop: 12 }}>
            <Button variant="primary" onClick={onShowSample}>
              Show a sample result instead
            </Button>
          </div>
        </div>
      </Section>
    );
  }

  if (outcome.kind === "rejected") {
    return (
      <Section tone="paper" title="The engine declined to answer.">
        {provenance === "sample" && <SampleBadge />}
        <FramedCard tone="bone">
          <p style={{ fontSize: 15, maxWidth: "62ch" }}>{outcome.error.detail}</p>
          <p className="ax-error__code atlas-cite" style={{ marginTop: 10 }}>
            error.code = {outcome.error.code}
          </p>
        </FramedCard>
        <p className="ax-field__hint" style={{ marginTop: 16, maxWidth: "62ch" }}>
          This is a structural answer, not a legal one. The law here was compiled from sources fixed at a
          date; asked about something outside them, the engine says so instead of inventing a verdict.
        </p>
        {offlineDetail && (
          <p className="meta" style={{ marginTop: 12 }}>Engine unreachable: {offlineDetail}</p>
        )}
      </Section>
    );
  }

  const a = outcome.assessment;
  return (
    <Section tone="paper">
      <div className="ax-result__head">
        <div>
          <h2>The settlement map.</h2>
          {/* The case-file view states its own provenance; don't say it twice. */}
          {!CaseFile && (
            <p className="meta" style={{ marginTop: 8 }}>
              engine {a.engine} · sources as of {a.snapshot.source_as_of} · deaths supported through{" "}
              {a.snapshot.supported_death_dates_through}
            </p>
          )}
        </div>
        {provenance === "sample" && <SampleBadge inline>Sample result — not a live engine run.</SampleBadge>}
      </div>

      {provenance === "sample" && offlineDetail && (
        <p className="meta" style={{ marginBottom: 20 }}>
          Shown because the engine was unreachable: {offlineDetail}
        </p>
      )}

      {CaseFile ? (
        <CaseFile assessment={a} onEditFact={onEditFact} />
      ) : (
        <BuiltInSummary assessment={a} onEditFact={onEditFact} />
      )}
    </Section>
  );
}

// ====================================================================
// Built-in summary — stands in until the case-file view mounts here
// ====================================================================

function BuiltInSummary({
  assessment: a,
  onEditFact,
}: {
  assessment: SettlementAssessment;
  onEditFact: (path: string) => void;
}) {
  const probate = a.asset_map.filter((x) => x.classification === "probate").length;
  const nonProbate = a.asset_map.filter((x) => x.classification === "non_probate").length;
  const unknown = a.asset_map.filter((x) => x.classification === "unknown").length;

  return (
    <div className="ax-stack-24">
      <div className="ax-summary">
        <FramedCard tone="navy">
          <span className="k">Known probate estate</span>
          <span className="v">{formatUSD(a.probate_estate.known_subtotal_cents)}</span>
          <span className="k">
            {a.probate_estate.status === "known" ? "Complete" : "Partial — some facts are still open"}
          </span>
        </FramedCard>
        <FramedCard tone="bone">
          <span className="k">Assets classified</span>
          <span className="v">
            {probate} / {nonProbate} / {unknown}
          </span>
          <span className="k">probate · non-probate · unknown</span>
        </FramedCard>
        <FramedCard tone="lav">
          <span className="k">Facts still open</span>
          <span className="v">{a.unresolved_facts.length}</span>
          <span className="k">each one named below</span>
        </FramedCard>
      </div>

      <Block title="Every asset, and why.">
        {a.asset_map.map((x) => (
          <div className="ax-list-row" key={x.name}>
            <StatusGlyph
              tone={x.classification === "probate" ? "out" : x.classification === "non_probate" ? "ok" : "wait"}
              label={x.classification.replace("_", " ")}
            />
            <div className="ax-list-row__body">
              <div className="ax-row ax-row--between">
                <span className="ax-list-row__title">{x.name}</span>
                <span className="ax-list-row__title">{formatUSD(x.value_cents)}</span>
              </div>
              <p className="ax-list-row__sub">{x.reason}</p>
              <div className="ax-row" style={{ marginTop: 6 }}>
                <Chip tone={x.classification === "unknown" ? "wait" : x.classification === "probate" ? "out" : "ok"}>
                  {x.classification === "non_probate" ? "outside the estate" : x.classification === "probate" ? "in the estate" : "cannot say yet"}
                </Chip>
                <CitationLine citations={x.citation} />
              </div>
            </div>
          </div>
        ))}
      </Block>

      {a.jurisdictions.map((j) => (
        <Block key={j.code} title={`${j.code} — ${j.role}.`} aside={<Chip tone={j.verdict === "ELIGIBLE" ? "ok" : j.verdict === "INCOMPLETE_INFO" ? "wait" : "out"}>{j.verdict.replace(/_/g, " ").toLowerCase()}</Chip>}>
          {j.routes.map((r) => (
            <div className="ax-list-row" key={r.route}>
              <StatusGlyph tone={ROUTE_STATUS_TONE[r.status]} label={r.status.replace(/_/g, " ")} />
              <div className="ax-list-row__body">
                <div className="ax-row ax-row--between">
                  <span className="ax-list-row__title">{r.label}</span>
                  <Chip tone={ROUTE_STATUS_TONE[r.status]}>{r.status.replace(/_/g, " ")}</Chip>
                </div>
                {r.reasons.map((reason) => (
                  <p className="ax-list-row__sub" key={reason.id}>
                    {reason.text}
                  </p>
                ))}
                <div className="ax-row" style={{ marginTop: 6 }}>
                  {r.forms.map((f) => (
                    <Chip tone="out" key={f}>
                      {f}
                    </Chip>
                  ))}
                  <CitationLine citations={r.citations} />
                </div>
              </div>
            </div>
          ))}
        </Block>
      ))}

      {a.federal.length > 0 && (
        <Block title="Federal.">
          {a.federal.map((f) => (
            <div className="ax-list-row" key={f.item}>
              <StatusGlyph
                tone={f.status === "payable" || f.status === "required" ? "ok" : f.status === "needs_information" ? "wait" : "out"}
                label={f.status.replace(/_/g, " ")}
              />
              <div className="ax-list-row__body">
                <div className="ax-row ax-row--between">
                  <span className="ax-list-row__title">{f.label}</span>
                  <span className="ax-list-row__title">
                    {f.amount_cents != null ? formatUSD(f.amount_cents) : ""}
                  </span>
                </div>
                {f.reasons.map((r) => (
                  <p className="ax-list-row__sub" key={r.id}>
                    {r.text}
                  </p>
                ))}
                <div className="ax-row" style={{ marginTop: 6 }}>
                  <Chip tone={f.status === "needs_information" ? "wait" : "out"}>{f.status.replace(/_/g, " ")}</Chip>
                  <CitationLine citations={f.citations} />
                </div>
              </div>
            </div>
          ))}
        </Block>
      )}

      {a.flags.length > 0 && (
        <Block title="Where a form is not enough.">
          {a.flags.map((f) => (
            <div className="ax-list-row" key={f.id}>
              <StatusGlyph tone={f.severity === "critical" ? "crit" : f.severity === "warning" ? "wait" : "out"} label={f.severity} />
              <div className="ax-list-row__body">
                <div className="ax-row ax-row--between">
                  <span className="ax-list-row__title">{f.title}</span>
                  <Chip tone={f.severity === "critical" ? "crit" : f.severity === "warning" ? "wait" : "out"}>
                    {f.severity}
                  </Chip>
                </div>
                <p className="ax-list-row__sub">{f.detail}</p>
                <p className="ax-list-row__sub">
                  <strong style={{ fontWeight: 500 }}>{f.action}</strong>
                </p>
                <CitationLine citations={f.citation} />
              </div>
            </div>
          ))}
        </Block>
      )}

      {a.deadlines.length > 0 && (
        <Block title="Dates that matter.">
          {a.deadlines.map((d) => (
            <div className="ax-list-row" key={d.id}>
              <StatusGlyph tone={d.status === "computed" ? "ok" : "wait"} label={d.status.replace(/_/g, " ")} />
              <div className="ax-list-row__body">
                <div className="ax-row ax-row--between">
                  <span className="ax-list-row__title">{d.label}</span>
                  <span className="ax-list-row__title">
                    {d.status === "computed" ? formatDate(d.date) : d.status === "awaiting_event" ? "once the estate is opened" : "not yet computable"}
                  </span>
                </div>
                <CitationLine citations={d.citation} />
              </div>
            </div>
          ))}
        </Block>
      )}

      {a.unresolved_facts.length > 0 && (
        <Block title="What is still unknown.">
          <p className="ax-list-row__sub" style={{ marginBottom: 10 }}>
            None of these is a no. Each is a fact the engine refused to assume — go and answer one and the map
            redraws.
          </p>
          <div className="ax-row">
            {a.unresolved_facts.map((p) => (
              <Button key={p} size="sm" onClick={() => onEditFact(p)}>
                {p}
              </Button>
            ))}
          </div>
        </Block>
      )}

      {a.next_actions.length > 0 && (
        <Block title="What to do next.">
          {a.next_actions.map((n) => (
            <div className="ax-list-row" key={n.id}>
              <StatusGlyph tone={n.blocked_by.length > 0 ? "wait" : "ok"} label={n.blocked_by.length > 0 ? "blocked" : "ready"} />
              <div className="ax-list-row__body">
                <span className="ax-list-row__title">{n.label}</span>
                {n.blocked_by.length > 0 && (
                  <p className="ax-list-row__sub">Waiting on {n.blocked_by.join(", ")}</p>
                )}
              </div>
            </div>
          ))}
        </Block>
      )}

      {a.notes.length > 0 && (
        <Block title="Notes.">
          {a.notes.map((n) => (
            <p className="ax-list-row__sub" key={n} style={{ paddingTop: 6 }}>
              {n}
            </p>
          ))}
        </Block>
      )}
    </div>
  );
}

function Block({
  title,
  aside,
  children,
}: {
  title: string;
  aside?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <FramedCard tone="paper">
      <div className="ax-row ax-row--between" style={{ marginBottom: 10 }}>
        <h3 style={{ fontSize: 24 }}>{title}</h3>
        {aside}
      </div>
      {children}
    </FramedCard>
  );
}
