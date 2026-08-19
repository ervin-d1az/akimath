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
