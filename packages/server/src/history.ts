import { skillName } from "@akimath/core";

import type { Response } from "./routing.js";

/**
 * What `GET /me/history` answers.
 *
 * **PURE** — grouped rows in, the frozen `History` out.
 *
 * **An entry is a session, not an attempt.** The schema asks for a `score` and
 * a `title`, and neither means anything about one answered item. Every
 * submission has carried a `sessionId` since the freeze; migration 0004 is what
 * finally gave it somewhere to land, and this is what it was for.
 */

/**
 * How many sessions one answer carries.
 *
 * `GET /me/history` declares no parameters, so there is no page to ask for and
 * nothing for a client to do with a cursor it cannot send. A cap is therefore
 * the server's to choose, and it is stated here rather than buried in SQL. When
 * paging arrives it is a contract change and this becomes a default.
 */
export const HISTORY_LIMIT = 50;

/** One session, as the repository groups it. */
export interface SessionSummary {
  /** The last answer in the session, which is when it reads as having happened. */
  readonly at: Date;
  readonly total: number;
  readonly correct: number;
  /** Null when the session spans more than one, which no content can do yet. */
  readonly skillId: number | null;
  /**
   * What the session moved the player's rating by, as it was recorded, or null
   * when no single figure is a fact about the session. See `historyResponse`
   * for the two ways that happens.
   */
  readonly ratingDelta: number | null;
}

/**
 * What a session is called.
 *
 * **Named after the skill when there is one name to use.** A session that
 * spanned two skills is not "Restas" and is not one of them chosen by
 * iteration order; a skill nobody has named yet is not a blank line. Both fall
 * back to the generic, which is true of every session.
 */
export function sessionTitle(skillId: number | null): string {
  const named = skillId === null ? null : skillName(skillId);
  return named ?? "Serie de retos";
}

/**
 * `4/5`, the way the score reads on a screen.
 *
 * A string in the frozen schema rather than two numbers, which is a
 * presentation decision the contract already made — so this is where it is
 * kept, once.
 */
export function sessionScore(correct: number, total: number): string {
  return `${correct}/${total}`;
}

/**
 * How a recorded movement reads on a screen.
 *
 * **Whole rating points, because the frozen schema has no other kind** —
 * `HistoryEntry.ratingDelta` is `{type: integer, nullable: true}`. The stored
 * figure is the difference between two `real` columns, so it becomes whole
 * somewhere, and it becomes whole here rather than in the record: what was
 * measured keeps every digit it was measured with, and rounding is a
 * presentation decision.
 */
export function roundedDelta(change: number | null): number | null {
  if (change === null) {
    return null;
  }
  const points = Math.round(change);
  // `Math.round(-0.2)` is `-0`, a different value from `0` to `Object.is`. A
  // rating that slipped by a fifth of a point is not a distinct outcome from
  // one that held, and a JSON `-0` would be a distinction nobody meant.
  return Object.is(points, -0) ? 0 : points;
}

/**
 * The frozen `History`, newest first.
 *
 * **`ratingDelta` is a real figure now, and null is still an answer.** It is
 * the movement the rating engine recorded for that session, taken from the row
 * `POST /attempts` wrote at the moment both ends of the subtraction existed —
 * never recomputed here, because the difficulty classes a session was rated
 * against move on the very next batch and a figure derived from today's would
 * look like a measurement without being one.
 *
 * Two kinds of session have no such figure, and both answer null:
 *
 *   · **One that spans two skills.** Two ratings moved, by different amounts
 *     and possibly in opposite directions. Summing them adds two independent
 *     scales together and picking one is `min(skill_id)` again — the same
 *     reason `sessionTitle` refuses to name such a session after either.
 *   · **One that only calibrated.** Every answer met a difficulty class nobody
 *     had met, so it taught the class and left the player where it found them
 *     (`rating.ts`). Nothing measured the player, and *zero is already taken*:
 *     the wire type is an integer, so a measured change of a third of a point
 *     renders as `0`. Reporting `0` for an unmeasured session would collapse
 *     "we did not measure you" into "we measured you and you held".
 *
 * **`kind` is always `series`.** The other value is `puzzle`, and a puzzle
 * leaves no row in any table — nothing records that one was solved, so nothing
 * can report it. An entry claiming otherwise would be a screen inventing a
 * history.
 */
export function historyResponse(sessions: readonly SessionSummary[]): Response {
  return {
    status: 200,
    body: {
      entries: sessions.map((session) => ({
        kind: "series",
        title: sessionTitle(session.skillId),
        at: session.at.toISOString(),
        score: sessionScore(session.correct, session.total),
        ratingDelta: roundedDelta(session.ratingDelta),
      })),
    },
  };
}
