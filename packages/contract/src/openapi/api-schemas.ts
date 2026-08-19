import { z } from "zod";

import { KEYPAD_LAYOUTS } from "../keypad-layout.js";

/**
 * The request and response shapes the API serves.
 *
 * **Nothing here is invented.** `ItemResponse`, `AttemptSubmission` and `Verdict`
 * are transcribed from ADR 0001's spike, which carries them verbatim; the rest
 * are the endpoints `ARCHITECTURE.md` §5 names. Where a shape is genuinely
 * unstated it is an open question in `design.md`, because a specification is
 * expensive to change once a client is written against it and that is the whole
 * reason for freezing it early.
 *
 * Three invariants are visible in what is **absent**, and each has a test
 * sweeping the emitted document for it rather than trusting this comment:
 *
 * - No `templateId`, `templateVersion` or `seed`, anywhere. Those reconstruct
 *   the problem; `ARCHITECTURE.md` §4 is explicit that they never travel and
 *   that the client answers with the item id alone.
 * - No `options` on the item response. `ARCHITECTURE.md`:202 still lists it and
 *   §4's own resolution contradicts it — a field offering a child a set of
 *   answers to pick from is a different product. That line is corrected in this
 *   change.
 * - No correctness field on the submission. §4: the sync endpoint "does not
 *   accept an `ok` field — that is what makes the invariant true by construction
 *   rather than by discipline", and a schema is where by-construction lives.
 */

export const PromptTokenSchema = z.object({
  kind: z.enum(["number", "operator", "blank", "text"]),
  text: z.string(),
});

export const ItemResponseSchema = z.object({
  itemId: z.uuid(),
  prompt: z.array(PromptTokenSchema),
  keypad: z.enum(KEYPAD_LAYOUTS),
});

export const AttemptSubmissionSchema = z.object({
  itemId: z.uuid(),
  /**
   * The rating period. `ARCHITECTURE.md` §5 puts a client-generated session id
   * on every attempt; the frozen `attempts` table has no such column, so today
   * it groups the sync batch in flight and is not persisted. Where it should
   * live is an open question on `f1-core-rederivation`.
   */
  sessionId: z.uuid(),
  answer: z.string(),
  clientTs: z.iso.datetime(),
});

export const VerdictSchema = z.object({
  itemId: z.uuid(),
  ok: z.boolean(),
  /**
   * The diagnosis, opaque on the wire.
   *
   * `ARCHITECTURE.md` §2 forbids response polymorphism outright — no `oneOf`, no
   * `discriminator` — so variance lives inside an object, exactly as the frozen
   * pack format already types a stimulus payload.
   */
  payload: z.record(z.string(), z.unknown()),
});

export const AttemptBatchSchema = z.object({
  attempts: z.array(AttemptSubmissionSchema),
});

export const VerdictBatchSchema = z.object({
  verdicts: z.array(VerdictSchema),
});

export const OfflinePackRefSchema = z.object({
  packId: z.uuid(),
  index: z.int().min(0),
});

export const OfflinePackSchema = z.object({
  packId: z.uuid(),
  issuedAt: z.iso.datetime(),
  expiresAt: z.iso.datetime(),
  /** The pack body, validated by the frozen pack schema rather than here. */
  pack: z.record(z.string(), z.unknown()),
});

/**
 * The three bands `players.age_band` accepts, declared once.
 *
 * **The band is a routing decision, not a demographic** (`CLAUDE.md`): it is
 * what sends a player into child protections or not. Two schemas below carry
 * it, and a set that drifted between them would let a request declare a band
 * the profile can never report back.
 */
const AGE_BANDS = ["under_13", "13_17", "adult"] as const;

/**
 * What a device sends to attach itself to an account.
 *
 * **The band travels with the link, and it has to.** `players.age_band` is NOT
 * NULL with no default, and ADR 0002 removed the guest sync that used to write
 * the row first — an unlinked device holds no session and leaves no row, so
 * this request *is* the row's creation. There is no later request at which the
 * band could arrive and no earlier one at which it could have.
 *
 * It is not read off the account either. Linking is an adult's act, but the
 * player being linked need not be an adult, and reading `adult` off the
 * credential would route a child out of their own protections — the one
 * mistake `age_band` exists to prevent.
 */
export const PlayerLinkSchema = z.object({
  playerId: z.uuid(),
  ageBand: z.enum(AGE_BANDS),
});

export const MeSchema = z.object({
  playerId: z.uuid(),
  ageBand: z.enum(AGE_BANDS),
  createdAt: z.iso.datetime(),
});

export const StandingSchema = z.object({
  playerId: z.uuid(),
  skills: z.array(
    z.object({
      skillId: z.int().min(1),
      rating: z.number(),
      deviation: z.number(),
      updatedAt: z.iso.datetime(),
    }),
  ),
});

export const HistoryEntrySchema = z.object({
  kind: z.enum(["series", "puzzle"]),
  title: z.string(),
  at: z.iso.datetime(),
  score: z.string(),
  /** Null for a puzzle, which carries no rating — drawn, not defensive. */
  ratingDelta: z.int().nullable(),
});

export const HistorySchema = z.object({
  entries: z.array(HistoryEntrySchema),
});

export const ErrorSchema = z.object({
  error: z.string(),
  message: z.string(),
});

/** Every named schema the document publishes, in emission order. */
export const API_SCHEMAS = {
  PromptToken: PromptTokenSchema,
  ItemResponse: ItemResponseSchema,
  AttemptSubmission: AttemptSubmissionSchema,
  AttemptBatch: AttemptBatchSchema,
  Verdict: VerdictSchema,
  VerdictBatch: VerdictBatchSchema,
  OfflinePackRef: OfflinePackRefSchema,
  OfflinePack: OfflinePackSchema,
  PlayerLink: PlayerLinkSchema,
  Me: MeSchema,
  Standing: StandingSchema,
  HistoryEntry: HistoryEntrySchema,
  History: HistorySchema,
  Error: ErrorSchema,
} as const;
