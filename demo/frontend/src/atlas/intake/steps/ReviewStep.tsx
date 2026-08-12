import { Chip, FramedCard, StatusGlyph } from "../../design/primitives";
import { formatDate, formatUSD } from "../../types";
import {
  knownAssetTotalCents,
  knownDebtTotalCents,
  openFacts,
  type StepProps,
} from "../model";

export function ReviewStep({ draft, onJump }: StepProps & { onJump: (step: number) => void }) {
  const open = openFacts(draft);
  const named = draft.assets.filter((a) => a.name.trim() !== "");
  const valued = named.filter((a) => a.gross_value_cents != null);

  const rows: [string, string][] = [
    ["Date of death", formatDate(draft.decedent.death_date)],
    ["State they lived in", draft.decedent.domicile_state ?? "Not sure"],
    ["Surviving spouse", draft.decedent.surviving_spouse == null ? "Not sure" : draft.decedent.surviving_spouse ? "Yes" : "No"],
    ["Things listed", `${named.length}`],
    [
      "Value of the things with a value",
      valued.length === named.length
        ? formatUSD(knownAssetTotalCents(draft))
        : `${formatUSD(knownAssetTotalCents(draft))} across ${valued.length} of ${named.length}`,
    ],
    ["Debts listed", draft.debts.length === 0 ? "None" : `${draft.debts.length}, ${formatUSD(knownDebtTotalCents(draft))}`],
    ["People listed", `${draft.heirs.length}`],
    [
      "List confirmed complete",
      draft.inventory_complete == null ? "Not sure" : draft.inventory_complete ? "Yes" : "No",
    ],
  ];

  return (
    <>
      <div className="ax-review">
        <dl>
          {rows.map(([k, v]) => (
            <div key={k}>
              <dt>{k}</dt>
              <dd>{v}</dd>
            </div>
          ))}
        </dl>
      </div>

      <div className="ax-group">
        <h5>What is still open.</h5>
        {open.length === 0 ? (
          <FramedCard tone="bone">
            <p style={{ fontSize: 14 }}>
              Nothing is open. Every question has an answer — which means every conclusion the engine reaches
              will be a conclusion, not a maybe.
            </p>
          </FramedCard>
        ) : (
          <FramedCard tone="bone">
            <div className="ax-row" style={{ marginBottom: 12 }}>
              <Chip tone="wait">
                <StatusGlyph tone="wait" label="" />
                {open.length} {open.length === 1 ? "open fact" : "open facts"}
              </Chip>
              <span className="ax-quiet" style={{ fontSize: 13 }}>
                None of these is a no. Each one is a thing to find out, and the result will say what it blocks.
              </span>
            </div>
            <ul>
              {open.map((f) => (
                <li key={f.path}>
                  <button type="button" className="ax-rail__item" onClick={() => onJump(f.step)}>
                    {f.label}
                    <span className="p">{f.path}</span>
                  </button>
                </li>
              ))}
            </ul>
          </FramedCard>
        )}
      </div>
    </>
  );
}
