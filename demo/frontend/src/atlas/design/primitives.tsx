/* Atlas primitive kit — the Alix design language as components.
   Everything here composes the classes in tokens.css; nothing here restates the
   palette. Two rules are load-bearing and are enforced by the API shapes below:

   1. Every input can answer "Not sure", and answering it emits `null`. Unknown is
      the product's thesis, so it is an ordinary, calm option — never a failure.
   2. Money is entered in dollars and emitted as integer cents. No floats. */

import { useCallback, useEffect, useId, useRef, useState } from "react";
import type { CivilDate, Citation } from "../types";

// ---------------------------------------------------------------- money

/** Dollars typed by a human → integer cents. `null` for empty; `undefined` for
    text we refuse to guess at (the caller shows a quiet hint instead). */
export function dollarsToCents(raw: string): number | null | undefined {
  const s = raw.replace(/[$,\s]/g, "");
  if (s === "") return null;
  if (!/^\d+(\.\d{0,2})?$/.test(s)) return undefined;
  const [whole, frac = ""] = s.split(".");
  return Number(whole) * 100 + Number((frac + "00").slice(0, 2));
}

/** Integer cents → the string we put back in the input. Never lossy. */
export function centsToDollars(cents: number | null | undefined): string {
  if (cents === null || cents === undefined) return "";
  const whole = Math.trunc(cents / 100);
  const frac = cents % 100;
  const grouped = whole.toLocaleString("en-US");
  return frac === 0 ? grouped : `${grouped}.${String(frac).padStart(2, "0")}`;
}

/** Scroll that honours `prefers-reduced-motion` — the CSS media block in
    tokens.css can flatten transitions but not a smooth scroll. */
export function scrollToEl(el: Element | null | undefined, block: ScrollLogicalPosition = "start") {
  if (!el) return;
  const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
  el.scrollIntoView({ block, behavior: reduce ? "auto" : "smooth" });
}

// ---------------------------------------------------------------- primitives

export type ChipTone = "ok" | "wait" | "out" | "crit" | "lav" | "onDark";
export type InnerTone = "navy" | "bone" | "lav" | "cyan" | "paper";
export type SectionTone = "ink" | "navy" | "bone" | "paper";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "onDark" | "quiet";
  size?: "md" | "sm";
}

export function Button({
  variant = "secondary",
  size = "md",
  className = "",
  type = "button",
  ...rest
}: ButtonProps) {
  const cls = ["atlas-btn", `atlas-btn--${variant}`, size === "sm" ? "atlas-btn--sm" : "", className]
    .filter(Boolean)
    .join(" ");
  return <button type={type} className={cls} {...rest} />;
}

export function Chip({
  tone = "lav",
  children,
  className = "",
}: {
  tone?: ChipTone;
  children: React.ReactNode;
  className?: string;
}) {
  return <span className={`atlas-chip chip--${tone} ${className}`}>{children}</span>;
}

/** The signature Alix pattern: a white 6px frame around a solid inner card. */
export function FramedCard({
  tone = "bone",
  className = "",
  innerClassName = "",
  children,
}: {
  tone?: InnerTone;
  className?: string;
  innerClassName?: string;
  children: React.ReactNode;
}) {
  return (
    <div className={`atlas-framed ${className}`}>
      <div className={`inner inner--${tone} ${innerClassName}`}>{children}</div>
    </div>
  );
}

/** A major section: one solid rounded block on the white page. */
export function Section({
  tone = "paper",
  title,
  lede,
  actions,
  id,
  className = "",
  children,
}: {
  tone?: SectionTone;
  title?: React.ReactNode;
  lede?: React.ReactNode;
  actions?: React.ReactNode;
  id?: string;
  className?: string;
  children?: React.ReactNode;
}) {
  return (
    <section id={id} className={`atlas-section atlas-section--${tone} ${className}`}>
      {(title || actions) && (
        <div className="ax-row ax-row--between" style={{ marginBottom: lede ? 12 : 24 }}>
          {title ? <h2>{title}</h2> : <span />}
          {actions}
        </div>
      )}
      {lede && <p className="lede" style={{ maxWidth: "62ch", marginBottom: 24 }}>{lede}</p>}
      {children}
    </section>
  );
}

/** Status is never carried by color alone — each tone has its own shape. */
export function StatusGlyph({ tone, label }: { tone: ChipTone; label: string }) {
  const color =
    tone === "ok" ? "var(--ok-fg)" :
    tone === "wait" ? "var(--wait-fg)" :
    tone === "crit" ? "var(--crit-fg)" :
    "var(--ink-40)";
  return (
    <span className="ax-glyph" role="img" aria-label={label} title={label}>
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
        {tone === "ok" && (
          <path d="M3 7.4L5.8 10L11 4" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
        )}
        {tone === "wait" && (
          <>
            <circle cx="7" cy="7" r="5.2" stroke={color} strokeWidth="1.4" strokeDasharray="2.2 2.2" />
            <circle cx="7" cy="7" r="1.5" fill={color} />
          </>
        )}
        {tone === "crit" && (
          <>
            <path d="M7 2L12.5 11.5H1.5L7 2Z" stroke={color} strokeWidth="1.4" strokeLinejoin="round" />
            <path d="M7 6V8.4" stroke={color} strokeWidth="1.4" strokeLinecap="round" />
            <circle cx="7" cy="10.1" r="0.75" fill={color} />
          </>
        )}
        {(tone === "out" || tone === "lav" || tone === "onDark") && (
          <path d="M3.2 7H10.8" stroke={color} strokeWidth="1.6" strokeLinecap="round" />
        )}
      </svg>
    </span>
  );
}

/** Doctrine 4: no legal claim renders without the statute it came from. */
export function CitationLine({
  citations,
  className = "",
}: {
  citations: Citation | Citation[] | null | undefined;
  className?: string;
}) {
  const list = citations == null ? [] : Array.isArray(citations) ? citations : [citations];
  if (list.length === 0) return null;
  return (
    <span className={`atlas-cite ${className}`}>
      {list.map((c, i) => (
        <span key={`${c.label}-${i}`}>
          {i > 0 && " · "}
          {c.url ? (
            <a href={c.url} target="_blank" rel="noreferrer noopener" style={{ color: "inherit" }}>
              {c.label}
            </a>
          ) : (
            c.label
          )}
        </span>
      ))}
    </span>
  );
}

/** Plain-English gloss for a term a grieving non-lawyer has never met.
    The bubble stays in the accessibility tree via aria-describedby even when
    it is visually hidden, so keyboard and screen-reader users get the text. */
export function Tooltip({ label, children }: { label?: string; children: React.ReactNode }) {
  const id = useId();
  const [open, setOpen] = useState(false);
  const wrap = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open]);

  return (
    <span
      className="ax-tt"
      ref={wrap}
      onMouseEnter={() => setOpen(true)}
      onMouseLeave={() => setOpen(false)}
    >
      <button
        type="button"
        className="ax-tt__btn"
        aria-label={label ?? "What does this mean?"}
        aria-describedby={id}
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
      >
        ?
      </button>
      <span id={id} role="note" className={`ax-tt__bubble ${open ? "is-open" : ""}`}>
        {children}
      </span>
    </span>
  );
}

// ---------------------------------------------------------------- fields

export function Field({
  label,
  hint,
  explain,
  htmlFor,
  factPath,
  unknown,
  span,
  children,
}: {
  label: string;
  hint?: React.ReactNode;
  /** Plain-English gloss shown behind the "?" affordance. */
  explain?: React.ReactNode;
  htmlFor?: string;
  factPath?: string;
  unknown?: boolean;
  span?: boolean;
  children: React.ReactNode;
}) {
  return (
    <div className={`ax-field ${span ? "ax-span-2" : ""}`} data-fact={factPath}>
      <div className="ax-field__top">
        {htmlFor ? (
          <label className="ax-field__label" htmlFor={htmlFor}>
            {label}
          </label>
        ) : (
          <span className="ax-field__label">{label}</span>
        )}
        {explain && <Tooltip label={`What does "${label}" mean?`}>{explain}</Tooltip>}
        {/* Amber, because unknown is amber here — but as a quiet word rather
            than a badge. A first-run form is nearly all unknown, and a wall of
            badges would read as a wall of errors. */}
        {unknown && <span className="ax-field__unknown">not answered yet</span>}
      </div>
      {hint && <p className="ax-field__hint">{hint}</p>}
      {children}
    </div>
  );
}

export function TextInput({
  id,
  value,
  onChange,
  placeholder,
  ...rest
}: {
  id: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
} & Omit<React.InputHTMLAttributes<HTMLInputElement>, "id" | "value" | "onChange">) {
  return (
    <input
      id={id}
      className="atlas-input"
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      {...rest}
    />
  );
}

export interface Choice<T extends string> {
  value: T;
  label: string;
  /** One plain sentence. Assume the reader has never seen the term. */
  explain?: string;
}

const UNKNOWN = "__not_sure__";
const NOT_SURE_EXPLAIN = "We record this as unknown and tell you exactly which conclusions it blocks.";

/** A native select with "Not sure" as an ordinary, first-class option. */
export function Select<T extends string>({
  id,
  value,
  options,
  onChange,
  notSureLabel = "Not sure",
}: {
  id: string;
  value: T | null;
  options: Choice<T>[];
  onChange: (v: T | null) => void;
  notSureLabel?: string;
}) {
  return (
    <select
      id={id}
      className="atlas-select"
      value={value ?? UNKNOWN}
      onChange={(e) => onChange(e.target.value === UNKNOWN ? null : (e.target.value as T))}
    >
      {options.map((o) => (
        <option key={o.value} value={o.value}>
          {o.label}
        </option>
      ))}
      <option value={UNKNOWN}>{notSureLabel}</option>
    </select>
  );
}

/** Radio cards, for the choices that need a sentence of explanation each
    (how an asset was titled, what a beneficiary designation is, and so on). */
export function ChoiceGroup<T extends string>({
  id,
  legend,
  value,
  options,
  onChange,
  notSureLabel = "Not sure",
  notSureExplain = NOT_SURE_EXPLAIN,
  layout = "cards",
}: {
  id: string;
  legend: string;
  value: T | null;
  options: Choice<T>[];
  onChange: (v: T | null) => void;
  notSureLabel?: string;
  notSureExplain?: string;
  layout?: "cards" | "pills";
}) {
  const render = (key: string, label: string, explain: string | undefined, checked: boolean, on: () => void, unknown = false) => (
    <label key={key} className={`ax-opt ${unknown ? "ax-opt--unknown" : ""}`}>
      <input type="radio" name={id} value={key} checked={checked} onChange={on} />
      <span>
        {label}
        {layout === "cards" && explain && <em>{explain}</em>}
      </span>
    </label>
  );
  return (
    <fieldset style={{ border: 0, margin: 0, padding: 0 }}>
      <legend className="ax-sr">{legend}</legend>
      <div className={layout === "cards" ? "ax-choice" : "ax-opts"}>
        {options.map((o) => render(o.value, o.label, o.explain, value === o.value, () => onChange(o.value)))}
        {render(UNKNOWN, notSureLabel, notSureExplain, value === null, () => onChange(null), true)}
      </div>
    </fieldset>
  );
}

/** Booleans are tri-state here, because "we don't know" is a real answer. */
export function Toggle({
  id,
  legend,
  value,
  onChange,
  yesLabel = "Yes",
  noLabel = "No",
  notSureLabel = "Not sure",
}: {
  id: string;
  legend: string;
  value: boolean | null;
  onChange: (v: boolean | null) => void;
  yesLabel?: string;
  noLabel?: string;
  notSureLabel?: string;
}) {
  const opt = (key: string, label: string, checked: boolean, on: () => void, unknown = false) => (
    <label key={key} className={`ax-opt ${unknown ? "ax-opt--unknown" : ""}`}>
      <input type="radio" name={id} value={key} checked={checked} onChange={on} />
      <span>{label}</span>
    </label>
  );
  return (
    <fieldset style={{ border: 0, margin: 0, padding: 0 }}>
      <legend className="ax-sr">{legend}</legend>
      <div className="ax-opts">
        {opt("yes", yesLabel, value === true, () => onChange(true))}
        {opt("no", noLabel, value === false, () => onChange(false))}
        {opt(UNKNOWN, notSureLabel, value === null, () => onChange(null), true)}
      </div>
    </fieldset>
  );
}

/** Dollars in, integer cents out. Unparseable text is never guessed at. */
export function MoneyInput({
  id,
  value,
  onChange,
  placeholder = "0",
}: {
  id: string;
  value: number | null;
  onChange: (cents: number | null) => void;
  placeholder?: string;
}) {
  const [raw, setRaw] = useState(() => centsToDollars(value));
  const [bad, setBad] = useState(false);

  // Re-sync when the value is replaced from outside (sample load, reset).
  const lastEmitted = useRef(value);
  useEffect(() => {
    if (value !== lastEmitted.current) {
      lastEmitted.current = value;
      setRaw(centsToDollars(value));
      setBad(false);
    }
  }, [value]);

  const handle = useCallback(
    (next: string) => {
      setRaw(next);
      const cents = dollarsToCents(next);
      if (cents === undefined) {
        setBad(true);
        return;
      }
      setBad(false);
      lastEmitted.current = cents;
      onChange(cents);
    },
    [onChange],
  );

  return (
    <>
      <div className="ax-input-row">
        <span className="ax-money">
          <span className="ax-money__sign" aria-hidden="true">$</span>
          <input
            id={id}
            className="atlas-input"
            inputMode="decimal"
            autoComplete="off"
            value={raw}
            placeholder={placeholder}
            aria-invalid={bad || undefined}
            onChange={(e) => handle(e.target.value)}
            onBlur={() => !bad && setRaw(centsToDollars(dollarsToCents(raw) ?? null))}
          />
        </span>
        <Button
          size="sm"
          onClick={() => {
            setRaw("");
            setBad(false);
            lastEmitted.current = null;
            onChange(null);
          }}
        >
          Not sure
        </Button>
      </div>
      {bad ? (
        <p className="ax-warn">We can only read plain amounts, like 141000 or 141000.50.</p>
      ) : value === null ? (
        <p className="ax-field__hint">Left blank — recorded as unknown, not as zero.</p>
      ) : null}
    </>
  );
}

export function toISO(d: CivilDate | null): string {
  if (!d) return "";
  return `${String(d.year).padStart(4, "0")}-${String(d.month).padStart(2, "0")}-${String(d.day).padStart(2, "0")}`;
}

export function fromISO(s: string): CivilDate | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  return { year: Number(m[1]), month: Number(m[2]), day: Number(m[3]) };
}

export function DateField({
  id,
  value,
  onChange,
}: {
  id: string;
  value: CivilDate | null;
  onChange: (v: CivilDate | null) => void;
}) {
  return (
    <div className="ax-input-row">
      <input
        id={id}
        type="date"
        className="atlas-input"
        value={toISO(value)}
        onChange={(e) => onChange(fromISO(e.target.value))}
      />
      <Button size="sm" onClick={() => onChange(null)}>
        Not sure
      </Button>
    </div>
  );
}

/** Nothing that came out of a fixture may ever look like a live engine result. */
export function SampleBadge({ inline = false, children }: { inline?: boolean; children?: React.ReactNode }) {
  return (
    <p className={`ax-sample ${inline ? "ax-sample--inline" : ""}`}>
      <StatusGlyph tone="wait" label="Sample data" />
      {children ?? "Sample data — written by hand to develop this view. Not a live engine result."}
    </p>
  );
}
