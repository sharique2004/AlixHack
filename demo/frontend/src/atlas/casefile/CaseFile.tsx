/**
 * Case file — one screen.
 *
 * Three things, in the order a person actually needs them:
 *   1. the answer          — what happens to this estate, in one sentence
 *   2. where the money goes — two lists, one row per asset
 *   3. what's left to do   — unknowns, flags, dates, folded into one block
 *
 * Everything else the engine returns (every route, the federal items, the
 * engine's own notes) sits behind one disclosure. It is available, not shouted.
 *
 *   <CaseFile assessment={assessment} onEditFact={(path) => …} />
 */

import type { AssetClassification, SettlementAssessment } from "../types";
import { formatDate, formatUSD } from "../types";
import { describeFact, splitEstate } from "./format";
import "./casefile.css";

/** The one sentence at the top. Derived only from what the engine reported. */
function headline(a: SettlementAssessment): { answer: string; detail: string | null } {
  const FALLBACKS = ["ca_formal_probate_or_other", "fl_formal_administration"];
  for (const j of a.jurisdictions) {
    const win = j.routes.find((r) => r.status === "qualifies" && !FALLBACKS.includes(r.route));
    if (win) {
      return {
        answer: `${win.label}.`,
        detail: [j.code, win.citations[0]?.label, win.forms.join(", ")]
          .filter(Boolean)
          .join(" · "),
      };
    }
  }
  if (a.unresolved_facts.length > 0) {
    const n = a.unresolved_facts.length;
    return {
      answer: n === 1 ? "One fact still decides this." : `${n} facts still decide this.`,
      detail: "Nothing below is assumed. Fill these in and the answer resolves.",
    };
  }
  return { answer: "Formal probate is required.", detail: "No simplified route is open." };
}

function AssetRow(props: { asset: AssetClassification }): JSX.Element {
  const a = props.asset;
  return (
    <li className="cf2-row">
      <span className="cf2-row__name">{a.name}</span>
      <span className="cf2-row__val">{formatUSD(a.value_cents)}</span>
    </li>
  );
}

function Column(props: {
  title: string;
  total: number | null;
  assets: AssetClassification[];
  /** Surface, named by meaning rather than by position, so the columns can be
      ordered to match the figures above without the tints following along. */
  tone: "probate" | "outside" | "wait";
}): JSX.Element | null {
  if (props.assets.length === 0) return null;
  return (
    <div className={`cf2-col cf2-col--${props.tone}`}>
      <div className="cf2-col__head">
        <span>{props.title}</span>
        <span className="cf2-col__total">{formatUSD(props.total)}</span>
      </div>
      <ul className="cf2-list">
        {props.assets.map((a) => (
          <AssetRow key={a.name} asset={a} />
        ))}
      </ul>
    </div>
  );
}

export function CaseFile(props: {
  assessment: SettlementAssessment;
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const a = props.assessment;
  const split = splitEstate(a.asset_map);
  const { answer, detail } = headline(a);
  const critical = a.flags.filter((f) => f.severity === "critical");
  // Chronological. The engine emits deadlines grouped by rule, which is the
  // wrong order for a list whose entire job is "what comes next".
  const dated = a.deadlines
    .filter((d) => d.status === "computed" && d.date)
    .sort((x, y) => {
      const k = (d: typeof x) => (d.date!.year * 10000) + (d.date!.month * 100) + d.date!.day;
      return k(x) - k(y);
    });

  return (
    <div className="atlas cf2">
      {/* 1 — the answer. The three numbers are the point of the page, so they
             get the size: a tiny grey run-on line whispered the one thing a
             reader is here for. */}
      <section className="cf2-answer">
        <h1>{answer}</h1>
        {detail ? <p className="cf2-answer__detail">{detail}</p> : null}
        {a.asset_map.length > 0 || a.unresolved_facts.length > 0 ? (
          <dl className="cf2-figs">
            <div className="cf2-fig">
              <dt>Through probate</dt>
              <dd>{formatUSD(a.probate_estate.known_subtotal_cents)}</dd>
            </div>
            <div className="cf2-fig">
              <dt>Passes outside it</dt>
              <dd>{formatUSD(split.nonProbateKnownCents)}</dd>
            </div>
            {a.unresolved_facts.length > 0 ? (
              <div className="cf2-fig cf2-fig--wait">
                <dt>Still unknown</dt>
                <dd>{a.unresolved_facts.length}</dd>
              </div>
            ) : null}
          </dl>
        ) : null}
      </section>

      {/* 2 — where the money goes. Nothing to show before any asset is entered. */}
      {a.asset_map.length > 0 ? (
      <section className="cf2-block">
        <h2>Where the money goes.</h2>
        {/* Same order as the figures above — three concepts, one order. */}
        <div className="cf2-cols">
          <Column
            title="Through probate"
            total={split.probateKnownCents}
            assets={split.probate}
            tone="probate"
          />
          <Column
            title="Passes outside probate"
            total={split.nonProbateKnownCents}
            assets={split.nonProbate}
            tone="outside"
          />
          <Column
            title="Not yet placed"
            total={split.unknownKnownCents}
            assets={split.unknown}
            tone="wait"
          />
        </div>
      </section>
      ) : null}

      {/* 3 — what's left to do */}
      {critical.length > 0 || a.unresolved_facts.length > 0 || dated.length > 0 ? (
        <section className="cf2-block">
          <h2>What's left.</h2>

          {critical.map((f) => (
            <div key={f.id} className="cf2-item cf2-item--crit">
              <strong>{f.title}</strong>
              <span>{f.action}</span>
            </div>
          ))}

          {/* Open questions and dates are different kinds of thing — one is a
              question you answer, the other is a day that arrives. Rendering
              them as one undifferentiated list made both harder to read. */}
          {a.unresolved_facts.length > 0 ? (
            <div className="cf2-group">
              <h3 className="cf2-group__label">
                Questions that would resolve this
                <span>{a.unresolved_facts.length}</span>
              </h3>
              {a.unresolved_facts.slice(0, 6).map((path) => {
                const d = describeFact(path, a.asset_map);
                const owner = d.owner && d.owner !== "The decedent" ? d.owner : "";
                return (
                  <button
                    key={path}
                    type="button"
                    className="cf2-ask"
                    onClick={() => props.onEditFact?.(path)}
                  >
                    {/* Lead with the question. The owner only earns a line when
                        it names a specific asset. */}
                    <span className="cf2-ask__q">{d.label}</span>
                    {owner ? <span className="cf2-ask__owner">{owner}</span> : null}
                    <span className="cf2-ask__go" aria-hidden="true">→</span>
                  </button>
                );
              })}
            </div>
          ) : null}

          {dated.length > 0 ? (
            <div className="cf2-group">
              <h3 className="cf2-group__label">
                Dates that arrive on their own
                <span>{dated.length}</span>
              </h3>
              {dated.map((d) => (
                <div key={d.id} className="cf2-date">
                  <time className="cf2-date__when">{formatDate(d.date)}</time>
                  <span className="cf2-date__what">{d.label}</span>
                </div>
              ))}
            </div>
          ) : null}
        </section>
      ) : null}

      {/* everything else — available, not shouted */}
      <details className="cf2-more">
        <summary>Every route, the federal items, and the engine's notes</summary>
        <div className="cf2-more__body">
          {a.jurisdictions.map((j) => (
            <div key={`${j.code}-${j.role}`} className="cf2-more__group">
              <h3>
                {j.code} <span>{j.role}</span>
              </h3>
              {j.routes.map((r) => (
                <div key={r.route} className="cf2-more__row">
                  <span className={`cf2-dot cf2-dot--${r.status}`} aria-hidden="true" />
                  <span className="cf2-more__label">{r.label}</span>
                  <span className="cf2-more__cite mono">{r.citations[0]?.label ?? ""}</span>
                </div>
              ))}
            </div>
          ))}
          {a.federal.length > 0 ? (
            <div className="cf2-more__group">
              <h3>Federal</h3>
              {a.federal.map((f) => (
                <div key={f.item} className="cf2-more__row">
                  <span className="cf2-more__label">{f.label}</span>
                  <span className="cf2-more__cite mono">{f.status.replace(/_/g, " ")}</span>
                </div>
              ))}
            </div>
          ) : null}
          {a.notes.length > 0 ? (
            <div className="cf2-more__group">
              <h3>Notes</h3>
              {a.notes.map((n, i) => (
                <p key={i} className="cf2-more__note">
                  {n}
                </p>
              ))}
            </div>
          ) : null}
        </div>
      </details>

      <footer className="cf2-footer">
        <p>
          This proves the consequences of the facts supplied. It does not verify that those
          facts are true, and it is not legal advice.
        </p>
        <p>
          Independent prototype by Sharique Khatri. Not affiliated with, endorsed by, or
          connected to Alix.
        </p>
      </footer>
    </div>
  );
}

export default CaseFile;
