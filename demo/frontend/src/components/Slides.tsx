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
            <span className="slide-kicker">California probate · Small estates</span>
            <h2>
              One legal question.
              <br />
              Two ways to answer it.
            </h2>
            <p className="slide-lead">
              Can this family skip probate? We built both answers to compare them live:
            </p>
            <ul className="slide-points">
              <li>
                <strong>Ask an LLM every time</strong> — Gemini reads the statute for every
                single case
              </li>
              <li>
                <strong>Run the compiled law</strong> — the statute written once into
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
                <strong>It fills the gaps</strong> — unknowns get treated as favorable: in
                our audit it ruled a case <em>eligible</em> while the date of death was
                still unknown
              </li>
              <li>
                <strong>You pay per question, and the answer wobbles</strong> — ~15 s, ~8k
                tokens, ≈ $0.01–0.03 per case — and only <strong>23 of 36 runs</strong>{" "}
                matched the verified answer
              </li>
            </ul>
            <p className="slide-foot">
              Audit method: 3 independent runs on each of 12 cases, graded against the
              statute — full write-up in AUDIT.md
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
                <strong>Deterministic</strong> — same input, same answer, every time:{" "}
                <strong>12/12</strong> on the same audit
              </li>
              <li>
                <strong>Verified</strong> — checked against the statutory predicates on{" "}
                <strong>435,456 cases</strong>, zero mismatches
              </li>
              <li>
                <strong>Instant and free</strong> — ~20 ms of compute, ≈ $0.0000005 per
                case, zero tokens
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
