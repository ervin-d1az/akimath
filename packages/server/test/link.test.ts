import { describe, expect, it } from "vitest";

import { conflictResponse, linkOutcome, readLinkRequest, type LinkRequest } from "../src/link.js";
import type { Response } from "../src/routing.js";
import { validatesAsError } from "./support/contract.js";

const PLAYER = "018f4e3c-0000-7000-8000-0000000000b1";
const OTHER_PLAYER = "018f4e3c-0000-7000-8000-0000000000b2";
const ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000a1";
const OTHER_ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000a2";
const KEY = "a-fresh-idempotency-key";

const body = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
  playerId: PLAYER,
  ageBand: "under_13",
  ...over,
});

const isRefusal = (value: unknown): value is Response =>
  typeof value === "object" && value !== null && "status" in value;

describe("reading a link request", () => {
  it("accepts the two fields the frozen schema requires", () => {
    expect(readLinkRequest(body(), KEY)).toEqual({ playerId: PLAYER, ageBand: "under_13" });
  });

  it("refuses a request with no Idempotency-Key", () => {
    // The contract marks the header `required: true`. A server that ignores it
    // teaches clients it is optional, and the first one to drop it finds out
    // otherwise on the day retries start mattering.
    for (const key of [undefined, "", "   "]) {
      const refusal = readLinkRequest(body(), key);
      expect(isRefusal(refusal) && refusal.status, JSON.stringify(key)).toBe(400);
    }
  });

  it("refuses a body that carries authUserId", () => {
    // **The one unknown property that matters.** A caller choosing whose
    // account to attach a player to is the account-takeover the schema's
    // `additionalProperties: false` exists to prevent.
    const refusal = readLinkRequest(body({ authUserId: OTHER_ACCOUNT }), KEY);
    expect(isRefusal(refusal) && refusal.status).toBe(400);
    expect(isRefusal(refusal) && (refusal.body as { message: string }).message)
      .toContain("authUserId");
  });

  it("refuses any other unknown property too", () => {
    expect(isRefusal(readLinkRequest(body({ nickname: "Aki" }), KEY))).toBe(true);
  });

  it("refuses a playerId that is not a uuid", () => {
    for (const bad of ["", "not-a-uuid", 42, null, `${PLAYER}x`]) {
      expect(isRefusal(readLinkRequest(body({ playerId: bad }), KEY)), String(bad)).toBe(true);
    }
  });

  it("refuses a playerId that only stringifies to a uuid", () => {
    // **`RegExp.test` coerces.** `UUID.test([PLAYER])` is true, because an
    // array of one string stringifies to that string — so the `typeof` guard is
    // load-bearing and not belt-and-braces. Without it an array reaches the
    // query typed as a `string`.
    for (const bad of [[PLAYER], { toString: () => PLAYER }]) {
      expect(isRefusal(readLinkRequest(body({ playerId: bad }), KEY)), JSON.stringify(bad))
        .toBe(true);
    }
  });

  it("refuses a band nobody decided", () => {
    // Widening the set is a migration, never a caller's choice.
    for (const bad of ["18_plus", "adulto", "", 3, null]) {
      expect(isRefusal(readLinkRequest(body({ ageBand: bad }), KEY)), String(bad)).toBe(true);
    }
  });

  it("accepts each band the database accepts", () => {
    // The control. "Everything is refused" would satisfy the test above.
    for (const band of ["under_13", "13_17", "adult"]) {
      expect(readLinkRequest(body({ ageBand: band }), KEY)).toEqual({
        playerId: PLAYER,
        ageBand: band,
      });
    }
  });

  it("refuses a body that is not an object", () => {
    for (const bad of [null, "a string", 7, [1, 2]]) {
      expect(isRefusal(readLinkRequest(bad, KEY)), JSON.stringify(bad)).toBe(true);
    }
  });

  it("every refusal is the frozen Error shape, tagged and explained", () => {
    // Tag and message both asserted: an empty tag and an empty message each
    // satisfy the schema, and neither tells a client what to fix.
    const refusals: Array<[string, unknown, string | undefined]> = [
      ["no key", body(), undefined],
      ["not an object", "nope", KEY],
      ["unknown property", body({ nickname: "Aki" }), KEY],
      ["bad playerId", body({ playerId: "x" }), KEY],
      ["bad band", body({ ageBand: "18_plus" }), KEY],
    ];
    const messages = new Set<string>();
    for (const [name, given, key] of refusals) {
      const refusal = readLinkRequest(given, key);
      expect(isRefusal(refusal), name).toBe(true);
      if (!isRefusal(refusal)) {
        continue;
      }
      const asError = refusal.body as { error: string; message: string };
      expect(validatesAsError(refusal.body), name).toBe(true);
      expect(asError.error, name).toBe("malformed");
      expect(asError.message.length, name).toBeGreaterThan(0);
      messages.add(asError.message);
    }
    // Five ways to be malformed, five different sentences — otherwise the tag
    // is all a client has, and it is the same tag every time.
    expect(messages.size).toBe(refusals.length);
  });

  it("the refusals name what they refused", () => {
    const band = readLinkRequest(body({ ageBand: "18_plus" }), KEY);
    expect(isRefusal(band) && (band.body as { message: string }).message)
      .toContain("under_13, 13_17, adult");

    const key = readLinkRequest(body(), undefined);
    expect(isRefusal(key) && (key.body as { message: string }).message)
      .toContain("Idempotency-Key");
  });
});

describe("what a link should do about the rows that already exist", () => {
  const request: LinkRequest = { playerId: PLAYER, ageBand: "under_13" };
  const outcome = (playerForAccount: string | null, accountForPlayer: string | null) =>
    linkOutcome({ request, playerForAccount, accountForPlayer, accountId: ACCOUNT });

  it("creates when neither row exists", () => {
    expect(outcome(null, null)).toEqual({ kind: "create" });
  });

  it("is idempotent when the same account already linked the same player", () => {
    // Real idempotency, not a replayed response: the inputs determine the row,
    // so asking twice cannot mean two different things. That is why the
    // `Idempotency-Key` needs no store behind it yet.
    expect(outcome(PLAYER, ACCOUNT)).toEqual({ kind: "existing" });
  });

  it("refuses when the account already has a different player", () => {
    const result = outcome(OTHER_PLAYER, null);
    expect(result.kind).toBe("conflict");
    expect(result.kind === "conflict" && result.why).toContain("already has a player");
  });

  it("refuses when the player already belongs to someone else", () => {
    // A device could hand its `player_id` to another account, deliberately or
    // by restoring a backup. The row is not theirs to claim.
    const result = outcome(null, OTHER_ACCOUNT);
    expect(result.kind).toBe("conflict");
    expect(result.kind === "conflict" && result.why).toContain("another account");
  });

  it("the two refusals say different things", () => {
    const a = outcome(OTHER_PLAYER, null);
    const b = outcome(null, OTHER_ACCOUNT);
    expect(a.kind === "conflict" && b.kind === "conflict" && a.why).not.toBe(
      b.kind === "conflict" ? b.why : "",
    );
  });

  it("refuses when the two rows disagree with each other", () => {
    // The database's constraints make this unreachable — `auth_user_id` is
    // UNIQUE and `id` is the key — but the function is not the place to assume
    // that. Both halves must agree before a link is called idempotent;
    // "this account has that player" and "that player has this account" are two
    // facts, and acting on one of them is how a mismatch becomes a silent
    // no-op.
    expect(outcome(PLAYER, OTHER_ACCOUNT).kind).toBe("conflict");
  });

  it("a conflict is a 409, tagged and explained", () => {
    const response = conflictResponse("because");
    expect(response.status).toBe(409);
    expect(validatesAsError(response.body)).toBe(true);
    expect(response.body).toEqual({ error: "already_linked", message: "because" });
  });
});
