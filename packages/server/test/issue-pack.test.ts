import { createHmac } from "node:crypto";

import { canonicalize, parsePack } from "@akimath/contract";
import { afterEach, beforeEach, expect, it } from "vitest";

import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
import type { Caller } from "../src/routing.js";
import { authoredAnswers } from "./support/authored.js";
import { shippedPackNamed } from "./support/shipped.js";
import { describeWithDatabase, freshDatabase, type TestDatabase } from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-00000000ab01";
const PLAYER = "018f4e3c-0000-7000-8000-00000000ab01";
const SESSION = "018f4e3c-0000-7000-8000-00000000ab02";
const AT = "2026-08-19T09:15:00.000Z";

describeWithDatabase("POST /packs, against a real database", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;

  const starter = shippedPackNamed("starter");
  const shipped = starter.pack;
  /** The plaintext answers the built pack only ever carries as digests. */
  const answers = authoredAnswers();

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
    readonly pack: {
      readonly items: { readonly answer: { readonly digest: string }; readonly skill_id: number }[];
      readonly puzzles: unknown[];
      readonly pack_salt: string;
      readonly issued_at: string;
      readonly expires_at: string;
    };
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

  it("answers the content the app already ships", async () => {
    // Eighty items and the boards, not twenty generated subtractions. Until
    // 0005 made an authored item gradeable, the worse pack was the only one
    // anything could sync.
    const response = await issue();

    expect(response.status).toBe(200);
    const body = (await response.json()) as Record<string, unknown> & Issued;
    expect(Object.keys(body).sort()).toEqual(["expiresAt", "issuedAt", "pack", "packId"]);
    const checked = parsePack(body.pack);
    expect(checked.ok, checked.ok ? "" : checked.tag).toBe(true);
    expect(body.pack.items).toHaveLength(shipped.items.length);
    expect(body.pack.puzzles).toHaveLength(shipped.puzzles.length);
  });

  it("and the window is the issuance's, not the build's", async () => {
    const body = (await (await issue()).json()) as Issued;

    expect(body.pack.issued_at).not.toBe(shipped.issued_at);
    expect(new Date(body.pack.expires_at).getTime())
      .toBeGreaterThan(new Date(body.pack.issued_at).getTime());
  });

  it("it writes one row naming the content, with one entry per item", async () => {
    const body = (await (await issue()).json()) as Issued;

    const row = await db.client.query<{
      player_id: string;
      item_refs: { kind: string; digest: string; skill_id: number }[];
      pack_salt: Buffer;
      content_id: string | null;
    }>(
      `SELECT player_id, item_refs, pack_salt, content_id
         FROM offline_packs WHERE id = $1`,
      [body.packId],
    );
    expect(row.rows[0]?.player_id).toBe(PLAYER);
    // **A name and a digest, not the body.** 158 KB per issuance, identical
    // for every player, is a table that grows and says nothing new each time —
    // and a name alone would follow the artifact wherever an edit took it.
    expect(row.rows[0]?.content_id).toBe(starter.id);
    expect(row.rows[0]?.content_id).toMatch(/^starter@[0-9a-f]{64}$/u);
    expect(row.rows[0]?.item_refs).toHaveLength(shipped.items.length);
    expect(row.rows[0]?.item_refs[0]?.kind).toBe("digest");
    expect(row.rows[0]?.pack_salt.length).toBe(16);
  });

  it("the manifest it stored is the pack it answered with", async () => {
    // The seam that has no other guard: the row is what grading reads, and the
    // body is what the player plays.
    const body = (await (await issue()).json()) as Issued;
    const stored = await db.client.query<{
      item_refs: { digest: string; skill_id: number }[];
    }>("SELECT item_refs FROM offline_packs WHERE id = $1", [body.packId]);

    stored.rows[0]!.item_refs.forEach((entry, index) => {
      expect(entry.digest, `item ${index}`).toBe(body.pack.items[index]!.answer.digest);
      expect(entry.skill_id, `item ${index}`).toBe(body.pack.items[index]!.skill_id);
    });
  });

  it("**the loop closes on authored content**, which is the whole point", async () => {
    // Issue, answer, sync, graded — on an item **nobody can rederive**. The
    // answer comes from the authoring source, which is the only place it exists
    // in plaintext: the pack carries a digest, and so does the server.
    const body = (await (await issue()).json()) as Issued;

    const right = answers[0]!;
    const wrong = `${right}0`;
    expect(canonicalize(right).ok, right).toBe(true);

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
        answer: wrong,
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

  it("a pack can be fetched again, and it is the same pack", async () => {
    // Rebuilt from the content it names plus the row's own window — not read
    // back from a stored body.
    const issued = (await (await issue()).json()) as Issued & Record<string, unknown>;

    const again = await app().fetch(
      new Request(`http://localhost/packs/${issued.packId}`, { method: "GET" }),
    );

    expect(again.status).toBe(200);
    expect(await again.json()).toEqual(issued);
  });

  it("two issues are two packs of the same content", async () => {
    const first = (await (await issue()).json()) as Issued;
    const second = (await (await issue()).json()) as Issued;

    expect(second.packId).not.toBe(first.packId);
    expect((await db.client.query("SELECT 1 FROM offline_packs")).rowCount).toBe(2);
    // **The same salt, and that is not a leak.** A copy shares the content's
    // salt because its digests were taken under it. The salt ships *inside*
    // every pack anyway, and every player gets the same content — so one
    // player's digests say nothing about another's that installing the app
    // would not.
    expect(second.pack.pack_salt).toBe(first.pack.pack_salt);
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

  it("a row naming content this build no longer ships is a 404", async () => {
    // The row is real and the content is gone. There is nothing the caller can
    // do that a different status would help with.
    const gone = "018f4e3c-0000-7000-8000-00000000ab0a";
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, item_refs, pack_salt, expires_at, content_id)
       VALUES ($1, $2, '[]'::jsonb, '\\x00', now() + interval '30 days', 'a-pack-from-2019')`,
      [gone, PLAYER],
    );

    const response = await app().fetch(
      new Request(`http://localhost/packs/${gone}`, { method: "GET" }),
    );

    expect(response.status).toBe(404);
  });

  it("an account with no player is told to link one first", async () => {
    await db.client.query("DELETE FROM players WHERE auth_user_id = $1", [ACCOUNT]);

    const response = await issue();

    expect(response.status).toBe(404);
    expect(((await response.json()) as { error: string }).error).toBe("no_player");
  });
});
