/* Minimal pathname router — no dependencies, and deliberately not a SPA router.

   The two pages carry stylesheets that both define `:root` custom properties
   under the same names (`--ink`, `--blue`, …). A static import would hoist both
   and let the loser win at random, so each route dynamically imports only its
   own CSS and cross-route links are ordinary full page loads.

     /          → Atlas, the settlement map
     /evidence  → the original LLM-vs-Lean comparison, unchanged
*/

import React from "react";
import ReactDOM from "react-dom/client";

const root = ReactDOM.createRoot(document.getElementById("root")!);
const path = window.location.pathname.replace(/\/+$/, "") || "/";

async function boot() {
  if (path === "/evidence") {
    await import("./styles.css");
    const { default: Evidence } = await import("./App");
    root.render(
      <React.StrictMode>
        <Evidence />
      </React.StrictMode>,
    );
    return;
  }

  await import("./atlas/design/atlas.css");
  const { default: Atlas } = await import("./atlas/App");
  document.title = "Atlas — a settlement map for a simple estate";
  root.render(
    <React.StrictMode>
      <Atlas />
    </React.StrictMode>,
  );
}

void boot();
