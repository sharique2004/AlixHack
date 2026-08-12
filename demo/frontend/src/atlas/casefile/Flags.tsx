/**
 * Case file — the referral layer.
 *
 * Flags are where this tool says "not me". Critical is the only place saturated
 * colour appears on this screen, and it never fires on an unknown alone.
 */

import type { AssetClassification, Flag } from "../types";
import { Chip, Cite, Empty, Framed, SectionHead } from "./primitives";
import type { Tone } from "./primitives";
import { SEVERITY_LABEL, capitalize, countWord, describeFact, orderFlags, pluralize } from "./format";

const SEVERITY_TONE: Record<Flag["severity"], Tone> = {
  critical: "crit",
  warning: "wait",
  info: "out",
};

/* Only critical gets the red tint. Amber is reserved for open questions, so a
   warning sits on the warm neutral and carries its severity in the chip. */
const SEVERITY_INNER: Record<Flag["severity"], "crit" | "bone" | "paper"> = {
  critical: "crit",
  warning: "bone",
  info: "paper",
};

export function FlagCard(props: {
  flag: Flag;
  assets: AssetClassification[];
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const f = props.flag;
  return (
    <Framed inner={SEVERITY_INNER[f.severity]} className={`cf-flag cf-flag--${f.severity}`}>
      <div className="cf-flag__top">
        <Chip tone={SEVERITY_TONE[f.severity]}>{SEVERITY_LABEL[f.severity]}</Chip>
        <span className="cf-flag__id mono">{f.id}</span>
      </div>

      <h3 className="cf-h cf-h--md cf-flag__title">{f.title}</h3>
      <p className="cf-flag__detail">{f.detail}</p>

      <div className="cf-flag__action">
        <span className="cf-flag__actionLead">Do this</span>
        <span className="cf-flag__actionText">{f.action}</span>
      </div>

      <div className="cf-flag__foot">
        <Cite citation={f.citation} />
        {f.triggered_by.length > 0 ? (
          <div className="cf-flag__trigger">
            <span className="cf-flag__triggerLead">Triggered by</span>
            {f.triggered_by.map((path) => {
              const d = describeFact(path, props.assets);
              const label = d.owner ? `${d.owner} · ${d.label}` : d.label;
              if (!props.onEditFact) {
                return (
                  <span key={path} className="cf-trigger">{label}</span>
                );
              }
              return (
                <button
                  key={path}
                  type="button"
                  className="cf-trigger cf-trigger--live"
                  onClick={() => props.onEditFact?.(path)}
                >
                  {label}
                </button>
              );
            })}
          </div>
        ) : null}
      </div>
    </Framed>
  );
}

export function Flags(props: {
  flags: Flag[];
  assets: AssetClassification[];
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const ordered = orderFlags(props.flags);
  const critical = ordered.filter((f) => f.severity === "critical").length;

  return (
    <section className="atlas-section atlas-section--paper cf-section cf-flags">
      <SectionHead
        eyebrow="Flags"
        title="Where this stops being paperwork."
        lede={
          critical > 0
            ? `${capitalize(countWord(critical))} ${pluralize(critical, "issue needs", "issues need")} a professional before anything is distributed. The rest are context.`
            : "Nothing here needs a professional on these facts. What follows is context worth carrying into the next conversation."
        }
      />
      {ordered.length === 0 ? (
        <Empty
          title="No flags fired."
          body="On the facts supplied, none of the referral rules matched. That is a result, not an absence of checking."
        />
      ) : (
        <div className="cf-flags__list">
          {ordered.map((f) => (
            <FlagCard
              key={f.id}
              flag={f}
              assets={props.assets}
              onEditFact={props.onEditFact}
            />
          ))}
        </div>
      )}
    </section>
  );
}
