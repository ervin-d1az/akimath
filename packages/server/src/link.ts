import type { Response } from "./routing.js";

/** A well-formed link request, once the body has been believed. */
export interface LinkRequest {
  readonly playerId: string;
  readonly ageBand: string;
}

/**
 * What to do about a link, given what the database already holds.
 *
 * Three outcomes and no fourth. `existing` is what makes the operation
 * idempotent *by nature* rather than by bookkeeping: the same account asking
 * to link the same player twice is not an error and does not need a replay
 * store to say so.
 */
export type LinkOutcome =
  | { readonly kind: "create" }
  | { readonly kind: "existing" }
  | { readonly kind: "conflict"; readonly why: string };

/** The bands `players.age_band` accepts, and the frozen `PlayerLink` offers. */
const BANDS: readonly string[] = ["under_13", "13_17", "adult"];

const UUID = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

function bad(message: string): Response {
  return { status: 400, body: { error: "malformed", message } };
}

/**
 * Reads the request, or the reason it is not one.
 *
 * **PURE.** No clock, no database, no session — whether the *caller* may do
 * this is `route()`'s question and whether the row *can* exist is the
 * database's; this only asks whether the request is a request.
 *
 * **`Idempotency-Key` is required because the contract requires it.** A server
 * that ignores a header its own specification marks `required: true` teaches
 * clients the header is optional, and the first one to drop it finds out
 * otherwise on the day retries start mattering.
 *
 * **An unknown property is refused**, because the frozen schema says
 * `additionalProperties: false` — and one unknown property in particular is the
 * point: a body carrying `authUserId` would be a caller choosing whose account
 * to attach a player to.
 */
export function readLinkRequest(
  body: unknown,
  idempotencyKey: string | undefined,
): LinkRequest | Response {
  if ((idempotencyKey ?? "").trim().length === 0) {
    return bad("This operation needs an Idempotency-Key header.");
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return bad("The body must be a JSON object.");
  }

  const given = body as Record<string, unknown>;
  const unknown = Object.keys(given).filter((key) => key !== "playerId" && key !== "ageBand");
  if (unknown.length > 0) {
    return bad(`The body carries ${unknown.join(", ")}, which this operation does not accept.`);
  }

  const playerId = given["playerId"];
  if (typeof playerId !== "string" || !UUID.test(playerId)) {
    return bad("playerId must be a uuid the device minted.");
  }

  const ageBand = given["ageBand"];
  if (typeof ageBand !== "string" || !BANDS.includes(ageBand)) {
    return bad(`ageBand must be one of ${BANDS.join(", ")}.`);
  }

  return { playerId, ageBand };
}

/**
 * What the link should do, given the two rows that could already exist.
 *
 * **PURE**, and the reason it is separated from the query is that the
 * interesting part is the four-way comparison, not the SQL. Both lookups are
 * needed: an account can already have a player, and a player can already
 * belong to an account, and those are different refusals.
 */
export function linkOutcome(options: {
  readonly request: LinkRequest;
  /** The player already linked to this account, if any. */
  readonly playerForAccount: string | null;
  /** The account this player already belongs to, if any. */
  readonly accountForPlayer: string | null;
  readonly accountId: string;
}): LinkOutcome {
  const { request, playerForAccount, accountForPlayer, accountId } = options;

  if (playerForAccount === request.playerId && accountForPlayer === accountId) {
    // Asked twice, answered the same. This is the idempotency the contract's
    // header promises, and it is real rather than replayed.
    return { kind: "existing" };
  }
  if (playerForAccount !== null) {
    return {
      kind: "conflict",
      why: "This account already has a player. One account, one player (see migration 0003).",
    };
  }
  if (accountForPlayer !== null) {
    return {
      kind: "conflict",
      why: "That player already belongs to another account.",
    };
  }
  return { kind: "create" };
}

/** The answer a conflict earns. */
export function conflictResponse(why: string): Response {
  return { status: 409, body: { error: "already_linked", message: why } };
}
