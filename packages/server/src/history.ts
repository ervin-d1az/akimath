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
 * The frozen `History`, newest first.
 *
 * **`ratingDelta` is null and the schema allows it.** Rating is F4; a number
 * here would be invented. Null is the schema's way of saying "not this time",
 * and it is the honest value until `user_skills` has rows.
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
        ratingDelta: null,
      })),
    },
  };
}
