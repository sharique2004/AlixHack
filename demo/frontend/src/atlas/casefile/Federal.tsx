/**
 * Case file — the federal layer.
 *
 * Two items sit outside state probate entirely: the refund claim for a deceased
 * taxpayer, and the Social Security lump-sum death payment, which has its own
 * payee ladder and is never payable to the estate.
 */

import type { AssetClassification, FederalReport } from "../types";
import { formatUSD } from "../types";
import { Chip, Cites, Empty, FactList, Framed, Reasons, SectionHead } from "./primitives";
import { FEDERAL_STATUS_LABEL, PAYEE_LABEL, humanizeId } from "./format";
import type { Tone } from "./primitives";

const STATUS_TONE: Record<string, Tone> = {
  required: "ok",
  payable: "ok",
  not_required: "out",
  not_payable: "out",
  needs_information: "wait",
};

export function FederalCard(props: {
  item: FederalReport;
  assets: AssetClassification[];
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const f = props.item;
  const tone = STATUS_TONE[f.status] ?? "out";
  const showLedger = f.payee !== null || f.amount_cents !== null;

  return (
    <Framed inner={f.status === "needs_information" ? "wait" : "paper"} className="cf-fed">
      <div className="cf-fed__top">
        <div>
          <div className="cf-fed__label">{f.label}</div>
          <div className="cf-fed__id mono">{f.item}</div>
        </div>
        <Chip tone={tone}>{FEDERAL_STATUS_LABEL[f.status] ?? humanizeId(f.status)}</Chip>
      </div>

      {showLedger ? (
        <dl className="cf-fed__ledger">
          {f.payee !== null ? (
            <div>
              <dt>Payable to</dt>
              <dd>{PAYEE_LABEL[f.payee] ?? humanizeId(f.payee)}</dd>
            </div>
          ) : null}
          {f.amount_cents !== null ? (
            <div>
              <dt>Amount</dt>
              <dd className="cf-h cf-h--sm">{formatUSD(f.amount_cents)}</dd>
            </div>
          ) : null}
        </dl>
      ) : null}

      <Reasons reasons={f.reasons} />
      <FactList paths={f.missing_facts} assets={props.assets} onEditFact={props.onEditFact} />
      <Cites citations={f.citations} />
    </Framed>
  );
}

export function Federal(props: {
  federal: FederalReport[];
  assets: AssetClassification[];
  onEditFact?: (path: string) => void;
}): JSX.Element {
  // Heading says "the federal government", not "Washington": this page routes by
  // state, and Washington is one of them (a community-property state, at that).
  return (
    <section className="atlas-section atlas-section--paper cf-section cf-fedsec">
      <SectionHead
        eyebrow="Federal"
        title="What the federal government owes, and what it needs."
        lede="These run in parallel with anything a state court does, and on their own clocks."
      />
      {props.federal.length === 0 ? (
        <Empty
          title="Nothing federal on these facts."
          body="No refund claim and no Social Security payment has been assessed for this case."
        />
      ) : (
        <div className="cf-fedsec__grid">
          {props.federal.map((f) => (
            <FederalCard
              key={f.item}
              item={f}
              assets={props.assets}
              onEditFact={props.onEditFact}
            />
          ))}
        </div>
      )}
    </section>
  );
}
