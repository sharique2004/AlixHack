/**
 * Case file — routes by jurisdiction.
 *
 * The domicile state leads; ancillary states are clearly secondary. A route
 * that needs information reads as one question away, never as a refusal.
 */

import type { AssetClassification, JurisdictionReport, RouteReport } from "../types";
import { ROUTE_STATUS_TONE } from "../types";
import { Chip, Cites, Empty, FactList, Framed, Reasons, SectionHead } from "./primitives";
import {
  ROUTE_STATUS_LABEL,
  VERDICT_LABEL,
  capitalize,
  countWord,
  dedupe,
  orderJurisdictions,
  orderRoutes,
  pluralize,
  stateName,
} from "./format";

const VERDICT_TONE = {
  ELIGIBLE: "ok",
  INCOMPLETE_INFO: "wait",
  OTHER_FORM_REQUIRED: "out",
} as const;

export function RouteCard(props: {
  route: RouteReport;
  assets: AssetClassification[];
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const r = props.route;
  const tone = ROUTE_STATUS_TONE[r.status];
  const missing = dedupe(r.missing_facts);
  const inner = r.status === "qualifies" ? "paper" : r.status === "needs_information" ? "wait" : "bone";

  return (
    <Framed inner={inner} className={`cf-route cf-route--${r.status}`}>
      <div className="cf-route__top">
        <div>
          <div className="cf-route__label">{r.label}</div>
          <div className="cf-route__id mono">{r.route}</div>
        </div>
        <Chip tone={tone}>{ROUTE_STATUS_LABEL[r.status]}</Chip>
      </div>

      {r.status === "needs_information" ? (
        <div className="cf-route__ask">
          {missing.length === 0
            ? "Open — one or more facts are still outstanding."
            : missing.length === 1
              ? "One question away."
              : `${capitalize(countWord(missing.length))} questions away.`}
        </div>
      ) : null}

      <Reasons reasons={r.reasons} />

      {missing.length > 0 ? (
        <FactList paths={missing} assets={props.assets} onEditFact={props.onEditFact} />
      ) : null}

      <div className="cf-route__foot">
        {r.forms.length > 0 ? (
          <div className="cf-forms">
            <span className="cf-forms__lead">
              {pluralize(r.forms.length, "Court form", "Court forms")}
            </span>
            {r.forms.map((f) => (
              <span key={f} className="cf-forms__item mono">{f}</span>
            ))}
          </div>
        ) : null}
        <Cites citations={r.citations} />
      </div>
    </Framed>
  );
}

export function JurisdictionPanel(props: {
  jurisdiction: JurisdictionReport;
  assets: AssetClassification[];
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const j = props.jurisdiction;
  const ancillary = j.role === "ancillary";
  const routes = orderRoutes(j.routes);

  return (
    <section className={`cf-jur${ancillary ? " cf-jur--ancillary" : ""}`}>
      <header className="cf-jur__head">
        <div className="cf-jur__title">
          <span className="cf-jur__code">{j.code}</span>
          <div>
            <h3 className="cf-h cf-h--md">{stateName(j.code)}</h3>
            <div className="cf-jur__role">
              {ancillary
                ? "Ancillary — property sits here, the estate is administered elsewhere."
                : "State of domicile — the primary proceeding."}
            </div>
          </div>
        </div>
        <div className="cf-jur__verdict">
          <Chip tone={VERDICT_TONE[j.verdict]}>{VERDICT_LABEL[j.verdict]}</Chip>
          <div className="cf-jur__verdictId mono">{j.verdict}</div>
        </div>
      </header>

      {routes.length === 0 ? (
        <Empty
          title="No routes evaluated here."
          body="This jurisdiction is on the record, but no transfer route has been assessed against these facts."
        />
      ) : (
        <div className="cf-jur__routes">
          {routes.map((r) => (
            <RouteCard
              key={r.route}
              route={r}
              assets={props.assets}
              onEditFact={props.onEditFact}
            />
          ))}
        </div>
      )}
    </section>
  );
}

export function Jurisdictions(props: {
  jurisdictions: JurisdictionReport[];
  assets: AssetClassification[];
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const ordered = orderJurisdictions(props.jurisdictions);
  return (
    <section className="atlas-section atlas-section--bone cf-section cf-jurs">
      <SectionHead
        eyebrow="Routes"
        title="What each state allows."
        lede="Every route is evaluated independently against the same facts. A route is only ruled out when a known fact rules it out — never because something is missing."
      />
      {ordered.length === 0 ? (
        <Empty
          title="No jurisdiction on file."
          body="Once a state of domicile is on the record, its transfer routes appear here."
        />
      ) : (
        <div className="cf-jurs__list">
          {ordered.map((j) => (
            <JurisdictionPanel
              key={`${j.code}-${j.role}`}
              jurisdiction={j}
              assets={props.assets}
              onEditFact={props.onEditFact}
            />
          ))}
        </div>
      )}
    </section>
  );
}
