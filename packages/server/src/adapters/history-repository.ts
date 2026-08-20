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
  }>(
    `SELECT max(answered_at)                                   AS at,
            count(*)::int                                      AS total,
            count(*) FILTER (WHERE is_correct)::int            AS correct,
            CASE WHEN count(DISTINCT skill_id) = 1
                 THEN min(skill_id)::int END                   AS skill_id
       FROM attempts
      WHERE player_id = $1::uuid
      GROUP BY session_id
      ORDER BY max(answered_at) DESC
      LIMIT $2::int`,
    [playerId, limit],
  );
  return result.rows.map((row) => ({
    at: row.at,
    total: row.total,
    correct: row.correct,
    skillId: row.skill_id,
  }));
}
