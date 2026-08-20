import { canonicalize, renderCanonicalAnswer } from "@akimath/contract";
import { coreRegistry, rederive, type TemplateRef, type TemplateRegistry } from "@akimath/core";

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
    return { kind: "issued", itemId };
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
  return { kind: "pack", packId, index };
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
  for (const [index, value] of attempts.entries()) {
    const attempt = readAttempt(value, `attempts[${index}]`);
    if ("status" in attempt) {
      return attempt;
    }
    read.push(attempt);
  }
  return read;
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
  // The same spelling the pack builder uses: a whole answer is whole, not a
  // fraction over one. See `packages/core`'s `build.ts`, which learned this the
  // hard way.
  const expected =
    generated.answer.denominator === 1n
      ? renderCanonicalAnswer(generated.answer.numerator)
      : renderCanonicalAnswer(generated.answer.numerator, generated.answer.denominator);
  return typed.value === expected;
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
