/* Ambient shim so route-scoped `await import("…​.css")` type-checks.
   The two stylesheets in this app (`src/styles.css` for the Evidence page and
   `atlas/design/tokens.css` for Atlas) both declare `:root` custom properties
   with colliding names, so each route must load only its own. Static imports
   are hoisted and would load both; dynamic imports keep them apart. */
declare module "*.css";
