import { answerDigest, canonicalize, storedAnswer } from "@akimath/contract";
import {
  coreRegistry,
  rederive,
  resolve,
  type TemplateRef,
  type TemplateRegistry,
} from "@akimath/core";

import type { Response } from "./routing.js";

/**
 * What `POST /attempts` accepts, and what a graded batch answers.
 *
 * **PURE.** A body in, attempts or a refusal out; a reference and a typed
 * answer in, a verdict out. No socket, no clock, no database — the repository
 * beside this resolves a source into a `TemplateRef` and the handler writes the
 * rows.
 *
 * **The answer is graded here, not believed.** `ARCHITECTURE.md` §4: the sync
 * endpoint "does not accept an `ok` field — that is what makes the invariant
 * true by construction rather than by discipline". So the server rederives the
 * item from `(template_id, template_version, seed, ladder_step)` and compares
 * canonical spellings.
 *
 * **Both derivations of "canonical" come from `packages/contract`**, which is
 * the package Dart is golden-tested against. A third comparison written here
 * is exactly the drift risk R2 names, and the pack builder has already been
 * bitten by a second spelling once (`packages/core` #50 — a whole answer
 * digested as `-9/1`).
 */

/** The longest an attempt may claim to have taken. Held to the contract's own
 * `maximum` by `test/attempts.test.ts`, because this package validates by hand
 * rather than with Zod and two derivations of a figure need a gate. */
export const ATTEMPT_ELAPSED_MS_MAX = 3_600_000;

/**
 * How many attempts one request may carry.
 *
 * **A bound, not a guess at a session's length.** A pack is fifty items and a
 * device syncing after a week offline might carry several; two hundred is
 * comfortably above that and far below "an array large enough to be the
 * request that takes the server down". A batch is one transaction, so the cost
 * is real.
 */
export const ATTEMPTS_PER_BATCH_MAX = 200;

/**
 * Which item an attempt answered.
 *
 * Mirrors `attempts_one_source` — `(issued_item_id) XOR (pack_id, pack_index)`.
 * The wire spells it as two optionals because OpenAPI 3.0.3 has no union the
 * hand-written Dart client could read; this is the shape the rest of the server
 * works in, where the exclusivity is a type rather than a rule.
 */
export type AttemptSource =
  | { readonly kind: "issued"; readonly itemId: string }
  | { readonly kind: "pack"; readonly packId: string; readonly index: number };

/** One answered item, believed as far as its shape and no further. */
export interface Attempt {
  readonly source: AttemptSource;
  readonly sessionId: string;
  readonly answer: string;
  readonly clientTs: string;
  readonly elapsedMs: number;
}

const UUID = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

/**
 * `YYYY-MM-DDTHH:MM[:SS[.fff]]Z`, the shape the frozen `date-time` pattern
 * allows — seconds optional, fraction optional, `Z` required.
 *
 * The frozen pattern also encodes leap years in the regex itself. Repeating
 * that here would be a second, subtly different calendar; instead the shape is
 * matched and the *calendar* is checked by round-tripping through `Date`, which
 * rejects 30 February by construction.
 */
const INSTANT = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?Z$/;

function bad(message: string): Response {
  return { status: 400, body: { error: "malformed", message } };
}

/** Whether a string is an instant the frozen pattern would accept. */
export function isFrozenInstant(value: unknown): value is string {
  if (typeof value !== "string") {
    return false;
  }
  const parts = INSTANT.exec(value);
  if (parts === null) {
    return false;
  }
  const [year, month, day, hour, minute] = parts.slice(1, 6).map(Number);
  const at = new Date(
    Date.UTC(year!, month! - 1, day!, hour!, minute!, Number(parts[6] ?? 0)),
  );
  // **Round-tripped, not merely parsed.** `Date.UTC(2026, 1, 30)` is 2 March,
  // and a check that only asked "did it parse" would accept a day February
  // never has — while still having to reject 29 February 2025 and accept 2028.
  //
  // Compared as one rendered date rather than as three components: an overflow
  // always shifts the month, so a separate day comparison is a clause no input
  // can be the sole cause of, and a clause nothing can exercise is dead.
  return at.toISOString().slice(0, 10) === `${parts[1]}-${parts[2]}-${parts[3]}`;
}

const KNOWN_KEYS: readonly string[] = [
  "itemId",
  "packRef",
  "sessionId",
  "answer",
  "clientTs",
  "elapsedMs",
];

function readSource(given: Record<string, unknown>, at: string): AttemptSource | Response {
  const hasItem = given["itemId"] !== undefined;
  const hasPack = given["packRef"] !== undefined;
  if (hasItem === hasPack) {
    return bad(
      `${at} must name exactly one source: itemId for an item this server issued, ` +
        "or packRef for one from an offline pack.",
    );
  }

  if (hasItem) {
    const itemId = given["itemId"];
    // `typeof` first: `RegExp.test` coerces, so `UUID.test([uuid])` is true and
    // an array of one string would pass for an item id.
    if (typeof itemId !== "string" || !UUID.test(itemId)) {
      return bad(`${at}.itemId must be a uuid.`);
    }
    return { kind: "issued", itemId: canonicalUuid(itemId) };
  }

  const packRef = given["packRef"];
  if (typeof packRef !== "object" || packRef === null || Array.isArray(packRef)) {
    return bad(`${at}.packRef must be an object with packId and index.`);
  }
  const ref = packRef as Record<string, unknown>;
  const unknown = Object.keys(ref).filter((key) => key !== "packId" && key !== "index");
  if (unknown.length > 0) {
    return bad(`${at}.packRef carries ${unknown.join(", ")}, which it does not accept.`);
  }
  const packId = ref["packId"];
  if (typeof packId !== "string" || !UUID.test(packId)) {
    return bad(`${at}.packRef.packId must be a uuid.`);
  }
  const index = ref["index"];
  if (typeof index !== "number" || !Number.isInteger(index) || index < 0) {
    return bad(`${at}.packRef.index must be a whole number, zero or more.`);
  }
  return { kind: "pack", packId: canonicalUuid(packId), index };
}

/**
 * A uuid in the one spelling the rest of the server will see.
 *
 * **A uuid is a value, not a spelling, and something has to say so once.** The
 * frozen pattern accepts either case, and Postgres canonicalises to lower case
 * on the way in — so an id handed back by `RETURNING` is not textually the id
 * that was sent. Two things depend on the two matching: the duplicate check
 * below, where the same item named twice in different case is one item and the
 * database's unique index would say so; and the rating, which pairs submitted
 * attempts with the rows that actually landed. Getting the second wrong records
 * the answer and rates nothing, and there is no way back — the row exists, so a
 * resend lands nothing either.
 *
 * Folded here rather than at each comparison, so that everything downstream —
 * the key, the insert, the verdict it echoes — is already speaking one dialect.
 */
function canonicalUuid(value: string): string {
  return value.toLowerCase();
}

function readAttempt(value: unknown, at: string): Attempt | Response {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return bad(`${at} must be a JSON object.`);
  }
  const given = value as Record<string, unknown>;

  // **Unknown properties are refused**, because the frozen schema says
  // `additionalProperties: false` — and one family of unknown property is the
  // whole point: a submission carrying `ok`, `correct` or `score` would be a
  // client grading itself, which §4's invariant exists to make impossible.
  const unknown = Object.keys(given).filter((key) => !KNOWN_KEYS.includes(key));
  if (unknown.length > 0) {
    return bad(`${at} carries ${unknown.join(", ")}, which this operation does not accept.`);
  }

  const source = readSource(given, at);
  if ("status" in source) {
    return source;
  }

  const sessionId = given["sessionId"];
  if (typeof sessionId !== "string" || !UUID.test(sessionId)) {
    return bad(`${at}.sessionId must be a uuid.`);
  }

  const answer = given["answer"];
  if (typeof answer !== "string") {
    // A number would grade against `String(9)`, which happens to work for
    // whole answers and not for `1/2` — the worst kind of nearly-working.
    return bad(`${at}.answer must be a string, exactly as it was typed.`);
  }

  const clientTs = given["clientTs"];
  if (!isFrozenInstant(clientTs)) {
    return bad(`${at}.clientTs must be an instant like 2026-08-19T09:15:00.000Z.`);
  }

  const elapsedMs = given["elapsedMs"];
  if (
    typeof elapsedMs !== "number" ||
    !Number.isInteger(elapsedMs) ||
    elapsedMs < 0 ||
    elapsedMs > ATTEMPT_ELAPSED_MS_MAX
  ) {
    return bad(
      `${at}.elapsedMs must be a whole number of milliseconds between 0 and ${ATTEMPT_ELAPSED_MS_MAX}.`,
    );
  }

  return { source, sessionId, answer, clientTs, elapsedMs };
}

/**
 * The batch, or the reason it is not one.
 *
 * **Every refusal names the index.** A batch of fifty with one bad row is
 * undiagnosable from "the body was malformed", and the client cannot bisect a
 * request it has already sent.
 *
 * An empty batch is accepted. A client syncing "whatever I have" should not
 * need a special case for having nothing; it costs one round trip and no rows.
 */
export function readAttemptBatch(body: unknown): readonly Attempt[] | Response {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return bad("The body must be a JSON object.");
  }
  const given = body as Record<string, unknown>;
  const unknown = Object.keys(given).filter((key) => key !== "attempts");
  if (unknown.length > 0) {
    return bad(`The body carries ${unknown.join(", ")}, which this operation does not accept.`);
  }
  const attempts = given["attempts"];
  if (!Array.isArray(attempts)) {
    return bad("The body must carry an attempts array.");
  }
  if (attempts.length > ATTEMPTS_PER_BATCH_MAX) {
    return bad(
      `A batch carries at most ${ATTEMPTS_PER_BATCH_MAX} attempts; this one carries ${attempts.length}.`,
    );
  }

  const read: Attempt[] = [];
  const seen = new Map<string, number>();
  for (const [index, value] of attempts.entries()) {
    const attempt = readAttempt(value, `attempts[${index}]`);
    if ("status" in attempt) {
      return attempt;
    }
    // **One attempt per item, and a batch is where that is cheapest to say.**
    // Migration 0004 makes it a unique index, so the insert would quietly keep
    // one of the two and answer as if both landed. Refusing here means the
    // client is told which two rows disagreed rather than left to wonder why
    // its count is short.
    const key = sourceKey(attempt.source);
    const first = seen.get(key);
    if (first !== undefined) {
      return bad(
        `attempts[${index}] names the same item as attempts[${first}]; an item is answered once.`,
      );
    }
    seen.set(key, index);
    read.push(attempt);
  }
  return read;
}

/**
 * How two attempts are recognised as being about the same item.
 *
 * No case folding here: `readSource` has already canonicalised the ids, so
 * every source this sees is spelled one way.
 */
export function sourceKey(source: AttemptSource): string {
  return source.kind === "issued"
    ? `issued:${source.itemId}`
    : `pack:${source.packId}:${source.index}`;
}

/**
 * Whether the typed answer is the one the reference derives to.
 *
 * **Rederived, never looked up.** The item's answer is not stored anywhere the
 * server could read it — that is the point of the rederivation machine, and it
 * is what lets `attempts` be append-only without keeping every prompt.
 *
 * An answer the canonicalizer refuses is **wrong, not an error**: a learner can
 * type nonsense, and throwing would turn one bad row into a 500 for the batch.
 * A *reference* that will not resolve is a different thing and does throw —
 * that is the server unable to do its job, and `resolve` refuses to guess at a
 * nearby version rather than rewrite history.
 */
export function gradeAnswer(
  ref: TemplateRef,
  answer: string,
  registry: TemplateRegistry = coreRegistry(),
): boolean {
  const generated = rederive(registry, ref);
  const typed = canonicalize(answer);
  if (!typed.ok) {
    return false;
  }
  // The same spelling the pack builder uses, by calling the same function
  // rather than writing it out again — the longhand this replaces agreed by
  // coincidence. Held by `test/one-way-to-spell-an-answer.test.ts`.
  const expected = storedAnswer(generated.answer.numerator, generated.answer.denominator);
  return typed.value === expected.canonical;
}

/**
 * What an answer is checked against, and how.
 *
 * **Two kinds, because there are two ways to know an answer is right.** A
 * template is *rederived* — regenerate the item and compare canonical
 * spellings. A digest is *verified* — recompute
 * `HMAC(pack_salt, canonicalize(what was typed))` and compare it to what the
 * pack already carries.
 *
 * The second exists because authored content cannot be rederived: an authored
 * item has no template reference. Seventy of the eighty items the app ships are
 * authored, so without it the pack a player actually plays could never be
 * synced.
 *
 * **On the digest path the server never learns the answer.** It holds a digest
 * and can only confirm or deny a guess — which is a stronger position than
 * rederivation leaves it in, not a weaker one.
 */
export type GradingSource =
  | { readonly kind: "template"; readonly ref: TemplateRef }
  | {
      readonly kind: "digest";
      readonly digest: string;
      readonly saltHex: string;
      /** From the manifest, because `attempts.skill_id` is NOT NULL and there
       * is no template to ask. */
      readonly skillId: number;
    };

/** A verdict and the skill it belongs to — the two facts a row needs. */
export interface Graded {
  readonly ok: boolean;
  readonly skillId: number;
}

/**
 * Grades one answer against whichever kind of source recorded it.
 *
 * **One call for both facts.** The skill comes from the template on one path
 * and from the manifest on the other, and a caller resolving it separately
 * would have to know which — which is the branch this function exists to own.
 */
export function gradeSource(
  source: GradingSource,
  answer: string,
  registry: TemplateRegistry = coreRegistry(),
): Graded {
  if (source.kind === "digest") {
    return { ok: matchesDigest(source.digest, source.saltHex, answer), skillId: source.skillId };
  }
  return {
    ok: gradeAnswer(source.ref, answer, registry),
    skillId: resolve(registry, source.ref).skillId,
  };
}

/**
 * Whether what was typed digests to what the pack carries.
 *
 * **The same two functions the pack builder used**, from `packages/contract`:
 * `canonicalize` folds what a keypad can produce and `answerDigest` is the
 * HMAC. A third spelling of either here is exactly the drift R2 names, and the
 * pack builder has already been bitten by one (`packages/core` #50).
 *
 * An answer the canonicalizer refuses is **wrong, not an error**, the same as
 * on the rederivation path: a learner can type nonsense, and nonsense is a
 * wrong answer.
 */
export function matchesDigest(digest: string, saltHex: string, answer: string): boolean {
  const typed = canonicalize(answer);
  return typed.ok && answerDigest(saltHex, typed.value) === digest;
}

/** One graded attempt, ready to be answered with. */
export interface GradedAttempt {
  readonly source: AttemptSource;
  readonly ok: boolean;
}

/**
 * The frozen `VerdictBatch`, in the order the attempts arrived.
 *
 * **`payload` is `{}` and not absent.** The schema marks it required; it is
 * where a diagnosis will go, and a diagnosis needs authored content the server
 * does not have yet. An empty object is honest about that in a way a missing
 * field is not.
 */
export function verdictsResponse(graded: readonly GradedAttempt[]): Response {
  return {
    status: 200,
    body: {
      verdicts: graded.map(({ source, ok }) => ({
        ...(source.kind === "issued"
          ? { itemId: source.itemId }
          : { packRef: { packId: source.packId, index: source.index } }),
        ok,
        payload: {},
      })),
    },
  };
}

/** The answer an attempt naming something the player does not have earns. */
export function unknownSourceResponse(index: number): Response {
  return {
    status: 404,
    body: {
      error: "no_such_item",
      message:
        `attempts[${index}] names an item this player does not have. Nothing in the ` +
        "batch was recorded.",
    },
  };
}
