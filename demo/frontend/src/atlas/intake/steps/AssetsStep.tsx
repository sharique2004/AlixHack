import {
  Button,
  ChoiceGroup,
  Field,
  FramedCard,
  MoneyInput,
  Select,
  Toggle,
} from "../../design/primitives";
import {
  ASSET_KINDS,
  BENEFICIARY_DESIGNATIONS,
  BENEFICIARY_GLOSS,
  STATES,
  TITLE_FORMS,
  TITLE_FORM_GLOSS,
} from "../copy";
import { newAsset, type DraftAsset, type StepProps } from "../model";

/** The heart of the intake. Two of these questions — how it was titled, and
    whether it names a beneficiary — decide whether an asset goes through
    probate at all, and almost nobody outside the profession knows that. So they
    are asked in full sentences, with the terms explained where they are asked. */
export function AssetsStep({ draft, update }: StepProps) {
  const assets = draft.assets;

  const patchAsset = (id: string, patch: Partial<DraftAsset>) =>
    update({ assets: assets.map((a) => (a._id === id ? { ...a, ...patch } : a)) });

  const removeAsset = (id: string) => update({ assets: assets.filter((a) => a._id !== id) });

  return (
    <>
      {assets.length === 0 && (
        <p className="ax-empty">
          Nothing listed yet. Add the first thing you know about — a house, an account, a car.
        </p>
      )}

      {assets.map((a, i) => {
        const p = `assets[${i}]`;
        return (
          <FramedCard key={a._id} tone="bone" className="ax-asset">
            <div className="ax-asset__head">
              <span className="ax-asset__n">{p}</span>
              <Button
                variant="quiet"
                onClick={() => removeAsset(a._id)}
                aria-label={`Remove ${a.name.trim() || `asset ${i + 1}`}`}
              >
                Remove
              </Button>
            </div>

            <div className="ax-fields">
              <Field label="What is it?" htmlFor={`${a._id}-name`} factPath={`${p}.name`} span>
                <input
                  id={`${a._id}-name`}
                  className="atlas-input"
                  value={a.name}
                  placeholder="Primary residence — 12 Oak St"
                  onChange={(e) => patchAsset(a._id, { name: e.target.value })}
                />
              </Field>

              <Field
                label="What kind of thing is it?"
                htmlFor={`${a._id}-kind`}
                factPath={`${p}.kind`}
                unknown={a.kind == null}
              >
                <Select
                  id={`${a._id}-kind`}
                  value={a.kind ?? null}
                  options={ASSET_KINDS}
                  onChange={(v) => patchAsset(a._id, { kind: v })}
                />
              </Field>

              <Field
                label="Which state is it in?"
                htmlFor={`${a._id}-situs`}
                factPath={`${p}.situs_state`}
                unknown={a.situs_state == null}
                hint="Real property is settled where it sits, even if they lived elsewhere."
              >
                <Select
                  id={`${a._id}-situs`}
                  value={a.situs_state ?? null}
                  options={STATES}
                  onChange={(v) => patchAsset(a._id, { situs_state: v })}
                />
              </Field>

              <Field
                label="Roughly what is it worth?"
                htmlFor={`${a._id}-value`}
                factPath={`${p}.gross_value_cents`}
                unknown={a.gross_value_cents == null}
                hint="Before subtracting anything owed on it."
              >
                <MoneyInput
                  id={`${a._id}-value`}
                  value={a.gross_value_cents ?? null}
                  onChange={(cents) => patchAsset(a._id, { gross_value_cents: cents })}
                />
              </Field>

              <Field
                label="How much is still owed on it?"
                htmlFor={`${a._id}-encumbrance`}
                factPath={`${p}.encumbrance_cents`}
                hint="A mortgage, a car loan, a lien. Leave it blank if nothing is owed and you are sure."
              >
                <MoneyInput
                  id={`${a._id}-encumbrance`}
                  value={a.encumbrance_cents ?? null}
                  onChange={(cents) => patchAsset(a._id, { encumbrance_cents: cents })}
                />
              </Field>

              <Field
                label="How was it titled?"
                explain={TITLE_FORM_GLOSS}
                factPath={`${p}.title_form`}
                unknown={a.title_form == null}
                hint="Whose names were on the deed, the account, or the certificate — and in what way."
                span
              >
                <ChoiceGroup
                  id={`${a._id}-title`}
                  legend="How was it titled?"
                  value={a.title_form ?? null}
                  options={TITLE_FORMS}
                  onChange={(v) => patchAsset(a._id, { title_form: v })}
                  notSureLabel="Not sure"
                  notSureExplain="Very common, and worth checking. This one fact usually decides whether the asset goes through probate at all."
                />
              </Field>

              <Field
                label="Does it name a beneficiary?"
                explain={BENEFICIARY_GLOSS}
                factPath={`${p}.beneficiary_designation`}
                unknown={a.beneficiary_designation == null}
                span
              >
                <ChoiceGroup
                  id={`${a._id}-benef`}
                  legend="Does it name a beneficiary?"
                  layout="pills"
                  value={a.beneficiary_designation ?? null}
                  options={BENEFICIARY_DESIGNATIONS}
                  onChange={(v) => patchAsset(a._id, { beneficiary_designation: v })}
                />
              </Field>

              {a.kind === "real_property" && (
                <Field
                  label="Was this their home?"
                  factPath={`${p}.is_primary_residence`}
                  unknown={a.is_primary_residence == null}
                  hint="California has a separate, higher-limit route for a decedent's primary residence."
                  span
                >
                  <Toggle
                    id={`${a._id}-home`}
                    legend="Was this their home?"
                    value={a.is_primary_residence ?? null}
                    onChange={(v) => patchAsset(a._id, { is_primary_residence: v })}
                  />
                </Field>
              )}
            </div>
          </FramedCard>
        );
      })}

      <div className="ax-row" style={{ marginTop: 18 }}>
        <Button onClick={() => update({ assets: [...assets, newAsset()] })}>Add another thing</Button>
      </div>

      <div className="ax-group">
        <h5>One more thing about this list.</h5>
        <Field
          label="Is this list complete?"
          factPath="inventory_complete"
          unknown={draft.inventory_complete == null}
          hint="Every value limit in the law is tested against the whole estate. Until you can say the list is complete, no limit can honestly be tested — so “not sure” is the right answer if you are not."
          span
        >
          <Toggle
            id="f-inventory"
            legend="Is this list of assets complete?"
            value={draft.inventory_complete ?? null}
            onChange={(v) => update({ inventory_complete: v })}
            yesLabel="Yes, that's everything"
            noLabel="No, there is more"
            notSureLabel="Not sure"
          />
        </Field>
      </div>
    </>
  );
}
