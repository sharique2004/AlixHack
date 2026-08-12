/**
 * Case file — what we still don't know.
 *
 * The engine's precision about its own ignorance is the product. Each open fact
 * is shown with exactly what it unblocks, and is answerable in place.
 */

import type { SettlementAssessment } from "../types";
import { Empty, Framed, SectionHead } from "./primitives";
import { capitalize, countWord, describeFact, whatWaitsOn } from "./format";

export function Unknowns(props: {
  assessment: SettlementAssessment;
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const a = props.assessment;
  const facts = a.unresolved_facts;
  const n = facts.length;

  return (
    <section className="atlas-section atlas-section--navy cf-section cf-unknowns">
      <SectionHead
        onDark
        eyebrow="Open questions"
        title={
          n === 0
            ? "Nothing is outstanding."
            : n === 1
              ? "One fact is still open."
              : `${capitalize(countWord(n))} facts are still open.`
        }
        lede={
          n === 0
            ? "Every fact this assessment depends on has been supplied. No conclusion on this page rests on an assumption."
            : "None of these were guessed at, defaulted to no, or quietly rounded away. Each one is listed with exactly what it is holding up."
        }
      />
      {n === 0 ? (
        <Empty
          title="No open facts."
          body="The assessment above stands on supplied facts alone."
        />
      ) : (
        <div className="cf-unknowns__grid">
          {facts.map((path) => {
            const d = describeFact(path, a.asset_map);
            const waiting = whatWaitsOn(a, path);
            const inner = (
              <>
                {d.owner ? <div className="cf-ask__owner">{d.owner}</div> : null}
                <div className="cf-h cf-h--sm cf-ask__label">{d.label}</div>
                <div className="cf-ask__path mono">{path}</div>
                {waiting.length > 0 ? (
                  <div className="cf-ask__waiting">
                    <div className="cf-ask__waitingLead">Holding up</div>
                    <ul>
                      {waiting.map((w) => (
                        <li key={w}>{w}</li>
                      ))}
                    </ul>
                  </div>
                ) : null}
                {props.onEditFact ? (
                  <span className="cf-ask__cta">Answer this →</span>
                ) : null}
              </>
            );

            return (
              <Framed key={path} inner="wait" className="cf-ask">
                {props.onEditFact ? (
                  <button
                    type="button"
                    className="cf-ask__btn"
                    onClick={() => props.onEditFact?.(path)}
                  >
                    {inner}
                  </button>
                ) : (
                  inner
                )}
              </Framed>
            );
          })}
        </div>
      )}
    </section>
  );
}
