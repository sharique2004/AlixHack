/**
 * Case file — the asset map.
 *
 * The intellectual core of the screen: every asset placed on one side of the
 * probate line, with the reason it lands there and the statute that puts it
 * there. Assets the engine could not place are surfaced first, because they
 * are the ones that decide the shape of the estate.
 */

import type { AssetClassification, SettlementAssessment } from "../types";
import { formatUSD } from "../types";
import { Cite, Empty, FactList, Framed, SectionHead } from "./primitives";
import { capitalize, countWord, humanizeId, pluralize, routeLabels, splitEstate } from "./format";

function CountsToward(props: {
  ids: string[];
  labels: Record<string, string>;
}): JSX.Element | null {
  if (props.ids.length === 0) return null;
  return (
    <div className="cf-counts">
      <span className="cf-counts__lead">Counts toward</span>
      {props.ids.map((id) => (
        <span key={id} className="cf-counts__item">
          {props.labels[id] ?? humanizeId(id)}
        </span>
      ))}
    </div>
  );
}

export function AssetCard(props: {
  asset: AssetClassification;
  labels: Record<string, string>;
  assets: AssetClassification[];
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const a = props.asset;
  const unknown = a.classification === "unknown";
  const inner = unknown ? "wait" : a.classification === "non_probate" ? "cyan" : "bone";
  return (
    <Framed inner={inner} className={`cf-asset cf-asset--${a.classification}`}>
      <div className="cf-asset__top">
        <div className="cf-asset__name">{a.name}</div>
        <div className="cf-asset__value cf-h">
          {a.value_cents === null ? (
            <span className="cf-asset__value--unknown">value unknown</span>
          ) : (
            formatUSD(a.value_cents)
          )}
        </div>
      </div>

      <p className="cf-asset__reason">{a.reason}</p>

      <div className="cf-asset__foot">
        {a.basis ? <span className="cf-basis mono">{a.basis}</span> : null}
        <Cite citation={a.citation} />
      </div>

      <CountsToward ids={a.counts_toward} labels={props.labels} />

      {unknown && a.missing_facts.length > 0 ? (
        <div className="cf-asset__ask">
          <div className="cf-asset__askLead">
            {a.missing_facts.length === 1
              ? "One answer places this asset."
              : `${capitalize(countWord(a.missing_facts.length))} answers place this asset.`}
          </div>
          <FactList
            paths={a.missing_facts}
            assets={props.assets}
            onEditFact={props.onEditFact}
          />
        </div>
      ) : null}
    </Framed>
  );
}

function Column(props: {
  title: string;
  note: string;
  totalCents: number | null;
  unvalued: number;
  assets: AssetClassification[];
  labels: Record<string, string>;
  allAssets: AssetClassification[];
  emphasis?: boolean;
  onEditFact?: (path: string) => void;
}): JSX.Element {
  return (
    <section className={`cf-col${props.emphasis ? " cf-col--emphasis" : ""}`}>
      <header className="cf-col__head">
        <div>
          <h3 className="cf-h cf-h--md">{props.title}</h3>
          <div className="cf-col__note">{props.note}</div>
        </div>
        <div className="cf-col__total">
          <div className="cf-h cf-h--md">{formatUSD(props.totalCents)}</div>
          <div className="cf-col__totalNote">
            {props.assets.length} {pluralize(props.assets.length, "asset", "assets")}
            {props.unvalued > 0
              ? ` · ${props.unvalued} with no value yet`
              : ""}
          </div>
        </div>
      </header>
      {props.assets.length === 0 ? (
        <Empty
          title="Nothing here."
          body="No asset on record falls into this column on the facts supplied."
        />
      ) : (
        <div className="cf-col__cards">
          {props.assets.map((a) => (
            <AssetCard
              key={a.name}
              asset={a}
              labels={props.labels}
              assets={props.allAssets}
              onEditFact={props.onEditFact}
            />
          ))}
        </div>
      )}
    </section>
  );
}

export function AssetMap(props: {
  assessment: SettlementAssessment;
  onEditFact?: (path: string) => void;
}): JSX.Element {
  const a = props.assessment;
  const split = splitEstate(a.asset_map);
  const labels = routeLabels(a);
  const subtotal = a.probate_estate.known_subtotal_cents;
  const partial = a.probate_estate.status === "partial";

  return (
    <section className="atlas-section atlas-section--paper cf-section cf-assetmap">
      <SectionHead
        eyebrow="The asset map"
        title="Where each asset lands."
        lede="Property that passes by survivorship, beneficiary designation, or trust never enters the probate estate. What remains is what any court route has to carry."
        right={
          <Framed inner={partial ? "wait" : "bone"} className="cf-subtotal">
            <div className="cf-subtotal__lead">
              {partial ? "Probate estate so far" : "Probate estate"}
            </div>
            <div className="cf-h cf-h--lg">{formatUSD(subtotal)}</div>
            <div className="cf-subtotal__note">
              {partial
                ? "Partial — the total moves once the unresolved assets below are placed."
                : "Complete on the facts supplied."}
            </div>
            {partial ? (
              <FactList
                paths={a.probate_estate.missing_facts}
                assets={a.asset_map}
                onEditFact={props.onEditFact}
              />
            ) : null}
          </Framed>
        }
      />

      {a.asset_map.length === 0 ? (
        <Empty
          title="No assets on file."
          body="Add the decedent's accounts, property, and policies and the map will draw itself."
        />
      ) : (
        <>
          {split.unknown.length > 0 ? (
            <section className="cf-unresolved">
              <div className="cf-unresolved__head">
                <h3 className="cf-h cf-h--md">
                  {split.unknown.length === 1
                    ? "One asset is still unplaced."
                    : `${capitalize(countWord(split.unknown.length))} assets are still unplaced.`}
                </h3>
                <p className="cf-unresolved__note">
                  These are the most consequential cards on this page. Until each one
                  is placed, no valuation cap can be tested — and an unknown is never
                  read as a no.
                </p>
              </div>
              <div className="cf-unresolved__cards">
                {split.unknown.map((asset) => (
                  <AssetCard
                    key={asset.name}
                    asset={asset}
                    labels={labels}
                    assets={a.asset_map}
                    onEditFact={props.onEditFact}
                  />
                ))}
              </div>
            </section>
          ) : null}

          <div className="cf-cols">
            <Column
              title="Passes outside probate."
              note="Transfers by operation of law or by contract. No court is involved."
              totalCents={split.nonProbateKnownCents}
              unvalued={split.nonProbateUnvalued}
              assets={split.nonProbate}
              labels={labels}
              allAssets={a.asset_map}
              onEditFact={props.onEditFact}
            />
            <Column
              title="Inside the probate estate."
              note="What a court route has to carry — and what every value cap is measured against."
              totalCents={split.probateKnownCents}
              unvalued={split.probateUnvalued}
              assets={split.probate}
              labels={labels}
              allAssets={a.asset_map}
              emphasis
              onEditFact={props.onEditFact}
            />
          </div>
        </>
      )}
    </section>
  );
}
