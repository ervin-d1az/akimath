import { afterEach, beforeEach, expect, it } from "vitest";

import {
  describeWithDatabase,
  freshDatabase,
  tableNames,
  type TestDatabase,
} from "./support/database.js";

const PLAYER = "018f4e3c-0000-7000-8000-0000000000aa";
const PACK = "018f4e3c-0000-7000-8000-0000000000bb";

/**
 * Fifty references, the shape the pack builder will emit.
 *
 * **The seed is a JSON string.** `template_refs` is `jsonb`, and node-postgres
 * parses jsonb with `JSON.parse`, so a seed above 2^53 stored as a JSON number
 * comes back a different number. Migration 0002 refuses one at the database.
 */
const fiftyRefs = Array.from({ length: 50 }, (_, index) => ({
  template_id: `t-${index}`,
  template_version: 1,
  seed: String(index),
  ladder_step: 2,
}));

/** A seed that cannot survive a round trip through a JSON number. */
const HUGE_SEED = "9223372036854775807";

describeWithDatabase("an offline pack is one row, not one row per item", () => {
  let db: TestDatabase;

  beforeEach(async () => {
    db = await freshDatabase();
    await db.client.query(
      "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'under_13', gen_random_uuid())",
      [PLAYER],
    );
  });

  afterEach(async () => {
    await db.close();
  });

  it("a fifty-item pack is one row carrying fifty references", async () => {
    // The constraint that forced the manifest: the server must be able to
    // revalidate every offline item, and the data model cannot pay four
    // downloads a day times fifty rows.
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
       VALUES ($1, $2, $3::jsonb, $4, now() + interval '7 days')`,
      [PACK, PLAYER, JSON.stringify(fiftyRefs), Buffer.from("salt")],
    );

    const rows = await db.client.query<{ refs: number }>(
      `SELECT jsonb_array_length(template_refs) AS refs
         FROM offline_packs WHERE id = $1`,
      [PACK],
    );

    expect(rows.rowCount, "a pack became more than one row").toBe(1);
    expect(rows.rows[0]?.refs).toBe(50);
  });

  it("a seed survives the round trip through jsonb exactly", async () => {
    // The whole reason 0002 exists. `issued_items.seed` is `bigint`, which
    // pg-types hands back as a raw string and is therefore safe; `template_refs`
    // is `jsonb`, which it hands to `JSON.parse`. Same seed, two storage paths,
    // and only one of them used to be lossy.
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
       VALUES ($1, $2, $3::jsonb, $4, now() + interval '7 days')`,
      [
        PACK,
        PLAYER,
        JSON.stringify([
          { template_id: "t-0", template_version: 1, seed: HUGE_SEED, ladder_step: 2 },
        ]),
        Buffer.from("salt"),
      ],
    );

    const read = await db.client.query<{ refs: { seed: string }[] }>(
      "SELECT template_refs AS refs FROM offline_packs WHERE id = $1",
      [PACK],
    );
    const seed = read.rows[0]?.refs[0]?.seed;

    expect(seed).toBe(HUGE_SEED);
    expect(BigInt(seed as string)).toBe(9223372036854775807n);
  });

  it("a seed stored as a JSON number is refused", async () => {
    // Not "discouraged in a comment". `splitmix64` avalanches, so a seed off by
    // one rederives an unrelated item rather than a similar one — and every
    // schema in the frozen pack format would still be perfectly happy with it.
    await expect(
      db.client.query(
        `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
         VALUES ($1, $2, $3::jsonb, $4, now() + interval '7 days')`,
        [
          PACK,
          PLAYER,
          JSON.stringify([
            { template_id: "t-0", template_version: 1, seed: 9223372036854775807, ladder_step: 2 },
          ]),
          Buffer.from("salt"),
        ],
      ),
    ).rejects.toThrow(/offline_packs_seeds_are_strings/);
  });

  it("a small seed as a number is refused too, not just a lossy one", async () => {
    // The rule is about the *type*, not about the magnitude. A magnitude rule
    // would let every seed under 2^53 through and fail the day the generator
    // started minting full-width ones — which is to say, in production.
    await expect(
      db.client.query(
        `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
         VALUES ($1, $2, $3::jsonb, $4, now() + interval '7 days')`,
        [
          PACK,
          PLAYER,
          JSON.stringify([
            { template_id: "t-0", template_version: 1, seed: 7, ladder_step: 2 },
          ]),
          Buffer.from("salt"),
        ],
      ),
    ).rejects.toThrow(/offline_packs_seeds_are_strings/);
  });

  it("no table in the schema is keyed per offline item", async () => {
    // The failure this guards is a later migration adding `offline_items`
    // because a per-item row felt tidier. Enumerated, so it fails here rather
    // than in a review nobody ran.
    const tables = await tableNames(db.client);
    expect(tables.length).toBeGreaterThan(0);
    console.log(`  offline packs · swept ${tables.length} tables`);

    const perItem = tables.filter((name) =>
      /^(offline_)?(pack_)?items?$/.test(name),
    );
    expect(perItem, "a per-offline-item table appeared").toEqual([]);
  });

  it("an attempt names an offline item by pack and index", async () => {
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
       VALUES ($1, $2, $3::jsonb, $4, now() + interval '7 days')`,
      [PACK, PLAYER, JSON.stringify(fiftyRefs), Buffer.from("salt")],
    );

    await expect(
      db.client.query(
        `INSERT INTO attempts
           (id, player_id, pack_id, pack_index, skill_id, is_correct, elapsed_ms,
            answered_at, session_id)
         VALUES ($1, $2, $3, 7, 1, true, 4200, now(), gen_random_uuid())`,
        ["018f4e3c-0000-7000-8000-0000000000cc", PLAYER, PACK],
      ),
    ).resolves.toBeTruthy();
  });

  it("an attempt cannot name both an issued item and a pack", async () => {
    // Exactly one source, or "where did this item come from" has two answers
    // and rederivation has none.
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
       VALUES ($1, $2, '[]'::jsonb, $3, now() + interval '7 days')`,
      [PACK, PLAYER, Buffer.from("salt")],
    );
    await db.client.query(
      `INSERT INTO issued_items
         (id, player_id, template_id, template_version, seed, ladder_step)
       VALUES ($1, $2, 't-1', 1, 99, 2)`,
      ["018f4e3c-0000-7000-8000-0000000000dd", PLAYER],
    );

    await expect(
      db.client.query(
        `INSERT INTO attempts
           (id, player_id, issued_item_id, pack_id, pack_index, skill_id,
            is_correct, elapsed_ms, answered_at, session_id)
         VALUES ($1, $2, $3, $4, 7, 1, true, 4200, now(), gen_random_uuid())`,
        [
          "018f4e3c-0000-7000-8000-0000000000ee",
          PLAYER,
          "018f4e3c-0000-7000-8000-0000000000dd",
          PACK,
        ],
      ),
    ).rejects.toThrow(/attempts_one_source/);
  });
});
