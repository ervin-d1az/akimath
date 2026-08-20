import type pg from "pg";
import type { ManifestEntry } from "@akimath/core";

/**
 * Writing an issued pack down.
 *
 * **ADAPTER.** One statement and the two spellings a salt has.
 *
 * **`pack_salt` is `bytea` in the column and 32 lowercase hex characters in the
 * frozen format.** Sixteen bytes either way; `decode(..., 'hex')` is where the
 * two meet, and it is here rather than in the pure module because the column's
 * type is a storage decision and the format's is a contract.
 */
export interface PackToStore {
  readonly playerId: string;
  /** The one skill an issued pack draws from today. */
  readonly skillId: number;
  readonly manifest: readonly ManifestEntry[];
  readonly saltHex: string;
  readonly issuedAt: Date;
  readonly expiresAt: Date;
}

/**
 * Appends the row and hands back the id the database minted.
 *
 * `gen_random_uuid()` with `RETURNING`, for the reason `insertPlayer` uses
 * `RETURNING`: the id belongs to the row, and reading it back in a second
 * statement is a round trip that can also disagree.
 *
 * **The manifest goes in as one `jsonb` value with its seeds as strings.**
 * Migration 0002 refuses a numeric seed inside `template_refs`, because jsonb
 * is read with `JSON.parse` and a bigint above 2^53 comes back wrong —
 * `toManifestEntry` has already spelled them, and this only has to not undo it.
 */
export async function insertPack(
  client: pg.ClientBase,
  pack: PackToStore,
): Promise<string> {
  const result = await client.query<{ id: string }>(
    `INSERT INTO offline_packs
       (id, player_id, skill_id, template_refs, pack_salt, issued_at, expires_at)
     VALUES (gen_random_uuid(), $1::uuid, $2::smallint, $3::jsonb,
             decode($4, 'hex'), $5::timestamptz, $6::timestamptz)
     RETURNING id`,
    [
      pack.playerId,
      pack.skillId,
      JSON.stringify(pack.manifest),
      pack.saltHex,
      pack.issuedAt.toISOString(),
      pack.expiresAt.toISOString(),
    ],
  );
  const row = result.rows[0];
  if (row === undefined) {
    throw new Error("the insert returned no row");
  }
  return row.id;
}
