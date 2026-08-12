import { Button, Field, FramedCard, Select, TextInput, Toggle } from "../../design/primitives";
import { RELATIONSHIPS } from "../copy";
import { newHeir, type DraftHeir, type StepProps } from "../model";

export function FamilyStep({ draft, update }: StepProps) {
  const heirs = draft.heirs;
  const patch = (id: string, p: Partial<DraftHeir>) =>
    update({ heirs: heirs.map((h) => (h._id === id ? { ...h, ...p } : h)) });

  return (
    <>
      {heirs.length === 0 && (
        <p className="ax-empty">Nobody listed yet. Start with the people closest to them.</p>
      )}

      {heirs.map((h, i) => (
        <FramedCard key={h._id} tone="bone" className="ax-asset">
          <div className="ax-asset__head">
            <span className="ax-asset__n">heirs[{i}]</span>
            <Button
              variant="quiet"
              onClick={() => update({ heirs: heirs.filter((x) => x._id !== h._id) })}
              aria-label={`Remove person ${i + 1}`}
            >
              Remove
            </Button>
          </div>
          <div className="ax-fields">
            <Field label="Their name" htmlFor={`${h._id}-name`}>
              <TextInput
                id={`${h._id}-name`}
                value={h.name ?? ""}
                onChange={(v) => patch(h._id, { name: v })}
                placeholder="Ana Reyes"
              />
            </Field>

            <Field
              label="How were they related?"
              htmlFor={`${h._id}-rel`}
              unknown={h.relationship == null}
            >
              <Select
                id={`${h._id}-rel`}
                value={h.relationship ?? null}
                options={RELATIONSHIPS}
                onChange={(v) => patch(h._id, { relationship: v })}
              />
            </Field>

            <Field
              label="How old are they?"
              htmlFor={`${h._id}-age`}
              unknown={h.age == null}
              hint="A minor cannot be handed an inheritance directly, so this changes what has to happen."
            >
              <input
                id={`${h._id}-age`}
                className="atlas-input"
                inputMode="numeric"
                value={h.age ?? ""}
                placeholder="Not sure"
                onChange={(e) => {
                  const v = e.target.value.trim();
                  patch(h._id, { age: v === "" || !/^\d{1,3}$/.test(v) ? null : Number(v) });
                }}
              />
            </Field>

            <Field
              label="Do they receive means-tested benefits?"
              unknown={h.receives_means_tested_benefits == null}
              hint="An inheritance can cost someone their SSI or Medicaid unless it is structured for it."
            >
              <Toggle
                id={`${h._id}-benefits`}
                legend="Do they receive means-tested benefits?"
                value={h.receives_means_tested_benefits ?? null}
                onChange={(v) => patch(h._id, { receives_means_tested_benefits: v })}
              />
            </Field>

            <Field
              label="Have they given up their share?"
              unknown={h.disclaimed == null}
              hint="A formal disclaimer. Rare, but it changes who takes."
            >
              <Toggle
                id={`${h._id}-disclaimed`}
                legend="Have they given up their share?"
                value={h.disclaimed ?? null}
                onChange={(v) => patch(h._id, { disclaimed: v })}
              />
            </Field>

            {draft.decedent.manner_of_death === "homicide" && (
              <Field
                label="Are they a suspect in the death?"
                unknown={h.is_suspect_in_death == null}
                hint="Asked only because the manner of death is recorded as homicide. Nothing about this is an accusation — it is a screen the law requires."
              >
                <Toggle
                  id={`${h._id}-suspect`}
                  legend="Are they a suspect in the death?"
                  value={h.is_suspect_in_death ?? null}
                  onChange={(v) => patch(h._id, { is_suspect_in_death: v })}
                />
              </Field>
            )}
          </div>
        </FramedCard>
      ))}

      <div className="ax-row" style={{ marginTop: 18 }}>
        <Button onClick={() => update({ heirs: [...heirs, newHeir()] })}>Add a person</Button>
      </div>

      <div className="ax-group">
        <h5>One question about the people, not the paperwork.</h5>
        <Field
          label="Is anyone in disagreement about any of this?"
          factPath="conflict_signals"
          unknown={draft.conflict_signals == null}
          hint="Simplified transfer routes are built on everyone agreeing. Where they do not, the honest answer is a different process, not a faster form."
          span
        >
          <Toggle
            id="f-conflict"
            legend="Is anyone in disagreement about any of this?"
            value={draft.conflict_signals ?? null}
            onChange={(v) => update({ conflict_signals: v })}
          />
        </Field>
      </div>
    </>
  );
}
