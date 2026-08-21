import type pg from "pg";

import {
  difficultyKey,
  type RatedDifficulty,
  type RatedSkill,
  type SessionDelta,
  type StoredSkill,
} from "../rating.js";
import type { Skill } from "@akimath/core";

/**
 * The queries the rating needs, and nothing else.
 *
 * **ADAPTER.** Four statements and a lock; every decision about what a rating
 * *means* is `../rating.ts`, which is pure and tested without a socket.
 *
 * **It runs as `app_request`, and that is not a preference.** Migration 0001
 * already grants that role `SELECT, INSERT, UPDATE` on `user_skills` — the
 * rating was always going to be written from the request path, which is why the
 * grant was written before anything could use it. The alternative role,
 * `retention_job`, holds no INSERT or UPDATE anywhere by that migration's stated
 * rule, and `inErasureRole` is pinned to a single caller by
 * `test/one-way-to-erase.test.ts`. So no migration was needed to *write* a
 * rating; `difficulty_ratings` (0007) is a new table, not a new permission.
 *
 * **`real[]` on the way in, matching the columns.** `@akimath/core` narrows
 * every figure it returns to float32 precisely so that what is stored is what
 * was computed; binding them as `double precision` would round-trip through a
 * wider type and reintroduce the drift that narrowing removed.
 */

/**
 * Serialises two devices syncing for the same player.
 *
 * `ARCHITECTURE.md` §5 names this: "`pg_advisory_xact_lock` to serialize two
 * devices". The read of the prior and the write of the posterior are separate
 * statements with a computation between them, so without it two concurrent
 * batches both read the same rating and one of them is silently discarded.
 *
 * **An advisory lock and not `SELECT … FOR UPDATE`.** A player being rated for
 * the first time has no `user_skills` row, and a row lock cannot lock a row
 * that is not there — which is exactly the case two devices racing on a fresh
 * account produce.
 *
 * Released by the transaction, always: `inRequestRole` commits or rolls back,
 * and `xact` locks go with it either way.
 *
 * The namespace keeps this lock from colliding with any other advisory lock
 * this database might grow; the second key is the player.
 */
const RATING_LOCK_NAMESPACE = 0x9a71;

export async function lockPlayerRating(
  client: pg.ClientBase,
  playerId: string,
): Promise<void> {
  await client.query("SELECT pg_advisory_xact_lock($1::int, hashtext($2::text))", [
    RATING_LOCK_NAMESPACE,
    playerId,
  ]);
}

/** The player's stored ratings for the skills this batch touched. */
export async function storedSkills(
  client: pg.ClientBase,
  playerId: string,
  skillIds: readonly number[],
): Promise<ReadonlyMap<number, StoredSkill>> {
  if (skillIds.length === 0) {
    return new Map();
  }
  const result = await client.query<{
    skill_id: number;
    rating: number;
    deviation: number;
    updated_at: Date;
  }>(
    `SELECT skill_id, rating, deviation, updated_at
       FROM user_skills
      WHERE player_id = $1::uuid AND skill_id = ANY($2::smallint[])`,
    [playerId, skillIds],
  );
  return new Map(
    result.rows.map((row) => [
      row.skill_id,
      { rating: row.rating, deviation: row.deviation, updatedAt: row.updated_at },
    ]),
  );
}

/** One difficulty class this batch met. */
export interface DifficultyClass {
  readonly skillId: number;
  readonly ladderStep: number;
}

/**
 * What the players have measured about the classes this batch met.
 *
 * **Joined against the exact pairs, not the cross product of two `ANY`s.** A
 * batch spanning skills 1 and 2 at steps 3 and 4 asks about two classes and
 * `ANY … AND ANY …` would answer about four — and a class that was never
 * attempted would arrive looking calibrated, which changes what the pure layer
 * decides.
 *
 * A class with no row is absent rather than defaulted: "nobody has measured
 * this" is the distinction the whole rating turns on, and a default here would
 * erase it before `rateAttempts` could see it.
 */
export async function measuredDifficulties(
  client: pg.ClientBase,
  wanted: readonly DifficultyClass[],
): Promise<ReadonlyMap<string, Skill>> {
  if (wanted.length === 0) {
    return new Map();
  }
  const result = await client.query<{
    skill_id: number;
    ladder_step: number;
    rating: number;
    deviation: number;
  }>(
    `SELECT d.skill_id, d.ladder_step, d.rating, d.deviation
       FROM difficulty_ratings d
       JOIN unnest($1::smallint[], $2::smallint[]) AS want(skill_id, ladder_step)
         ON d.skill_id = want.skill_id AND d.ladder_step = want.ladder_step`,
    [wanted.map((one) => one.skillId), wanted.map((one) => one.ladderStep)],
  );
  return new Map(
    result.rows.map((row) => [
      difficultyKey(row.skill_id, row.ladder_step),
      { rating: row.rating, deviation: row.deviation },
    ]),
  );
}

/**
 * Writes the player's new ratings.
 *
 * `updated_at` is `now()` — the transaction's clock, which is what `decay`
 * measures against next time. A client's `clientTs` is not used for it: a
 * device whose clock is wrong would otherwise be able to age its own rating.
 */
export async function writeSkills(
  client: pg.ClientBase,
  playerId: string,
  skills: readonly RatedSkill[],
): Promise<void> {
  if (skills.length === 0) {
    return;
  }
  await client.query(
    `INSERT INTO user_skills (player_id, skill_id, rating, deviation, updated_at)
     SELECT $1::uuid, s.skill_id, s.rating, s.deviation, now()
       FROM unnest($2::smallint[], $3::real[], $4::real[])
            AS s(skill_id, rating, deviation)
     ON CONFLICT (player_id, skill_id) DO UPDATE
        SET rating = EXCLUDED.rating,
            deviation = EXCLUDED.deviation,
            updated_at = EXCLUDED.updated_at`,
    [
      playerId,
      skills.map((one) => one.skillId),
      skills.map((one) => one.rating),
      skills.map((one) => one.deviation),
    ],
  );
}

/**
 * Writes what each rating period moved, so `GET /me/history` can report it.
 *
 * **It adds rather than replaces, and that is the whole conflict clause.** A
 * session can reach the server in two batches — a device flushes what it has,
 * the player answers more of the same session, it flushes again — and each
 * batch is a rating period of its own against the prior the one before it left.
 * What the session moved is therefore the sum, and keeping only the last write
 * would drop everything the earlier flushes did.
 *
 * A *resent* batch never gets here: `insertAttempts` is `ON CONFLICT DO
 * NOTHING`, so nothing lands, no period is formed, and `rateAttempts` returns
 * no deltas at all.
 *
 * `created_at` is deliberately not touched on conflict — it is when the session
 * was first recorded, which is what the retention sweep ages the row by.
 */
export async function writeSessionDeltas(
  client: pg.ClientBase,
  playerId: string,
  deltas: readonly SessionDelta[],
): Promise<void> {
  if (deltas.length === 0) {
    return;
  }
  await client.query(
    `INSERT INTO session_deltas (player_id, session_id, skill_id, rating_delta)
     SELECT $1::uuid, d.session_id, d.skill_id, d.rating_delta
       FROM unnest($2::uuid[], $3::smallint[], $4::real[])
            AS d(session_id, skill_id, rating_delta)
     ON CONFLICT (player_id, session_id, skill_id) DO UPDATE
        SET rating_delta = session_deltas.rating_delta + EXCLUDED.rating_delta`,
    [
      playerId,
      deltas.map((one) => one.sessionId),
      deltas.map((one) => one.skillId),
      deltas.map((one) => one.change),
    ],
  );
}

/** Writes what the batch measured about the classes it met. */
export async function writeDifficulties(
  client: pg.ClientBase,
  difficulties: readonly RatedDifficulty[],
): Promise<void> {
  if (difficulties.length === 0) {
    return;
  }
  await client.query(
    `INSERT INTO difficulty_ratings (skill_id, ladder_step, rating, deviation, updated_at)
     SELECT d.skill_id, d.ladder_step, d.rating, d.deviation, now()
       FROM unnest($1::smallint[], $2::smallint[], $3::real[], $4::real[])
            AS d(skill_id, ladder_step, rating, deviation)
     ON CONFLICT (skill_id, ladder_step) DO UPDATE
        SET rating = EXCLUDED.rating,
            deviation = EXCLUDED.deviation,
            updated_at = EXCLUDED.updated_at`,
    [
      difficulties.map((one) => one.skillId),
      difficulties.map((one) => one.ladderStep),
      difficulties.map((one) => one.rating),
      difficulties.map((one) => one.deviation),
    ],
  );
}
