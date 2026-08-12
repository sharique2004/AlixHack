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
            <span className="slide-kicker">A deliberately small demo</span>
            <h2>
              Is this estate eligible for
              <br />
              California's simple transfer?
            </h2>
            <p className="slide-lead">
              That is the whole scope. One narrow eligibility check under California
              probate law, small enough to build the answer two ways and compare them
              honestly.
            </p>
            <ul className="slide-points">
              <li>
                <strong>Ask an LLM every time.</strong> Gemini reads the statute fresh for
                every case.
              </li>
              <li>
                <strong>Or run the compiled law.</strong> The same statute, written once as
                proof-checked Lean 4 code.
              </li>
            </ul>
            <p className="slide-foot">
              Real statute (Prob. Code §13100–13650), real proofs (Lean 4,
              machine-checked), real meters (time, tokens, cost)
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
                <strong>The context window is the bottleneck.</strong> Retrieved documents
                have to fit inside it. Whatever gets cut, the model never sees, so it
                misses facts.
              </li>
              <li>
                <strong>It fills the gaps.</strong> When a fact is unknown, the model
                assumes the favorable answer. In our audit it called a case
                <em> eligible</em> while the date of death was still unknown.
              </li>
              <li>
                <strong>You pay for every question, and answers wobble.</strong> Around 15
                seconds, 8,000 tokens and a cent or three per case, and only{" "}
                <strong>23 of 36 runs</strong> matched the verified answer.
              </li>
            </ul>
            <p className="slide-foot">
              Audit method: 3 independent runs on each of 12 cases, graded against the
              statute. Full write-up in AUDIT.md.
            </p>
          </div>
        )}

        {i === 2 && (
          <div className="slide-body">
            <span className="slide-kicker">What we built instead</span>
            <h2>Use the LLM once, to write the code</h2>
            <PipelineCompiled />
            <ul className="slide-points">
              <li>
                <strong>Deterministic.</strong> Same input, same answer, every time.{" "}
                <strong>12 out of 12</strong> on the same audit.
              </li>
              <li>
                <strong>Machine-checked.</strong> <strong>79 lemmas</strong> about the
                statutory predicates are proved every time the code compiles. No unproved
                assumptions.
              </li>
              <li>
                <strong>Instant and nearly free.</strong> About 17 ms of compute and two
                ten-millionths of a dollar per case. Zero tokens.
              </li>
              <li>
                <strong>Honest about its limits.</strong> It refuses dates beyond its
                sources, and a missing fact means asking the family, never guessing.
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
