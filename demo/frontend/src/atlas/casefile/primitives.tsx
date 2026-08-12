/**
 * Case file — local primitives.
 *
 * Deliberately self-contained: this module imports only design tokens and the
 * contract types, never the shared primitive kit, so the case file renders on
 * its own. Styling leans on the token classes in design/tokens.css.
 */

import type { ReactNode } from "react";
import type { AssetClassification, Citation, FactPath } from "../types";
import { describeFact } from "./format";

export type Tone = "ok" | "wait" | "out" | "crit" | "lav" | "onDark";

export function Chip(props: { tone: Tone; children: ReactNode }): JSX.Element {
  return <span className={`atlas-chip chip--${props.tone}`}>{props.children}</span>;
}

/** Every legal claim on screen carries its citation, inline and in mono. */
export function Cite(props: { citation: Citation | null }): JSX.Element | null {
  const c = props.citation;
  if (!c) return null;
  if (c.url) {
    return (
      <a className="atlas-cite cf-cite" href={c.url} target="_blank" rel="noreferrer">
        {c.label}
      </a>
    );
  }
  return <span className="atlas-cite cf-cite">{c.label}</span>;
}

export function Cites(props: { citations: Citation[] }): JSX.Element | null {
  if (props.citations.length === 0) return null;
  return (
    <div className="cf-cites">
      {props.citations.map((c, i) => (
        <Cite key={`${c.label}-${i}`} citation={c} />
      ))}
    </div>
  );
}

/**
 * A missing fact. Interactive only when the host actually gave us a handler —
 * we never render an affordance that does nothing.
 */
export function FactButton(props: {
  path: FactPath;
  assets?: AssetClassification[];
  onEditFact?: (path: string) => void;
  tone?: "wait" | "quiet";
}): JSX.Element {
  const d = describeFact(props.path, props.assets ?? []);
  const tone = props.tone ?? "wait";
  const live = Boolean(props.onEditFact);
  const body = (
    <>
      <span className="cf-fact__label">
        {d.owner ? <span className="cf-fact__owner">{d.owner} · </span> : null}
        {d.label}
        {live ? <span className="cf-fact__go" aria-hidden="true">→</span> : null}
      </span>
      <span className="cf-fact__path mono">{d.path}</span>
    </>
  );
  if (!props.onEditFact) {
    return <span className={`cf-fact cf-fact--${tone}`}>{body}</span>;
  }
  return (
    <button
      type="button"
      className={`cf-fact cf-fact--${tone} cf-fact--live`}
      onClick={() => props.onEditFact?.(props.path)}
      aria-label={`Answer: ${d.owner ? `${d.owner} — ` : ""}${d.label}`}
    >
      {body}
    </button>
  );
}

export function FactList(props: {
  paths: FactPath[];
  assets?: AssetClassification[];
  onEditFact?: (path: string) => void;
  tone?: "wait" | "quiet";
}): JSX.Element | null {
  if (props.paths.length === 0) return null;
  return (
    <div className="cf-facts">
      {props.paths.map((p) => (
        <FactButton
          key={p}
          path={p}
          assets={props.assets}
          onEditFact={props.onEditFact}
          tone={props.tone}
        />
      ))}
    </div>
  );
}

/** Section masthead: serif title, one plain sentence of orientation. */
export function SectionHead(props: {
  eyebrow: string;
  title: string;
  lede?: string;
  right?: ReactNode;
  onDark?: boolean;
}): JSX.Element {
  return (
    <header className={`cf-head${props.onDark ? " cf-head--onDark" : ""}`}>
      <div>
        <div className="cf-eyebrow">{props.eyebrow}</div>
        <h2 className="cf-h cf-h--lg">{props.title}</h2>
        {props.lede ? <p className="cf-lede">{props.lede}</p> : null}
      </div>
      {props.right ? <div className="cf-head__right">{props.right}</div> : null}
    </header>
  );
}

/** The Alix framed card: white 6px frame around a solid inner block. */
export function Framed(props: {
  inner: "navy" | "bone" | "lav" | "cyan" | "paper" | "wait" | "crit";
  className?: string;
  children: ReactNode;
}): JSX.Element {
  return (
    <div className={`atlas-framed cf-framed${props.className ? ` ${props.className}` : ""}`}>
      <div className={`inner inner--${props.inner}`}>{props.children}</div>
    </div>
  );
}

/** Designed empty state — never a blank region. */
export function Empty(props: { title: string; body: string }): JSX.Element {
  return (
    <div className="cf-empty">
      <div className="cf-empty__title">{props.title}</div>
      <p className="cf-empty__body">{props.body}</p>
    </div>
  );
}

/** A reason line from the engine, with its stable id kept checkable. */
export function Reasons(props: { reasons: { id: string; text: string }[] }): JSX.Element | null {
  if (props.reasons.length === 0) return null;
  return (
    <ul className="cf-reasons">
      {props.reasons.map((r) => (
        <li key={r.id}>
          <span className="cf-reasons__text">{r.text}</span>
          <span className="cf-reasons__id mono">{r.id}</span>
        </li>
      ))}
    </ul>
  );
}
