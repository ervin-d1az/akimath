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
       (id, player_id, skill_id, item_refs, pack_salt, issued_at, expires_at)
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

/** A stored pack, as far as the database can say what one is. */
export interface StoredPack {
  readonly refs: readonly TemplateRef[];
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
 *
 * **A pack carrying authored items cannot be rebuilt, and answers 404 today.**
 * A digest entry has no reference, so there is nothing to regenerate the item
 * from — the digest identifies an answer, not a prompt. `POST /attempts` grades
 * such an item perfectly well, because grading only needs the digest; what a
 * re-fetch needs is the *content*, which lives in the pack body and is not
 * stored. Serving it back means storing it, and that is the next decision
 * rather than a silent hole here.
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
  }>(
    `SELECT item_refs,
            encode(pack_salt, 'hex') AS salt_hex,
            issued_at,
            expires_at
       FROM offline_packs
      WHERE id = $1::uuid AND player_id = $2::uuid`,
    [packId, playerId],
  );
  const row = result.rows[0];
  if (row === undefined) {
    return null;
  }

  const refs: TemplateRef[] = [];
  for (const entry of row.item_refs) {
    const read = fromManifestEntry(entry);
    const ref = read === null ? null : templateRefOf(read);
    if (ref === null) {
      // A digest entry has no reference and never will. `GET /packs/{packId}`
      // rebuilds from references, so a pack carrying authored items cannot be
      // rebuilt — see `packFor`'s own note.
      return null;
    }
    refs.push(ref);
  }
  return {
    refs,
    saltHex: row.salt_hex,
    issuedAt: row.issued_at,
    expiresAt: row.expires_at,
  };
}
