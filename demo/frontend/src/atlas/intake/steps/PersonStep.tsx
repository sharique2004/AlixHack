import { ChoiceGroup, DateField, Field, Select, Toggle } from "../../design/primitives";
import { MANNER_OF_DEATH, MARITAL_STATUS, STATES } from "../copy";
import type { StepProps } from "../model";

export function PersonStep({ draft, setDecedent }: StepProps) {
  const d = draft.decedent;
  return (
    <>
      <div className="ax-fields">
        <Field
          label="When did they die?"
          htmlFor="f-death-date"
          factPath="decedent.death_date"
          unknown={d.death_date == null}
          hint="Waiting periods and deadlines are counted from this date."
        >
          <DateField id="f-death-date" value={d.death_date ?? null} onChange={(v) => setDecedent({ death_date: v })} />
        </Field>

        <Field
          label="Which state did they live in?"
          htmlFor="f-domicile"
          factPath="decedent.domicile_state"
          unknown={d.domicile_state == null}
          hint="Where they lived, not where they died. It decides whose law applies to everything except real property."
        >
          <Select
            id="f-domicile"
            value={d.domicile_state ?? null}
            options={STATES}
            onChange={(v) => setDecedent({ domicile_state: v })}
          />
        </Field>

        <Field
          label="Were they married?"
          htmlFor="f-marital"
          factPath="decedent.marital_status"
          unknown={d.marital_status == null}
        >
          <Select
            id="f-marital"
            value={d.marital_status ?? null}
            options={MARITAL_STATUS}
            onChange={(v) => setDecedent({ marital_status: v })}
          />
        </Field>

        <Field
          label="Is there a surviving spouse or registered partner?"
          factPath="decedent.surviving_spouse"
          unknown={d.surviving_spouse == null}
          hint="A surviving spouse opens routes that nobody else can use."
        >
          <Toggle
            id="f-spouse"
            legend="Is there a surviving spouse or registered partner?"
            value={d.surviving_spouse ?? null}
            onChange={(v) => setDecedent({ surviving_spouse: v })}
          />
        </Field>

        <Field
          label="How did they die?"
          span
          factPath="decedent.manner_of_death"
          unknown={d.manner_of_death == null}
          hint="This is on the death certificate. It matters because a few answers change who is allowed to inherit at all."
        >
          <ChoiceGroup
            id="f-manner"
            legend="How did they die?"
            layout="pills"
            value={d.manner_of_death ?? null}
            options={MANNER_OF_DEATH}
            onChange={(v) => setDecedent({ manner_of_death: v })}
          />
        </Field>

        <Field
          label="Is the death certificate final?"
          factPath="decedent.death_certificate_final"
          unknown={d.death_certificate_final == null}
          hint="Some are issued as pending while a coroner finishes. Banks generally will not act on a pending certificate."
        >
          <Toggle
            id="f-cert"
            legend="Is the death certificate final?"
            value={d.death_certificate_final ?? null}
            onChange={(v) => setDecedent({ death_certificate_final: v })}
          />
        </Field>

        <Field
          label="Were they a veteran?"
          factPath="decedent.veteran"
          unknown={d.veteran == null}
          hint="Veterans' survivors may be owed burial and survivor benefits that nobody offers unasked."
        >
          <Toggle
            id="f-veteran"
            legend="Were they a veteran?"
            value={d.veteran ?? null}
            onChange={(v) => setDecedent({ veteran: v })}
          />
        </Field>
      </div>
    </>
  );
}
