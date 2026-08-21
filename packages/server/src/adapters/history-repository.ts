import type pg from "pg";

import type { SessionSummary } from "../history.js";

/**
 * The one query `GET /me/history` needs.
 *
 * **ADAPTER.** Grouping is the database's job and it does it in one statement;
 * pulling every attempt across to count them in TypeScript would be a table
 * scan's worth of rows to produce a handful of numbers.
 *
 * **`skill_id` collapses to null when a session spans more than one.**
 * `min(skill_id)` would name the session after whichever came first
 * numerically, which is not a fact about the session. No content can produce a
 * mixed one yet; the query answers correctly for the day it can.
 *
 * **The delta is read, never derived.** `session_deltas` holds what the rating
 * engine recorded at the instant it computed it, and nothing here recomputes
 * or estimates: a session with no row simply has no figure, which is what a
 * session that only calibrated leaves behind.
 *
 * **A mixed session loses its delta by the same rule that loses its name.**
 * The join matches on `skill_id`, and `skill_id` is already null for such a
 * session — `NULL = 1` is never true, so no row is matched and the delta comes
 * back null. That is the intended answer, not a coincidence: two skills moved
 * by two different amounts and no single number is a fact about the session.
 * The condition is left to do it rather than propped up with an
 * `a.skill_id IS NOT NULL` no input could ever be the sole cause of.
 */
export async function recentSessions(
  client: pg.ClientBase,
  playerId: string,
  limit: number,
): Promise<readonly SessionSummary[]> {
  const result = await client.query<{
    at: Date;
    total: number;
    correct: number;
    skill_id: number | null;
    rating_delta: number | null;
  }>(
    `SELECT played.at, played.total, played.correct, played.skill_id,
            moved.rating_delta
       FROM (
         SELECT session_id,
                max(answered_at)                            AS at,
                count(*)::int                               AS total,
                count(*) FILTER (WHERE is_correct)::int     AS correct,
                CASE WHEN count(DISTINCT skill_id) = 1
                     THEN min(skill_id)::int END            AS skill_id
           FROM attempts
          WHERE player_id = $1::uuid
          GROUP BY session_id
          ORDER BY max(answered_at) DESC
          LIMIT $2::int
       ) AS played
       LEFT JOIN session_deltas AS moved
              ON moved.player_id = $1::uuid
             AND moved.session_id = played.session_id
             AND moved.skill_id = played.skill_id
      ORDER BY played.at DESC`,
    [playerId, limit],
  );
  return result.rows.map((row) => ({
    at: row.at,
    total: row.total,
    correct: row.correct,
    skillId: row.skill_id,
    ratingDelta: row.rating_delta,
  }));
}
