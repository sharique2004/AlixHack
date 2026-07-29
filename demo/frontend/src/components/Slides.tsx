import { useCallback, useEffect, useState } from "react";

/**
 * The 1-minute pitch deck, shown fullscreen over the app.
 * Three slides; the last one hands off to the live demo.
 */

function PipelineToday() {
  return (
    <div className="slide-pipe" aria-label="Today's pipeline: user info, knowledge graph, documents, LLM context, answer">
      <span className="pipe-node">User's info</span>
      <span className="pipe-arrow">→</span>
      <span className="pipe-node">Knowledge graph</span>
      <span className="pipe-arrow">→</span>
      <span className="pipe-node">Documents</span>
      <span className="pipe-arrow">→</span>
      <span className="pipe-node pipe-node-hot">LLM context window</span>
      <span className="pipe-arrow">→</span>
      <span className="pipe-node">Answer</span>
    </div>
  );
}

function PipelineCompiled() {
  return (
    <div className="slide-pipe" aria-label="New pipeline: statute, LLM authors once, proof-checked Lean 4 code, every case runs the code">
      <span className="pipe-node">Statute</span>
      <span className="pipe-arrow">→</span>
      <span className="pipe-node">LLM authors · once</span>
      <span className="pipe-arrow">→</span>
      <span className="pipe-node pipe-node-good">Lean 4 code · proof-checked</span>
      <span className="pipe-arrow">→</span>
      <span className="pipe-node">Every case runs the code</span>
    </div>
  );
}

interface SlidesProps {
  onClose: () => void;
}

export function Slides({ onClose }: SlidesProps) {
  const [i, setI] = useState(0);
  const last = 2;

  const next = useCallback(() => setI((v) => Math.min(v + 1, last)), []);
  const prev = useCallback(() => setI((v) => Math.max(v - 1, 0)), []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "ArrowRight" || e.key === " " || e.key === "Enter") next();
      else if (e.key === "ArrowLeft") prev();
      else if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [next, prev, onClose]);

  return (
    <div className="slides" role="dialog" aria-modal="true" aria-label="Pitch slides">
      <button type="button" className="slides-close" onClick={onClose} aria-label="Close slides">
        ✕
      </button>

      <div className="slide" onClick={next}>
        {i === 0 && (
          <div className="slide-body">
            <span className="slide-kicker">This demo · one small problem, on purpose</span>
            <h2>
              Is this estate eligible for
              <br />
              California's simple transfer?
            </h2>
            <p className="slide-lead">
              That's the entire scope — one narrow eligibility check under California
              probate law. Small enough to build the answer both ways and compare them
              honestly:
            </p>
            <ul className="slide-points">
              <li>
                <strong>Ask an LLM every time</strong> — Gemini reads the statute for every
                single case
              </li>
              <li>
                <strong>Run the compiled law</strong> — the same statute written once into
                proof-checked Lean 4 code
              </li>
            </ul>
            <p className="slide-foot">
              Real statute (Prob. Code §13100–13650) · real proofs (Lean 4, machine-checked) ·
              real meters (time, tokens, cost)
            </p>
          </div>
        )}

        {i === 1 && (
          <div className="slide-body">
            <span className="slide-kicker">How it works today</span>
            <h2>Every case runs through the LLM</h2>
            <PipelineToday />
            <ul className="slide-points">
              <li>
                <strong>The context window is the bottleneck</strong> — retrieved documents
                must fit inside it, so information gets cut, and the model misses facts it
                was never shown
              </li>
              <li>
                <strong>Unknowns need an explicit contract</strong> — absent facts must stay
                unresolved instead of being filled from plausible assumptions
              </li>
              <li>
                <strong>Every question is a fresh inference</strong> — latency, tokens, and
                cost recur, and sampling can change the answer
              </li>
            </ul>
            <p className="slide-foot">
              The live comparison reports time, tokens, and estimated cost for the current
              case
            </p>
          </div>
        )}

        {i === 2 && (
          <div className="slide-body">
            <span className="slide-kicker">What we built instead</span>
            <h2>Use the LLM once — to write the code</h2>
            <PipelineCompiled />
            <ul className="slide-points">
              <li>
                <strong>Deterministic</strong> — the same typed input executes the same
                decision procedure every time
              </li>
              <li>
                <strong>Verified</strong> — total-case exactness and partial-completion
                soundness are theorem-backed, with executable coverage for all 12 shipped
                samples
              </li>
              <li>
                <strong>No inference tokens</strong> — each answer runs the compiled engine,
                and the panel measures its runtime live
              </li>
              <li>
                <strong>Honest about limits</strong> — refuses dates beyond its sources; a
                missing fact means <em>“ask the family,”</em> never a guess
              </li>
            </ul>
            <p className="slide-close-line">The LLM is the compiler, not the judge.</p>
            <button
              type="button"
              className="btn-dark slide-cta"
              onClick={(e) => {
                e.stopPropagation();
                onClose();
              }}
            >
              Show the demo →
            </button>
          </div>
        )}
      </div>

      <div className="slides-nav">
        <button type="button" onClick={prev} disabled={i === 0} aria-label="Previous slide">
          ←
        </button>
        {[0, 1, 2].map((n) => (
          <span key={n} className={`slide-dot${n === i ? " dot-active" : ""}`} />
        ))}
        <button type="button" onClick={next} disabled={i === last} aria-label="Next slide">
          →
        </button>
      </div>
    </div>
  );
}
