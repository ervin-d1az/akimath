import { createHmac } from "node:crypto";

import { parsePack, storedAnswer } from "@akimath/contract";
import { coreRegistry, fromManifestEntry, rederive, templateRefOf } from "@akimath/core";
import { afterEach, beforeEach, expect, it } from "vitest";

import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
import { PACK_ITEM_COUNT } from "../src/packs.js";
import type { Caller } from "../src/routing.js";
import { describeWithDatabase, freshDatabase, type TestDatabase } from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-00000000ab01";
const PLAYER = "018f4e3c-0000-7000-8000-00000000ab01";
const SESSION = "018f4e3c-0000-7000-8000-00000000ab02";
const AT = "2026-08-19T09:15:00.000Z";

describeWithDatabase("POST /packs, against a real database", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;

  const app = () =>
    createApp({
      version: "1.2.3",
      verify: () => Promise.resolve({ kind: "session", userId: ACCOUNT } as Caller),
      log: createLogger({ level: "error", write: () => {}, now: () => new Date(AT) }),
      handlers: createHandlers(requests),
    });

  // `Hono.fetch` is typed `Response | Promise<Response>`; awaiting it here
  // rather than at every call site keeps the tests reading as one request each.
  const issue = async (): Promise<Response> =>
    app().fetch(new Request("http://localhost/packs", { method: "POST" }));

  const sync = async (attempts: unknown[]): Promise<Response> =>
    app().fetch(
      new Request("http://localhost/attempts", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ attempts }),
      }),
    );

  interface Issued {
    readonly packId: string;
    readonly pack: { readonly items: { readonly answer: { readonly digest: string } }[] };
  }

  beforeEach(async () => {
    db = await freshDatabase();
    requests = createRequestDatabase(db.url);
    await db.client.query(
      "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', $2)",
      [PLAYER, ACCOUNT],
    );
  });

  afterEach(async () => {
    await requests.close();
    await db.close();
  });

  it("answers a pack the client would accept", async () => {
    const response = await issue();

    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown> & Issued;
    expect(Object.keys(body).sort()).toEqual(["expiresAt", "issuedAt", "pack", "packId"]);
    const checked = parsePack(body.pack);
    expect(checked.ok, checked.ok ? "" : checked.tag).toBe(true);
    expect(body.pack.items).toHaveLength(PACK_ITEM_COUNT);
  });

  it("and writes one row carrying one reference per item", async () => {
    const body = (await (await issue()).json()) as Issued;

    const row = await db.client.query<{
      player_id: string;
      item_refs: unknown[];
      pack_salt: Buffer;
      skill_id: number;
    }>("SELECT player_id, item_refs, pack_salt, skill_id FROM offline_packs WHERE id = $1", [
      body.packId,
    ]);
    expect(row.rows[0]?.player_id).toBe(PLAYER);
    expect(row.rows[0]?.item_refs).toHaveLength(PACK_ITEM_COUNT);
    // Sixteen bytes in the column, thirty-two hex characters in the format.
    expect(row.rows[0]?.pack_salt.length).toBe(16);
    expect(row.rows[0]?.skill_id).toBe(1);
  });

  it("the manifest it stored is the pack it answered with", async () => {
    // The seam that has no other guard: the row is what grading reads, and the
    // body is what the player plays. Compared through the database rather than
    // through the response, because a manifest that never landed would pass a
    // check that only looked at what was returned.
    const body = (await (await issue()).json()) as Issued;
    const stored = await db.client.query<{ item_refs: unknown[]; pack_salt: Buffer }>(
      "SELECT item_refs, pack_salt FROM offline_packs WHERE id = $1",
      [body.packId],
    );
    const refs = stored.rows[0]!.item_refs;
    const salt = stored.rows[0]!.pack_salt.toString("hex");

    refs.forEach((entry, index) => {
      const generated = rederive(coreRegistry(), templateRefOf(fromManifestEntry(entry)!)!);
      const { canonical } = storedAnswer(
        generated.answer.numerator,
        generated.answer.denominator,
      );
      // HMAC recomputed here rather than through `answerDigest`, so the
      // assertion is an independent derivation from the bytes the database
      // holds — calling the production function would only prove it agrees
      // with itself.
      expect(body.pack.items[index]!.answer.digest, `item ${index}`).toBe(
        createHmac("sha256", Buffer.from(salt, "hex")).update(canonical, "utf8").digest("hex"),
      );
    });
  });

  it("**the loop closes**: an item it issued grades when it comes back", async () => {
    // Issue, answer, sync, graded. Every step through the real endpoints and a
    // real database, which is the first time this path has existed end to end.
    const body = (await (await issue()).json()) as Issued;
    const stored = await db.client.query<{ item_refs: unknown[] }>(
      "SELECT item_refs FROM offline_packs WHERE id = $1",
      [body.packId],
    );
    const generated = rederive(coreRegistry(), templateRefOf(fromManifestEntry(stored.rows[0]!.item_refs[0])!)!);
    const right = storedAnswer(
      generated.answer.numerator,
      generated.answer.denominator,
    ).canonical;

    const response = await sync([
      {
        packRef: { packId: body.packId, index: 0 },
        sessionId: SESSION,
        answer: right,
        clientTs: AT,
        elapsedMs: 4200,
      },
      {
        packRef: { packId: body.packId, index: 1 },
        sessionId: SESSION,
        answer: "definitivamente no",
        clientTs: AT,
        elapsedMs: 900,
      },
    ]);

    expect(response.status).toBe(200);
    const verdicts = ((await response.json()) as { verdicts: { ok: boolean }[] }).verdicts;
    expect(verdicts.map((v) => v.ok)).toEqual([true, false]);

    const rows = await db.client.query<{ is_correct: boolean; pack_index: number }>(
      "SELECT is_correct, pack_index FROM attempts ORDER BY pack_index",
    );
    expect(rows.rows).toEqual([
      { is_correct: true, pack_index: 0 },
      { is_correct: false, pack_index: 1 },
    ]);
  });

  it("two issues are two packs, with different salts", async () => {
    const first = (await (await issue()).json()) as Issued;
    const second = (await (await issue()).json()) as Issued;

    expect(second.packId).not.toBe(first.packId);
    const count = await db.client.query("SELECT 1 FROM offline_packs");
    expect(count.rowCount).toBe(2);
    // Different salts, so one player's two packs are not comparable either.
    const salts = await db.client.query<{ hex: string }>(
      "SELECT encode(pack_salt, 'hex') AS hex FROM offline_packs",
    );
    expect(new Set(salts.rows.map((r) => r.hex)).size).toBe(2);
  });

  it("a pack can be fetched again, and it is the same pack", async () => {
    // **Rebuilt, not read back.** `offline_packs` stores a manifest and a salt
    // rather than fifty rows of rendered item — that is what the manifest is
    // for — so a re-fetch reconstructs. Every digest has to come back
    // identical or a client that already has attempts against this pack is
    // holding answers to a different one.
    const issued = (await (await issue()).json()) as Issued & Record<string, unknown>;

    const again = await app().fetch(
      new Request(`http://localhost/packs/${issued.packId}`, { method: "GET" }),
    );

    expect(again.status).toBe(200);
    expect(await again.json()).toEqual(issued);
  });

  it("and not somebody else's, which is a 404 rather than a 403", async () => {
    // Telling the two apart would confirm that a stranger's pack exists.
    const other = "018f4e3c-0000-7000-8000-00000000ab09";
    await db.client.query(
      "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', gen_random_uuid())",
      [other],
    );
    const theirs = await db.client.query<{ id: string }>(
      `INSERT INTO offline_packs (id, player_id, item_refs, pack_salt, expires_at)
       VALUES (gen_random_uuid(), $1, '[]'::jsonb, '\\x00', now() + interval '30 days')
       RETURNING id`,
      [other],
    );

    const response = await app().fetch(
      new Request(`http://localhost/packs/${theirs.rows[0]!.id}`, { method: "GET" }),
    );

    expect(response.status).toBe(404);
    expect(((await response.json()) as { error: string }).error).toBe("no_such_pack");
  });

  it("and a pack that never existed is the same 404", async () => {
    const response = await app().fetch(
      new Request("http://localhost/packs/018f4e3c-0000-7000-8000-0000000000ff", {
        method: "GET",
      }),
    );

    expect(response.status).toBe(404);
    expect(((await response.json()) as { error: string }).error).toBe("no_such_pack");
  });

  it("an account with no player is told to link one first", async () => {
    await db.client.query("DELETE FROM players WHERE auth_user_id = $1", [ACCOUNT]);

    const response = await issue();

    expect(response.status).toBe(404);
    expect(((await response.json()) as { error: string }).error).toBe("no_player");
  });
});
