import { afterEach, beforeEach, expect, it } from "vitest";

import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
import type { Caller } from "../src/routing.js";
import { validatesAsError } from "./support/contract.js";
import { describeWithDatabase, freshDatabase, type TestDatabase } from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000c1";
const OTHER_ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000c2";
const PLAYER = "018f4e3c-0000-7000-8000-0000000000c1";
const OTHER_PLAYER = "018f4e3c-0000-7000-8000-0000000000c2";

describeWithDatabase("POST /players/link, against a real database", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;

  const link = async (
    body: unknown,
    options: { account?: string; key?: string | null } = {},
  ): Promise<Response> => {
    const headers: Record<string, string> = { "content-type": "application/json" };
    if (options.key !== null) {
      headers["Idempotency-Key"] = options.key ?? "a-key";
    }
    const caller: Caller = { kind: "session", userId: options.account ?? ACCOUNT };
    return createApp({
      version: "1.2.3",
      verify: () => Promise.resolve(caller),
      log: createLogger({
        level: "error",
        write: () => {},
        now: () => new Date("2026-08-19T09:15:00.000Z"),
      }),
      handlers: createHandlers(requests),
    }).fetch(
      new Request("http://localhost/players/link", {
        method: "POST",
        headers,
        body: JSON.stringify(body),
      }),
    );
  };

  beforeEach(async () => {
    db = await freshDatabase();
    requests = createRequestDatabase(db.url);
  });

  afterEach(async () => {
    await requests.close();
    await db.close();
  });

  it("links a player and answers the frozen Me", async () => {
    const response = await link({ playerId: PLAYER, ageBand: "under_13" });

    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown>;
    expect(Object.keys(body).sort()).toEqual(["ageBand", "createdAt", "playerId"]);
    expect(body["playerId"]).toBe(PLAYER);
    expect(body["ageBand"]).toBe("under_13");
    expect(body["createdAt"]).toMatch(/Z$/);
  });

  it("and the row carries the account from the session, not the body", async () => {
    await link({ playerId: PLAYER, ageBand: "adult" });

    const row = await db.client.query<{ auth_user_id: string }>(
      "SELECT auth_user_id FROM players WHERE id = $1",
      [PLAYER],
    );
    expect(row.rows[0]?.auth_user_id).toBe(ACCOUNT);
  });

  it("asked twice, it answers the same thing", async () => {
    // The idempotency the contract's required header promises — real, because
    // the inputs determine the row, rather than replayed from a store.
    const first = await link({ playerId: PLAYER, ageBand: "13_17" });
    const second = await link({ playerId: PLAYER, ageBand: "13_17" });

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect(await second.json()).toEqual(await first.json());

    const count = await db.client.query("SELECT 1 FROM players");
    expect(count.rowCount).toBe(1);
  });

  it("refuses a second, different player on the same account", async () => {
    await link({ playerId: PLAYER, ageBand: "adult" });
    const response = await link({ playerId: OTHER_PLAYER, ageBand: "adult" });

    expect(response.status).toBe(409);
    const body = (await response.json()) as { message: string };
    expect(validatesAsError(body)).toBe(true);
    expect(body.message).toContain("already has a player");
  });

  it("refuses a player that belongs to somebody else", async () => {
    // A device can hand its `player_id` on by restoring a backup. The row is
    // not the new account's to claim.
    await link({ playerId: PLAYER, ageBand: "adult" });
    const response = await link({ playerId: PLAYER, ageBand: "adult" }, { account: OTHER_ACCOUNT });

    expect(response.status).toBe(409);
    expect((await response.json() as { message: string }).message).toContain("another account");
  });

  it("refuses a body that names the account", async () => {
    // The account-takeover the schema's `additionalProperties: false` exists
    // for: a caller choosing whose player this becomes.
    const response = await link({
      playerId: PLAYER,
      ageBand: "adult",
      authUserId: OTHER_ACCOUNT,
    });

    expect(response.status).toBe(400);
    const left = await db.client.query("SELECT 1 FROM players");
    expect(left.rowCount).toBe(0);
  });

  it("refuses a request with no Idempotency-Key, and writes nothing", async () => {
    const response = await link({ playerId: PLAYER, ageBand: "adult" }, { key: null });

    expect(response.status).toBe(400);
    const left = await db.client.query("SELECT 1 FROM players");
    expect(left.rowCount).toBe(0);
  });

  it("refuses a band the database would refuse, before asking it", async () => {
    const response = await link({ playerId: PLAYER, ageBand: "18_plus" });

    expect(response.status).toBe(400);
    // A CHECK violation would have been a 500. Catching it in the pure reader
    // is the difference between a message and a stack trace.
    expect(validatesAsError(await response.json())).toBe(true);
  });

  it("refuses a body that is not JSON at all", async () => {
    const response = await createApp({
      version: "1.2.3",
      verify: () => Promise.resolve({ kind: "session", userId: ACCOUNT } as Caller),
      log: createLogger({ level: "error", write: () => {}, now: () => new Date() }),
      handlers: createHandlers(requests),
    }).fetch(
      new Request("http://localhost/players/link", {
        method: "POST",
        headers: { "content-type": "application/json", "Idempotency-Key": "k" },
        body: "<html>not json</html>",
      }),
    );

    expect(response.status).toBe(400);
  });

  it("a caller with no session never reaches the database", async () => {
    const response = await createApp({
      version: "1.2.3",
      verify: () => Promise.resolve({ kind: "absent" } as Caller),
      log: createLogger({ level: "error", write: () => {}, now: () => new Date() }),
      handlers: createHandlers(requests),
    }).fetch(
      new Request("http://localhost/players/link", {
        method: "POST",
        headers: { "Idempotency-Key": "k", "content-type": "application/json" },
        body: JSON.stringify({ playerId: PLAYER, ageBand: "adult" }),
      }),
    );

    expect(response.status).toBe(401);
    const left = await db.client.query("SELECT 1 FROM players");
    expect(left.rowCount).toBe(0);
  });

  it("and then GET /me finds what the link created", async () => {
    // The pair, end to end: link, then ask who you are.
    await link({ playerId: PLAYER, ageBand: "under_13" });

    const me = await createApp({
      version: "1.2.3",
      verify: () => Promise.resolve({ kind: "session", userId: ACCOUNT } as Caller),
      log: createLogger({ level: "error", write: () => {}, now: () => new Date() }),
      handlers: createHandlers(requests),
    }).fetch(new Request("http://localhost/me"));

    expect(me.status).toBe(200);
    expect((await me.json() as { playerId: string }).playerId).toBe(PLAYER);
  });
});
