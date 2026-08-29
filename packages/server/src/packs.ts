import { parsePack, type Pack } from "@akimath/contract";
import { toDigestEntry, type ManifestEntry } from "@akimath/core";

import type { Response } from "./routing.js";

/**
 * What an issued offline pack contains.
 *
 * **PURE.** Content and two instants in; a pack and its manifest out. The clock
 * is the adapter's, which is what lets this be compared object-to-object.
 *
 * **There used to be a generator here** — `issuedPack`, which made a pack of
 * twenty template items with fresh seeds. It went when `POST /packs` started
 * issuing a copy of the pack the app ships: eighty authored items and
 * thirty-five boards against twenty integer subtractions, and after migration
 * 0005 both are equally gradeable. Nothing called it, and code nothing calls is
 * a claim about what the server does that is not true. It comes back with a
 * caller, written against one.
 */

/**
 * How long an issued pack stays playable, in milliseconds — thirty times a day.
 *
 * The window is the client's licence to keep playing offline, not a retention
 * figure: `retention.ts` owns those and this is not one of them. A pack that
 * has run out still grades at sync, because an attempt earned inside the window
 * is not made wrong by a late sync.
 */
export const PACK_LIFETIME_MS = 30 * 24 * 60 * 60 * 1000;

export interface IssuedPack {
  readonly pack: Pack;
  /** Exactly one entry per item, in the same order — that is what makes
   * `(packId, index)` address anything. */
  readonly manifest: readonly ManifestEntry[];
}

/** An instant, spelled the way every date-time in the contract is. */
function instant(at: Date): string {
  return at.toISOString();
}

/** When an issued pack stops being playable. */
export function packExpiry(issuedAt: Date): Date {
  return new Date(issuedAt.getTime() + PACK_LIFETIME_MS);
}

/**
 * What `offline_packs.content_id` records: a name **and** the bytes it named.
 *
 * **A name on its own is not an identity.** The column used to hold `starter`,
 * which resolves to whatever the build ships today — so editing an item inside
 * `packages/core/pack/starter.json`, the ordinary content act `npm run
 * build:pack` exists to make easy, re-pointed every outstanding row. A device
 * re-fetching within the thirty-day window got today's item at index *i* and
 * was graded against the digest of the *old* item at index *i*: a right answer
 * recorded `ok: false` in a table the request path can neither UPDATE nor
 * DELETE. Measured, not reasoned about — `test/pack-content-is-pinned.test.ts`
 * constructs it from a two-item reorder.
 *
 * Pinning the bytes turns "the artifact changed" into the fact migration 0006
 * already anticipated for this column — *an unknown name is a 404 from a server
 * that no longer ships it* — so `getOfflinePack` needs no new branch and the
 * client's own answer to a 404 is to ask for a new pack.
 *
 * `artifactDigest` is a digest of the file as it was read, so bytes that are
 * equal parse equal: this can refuse a pack the content did not really change
 * under, and can never accept one it did. A pack is worth thirty days and a
 * fresh one costs one request, so that is the direction to be wrong in.
 */
export function contentIdFor(name: string, artifactDigest: string): string {
  return `${name}@${artifactDigest}`;
}

/** The frozen `OfflinePack`, once the row has an id. */
export function offlinePackResponse(packId: string, issued: IssuedPack): Response {
  return {
    status: 200,
    body: {
      packId,
      issuedAt: issued.pack.issued_at,
      expiresAt: issued.pack.expires_at,
      // The pack body as the client will parse it — the same object this
      // module already put through `parsePack`.
      pack: issued.pack,
    },
  };
}

/**
 * The answer a pack this player does not have earns.
 *
 * **404 and not 403.** A pack id belonging to somebody else and a pack id that
 * never existed are the same fact to a caller who is entitled to neither, and
 * telling them apart would confirm that a stranger's pack exists.
 */
export function noSuchPackResponse(): Response {
  return {
    status: 404,
    body: {
      error: "no_such_pack",
      message: "There is no pack with that id for this player.",
    },
  };
}

/**
 * A shipped pack, issued as a copy of itself.
 *
 * **The content a player would actually choose.** Eighty items across six
 * families and thirty-five boards, against the twenty integer subtractions
 * `issuedPack` can generate — and until 0005 the generated ones were the only
 * pack anything could grade, so the worse content was the only content the
 * loop reached.
 *
 * **Every entry is a digest.** The artifact records what each item *is*, not
 * what made it: an authored item never had a template, and a generated one's
 * seed is not written into the pack it ends up in. So all eighty are graded by
 * verifying `HMAC(pack_salt, canonicalize(what was typed))` — and the server
 * never learns any of the eighty answers.
 *
 * **The two timestamps are the row's, not the artifact's.** A pack built in
 * August and issued in November is playable for a month from November; the
 * artifact's own window belongs to the build, and neither timestamp is
 * digested, so replacing them changes no item.
 *
 * **The puzzles come through untouched and have no manifest entries.** A puzzle
 * leaves no row in any table, so nothing can grade one, and `(packId, index)`
 * addresses `items` — a boards entry would shift every index after it.
 */
export function issuedCopy(options: {
  readonly content: Pack;
  readonly issuedAt: Date;
  readonly expiresAt: Date;
}): IssuedPack {
  const pack: Pack = {
    ...options.content,
    issued_at: instant(options.issuedAt),
    expires_at: instant(options.expiresAt),
  };

  // Validated, for the reason `packOf` is: the same check the client runs, so a
  // pack this server would not accept never leaves it.
  const checked = parsePack(pack);
  if (!checked.ok) {
    throw new Error(`the issued copy is not a pack: ${checked.tag}`);
  }

  return {
    pack: checked.pack,
    manifest: checked.pack.items.map((item) =>
      toDigestEntry({ digest: item.answer.digest, skillId: item.skill_id }),
    ),
  };
}
