import { toManifestEntry, type TemplateRef } from "@akimath/core";
import { afterEach, beforeEach, expect, it } from "vitest";

import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
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
      `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
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
    // Migration 0002 refuses a numeric seed in `template_refs` because `jsonb`
    // is read with `JSON.parse` and a bigint above 2^53 comes back wrong. This
    // is the code side of the same rule, end to end: the constraint is on the
    // *pack's* refs, so a pack that somehow carried one — or a future writer
    // that forgot — is answered as "no such item" rather than graded against an
    // item nobody was ever shown.
    const loose = "018f4e3c-0000-7000-8000-0000000000f7";
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
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
