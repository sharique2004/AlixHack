import { ChoiceGroup, Field, Toggle } from "../../design/primitives";
import { WILL_STATUS } from "../copy";
import type { StepProps } from "../model";

/** The will, and the handful of circumstances that quietly change which route
    an estate is on. Each of these maps to a referral flag in the contract, so
    they are asked plainly rather than buried. */
export function WillStep({ draft, setDecedent }: StepProps) {
  const d = draft.decedent;
  return (
    <>
      <div className="ax-fields ax-fields--one">
        <Field
          label="Did they leave a will?"
          factPath="decedent.will_status"
          unknown={d.will_status == null}
          hint="If you have not looked yet, say so. A will can turn up later and it changes who inherits."
        >
          <ChoiceGroup
            id="f-will"
            legend="Did they leave a will?"
            value={d.will_status ?? null}
            options={WILL_STATUS}
            onChange={(v) => setDecedent({ will_status: v })}
            notSureLabel="We haven't found out yet"
          />
        </Field>
      </div>

      <div className="ax-group">
        <h5>Circumstances that can change the route.</h5>
        <div className="ax-fields">
          <Field
            label="Did the death happen at work, or because of work?"
            factPath="decedent.employment_related_death"
            unknown={d.employment_related_death == null}
            hint="Workers' compensation death benefits sit outside the estate entirely."
          >
            <Toggle
              id="f-work"
              legend="Did the death happen at work, or because of work?"
              value={d.employment_related_death ?? null}
              onChange={(v) => setDecedent({ employment_related_death: v })}
            />
          </Field>

          <Field
            label="Might someone else be at fault for the death?"
            factPath="decedent.third_party_fault_suspected"
            unknown={d.third_party_fault_suspected == null}
            hint="A car, a fall, a product, a doctor. If so there may be two separate claims, and they belong to different people."
          >
            <Toggle
              id="f-fault"
              legend="Might someone else be at fault for the death?"
              value={d.third_party_fault_suspected ?? null}
              onChange={(v) => setDecedent({ third_party_fault_suspected: v })}
            />
          </Field>

          <Field
            label="Did anyone who would have inherited die within about five days of them?"
            factPath="decedent.related_death_within_120h"
            unknown={d.related_death_within_120h == null}
            hint="Survivorship inside 120 hours is treated specially in most states."
          >
            <Toggle
              id="f-120h"
              legend="Did anyone who would have inherited die within about five days of them?"
              value={d.related_death_within_120h ?? null}
              onChange={(v) => setDecedent({ related_death_within_120h: v })}
            />
          </Field>

          <Field
            label="Did they receive Medicaid or Medi-Cal long-term care?"
            factPath="decedent.received_medicaid_ltc"
            unknown={d.received_medicaid_ltc == null}
            hint="The state may have a claim against the estate for what it paid."
          >
            <Toggle
              id="f-medicaid"
              legend="Did they receive Medicaid or Medi-Cal long-term care?"
              value={d.received_medicaid_ltc ?? null}
              onChange={(v) => setDecedent({ received_medicaid_ltc: v })}
            />
          </Field>

          <Field
            label="Was any lawsuit pending when they died?"
            factPath="decedent.pending_litigation"
            unknown={d.pending_litigation == null}
            hint="Either as the person suing or the person being sued."
            span
          >
            <Toggle
              id="f-litigation"
              legend="Was any lawsuit pending when they died?"
              value={d.pending_litigation ?? null}
              onChange={(v) => setDecedent({ pending_litigation: v })}
            />
          </Field>
        </div>
      </div>
    </>
  );
}
