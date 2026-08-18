/**
 * How long data lives, and nothing else.
 *
 * **PURE.** The instant comes in as a parameter; this module reads no clock, no
 * environment and no connection — the same shape `routing.ts` sets for this
 * package. The adapter beside it reads the clock and runs the DELETE under the
 * `retention_job` role.
 *
 * **These two numbers appear here and nowhere else in `src/`,** and a test
 * enumerates the source to keep it so. They are decision #3 and they have a
 * legal consequence; a figure with two homes is a figure that will disagree
 * with itself.
 */
export const RETENTION_DAYS = {
  attempts: 400,
  diagEvents: 30,
} as const;

const DAY_MS = 24 * 60 * 60 * 1000;

export interface RetentionCutoffs {
  /** Attempts recorded before this instant are expired. */
  readonly attempts: Date;
  /** Diagnosis events recorded before this instant are expired. */
  readonly diagEvents: Date;
}

/**
 * The instants before which each kind of row has expired.
 *
 * **Absolute elapsed time, deliberately.** 400 days means 400 × 24 h, not a
 * walk back over 400 local midnights. A local calendar day is 23, 24 or 25
 * hours long, and the Dart side already paid for the other reading: the streak
 * policy walked backwards with a `Duration` over local midnights and lost a
 * child's whole 30-day run across a Tijuana daylight-saving transition. Here
 * the calendar reading would be the bug — a retention policy is about how long
 * data has existed, not about which day it is where the server happens to be.
 */
export function retentionCutoffs(now: Date): RetentionCutoffs {
  return {
    attempts: new Date(now.getTime() - RETENTION_DAYS.attempts * DAY_MS),
    diagEvents: new Date(now.getTime() - RETENTION_DAYS.diagEvents * DAY_MS),
  };
}
