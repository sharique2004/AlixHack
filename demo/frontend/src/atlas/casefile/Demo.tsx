/**
 * Standalone harness for the case file.
 *
 * Renders <CaseFile> against the fixture with a live readout of onEditFact, so
 * the screen can be reviewed — and every fact affordance exercised — without
 * the shell, the intake wizard, or a running engine.
 *
 *   import CaseFileDemo from "./atlas/casefile/Demo";
 *   createRoot(el).render(<CaseFileDemo />);
 */

import { useEffect, useState } from "react";
import { CaseFile } from "./CaseFile";
import { sampleAssessment } from "./sample";

export function CaseFileDemo(): JSX.Element {
  const [lastEdited, setLastEdited] = useState<string | null>(null);

  // Tokens are loaded dynamically: the two stylesheets in this app declare
  // colliding :root custom properties, so each route loads only its own.
  useEffect(() => {
    void import("../design/tokens.css");
  }, []);

  return (
    <div className="atlas">
      <div className="atlas-shell">
        <CaseFile assessment={sampleAssessment} onEditFact={setLastEdited} />
      </div>
      <div
        role="status"
        style={{
          position: "fixed",
          left: "50%",
          bottom: 20,
          transform: "translateX(-50%)",
          background: "var(--ink)",
          color: "var(--paper)",
          borderRadius: 999,
          padding: "9px 18px",
          fontFamily: "var(--mono)",
          fontSize: 12,
          pointerEvents: "none",
        }}
      >
        {lastEdited
          ? `onEditFact("${lastEdited}")`
          : "harness — click any open fact to fire onEditFact"}
      </div>
    </div>
  );
}

export default CaseFileDemo;
