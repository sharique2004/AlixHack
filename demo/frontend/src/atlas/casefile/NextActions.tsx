/**
 * Case file — next actions, and the engine's own notes.
 *
 * An action that is blocked says what is blocking it, and the block is a fact
 * you can answer from here.
 */

import type { AssetClassification, NextAction } from "../types";
import { Empty, FactList, SectionHead } from "./primitives";
import { dedupe, pluralize } from "./format";

export function NextActions(props: {
  actions: NextAction[];
  assets: AssetClassification[];
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const ready = props.actions.filter((x) => x.blocked_by.length === 0);
  return (
    <section className="atlas-section atlas-section--paper cf-section cf-next">
      <SectionHead
        eyebrow="Next"
        title="What to do now."
        lede={
          props.actions.length === 0
            ? "Nothing is queued against this case yet."
            : `${ready.length} of ${props.actions.length} ${pluralize(props.actions.length, "step", "steps")} can be started today.`
        }
      />
      {props.actions.length === 0 ? (
        <Empty
          title="No steps queued."
          body="Once a route is open or a fact is answered, the work it implies is listed here."
        />
      ) : (
        <ol className="cf-next__list">
          {props.actions.map((x, i) => {
            const blocked = dedupe(x.blocked_by);
            return (
              <li key={x.id} className={`cf-step${blocked.length > 0 ? " cf-step--blocked" : ""}`}>
                <span className="cf-step__n">{i + 1}</span>
                <div className="cf-step__body">
                  <div className="cf-step__label">{x.label}</div>
                  <div className="cf-step__id mono">{x.id}</div>
                  {blocked.length > 0 ? (
                    <div className="cf-step__blocked">
                      <span className="cf-step__blockedLead">
                        Blocked until {pluralize(blocked.length, "this is", "these are")} answered
                      </span>
                      <FactList
                        paths={blocked}
                        assets={props.assets}
                        onEditFact={props.onEditFact}
                      />
                    </div>
                  ) : (
                    <div className="cf-step__ready">Ready to start.</div>
                  )}
                </div>
              </li>
            );
          })}
        </ol>
      )}
    </section>
  );
}

export function Notes(props: { notes: string[] }): JSX.Element | null {
  if (props.notes.length === 0) return null;
  return (
    <section className="cf-notes">
      <h3 className="cf-h cf-h--sm">Notes from the engine.</h3>
      <ul>
        {props.notes.map((n, i) => (
          <li key={i}>{n}</li>
        ))}
      </ul>
    </section>
  );
}
