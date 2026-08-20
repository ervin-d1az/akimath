import {
  answerDigest,
  parsePack,
  storedAnswer,
  type Item,
  type Pack,
} from "@akimath/contract";
import {
  coreRegistry,
  fallbackDiagnosis,
  issuable,
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
 * `template_refs[index]` — so an item with no template reference cannot be
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

  const refs: TemplateRef[] = options.seeds.map((seed) => ({
    templateId: template.id,
    templateVersion: template.version,
    seed,
    ladderStep: PACK_LADDER_STEP,
  }));

  const items: Item[] = refs.map((ref) => {
    const generated = template.generate(ref);
    const { shape, canonical } = storedAnswer(
      generated.answer.numerator,
      generated.answer.denominator,
    );
    return {
      skill_id: template.skillId,
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

  const expiresAt = new Date(options.issuedAt.getTime() + PACK_LIFETIME_MS);
  const pack: Pack = {
    pack_format_version: 1,
    pack_salt: options.saltHex,
    issued_at: instant(options.issuedAt),
    expires_at: instant(expiresAt),
    skill_nodes: [{ skill_id: template.skillId, state: "available" }],
    // A skill with items and no fallback is a pack the frozen validator
    // refuses outright (`missing_skill_fallback`), so this is load-bearing.
    skill_fallbacks: [{ skill_id: template.skillId, diagnosis: fallbackDiagnosis() }],
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
