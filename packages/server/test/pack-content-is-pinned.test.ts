import { createHash, randomBytes } from "node:crypto";

import { afterEach, beforeEach, expect, it } from "vitest";

import {
  createApp,
  createHandlers,
  type HandlerEnvironment,
} from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
import type { ShippedPack } from "../src/adapters/shipped-packs.js";
import { contentIdFor } from "../src/packs.js";
import type { Caller } from "../src/routing.js";
import { authoredAnswers } from "./support/authored.js";
import { describeWithDatabase, freshDatabase, type TestDatabase } from "./support/database.js";
import { shippedPackNamed } from "./support/shipped.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-00000000cd01";
const PLAYER = "018f4e3c-0000-7000-8000-00000000cd01";
const SESSION = "018f4e3c-0000-7000-8000-00000000cd02";
const AT = "2026-08-19T09:15:00.000Z";

/**
 * The hazard `content_id` used to carry, constructed rather than argued about.
 *
 * `offline_packs.content_id` held the bare name `starter`, and `POST /packs`,
 * `GET /packs/{packId}` and the rating's ladder-step lookup all resolved it
 * against *today's* artifact while grading used the manifest digests recorded
 * **at issuance**. So editing `packages/core/pack/starter.json` — the ordinary
 * content act `npm run build:pack` exists to make easy — silently re-pointed
 * every outstanding pack: within the thirty-day window a device re-fetched, was
 * handed today's item at index *i*, answered it correctly, and had that answer
 * compared with the digest of the *old* item at index *i*. The `ok: false` that
 * produced lands in `attempts`, which the request path can neither UPDATE nor
 * DELETE. Measured before the fix: `is_correct=false` for a right answer.
 *
 * **The edit here is a reorder**, because a reorder needs no crypto: the
 * digests travel with the items, so swapping two items is a real new artifact
 * whose answers this test already knows.
 */
describeWithDatabase("content edited under an outstanding pack", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;

  const answers = authoredAnswers();
  const before = shippedPackNamed("starter");
  const after = reorderedFirstTwo(before);
  const v1 = new Map([[before.id, before]]);
  const v2 = new Map([[after.id, after]]);

  /** The same content with its first two items swapped, as a new artifact. */
  function reorderedFirstTwo(source: ShippedPack): ShippedPack {
    const pack = {
      ...source.pack,
      items: [source.pack.items[1]!, source.pack.items[0]!, ...source.pack.items.slice(2)],
    };
    // Hashed the way `readShippedPacks` hashes: over the artifact's own bytes.
    return {
      id: contentIdFor(
        source.name,
        createHash("sha256").update(JSON.stringify(pack)).digest("hex"),
      ),
      name: source.name,
      pack,
    };
  }

  const environment = (packs: ReadonlyMap<string, ShippedPack>): HandlerEnvironment => ({
    now: () => new Date(AT),
    randomHex: (bytes) => randomBytes(bytes).toString("hex"),
    randomSeed: () => 0n,
    shippedPacks: () => packs,
  });

  const app = (packs: ReadonlyMap<string, ShippedPack>) =>
    createApp({
      version: "1.2.3",
      verify: () => Promise.resolve({ kind: "session", userId: ACCOUNT } as Caller),
      log: createLogger({ level: "error", write: () => {}, now: () => new Date(AT) }),
      handlers: createHandlers(requests, environment(packs)),
    });

  interface Issued {
    readonly packId: string;
    readonly pack: { readonly items: { readonly answer: { readonly digest: string } }[] };
  }

  const issue = async (packs: ReadonlyMap<string, ShippedPack>): Promise<Issued> =>
    (await (
      await app(packs).fetch(new Request("http://localhost/packs", { method: "POST" }))
    ).json()) as Issued;

  const answer = async (
    packs: ReadonlyMap<string, ShippedPack>,
    packId: string,
    index: number,
    typed: string,
  ): Promise<boolean> => {
    const response = await app(packs).fetch(
      new Request("http://localhost/attempts", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          attempts: [
            {
              packRef: { packId, index },
              sessionId: SESSION,
              answer: typed,
              clientTs: AT,
              elapsedMs: 4200,
            },
          ],
        }),
      }),
    );
    return ((await response.json()) as { verdicts: { ok: boolean }[] }).verdicts[0]!.ok;
  };

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

  it("is really an edit, or nothing below distinguishes anything", () => {
    // PROC-11's fixture bullet. Every assertion here compares item 0 with item
    // 1; two items sharing an answer, a digest or a difficulty would make the
    // whole file green for a reason unrelated to what it is about.
    expect(answers[0]).not.toBe(answers[1]);
    expect(before.pack.items[0]!.answer.digest).not.toBe(before.pack.items[1]!.answer.digest);
    expect(after.id).not.toBe(before.id);
    expect(after.name).toBe(before.name);
    console.log(`  pinned content · ${before.id.slice(0, 24)}… became ${after.id.slice(0, 24)}…`);
  });

  it("is a 404 on re-fetch, and not the new items under the old pack's id", async () => {
    // The fix. A row whose content this build can no longer produce is the
    // 404 `GET /packs/{packId}` already answered for content it no longer
    // ships, and the client reads that one answer as "ask for a new pack"
    // (`app/lib/features/sync/policy/pack_refresh.dart`).
    const issued = await issue(v1);

    const again = await app(v2).fetch(
      new Request(`http://localhost/packs/${issued.packId}`, { method: "GET" }),
    );

    expect(again.status).toBe(404);
    expect(((await again.json()) as { error: string }).error).toBe("no_such_pack");
  });

  it("and an answer earned against the body the device still holds is still right", async () => {
    // The fix must not strand an unsynced attempt. Grading reads the digest and
    // the salt off the row and never touches content, so a device that played
    // the old pack offline syncs it exactly as before.
    const issued = await issue(v1);

    expect(await answer(v2, issued.packId, 0, answers[0]!)).toBe(true);
  });

  it("while the answer the new items would have shown is wrong, which is why the 404 exists", async () => {
    // The hazard itself, kept as a test rather than as a memory. Index 0 of the
    // edited artifact is the old index 1, so `answers[1]` is what a player
    // handed the new body would type — and the row grades it against the old
    // item 0. Before the fix this reached a player: `GET /packs/{packId}`
    // answered 200 with exactly that body.
    const issued = await issue(v1);

    expect(await answer(v2, issued.packId, 0, answers[1]!)).toBe(false);
  });

  it("the rating is told the difficulty is unknown, not handed the new content's", async () => {
    // `stepInContent` reads the ladder step out of the content the row names,
    // and a row this build cannot resolve has none to read. Null is the honest
    // answer and the rating counts it as unplaced; borrowing whatever item now
    // sits at that index would measure the player against a class they never
    // met.
    expect(before.pack.items[1]!.ladder_step).toBeGreaterThan(0);
    const stale = await issue(v1);
    await answer(v2, stale.packId, 0, answers[0]!);

    const unplaced = await db.client.query("SELECT 1 FROM difficulty_ratings");
    expect(unplaced.rowCount).toBe(0);

    // The control, in the same test because either half alone is satisfiable
    // by accident: a rating that never wrote a difficulty row would pass the
    // assertion above and would be a rating measuring nothing.
    const current = await issue(v2);
    await answer(v2, current.packId, 0, answers[1]!);

    const placed = await db.client.query("SELECT 1 FROM difficulty_ratings");
    expect(placed.rowCount).toBe(1);
  });

  it("and issuing again gives the new content, which grades correctly", async () => {
    // The whole recovery, end to end: the 404 above sends the client here, and
    // what it gets is a pack of the edited artifact whose answers are graded
    // against the edited artifact's digests.
    const issued = await issue(v2);

    expect(issued.pack.items[0]!.answer.digest).toBe(after.pack.items[0]!.answer.digest);
    expect(await answer(v2, issued.packId, 0, answers[1]!)).toBe(true);

    const row = await db.client.query<{ content_id: string }>(
      "SELECT content_id FROM offline_packs WHERE id = $1",
      [issued.packId],
    );
    expect(row.rows[0]?.content_id).toBe(after.id);
  });
});
