/**
 * Case file — the timeline.
 *
 * Computed dates are definite and are printed. Everything else says plainly
 * what has to happen before it can have a date. We never render a fake date.
 */

import type { Deadline } from "../types";
import { formatDate } from "../types";
import { Chip, Cite, Empty, SectionHead } from "./primitives";
import { isPast, offsetPhrase, orderDeadlines, relativeToPhrase } from "./format";

function DeadlineRow(props: { deadline: Deadline; asOf: string }): JSX.Element {
  const d = props.deadline;
  const past = d.status === "computed" && isPast(d.date, props.asOf);
  const state = past ? "past" : d.status;

  return (
    <li className={`cf-dl cf-dl--${state}`}>
      <div className="cf-dl__mark" aria-hidden="true" />
      <div className="cf-dl__when">
        {d.status === "computed" && d.date ? (
          <>
            <div className="cf-h cf-h--sm cf-dl__date">{formatDate(d.date)}</div>
            <div className="cf-dl__rel">{offsetPhrase(d)}</div>
          </>
        ) : (
          <>
            <div className="cf-dl__undated">Not yet datable</div>
            <div className="cf-dl__rel">{offsetPhrase(d)}</div>
          </>
        )}
      </div>
      <div className="cf-dl__body">
        <div className="cf-dl__label">{d.label}</div>
        <div className="cf-dl__note">
          {d.status === "computed"
            ? past
              ? "This date has already passed as of the snapshot below."
              : "Computed from a date on the record."
            : d.status === "awaiting_event"
              ? `The clock starts when ${relativeToPhrase(d.relative_to)} — it has not started yet.`
              : "A fact this date depends on is still unknown, so no date is shown."}
        </div>
        <div className="cf-dl__foot">
          <Chip tone={past ? "out" : d.status === "computed" ? "ok" : "wait"}>
            {past
              ? "Passed"
              : d.status === "computed"
                ? "Computed"
                : d.status === "awaiting_event"
                  ? "Awaiting an event"
                  : "Needs information"}
          </Chip>
          <span className="cf-dl__id mono">{d.id}</span>
          <Cite citation={d.citation} />
        </div>
      </div>
    </li>
  );
}

export function Deadlines(props: { deadlines: Deadline[]; asOf: string }): JSX.Element {
  const ordered = orderDeadlines(props.deadlines);
  return (
    <section className="atlas-section atlas-section--bone cf-section cf-dls">
      <SectionHead
        eyebrow="Deadlines"
        title="What the calendar demands."
        lede="Some of these run from the date of death and can be computed today. Others cannot start until a court acts, and saying so is more useful than a guess."
      />
      {ordered.length === 0 ? (
        <Empty
          title="No deadlines yet."
          body="No date on the record starts a clock that applies to this estate."
        />
      ) : (
        <ol className="cf-dls__rail">
          {ordered.map((d) => (
            <DeadlineRow key={d.id} deadline={d} asOf={props.asOf} />
          ))}
        </ol>
      )}
    </section>
  );
}
