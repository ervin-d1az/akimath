import type pg from "pg";
import {
  fromManifestEntry,
  templateRefOf,
  type ManifestEntry,
  type TemplateRef,
} from "@akimath/core";

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
  /**
   * Which shipped pack this row is a copy of, or null when it is generated.
   *
   * A generated pack is fully described by its manifest; a copy names content
   * the server already holds, because the body is 158 KB and it is the same
   * 158 KB for every player.
   */
  readonly contentId: string | null;
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
       (id, player_id, skill_id, item_refs, pack_salt, issued_at, expires_at, content_id)
     VALUES (gen_random_uuid(), $1::uuid, $2::smallint, $3::jsonb,
             decode($4, 'hex'), $5::timestamptz, $6::timestamptz, $7)
     RETURNING id`,
    [
      pack.playerId,
      pack.skillId,
      JSON.stringify(pack.manifest),
      pack.saltHex,
      pack.issuedAt.toISOString(),
      pack.expiresAt.toISOString(),
      pack.contentId,
    ],
  );
  const row = result.rows[0];
  if (row === undefined) {
    throw new Error("the insert returned no row");
  }
  return row.id;
}

/** A stored pack, as far as the database can say what one is. */
export interface StoredPack {
  /** Names the shipped content this row copies, or null when it is generated. */
  readonly contentId: string | null;
  /** One per item, in stored order, whichever kind each turned out to be. */
  readonly entries: readonly ManifestEntry[];
  readonly saltHex: string;
  readonly issuedAt: Date;
  readonly expiresAt: Date;
}

/**
 * The pack a player already has, or null.
 *
 * **Scoped to the player.** A pack id is a uuid a caller could have seen
 * anywhere; without the `player_id` clause one account could read another's
 * pack, and a pack is a list of items with their answer digests.
 *
 * **An expired pack is still returned.** `expires_at` says a device may not
 * keep *playing* it, and that is the client's rule to enforce — the pack
 * carries the field. Refusing to hand back a pack whose attempts are still
 * unsynced would strand them.
 *
 * A manifest entry that will not read makes the whole pack null rather than a
 * pack with a hole in it: `(packId, index)` addresses items by position, and a
 * pack that quietly dropped one would shift every index after it.
 */
export async function packFor(
  client: pg.ClientBase,
  playerId: string,
  packId: string,
): Promise<StoredPack | null> {
  const result = await client.query<{
    item_refs: unknown[];
    salt_hex: string;
    issued_at: Date;
    expires_at: Date;
    content_id: string | null;
  }>(
    `SELECT item_refs,
            encode(pack_salt, 'hex') AS salt_hex,
            issued_at,
            expires_at,
            content_id
       FROM offline_packs
      WHERE id = $1::uuid AND player_id = $2::uuid`,
    [packId, playerId],
  );
  const row = result.rows[0];
  if (row === undefined) {
    return null;
  }

  const entries: ManifestEntry[] = [];
  for (const value of row.item_refs) {
    const entry = fromManifestEntry(value);
    if (entry === null) {
      return null;
    }
    entries.push(entry);
  }
  return {
    contentId: row.content_id,
    entries,
    saltHex: row.salt_hex,
    issuedAt: row.issued_at,
    expiresAt: row.expires_at,
  };
}
