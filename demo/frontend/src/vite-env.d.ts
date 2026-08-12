/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Absolute origin of the settlement engine API, e.g. https://api.atlas.example.com.
      Empty means same-origin (dev proxy, or frontend served by the API host). */
  readonly VITE_API_BASE?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
