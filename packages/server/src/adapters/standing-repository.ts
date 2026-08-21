import type pg from "pg";

import type { SkillRating } from "../standing.js";

/**
 * The one query `GET /me/standing` needs.
 *
 * **ADAPTER.** A `SELECT` and a row mapping, no decisions: what the answer
 * *means* is in `standing.ts`, where it is tested without a socket.
 *
 * **`app_request` already holds SELECT on `user_skills`** (migration 0001), so
 * reading it needs no grant and therefore no migration — the protected paths
 * stay untouched.
 *
 * **Ordered by skill, because something has to order it.** Postgres gives no
 * order without one, so two calls could answer the same ratings in different
 * sequences and a screen would reshuffle between refreshes. `skill_id` is the
 * one key every row has and it is stable; rating order would move under the
 * player.
 *
 * **`rating` and `deviation` are `real`.** `pg` hands a `real` back as a
 * JavaScript number already — unlike `bigint` or `numeric`, which arrive as
 * strings — so there is nothing to parse and nothing to round.
 */
export async function skillRatings(
  client: pg.ClientBase,
  playerId: string,
): Promise<readonly SkillRating[]> {
  const result = await client.query<{
    skill_id: number;
    rating: number;
    deviation: number;
    updated_at: Date;
  }>(
    `SELECT skill_id, rating, deviation, updated_at
       FROM user_skills
      WHERE player_id = $1::uuid
      ORDER BY skill_id`,
    [playerId],
  );
  return result.rows.map((row) => ({
    skillId: row.skill_id,
    rating: row.rating,
    deviation: row.deviation,
    updatedAt: row.updated_at,
  }));
}
