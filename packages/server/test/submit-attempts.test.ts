import { answerDigest } from "@akimath/contract";
import { toDigestEntry, toManifestEntry, type TemplateRef } from "@akimath/core";
import { afterEach, beforeEach, expect, it } from "vitest";

import { insertAttempts } from "../src/adapters/attempt-repository.js";
import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
import { sourceKey } from "../src/attempts.js";
import type { Caller } from "../src/routing.js";
import { validatesAsError } from "./support/contract.js";
import { describeWithDatabase, freshDatabase, type TestDatabase } from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000f1";
const OTHER_ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000f2";
const PLAYER = "018f4e3c-0000-7000-8000-0000000000f1";
const OTHER_PLAYER = "018f4e3c-0000-7000-8000-0000000000f2";
const ITEM = "018f4e3c-0000-7000-8000-0000000000f3";
const OTHER_ITEM = "018f4e3c-0000-7000-8000-0000000000f4";
const PACK = "018f4e3c-0000-7000-8000-0000000000f5";
const SESSION = "018f4e3c-0000-7000-8000-0000000000f6";

/**
 * `(arith.integer.subtract@2, seed 1000, step 3)`. `packages/core`'s golden
 * pins the arithmetic; this file only cares that the two ends agree.
 *
 * **Written through `toManifestEntry`, not by hand.** A hand-written manifest
 * here would be this file's guess at the shape, and the server reading its own
 * guess back proves nothing — a real pack written differently would make
 * `refForPackItem` return null for every item, and the 404 would look exactly
 * like a missing row.
 */
const TEMPLATE_REF: TemplateRef = {
  templateId: "arith.integer.subtract",
  templateVersion: 2,
  seed: 1000n,
  ladderStep: 3,
};
const REF = toManifestEntry(TEMPLATE_REF);
const ANSWER = "-9";
const AT = "2026-08-19T09:15:00.000Z";

describeWithDatabase("POST /attempts, against a real database", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;

  const submit = async (body: unknown, account: string = ACCOUNT): Promise<Response> => {
    const caller: Caller = { kind: "session", userId: account };
    return createApp({
      version: "1.2.3",
      verify: () => Promise.resolve(caller),
      log: createLogger({ level: "error", write: () => {}, now: () => new Date(AT) }),
      handlers: createHandlers(requests),
    }).fetch(
      new Request("http://localhost/attempts", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      }),
    );
  };

  const attempt = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
    itemId: ITEM,
    sessionId: SESSION,
    answer: ANSWER,
    clientTs: AT,
    elapsedMs: 4200,
    ...over,
  });

  const rows = async (): Promise<
    readonly {
      player_id: string;
      issued_item_id: string | null;
      pack_id: string | null;
      pack_index: number | null;
      skill_id: number;
      is_correct: boolean;
      elapsed_ms: number;
      answered_at: Date;
    }[]
  > =>
    (
      await db.client.query(
        `SELECT player_id, issued_item_id, pack_id, pack_index, skill_id,
                is_correct, elapsed_ms, answered_at
           FROM attempts ORDER BY answered_at, pack_index NULLS FIRST`,
      )
    ).rows;

  beforeEach(async () => {
    db = await freshDatabase();
    requests = createRequestDatabase(db.url);
    for (const [player, account] of [
      [PLAYER, ACCOUNT],
      [OTHER_PLAYER, OTHER_ACCOUNT],
    ]) {
      await db.client.query(
        "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', $2)",
        [player, account],
      );
    }
    await db.client.query(
      `INSERT INTO issued_items (id, player_id, template_id, template_version, seed, ladder_step)
            VALUES ($1, $2, $3, $4, $5, $6)`,
      [ITEM, PLAYER, REF.template_id, REF.template_version, REF.seed, REF.ladder_step],
    );
    // The same item, issued to somebody else.
    await db.client.query(
      `INSERT INTO issued_items (id, player_id, template_id, template_version, seed, ladder_step)
            VALUES ($1, $2, $3, $4, $5, $6)`,
      [OTHER_ITEM, OTHER_PLAYER, REF.template_id, REF.template_version, REF.seed, REF.ladder_step],
    );
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, item_refs, pack_salt, expires_at)
            VALUES ($1, $2, $3::jsonb, '\\x00', now() + interval '30 days')`,
      [PACK, PLAYER, JSON.stringify([REF, REF])],
    );
  });

  afterEach(async () => {
    await requests.close();
    await db.close();
  });

  it("grades an issued item by rederiving it, and records the attempt", async () => {
    const response = await submit({ attempts: [attempt()] });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      verdicts: [{ itemId: ITEM, ok: true, payload: {} }],
    });

    const [row] = await rows();
    expect(row).toMatchObject({
      player_id: PLAYER,
      issued_item_id: ITEM,
      pack_id: null,
      pack_index: null,
      // From the template, which is the only thing in a recorded reference
      // that knows which skill it exercises.
      skill_id: 1,
      is_correct: true,
      elapsed_ms: 4200,
    });
    expect(row?.answered_at.toISOString()).toBe(AT);
  });

  it("and a pack item, whose identity is a pair", async () => {
    const response = await submit({
      attempts: [attempt({ itemId: undefined, packRef: { packId: PACK, index: 1 } })],
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      verdicts: [{ packRef: { packId: PACK, index: 1 }, ok: true, payload: {} }],
    });
    expect((await rows())[0]).toMatchObject({
      issued_item_id: null,
      pack_id: PACK,
      pack_index: 1,
      is_correct: true,
    });
  });

  it("a wrong answer is recorded as one, not refused", async () => {
    const response = await submit({ attempts: [attempt({ answer: "9" })] });

    expect(response.status).toBe(200);
    expect((await rows())[0]?.is_correct).toBe(false);
  });

  it("and so is nonsense a learner could type", async () => {
    // Throwing here would turn one bad row into a 500 for the whole batch.
    const response = await submit({ attempts: [attempt({ answer: "no sé" })] });

    expect(response.status).toBe(200);
    expect((await rows())[0]?.is_correct).toBe(false);
  });

  it("the whole batch lands, in the order it arrived", async () => {
    const response = await submit({
      attempts: [
        attempt({ clientTs: "2026-08-19T09:00:00.000Z" }),
        attempt({ itemId: undefined, packRef: { packId: PACK, index: 0 }, answer: "9", clientTs: "2026-08-19T09:01:00.000Z" }),
      ],
    });

    const body = (await response.json()) as { verdicts: { ok: boolean }[] };
    expect(body.verdicts.map((v) => v.ok)).toEqual([true, false]);
    expect(await rows()).toHaveLength(2);
  });

  it("an authored item grades by its digest, which is the only way it can", async () => {
    // **The change this exists for.** An authored item has no template
    // reference, so `(packId, index)` could not address it and nothing could
    // grade it — and seventy of the eighty items the app ships are authored.
    // The pack already carries `HMAC(pack_salt, canonical answer)`; the server
    // keeps the salt and recomputes it over what was typed.
    //
    // It never learns the answer. It holds a digest and can only confirm or
    // deny a guess, which is a stronger position than rederivation leaves it
    // in.
    const authored = "018f4e3c-0000-7000-8000-00000000e001";
    const saltHex = "a1b2c3d4e5f60718293a4b5c6d7e8f90";
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, item_refs, pack_salt, expires_at)
            VALUES ($1, $2, $3::jsonb, decode($4, 'hex'), now() + interval '30 days')`,
      [
        authored,
        PLAYER,
        JSON.stringify([toDigestEntry({ digest: answerDigest(saltHex, "7"), skillId: 4 })]),
        saltHex,
      ],
    );

    const right = await submit({
      attempts: [
        attempt({ itemId: undefined, packRef: { packId: authored, index: 0 }, answer: "7" }),
      ],
    });

    expect(right.status).toBe(200);
    expect(((await right.json()) as { verdicts: { ok: boolean }[] }).verdicts[0]?.ok).toBe(true);
    // The skill comes from the manifest, because there is no template to ask.
    expect((await rows())[0]).toMatchObject({ skill_id: 4, is_correct: true, pack_index: 0 });
  });

  it("and a wrong answer to one is recorded as wrong, not refused", async () => {
    const authored = "018f4e3c-0000-7000-8000-00000000e002";
    const saltHex = "a1b2c3d4e5f60718293a4b5c6d7e8f90";
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, item_refs, pack_salt, expires_at)
            VALUES ($1, $2, $3::jsonb, decode($4, 'hex'), now() + interval '30 days')`,
      [
        authored,
        PLAYER,
        JSON.stringify([toDigestEntry({ digest: answerDigest(saltHex, "7"), skillId: 4 })]),
        saltHex,
      ],
    );

    const response = await submit({
      attempts: [
        attempt({ itemId: undefined, packRef: { packId: authored, index: 0 }, answer: "8" }),
      ],
    });

    expect(response.status).toBe(200);
    expect((await rows())[0]).toMatchObject({ skill_id: 4, is_correct: false });
  });

  it("an item this player does not have is a 404, and nothing is written", async () => {
    // **Atomic on purpose.** Recording the first attempt and refusing the
    // second would leave the client unable to tell what landed, and `attempts`
    // takes no UPDATE and no DELETE from the request path.
    const response = await submit({
      attempts: [attempt(), attempt({ itemId: OTHER_ITEM })],
    });

    expect(response.status).toBe(404);
    const body = await response.json();
    expect(validatesAsError(body)).toBe(true);
    // Named by index, because a batch of fifty is undiagnosable without it.
    expect((body as { message: string }).message).toContain("attempts[1]");
    expect(await rows()).toHaveLength(0);
  });

  it("and so is a pack index past the end of the manifest", async () => {
    const response = await submit({
      attempts: [attempt({ itemId: undefined, packRef: { packId: PACK, index: 7 } })],
    });

    expect(response.status).toBe(404);
    expect(await rows()).toHaveLength(0);
  });

  it("a manifest entry written the losing way is refused, not misread", async () => {
    // Migration 0002 refuses a numeric seed in `item_refs` because `jsonb`
    // is read with `JSON.parse` and a bigint above 2^53 comes back wrong. This
    // is the code side of the same rule, end to end: the constraint is on the
    // *pack's* refs, so a pack that somehow carried one — or a future writer
    // that forgot — is answered as "no such item" rather than graded against an
    // item nobody was ever shown.
    const loose = "018f4e3c-0000-7000-8000-0000000000f7";
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, item_refs, pack_salt, expires_at)
            VALUES ($1, $2, $3::jsonb, '\\x00', now() + interval '30 days')`,
      [
        loose,
        PLAYER,
        // Straight into the column, bypassing the CHECK by being a *number* the
        // constraint would refuse — asserted here so the two halves cannot
        // drift apart quietly.
        JSON.stringify([{ ...REF, seed: 1000 }]),
      ],
    ).catch(() => undefined);

    const wrote = await db.client.query("SELECT 1 FROM offline_packs WHERE id = $1", [loose]);
    if (wrote.rowCount === 0) {
      // The database refused it, which is migration 0002 doing its job — the
      // stronger of the two guards. Nothing left for the reader to prove.
      expect(wrote.rowCount).toBe(0);
      return;
    }

    const response = await submit({
      attempts: [attempt({ itemId: undefined, packRef: { packId: loose, index: 0 } })],
    });
    expect(response.status).toBe(404);
    expect(await rows()).toHaveLength(0);
  });

  it("the session travels, so a history can be grouped by it", async () => {
    // Every submission has carried a `sessionId` since the freeze and the table
    // had no column for it, which is why `GET /me/history` had nothing to build
    // a series out of. Migration 0004 is the answer to that open question.
    await submit({ attempts: [attempt()] });

    const [row] = await db.client.query<{ session_id: string }>(
      "SELECT session_id FROM attempts",
    ).then((r) => r.rows);
    expect(row?.session_id).toBe(SESSION);
  });

  it("sent twice, it records once and answers the same thing", async () => {
    // The retry this endpoint used to double. `attempts` accepts no UPDATE and
    // no DELETE from the request path, so nothing could have cleaned it up —
    // the counts would simply have been wrong, and the rating with them.
    //
    // Idempotent *by nature*: the verdicts are recomputed from the same inputs
    // rather than replayed from a store, the same way `linkPlayer` is.
    const first = await submit({ attempts: [attempt()] });
    const second = await submit({ attempts: [attempt()] });

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect(await second.json()).toEqual(await first.json());
    expect(await rows()).toHaveLength(1);
  });

  it("the insert reports which rows it actually appended, not how many were sent", async () => {
    // **The fact the rating is built on.** `ON CONFLICT DO NOTHING` means a
    // resent batch inserts nothing, and a caller that rated what it *submitted*
    // rather than what *landed* would move the rating twice for one answer.
    // `rowCount` alone cannot say it either: the rating has to know *which*
    // rows, because a batch is routinely part new and part replay.
    const row = {
      playerId: PLAYER,
      sessionId: SESSION,
      skillId: 1,
      isCorrect: true,
      elapsedMs: 10,
      answeredAt: AT,
    };
    const issued = { ...row, source: { kind: "issued", itemId: ITEM } } as const;
    const packed = {
      ...row,
      source: { kind: "pack", packId: PACK, index: 0 },
    } as const;

    await requests.inRequestRole(async (client) => {
      const first = await insertAttempts(client, [issued]);
      expect(first.map(sourceKey)).toEqual([sourceKey(issued.source)]);

      // The same item again, alongside one the table has never seen. Only the
      // second is new, and only the second may be rated.
      const second = await insertAttempts(client, [issued, packed]);
      expect(second.map(sourceKey)).toEqual([sourceKey(packed.source)]);

      // And a batch that is wholly a replay lands nothing at all.
      expect(await insertAttempts(client, [issued, packed])).toEqual([]);
    });
  });

  it("and the database refuses a duplicate even when nothing asked it nicely", async () => {
    // The reader refuses a repeated source and the insert says `ON CONFLICT DO
    // NOTHING`, so neither path can produce one. This is the constraint itself,
    // proven directly — the guard that is still there when a future writer
    // forgets both.
    await submit({ attempts: [attempt()] });

    await expect(
      db.client.query(
        `INSERT INTO attempts
           (id, player_id, issued_item_id, skill_id, is_correct, elapsed_ms, answered_at, session_id)
         VALUES (gen_random_uuid(), $1, $2, 1, true, 10, now(), $3)`,
        [PLAYER, ITEM, SESSION],
      ),
    ).rejects.toThrow(/attempts_one_per_issued_item/);

    await db.client.query(
      `INSERT INTO attempts
         (id, player_id, pack_id, pack_index, skill_id, is_correct, elapsed_ms, answered_at, session_id)
       VALUES (gen_random_uuid(), $1, $2, 0, 1, true, 10, now(), $3)`,
      [PLAYER, PACK, SESSION],
    );
    await expect(
      db.client.query(
        `INSERT INTO attempts
           (id, player_id, pack_id, pack_index, skill_id, is_correct, elapsed_ms, answered_at, session_id)
         VALUES (gen_random_uuid(), $1, $2, 0, 1, true, 10, now(), $3)`,
        [PLAYER, PACK, SESSION],
      ),
    ).rejects.toThrow(/attempts_one_per_pack_item/);
  });

  it("an account with no player is told to link one first", async () => {
    await db.client.query("DELETE FROM players WHERE auth_user_id = $1", [ACCOUNT]);

    const response = await submit({ attempts: [attempt()] });

    expect(response.status).toBe(404);
    expect((await response.json() as { error: string }).error).toBe("no_player");
  });

  it("an empty batch is answered, and writes nothing", async () => {
    const response = await submit({ attempts: [] });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ verdicts: [] });
    expect(await rows()).toHaveLength(0);
  });

  it("a body asserting its own verdict is refused before any of it is read", async () => {
    const response = await submit({ attempts: [attempt({ ok: true })] });

    expect(response.status).toBe(400);
    expect((await response.json() as { message: string }).message).toContain("ok");
    expect(await rows()).toHaveLength(0);
  });
});
