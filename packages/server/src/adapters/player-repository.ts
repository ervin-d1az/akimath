import type pg from "pg";

import type { PlayerRow } from "../players.js";

/**
 * The one query `GET /me` needs.
 *
 * **ADAPTER.** It holds SQL and nothing else; what the answer *means* is
 * `players.ts`, which is pure.
 *
 * The columns are named rather than `SELECT *`: a later migration adding a
 * column would otherwise start handing it to a function that never asked for
 * it, and `players` is the table this repository is most careful about.
 *
 * **`auth_user_id` is compared as a `uuid`.** The parameter arrives as the
 * token's `sub`, already checked into shape by `isAccountId` before any
 * connection was borrowed — so this cast cannot be where a bad subject becomes
 * a 500.
 */
export async function findPlayerForAccount(
  client: pg.ClientBase,
  accountId: string,
): Promise<PlayerRow | null> {
  const result = await client.query<PlayerRow>(
    `SELECT id, age_band, created_at
       FROM players
      WHERE auth_user_id = $1::uuid`,
    [accountId],
  );
  return result.rows[0] ?? null;
}

/**
 * The player already linked to an account, or null.
 *
 * Just the id: the caller is deciding whether a link may happen, not showing a
 * profile, and `SELECT id` is the whole of what that decision needs.
 */
export async function playerIdForAccount(
  client: pg.ClientBase,
  accountId: string,
): Promise<string | null> {
  const result = await client.query<{ id: string }>(
    "SELECT id FROM players WHERE auth_user_id = $1::uuid",
    [accountId],
  );
  return result.rows[0]?.id ?? null;
}

/**
 * The account a player already belongs to, or null.
 *
 * **The other half of the question**, and it is a different refusal: an account
 * that already has a player is one problem, and a player that already belongs
 * to somebody else is another. A device can hand its `player_id` on by
 * restoring a backup, so this is not hypothetical.
 */
export async function accountForPlayer(
  client: pg.ClientBase,
  playerId: string,
): Promise<string | null> {
  const result = await client.query<{ auth_user_id: string }>(
    "SELECT auth_user_id FROM players WHERE id = $1::uuid",
    [playerId],
  );
  return result.rows[0]?.auth_user_id ?? null;
}

/**
 * Writes the row and hands back what was written.
 *
 * `RETURNING` rather than a second `SELECT`: `created_at` is the database's
 * (`DEFAULT now()`), and reading it back in another statement is a round trip
 * that can also disagree.
 *
 * **The account comes from the caller's session**, never from the body — see
 * `readLinkRequest`, which refuses a body that mentions it at all.
 */
export async function insertPlayer(
  client: pg.ClientBase,
  player: { readonly id: string; readonly ageBand: string; readonly accountId: string },
): Promise<PlayerRow> {
  const result = await client.query<PlayerRow>(
    `INSERT INTO players (id, age_band, auth_user_id)
          VALUES ($1::uuid, $2, $3::uuid)
       RETURNING id, age_band, created_at`,
    [player.id, player.ageBand, player.accountId],
  );
  const row = result.rows[0];
  if (row === undefined) {
    throw new Error("the insert returned no row");
  }
  return row;
}

/**
 * Deletes the account's player, and says whether there was one.
 *
 * **The cascade is the erasure.** Five tables reference `players (id)` with
 * `ON DELETE CASCADE` — `issued_items`, `offline_packs`, `attempts`,
 * `user_skills`, `diag_events` — so one statement takes all of them, and
 * `test/delete-me.test.ts` counts the rows in every one rather than trusting
 * the schema to still say that. Referential actions run as the referencing
 * table's owner, so those child rows go whatever the deleting role is granted;
 * the grants exist for the retention job, which deletes from two of them
 * directly.
 *
 * **This must be called under `retention_job`.** `app_request` holds DELETE on
 * no table at all (`test/grants.test.ts`), which is what makes the
 * append-only-attempts invariant structural rather than a promise.
 *
 * `rowCount` rather than `RETURNING`: the caller is deciding between 204 and
 * 404 and has no use for the row it just destroyed.
 */
export async function deletePlayerForAccount(
  client: pg.ClientBase,
  accountId: string,
): Promise<boolean> {
  const result = await client.query("DELETE FROM players WHERE auth_user_id = $1::uuid", [
    accountId,
  ]);
  return (result.rowCount ?? 0) > 0;
}
