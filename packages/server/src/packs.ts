import {
  answerDigest,
  parsePack,
  storedAnswer,
  type Item,
  type Pack,
} from "@akimath/contract";
import { toDigestEntry } from "@akimath/core";
import {
  coreRegistry,
  fallbackDiagnosis,
  issuable,
  rederive,
  resolve,
  toManifestEntry,
  type ManifestEntry,
  type TemplateRef,
  type TemplateRegistry,
} from "@akimath/core";

import type { Response } from "./routing.js";

/**
 * What an issued offline pack contains.
 *
 * **PURE.** Seeds, a salt and an instant in; a pack and its manifest out. The
 * randomness and the clock are the adapter's, which is what lets this be
 * compared object-to-object.
 *
 * **Every item is generated from a template, and that is a constraint rather
 * than a simplification.** An attempt against a pack item names it by
 * `(packId, index)` and the server grades it by rederiving
 * `item_refs[index]` — so an item with no template reference cannot be
 * graded at all. Authored content carries none. It is therefore not issued this
 * way, and the contract's operation says so.
 *
 * **What that means for the player, said plainly:** with one template family
 * written, an issued pack is twenty integer subtractions. It is worse content
 * than the seventy authored items the app already ships, and nothing should
 * prefer it until there is a second family or a rating to make the ladder move.
 * What this closes is the *mechanism* — issue, play offline, sync, grade —
 * which had no first step.
 */

/** How many items an issued pack carries. */
export const PACK_ITEM_COUNT = 20;

/**
 * How long an issued pack stays playable, in milliseconds — thirty times a day.
 *
 * The window is the client's licence to keep playing offline, not a retention
 * figure: `retention.ts` owns those and this is not one of them. A pack that
 * has run out still grades at sync, because an attempt earned inside the window
 * is not made wrong by a late sync.
 */
export const PACK_LIFETIME_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Which rung an issued pack is drawn at.
 *
 * Fixed, because moving it is a rating decision and rating is F4. The number
 * matches the shipped declaration's, so an issued pack and the built one are
 * the same difficulty rather than accidentally different ones.
 */
export const PACK_LADDER_STEP = 3;

export interface IssuedPack {
  readonly pack: Pack;
  /** Exactly one entry per item, in the same order — that is what makes
   * `(packId, index)` address anything. */
  readonly manifest: readonly ManifestEntry[];
}

export interface IssueOptions {
  /** 32 lowercase hex characters, as the frozen format requires. */
  readonly saltHex: string;
  /** One per item. The caller decides how many, so the count is testable. */
  readonly seeds: readonly bigint[];
  readonly issuedAt: Date;
  readonly registry?: TemplateRegistry;
}

/** An instant, spelled the way every date-time in the contract is. */
function instant(at: Date): string {
  return at.toISOString();
}

/**
 * A pack, and the manifest that lets every item in it be graded later.
 *
 * The two are built together and in the same order on purpose: they are the
 * same list seen from the two ends of the offline loop, and the day they
 * diverge every pack attempt resolves to the wrong item and grades silently
 * wrong. `test/packs.test.ts` rederives each manifest entry and compares its
 * digest to the item beside it.
 */
export function issuedPack(options: IssueOptions): IssuedPack {
  const registry = options.registry ?? coreRegistry();
  const template = issuable(registry)[0];
  if (template === undefined) {
    // Unreachable while any version is issuable, and thrown rather than
    // answered because a server with no content is not a client's problem.
    throw new Error("no template is issuable, so there is nothing to put in a pack");
  }

  return packOf({
    refs: options.seeds.map((seed) => ({
      templateId: template.id,
      templateVersion: template.version,
      seed,
      ladderStep: PACK_LADDER_STEP,
    })),
    saltHex: options.saltHex,
    issuedAt: options.issuedAt,
    expiresAt: packExpiry(options.issuedAt),
    registry,
  });
}

export interface RebuildOptions {
  /** Read back from `offline_packs.item_refs`, in stored order. */
  readonly refs: readonly TemplateRef[];
  readonly saltHex: string;
  readonly issuedAt: Date;
  /** Stored rather than recomputed: the window belongs to the row. */
  readonly expiresAt: Date;
  readonly registry?: TemplateRegistry;
}

/**
 * The pack a stored manifest stands for.
 *
 * **A re-fetch rebuilds rather than reads a body**, which is why
 * `offline_packs` stores fifty references and not fifty rows — the whole point
 * of the manifest (`ARCHITECTURE.md` §4). What comes back is the same pack:
 * every digest is `HMAC(pack_salt, canonical answer)`, the salt is stored, the
 * answers rederive from the references, and both timestamps are columns.
 *
 * **The one thing that can differ is prose.** The skill's fallback diagnosis is
 * copy, and copy gets edited. It is not part of any digest and no attempt is
 * graded against it, so a re-fetch that reads better than the original is a
 * re-fetch that reads better — not a different pack.
 */
export function packOf(options: RebuildOptions): IssuedPack {
  const registry = options.registry ?? coreRegistry();
  const refs = options.refs;
  if (refs.length === 0) {
    // The frozen format allows an empty `items`, and an empty pack is still not
    // one — there is nothing to play and nothing to grade. Thrown rather than
    // answered: a stored manifest with no entries is a defect here.
    throw new Error("a pack with no items is not one");
  }

  const items: Item[] = refs.map((ref) => {
    const generated = rederive(registry, ref);
    const { shape, canonical } = storedAnswer(
      generated.answer.numerator,
      generated.answer.denominator,
    );
    return {
      skill_id: resolve(registry, ref).skillId,
      ladder_step: generated.ladderStep,
      keypad: "item",
      stimulus: {
        kind: "arithmetic",
        payload: {
          operator: generated.operator,
          left: generated.left,
          right: generated.right,
        },
      } as Item["stimulus"],
      answer: { shape, digest: answerDigest(options.saltHex, canonical) },
      // **No predicted distractors.** The pack builder predicts two for
      // subtraction and this does not: a wrong answer here meets the skill's
      // fallback copy, which is what fallback copy is for. Predicting them
      // would be a second copy of `distractors.ts` on the far side of a package
      // boundary, and the diagnosis a player sees would depend on which path
      // issued their pack.
      diagnosis: null,
    };
  });

  // Every skill the items actually belong to, sorted, rather than the first
  // template's — a manifest is a list of references and nothing says they all
  // exercise one skill.
  const skills = [...new Set(items.map((item) => item.skill_id))].sort((a, b) => a - b);
  const pack: Pack = {
    pack_format_version: 1,
    pack_salt: options.saltHex,
    issued_at: instant(options.issuedAt),
    expires_at: instant(options.expiresAt),
    skill_nodes: skills.map((skill_id) => ({ skill_id, state: "available" as const })),
    // A skill with items and no fallback is a pack the frozen validator
    // refuses outright (`missing_skill_fallback`), so this is load-bearing.
    skill_fallbacks: skills.map((skill_id) => ({ skill_id, diagnosis: fallbackDiagnosis() })),
    items,
    puzzles: [],
  };

  // **Validated here, not trusted.** The same `parsePack` the client will run,
  // so a pack this server would not accept never leaves it. A rejection is a
  // defect in this function, which is why it throws rather than answering.
  const checked = parsePack(pack);
  if (!checked.ok) {
    throw new Error(`the issued pack is not one: ${checked.tag}`);
  }

  return { pack: checked.pack, manifest: refs.map(toManifestEntry) };
}

/** When an issued pack stops being playable. */
export function packExpiry(issuedAt: Date): Date {
  return new Date(issuedAt.getTime() + PACK_LIFETIME_MS);
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
