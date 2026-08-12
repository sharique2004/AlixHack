/* The live "what we still don't know" rail.

   It is deliberately the calmest thing on the page. Amber, never red; a count,
   never a warning; and every entry is a link back to the question that would
   close it. The point is that not knowing is an ordinary, workable state. */

import { Chip, FramedCard, StatusGlyph } from "../design/primitives";
import { STEPS, type OpenFact } from "./model";

export function UnknownRail({
  facts,
  onJump,
}: {
  facts: OpenFact[];
  onJump: (step: number) => void;
}) {
  const grouped = STEPS.map((s, i) => ({ step: i, short: s.short, items: facts.filter((f) => f.step === i) })).filter(
    (g) => g.items.length > 0,
  );

  return (
    <aside className="ax-rail" aria-label="What we still don't know">
      <FramedCard tone="paper" innerClassName="ax-rail__inner">
        <h4>What we still don't know.</h4>
        {facts.length === 0 ? (
          <>
            <p className="ax-rail__count">Nothing is open.</p>
            <p className="ax-rail__none">
              Every answer here is an answer. The engine will not have to hedge on anything.
            </p>
          </>
        ) : (
          <>
            <p className="ax-rail__count">
              <Chip tone="wait">
                <StatusGlyph tone="wait" label="" />
                {facts.length} open
              </Chip>
            </p>
            <p className="ax-rail__none" style={{ marginBottom: 4 }}>
              Nothing here counts as a no. Each one comes back in the result as a named thing to find out.
            </p>
            {grouped.map((g) => (
              <div className="ax-rail__group" key={g.step}>
                <h5>{g.short}</h5>
                <ul>
                  {g.items.map((f) => (
                    <li key={f.path}>
                      <button
                        type="button"
                        className="ax-rail__item"
                        onClick={() => onJump(g.step)}
                        title={f.path}
                      >
                        {f.label}
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </>
        )}
      </FramedCard>
    </aside>
  );
}
