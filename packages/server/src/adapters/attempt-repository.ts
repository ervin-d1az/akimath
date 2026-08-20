import type pg from "pg";
import { fromManifestEntry, type TemplateRef } from "@akimath/core";

import type { AttemptSource } from "../attempts.js";

/**
 * The queries `POST /attempts` needs.
 *
 * **ADAPTER.** SQL and the shape of a row; every decision about what an answer
 * *means* is `../attempts.ts`, which is pure.
 *
 * **Both source tables hand back the same shape, and `@akimath/core` decides
 * what it means.** `issued_items.seed` is `bigint`, OID 20, which
 * node-postgres returns as a raw string precisely because a JavaScript number
 * cannot hold it; `offline_packs.template_refs` is `jsonb`, parsed with
 * `JSON.parse`, so migration 0002 forbids a numeric seed inside it for the
 * same reason. So both arrive as `{template_id, template_version, seed,
 * ladder_step}` with the seed as text, and `fromManifestEntry` is the single
 * definition of how that is read — shared with the pack builder that will
 * write it, rather than matched against a comment.
 *
 * A malformed entry is answered as "no such item" rather than thrown: it is
 * the server's problem, and the alternative is a 500 for the whole batch over
 * one bad row in a pack nobody can fix from the client side.
 */

/**
 * The reference behind an issued item, or null if this player has no such item.
 *
 * **Scoped to the player, not just the id.** An item id is a uuid a caller
 * could have seen anywhere; without the `player_id` clause, one account could
 * record attempts against another's issued items.
 */
export async function refForIssuedItem(
  client: pg.ClientBase,
  playerId: string,
  itemId: string,
): Promise<TemplateRef | null> {
  const result = await client.query<{
    template_id: string;
    template_version: number;
    seed: string;
    ladder_step: number;
  }>(
    `SELECT template_id, template_version, seed::text AS seed, ladder_step
       FROM issued_items
      WHERE id = $1::uuid AND player_id = $2::uuid`,
    [itemId, playerId],
  );
  const row = result.rows[0];
  return row === undefined ? null : fromManifestEntry(row);
}

/**
 * The reference behind a pack item, or null.
 *
 * **An expired pack still grades.** `expires_at` governs whether a device may
 * keep *playing* a pack, and a phone that was offline for a fortnight is
 * carrying attempts that were legitimately earned. Refusing them here would
 * throw away a child's week because their sync was late.
 *
 * The index is read in SQL rather than by pulling the whole manifest across:
 * a fifty-item pack is one jsonb value, and a batch of fifty attempts against
 * it would otherwise fetch it fifty times.
 */
export async function refForPackItem(
  client: pg.ClientBase,
  playerId: string,
  packId: string,
  index: number,
): Promise<TemplateRef | null> {
  const result = await client.query<{ ref: unknown }>(
    `SELECT template_refs -> $3::int AS ref
       FROM offline_packs
      WHERE id = $1::uuid AND player_id = $2::uuid`,
    [packId, playerId, index],
  );
  const row = result.rows[0];
  return row === undefined ? null : fromManifestEntry(row.ref);
}

/** One graded attempt, ready for the table. */
export interface AttemptRow {
  readonly playerId: string;
  readonly source: AttemptSource;
  readonly skillId: number;
  readonly isCorrect: boolean;
  readonly elapsedMs: number;
  readonly answeredAt: string;
}

/**
 * Appends the batch, in one statement.
 *
 * **`gen_random_uuid()` rather than an id from here.** `attempts.id` has no
 * default and no caller ever names it, so minting it in SQL keeps the one
 * source of randomness in the database and out of a module that would then
 * need a generator injected to stay testable.
 *
 * **One statement, not one per row.** A batch is already inside a transaction,
 * so correctness does not depend on it; two hundred round trips instead of one
 * does.
 *
 * **No `ON CONFLICT`, and no unique key to hang one on.** A client that retries
 * a batch after a timeout records it twice. That is a real gap, it is written
 * down in `CLAUDE.md`, and closing it needs a decision this change does not
 * make: the natural key would have to distinguish a retry from a legitimate
 * replay of the same pack item, and whether replaying is a product feature is
 * not settled.
 */
export async function insertAttempts(
  client: pg.ClientBase,
  rows: readonly AttemptRow[],
): Promise<number> {
  if (rows.length === 0) {
    return 0;
  }
  const values: unknown[] = [];
  const tuples = rows.map((row, position) => {
    const at = position * 7;
    values.push(
      row.playerId,
      row.source.kind === "issued" ? row.source.itemId : null,
      row.source.kind === "pack" ? row.source.packId : null,
      row.source.kind === "pack" ? row.source.index : null,
      row.skillId,
      row.isCorrect,
      row.elapsedMs,
    );
    return (
      `(gen_random_uuid(), $${at + 1}::uuid, $${at + 2}::uuid, $${at + 3}::uuid, ` +
      `$${at + 4}::smallint, $${at + 5}::smallint, $${at + 6}::boolean, ` +
      `$${at + 7}::integer, $${rows.length * 7 + position + 1}::timestamptz)`
    );
  });
  values.push(...rows.map((row) => row.answeredAt));

  const result = await client.query(
    `INSERT INTO attempts
       (id, player_id, issued_item_id, pack_id, pack_index, skill_id, is_correct, elapsed_ms, answered_at)
     VALUES ${tuples.join(", ")}`,
    values,
  );
  return result.rowCount ?? 0;
}
