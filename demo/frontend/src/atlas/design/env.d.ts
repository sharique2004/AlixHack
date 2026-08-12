/* Minimal typing for Vite's `import.meta.glob`.
   `atlas/App.tsx` uses it to mount agent UI-B's case-file view only if that
   module is actually present, so the app builds and renders either way.
   We declare the one member we use rather than referencing `vite/client`,
   whose own `declare module "*.css"` would collide with `./css.d.ts`. */

interface ImportMeta {
  readonly glob: (pattern: string) => Record<string, () => Promise<unknown>>;
}
