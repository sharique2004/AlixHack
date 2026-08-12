import { Button, Field, FramedCard, MoneyInput, Select } from "../../design/primitives";
import { DEBT_KINDS } from "../copy";
import { newDebt, type DraftDebt, type StepProps } from "../model";

export function DebtsStep({ draft, update }: StepProps) {
  const debts = draft.debts;
  const patch = (id: string, p: Partial<DraftDebt>) =>
    update({ debts: debts.map((x) => (x._id === id ? { ...x, ...p } : x)) });

  const assetOptions = draft.assets
    .filter((a) => a.name.trim() !== "")
    .map((a) => ({ value: a.name, label: a.name }));

  return (
    <>
      {debts.length === 0 && (
        <p className="ax-empty">
          Nothing listed. If you genuinely believe there were no debts, move on — but funeral costs and a
          last medical bill are easy to forget.
        </p>
      )}

      {debts.map((x, i) => (
        <FramedCard key={x._id} tone="bone" className="ax-asset">
          <div className="ax-asset__head">
            <span className="ax-asset__n">debts[{i}]</span>
            <Button
              variant="quiet"
              onClick={() => update({ debts: debts.filter((d) => d._id !== x._id) })}
              aria-label={`Remove debt ${i + 1}`}
            >
              Remove
            </Button>
          </div>
          <div className="ax-fields">
            <Field label="What kind of debt?" htmlFor={`${x._id}-kind`} unknown={x.kind == null}>
              <Select
                id={`${x._id}-kind`}
                value={x.kind ?? null}
                options={DEBT_KINDS}
                onChange={(v) => patch(x._id, { kind: v })}
              />
            </Field>
            <Field label="How much?" htmlFor={`${x._id}-amount`} unknown={x.amount_cents == null}>
              <MoneyInput
                id={`${x._id}-amount`}
                value={x.amount_cents ?? null}
                onChange={(cents) => patch(x._id, { amount_cents: cents })}
              />
            </Field>
            {assetOptions.length > 0 && (
              <Field
                label="Is it secured against something on your list?"
                htmlFor={`${x._id}-secured`}
                hint="A mortgage is secured against the house; a card balance is secured against nothing."
                span
              >
                <Select
                  id={`${x._id}-secured`}
                  value={x.secured_by_asset ?? null}
                  options={assetOptions}
                  onChange={(v) => patch(x._id, { secured_by_asset: v })}
                  notSureLabel="Not secured, or not sure"
                />
              </Field>
            )}
          </div>
        </FramedCard>
      ))}

      <div className="ax-row" style={{ marginTop: 18 }}>
        <Button onClick={() => update({ debts: [...debts, newDebt()] })}>Add a debt</Button>
      </div>
    </>
  );
}
