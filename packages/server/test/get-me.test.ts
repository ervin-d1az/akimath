import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import {
  createRequestDatabase,
  type RequestDatabase,
} from "../src/adapters/request-database.js";
import type { Caller } from "../src/routing.js";
import { profileResponse } from "../src/players.js";
import { validatesAsError } from "./support/contract.js";
import {
  describeWithDatabase,
  freshDatabase,
  type TestDatabase,
} from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000b1";
const OTHER_ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000b2";
const PLAYER = "018f4e3c-0000-7000-8000-0000000000b1";
const CREATED = new Date("2026-08-19T09:15:00.000Z");

describe("what a profile answer looks like", () => {
  it("is the three fields the frozen Me schema requires, and no more", () => {
    expect(
      profileResponse({ id: PLAYER, age_band: "under_13", created_at: CREATED }),
    ).toEqual({
      status: 200,
      body: {
        playerId: PLAYER,
        ageBand: "under_13",
        createdAt: "2026-08-19T09:15:00.000Z",
      },
    });
  });

  it("times carry milliseconds and a Z, because the contract's pattern demands both", () => {
    // `Me.createdAt` is pinned to a `date-time` pattern ending `(?:Z)` with an
    // optional fractional part — a value formatted any other way is off-contract
    // in a way no TypeScript type would catch.
    const body = profileResponse({
      id: PLAYER,
      age_band: "adult",
      created_at: new Date("2026-01-02T03:04:05.678Z"),
    }).body as { createdAt: string };
    expect(body.createdAt).toBe("2026-01-02T03:04:05.678Z");
  });

  it("no player is 404 and not 401, and says what to do about it", () => {
    // The caller authenticated. There is simply no player under that account
    // yet — the ordinary state of an adult who made an account and has not
    // linked a device. A 401 would send a client with a perfectly good session
    // off to fetch another one, forever.
    //
    // The tag and the message are asserted rather than just "it validates as an
    // Error": an empty tag and an empty message both satisfy the frozen schema,
    // and both are useless to the client that has to decide what to do next.
    const response = profileResponse(null);
    expect(response).toEqual({
      status: 404,
      body: {
        error: "no_player",
        message: "This account has no player yet. Link one with POST /players/link.",
      },
    });
    expect(validatesAsError(response.body)).toBe(true);
  });
});

describeWithDatabase("GET /me, against a real database", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;
  let lines: string[];

  const app = (caller: Caller) => {
    lines = [];
    return createApp({
      version: "1.2.3",
      verify: () => Promise.resolve(caller),
      log: createLogger({
        level: "debug",
        write: (line) => lines.push(line),
        now: () => CREATED,
      }),
      handlers: createHandlers(requests),
    });
  };

  const get = async (caller: Caller): Promise<Response> =>
    app(caller).fetch(new Request("http://localhost/me"));

  beforeEach(async () => {
    db = await freshDatabase();
    requests = createRequestDatabase(db.url);
    await db.client.query(
      "INSERT INTO players (id, age_band, auth_user_id, created_at) VALUES ($1, 'under_13', $2, $3)",
      [PLAYER, ACCOUNT, CREATED],
    );
  });

  afterEach(async () => {
    await requests.close();
    await db.close();
  });

  it("answers the player linked to the session", async () => {
    const response = await get({ kind: "session", userId: ACCOUNT });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      playerId: PLAYER,
      ageBand: "under_13",
      createdAt: "2026-08-19T09:15:00.000Z",
    });
  });

  it("and never somebody else's", async () => {
    // The one that matters. A row exists; it belongs to another account, and
    // the lookup is by account rather than by anything the caller sent.
    const response = await get({ kind: "session", userId: OTHER_ACCOUNT });
    expect(response.status).toBe(404);
  });

  it("refuses a caller with no session before touching the database", async () => {
    const response = await get({ kind: "absent" });
    expect(response.status).toBe(401);
  });

  it("runs the query as app_request, not as the owner", async () => {
    // The seam is proven in `request-database.test.ts`; this proves the handler
    // goes through it. `GET /me` needs only SELECT, so the way to show the role
    // applied is to take the grant away and watch the endpoint notice.
    await db.client.query("REVOKE SELECT ON players FROM app_request");
    const response = await get({ kind: "session", userId: ACCOUNT });

    expect(response.status).toBe(500);
    expect(validatesAsError(await response.json())).toBe(true);
    await db.client.query("GRANT SELECT ON players TO app_request");
  });

  it("a failure says nothing to the client and everything to the log", async () => {
    // A database error quotes the SQL it failed on, which is a schema
    // description handed to whoever asked for it.
    await db.client.query("REVOKE SELECT ON players FROM app_request");
    const response = await get({ kind: "session", userId: ACCOUNT });
    const body = (await response.json()) as { message: string };

    expect(body.message).not.toMatch(/players|select|permission/i);
    expect(lines.join("")).toContain("permission denied");
    await db.client.query("GRANT SELECT ON players TO app_request");
  });

  it("names the operation in the request line", async () => {
    await get({ kind: "session", userId: ACCOUNT });
    expect(JSON.parse(lines.at(-1) ?? "null")).toMatchObject({
      msg: "request",
      path: "/me",
      status: 200,
      operation: "getMe",
      caller: "session",
    });
  });
});
