/* The intake form.

   One page. Every question is on it, grouped but never gated — you can answer
   the ones you know, skip the rest, and submit from anywhere. The rail keeps a
   running count of what is still open.

   The form owns no case state — App does — so a result view can send the user
   back to a specific fact and the answer they give lands in the same draft. */

import { useEffect, useRef } from "react";
import { Button, scrollToEl } from "../design/primitives";
import type { SampleCase } from "../types";
import { NOT_SURE_PROMISE } from "./copy";
import { openFacts, STEPS, type Draft, type StepProps } from "./model";
import { UnknownRail } from "./UnknownRail";
import { PersonStep } from "./steps/PersonStep";
import { WillStep } from "./steps/WillStep";
import { AssetsStep } from "./steps/AssetsStep";
import { DebtsStep } from "./steps/DebtsStep";
import { FamilyStep } from "./steps/FamilyStep";

/** The five question groups, in the order they appear down the page.
    `review` is dropped: on one page there is nothing left to review to. */
const GROUPS = [
  { key: "person", Body: PersonStep },
  { key: "will", Body: WillStep },
  { key: "assets", Body: AssetsStep },
  { key: "debts", Body: DebtsStep },
  { key: "family", Body: FamilyStep },
] as const;

const sectionId = (i: number) => `ax-group-${GROUPS[i]?.key ?? i}`;

export function Wizard({
  draft,
  setDraft,
  onSubmit,
  busy,
  samples,
  onLoadSample,
  focusFact,
}: {
  draft: Draft;
  setDraft: (d: Draft) => void;
  onSubmit: () => void;
  busy: boolean;
  samples: SampleCase[];
  onLoadSample: (id: string) => void;
  /** A fact path to scroll to and focus, set when a result sends you back.
      The nonce makes asking for the same fact twice a new request. */
  focusFact: { path: string; nonce: number } | null;
}) {
  const panel = useRef<HTMLDivElement>(null);
  const facts = openFacts(draft);

  const props: StepProps = {
    draft,
    update: (patch) => setDraft({ ...draft, ...patch }),
    setDecedent: (patch) => setDraft({ ...draft, decedent: { ...draft.decedent, ...patch } }),
  };

  // Jumping to a fact should land on the question, not near it. Every question
  // is mounted now, so this no longer depends on which group is showing.
  useEffect(() => {
    if (!focusFact) return;
    const el = panel.current?.querySelector<HTMLElement>(
      `[data-fact="${CSS.escape(focusFact.path)}"]`,
    );
    if (!el) return;
    scrollToEl(el, "center");
    const control =
      el.querySelector<HTMLElement>('input:not([type="radio"]), select, textarea') ??
      el.querySelector<HTMLElement>('input[type="radio"]:checked') ??
      el.querySelector<HTMLElement>('input[type="radio"]') ??
      el.querySelector<HTMLElement>("button:not(.ax-tt__btn)");
    control?.focus({ preventScroll: true });
  }, [focusFact]);

  /** The rail still speaks in group indexes; on one page that is a scroll. */
  const jumpTo = (i: number) => {
    const el = document.getElementById(sectionId(i));
    if (el) scrollToEl(el);
  };

  return (
    <>
      {samples.length > 0 && (
        <div className="ax-samples">
          <span className="meta">Or start from a case we already have:</span>
          <div className="ax-row">
            {samples.map((s) => (
              <Button key={s.id} size="sm" onClick={() => onLoadSample(s.id)} title={s.blurb}>
                {s.label}
              </Button>
            ))}
          </div>
        </div>
      )}

      <div className="ax-wizard">
        <div className="ax-panel ax-panel--flow" ref={panel}>
          <p className="ax-field__hint ax-flow__promise">{NOT_SURE_PROMISE}</p>

          {GROUPS.map(({ key, Body }, i) => (
            <section key={key} id={sectionId(i)} className="ax-flow__group">
              <h3 className="ax-flow__title">{STEPS[i].title}</h3>
              <Body {...props} />
            </section>
          ))}

          <div className="ax-flow__foot">
            <Button variant="primary" onClick={onSubmit} disabled={busy}>
              {busy ? "Working…" : "Get the settlement map"}
            </Button>
            <span className="meta">
              {facts.length === 0
                ? "Nothing left open."
                : `${facts.length} question${facts.length === 1 ? "" : "s"} still open — that's fine, they come back named.`}
            </span>
          </div>
        </div>

        <UnknownRail facts={facts} onJump={jumpTo} />
      </div>
    </>
  );
}
