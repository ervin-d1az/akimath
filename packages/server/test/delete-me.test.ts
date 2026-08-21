import { afterEach, beforeEach, expect, it } from "vitest";

import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
import type { Caller } from "../src/routing.js";
import { validatesAsError } from "./support/contract.js";
import { describeWithDatabase, freshDatabase, type TestDatabase } from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000d1";
const OTHER_ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000d2";
const PLAYER = "018f4e3c-0000-7000-8000-0000000000d1";
const OTHER_PLAYER = "018f4e3c-0000-7000-8000-0000000000d2";

/**
 * Every table a player leaves a row in, and the ones that survive on purpose.
 *
 * The survivors are named rather than omitted: they hold no player id, they are
 * how calibration survives the retention job deleting raw attempts
 * (`adapters/retention-job.ts`), and a later reader finding one absent from this
 * list would have to guess whether that was a decision or an oversight.
 *
 * `difficulty_ratings` is the one the rating actually uses. It is an aggregate
 * over every player who met a difficulty class, so erasing one player must not
 * empty it — and it carries no `player_id`, which is what makes that true by
 * construction rather than by this test passing.
 */
const PLAYER_TABLES = [
  "attempts",
  "diag_events",
  "issued_items",
  "offline_packs",
  "user_skills",
] as const;

const SURVIVES_ERASURE: readonly {
  readonly table: string;
  readonly seed: string;
  readonly probe: string;
  readonly expected: string;
}[] = [
  {
    table: "template_stats",
    seed: "INSERT INTO template_stats (template_id, template_version, attempts) VALUES ('add-2', 1, 41)",
    probe: "SELECT attempts::text AS value FROM template_stats",
    expected: "41",
  },
  {
    table: "difficulty_ratings",
    seed: `INSERT INTO difficulty_ratings (skill_id, ladder_step, rating, deviation)
           VALUES (1, 3, 1234, 87)`,
    probe: "SELECT rating::text AS value FROM difficulty_ratings",
    expected: "1234",
  },
];

describeWithDatabase("DELETE /me, against a real database", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;

  const erase = async (account: string = ACCOUNT): Promise<Response> => {
    const caller: Caller = { kind: "session", userId: account };
    return createApp({
      version: "1.2.3",
      verify: () => Promise.resolve(caller),
      log: createLogger({
        level: "error",
        write: () => {},
        now: () => new Date("2026-08-19T09:15:00.000Z"),
      }),
      handlers: createHandlers(requests),
    }).fetch(new Request("http://localhost/me", { method: "DELETE" }));
  };

  /**
   * A player with one row in every table that references them.
   *
   * The child ids are built from the player's own last byte, so two seeded
   * players cannot collide — which they did on the first run of this file, and
   * the collision looked like a primary-key error rather than a test bug.
   */
  const seed = async (player: string, account: string): Promise<void> => {
    const mine = (nth: string): string => player.slice(0, -2) + nth;
    const item = mine(`e${player.slice(-1)}`);
    const pack = mine(`f${player.slice(-1)}`);
    const attempt = mine(`a${player.slice(-1)}`);
    const event = mine(`b${player.slice(-1)}`);
    await db.client.query(
      "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', $2)",
      [player, account],
    );
    await db.client.query(
      `INSERT INTO issued_items (id, player_id, template_id, template_version, seed, ladder_step)
            VALUES ($1, $2, 'add-2', 1, 7, 3)`,
      [item, player],
    );
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, item_refs, pack_salt, expires_at)
            VALUES ($1, $2, '[]'::jsonb, '\\x00', now())`,
      [pack, player],
    );
    await db.client.query(
      `INSERT INTO attempts (id, player_id, issued_item_id, skill_id, is_correct,
                             elapsed_ms, answered_at, session_id)
            VALUES ($1, $2, $3, 1, true, 1200, now(), gen_random_uuid())`,
      [attempt, player, item],
    );
    await db.client.query(
      "INSERT INTO user_skills (player_id, skill_id, rating, deviation) VALUES ($1, 1, 1000, 300)",
      [player],
    );
    await db.client.query(
      `INSERT INTO diag_events (id, player_id, attempt_id, misconception_id)
            VALUES ($1, $2, $3, 'off-by-one')`,
      [event, player, attempt],
    );
  };

  const rowsFor = async (player: string): Promise<Record<string, number>> => {
    const counts: Record<string, number> = {};
    for (const table of PLAYER_TABLES) {
      const result = await db.client.query(
        `SELECT count(*)::int AS n FROM ${table} WHERE player_id = $1`,
        [player],
      );
      counts[table] = result.rows[0]?.n ?? -1;
    }
    return counts;
  };

  beforeEach(async () => {
    db = await freshDatabase();
    requests = createRequestDatabase(db.url);
    for (const aggregate of SURVIVES_ERASURE) {
      await db.client.query(aggregate.seed);
    }
  });

  afterEach(async () => {
    await requests.close();
    await db.close();
  });

  it("answers 204 with no body at all", async () => {
    await seed(PLAYER, ACCOUNT);

    const response = await erase();

    // **Through `createApp().fetch`, not through `route()`.** A 204 carrying a
    // body is not a weaker answer, it is a `TypeError` inside the Fetch
    // `Response` constructor — thrown where the handler's own try/catch cannot
    // see it. Asserting the status on the pure decision would pass while the
    // real endpoint returned a 500.
    expect(response.status).toBe(204);
    expect(await response.text()).toBe("");
    expect(response.headers.get("content-type")).toBeNull();
  });

  it("and every row that referenced the player is gone", async () => {
    await seed(PLAYER, ACCOUNT);
    expect(Object.values(await rowsFor(PLAYER))).not.toContain(0);

    await erase();

    expect(await rowsFor(PLAYER)).toEqual(
      Object.fromEntries(PLAYER_TABLES.map((table) => [table, 0])),
    );
    const player = await db.client.query("SELECT 1 FROM players WHERE id = $1", [PLAYER]);
    expect(player.rowCount).toBe(0);
  });

  it("every aggregate that carries no player survives", async () => {
    // PROC-10: driven by a list, so the count is reported and a list that
    // silently reached zero cannot pass as "nothing was wrong".
    expect(SURVIVES_ERASURE).not.toHaveLength(0);
    console.log(
      `  erasure · ${SURVIVES_ERASURE.length} aggregates survive: ` +
        SURVIVES_ERASURE.map((a) => a.table).join(", "),
    );
    await seed(PLAYER, ACCOUNT);

    await erase();

    for (const aggregate of SURVIVES_ERASURE) {
      const kept = await db.client.query<{ value: string }>(aggregate.probe);
      expect(kept.rows[0]?.value, `${aggregate.table} did not survive erasure`).toBe(
        aggregate.expected,
      );
    }
  });

  it("and nobody else's rows move", async () => {
    await seed(PLAYER, ACCOUNT);
    await seed(OTHER_PLAYER, OTHER_ACCOUNT);

    await erase();

    expect(await rowsFor(OTHER_PLAYER)).toEqual(
      Object.fromEntries(PLAYER_TABLES.map((table) => [table, 1])),
    );
  });

  it("an account with no player is told so, in the frozen Error shape", async () => {
    const response = await erase();

    expect(response.status).toBe(404);
    const body = await response.json();
    expect(validatesAsError(body)).toBe(true);
    expect((body as Record<string, unknown>)["error"]).toBe("no_player");
  });

  it("asked twice, the second time says there is nothing left", async () => {
    // Not 204 both times. The first call is the erasure; the second is a client
    // asking to erase something that does not exist, and telling it "done"
    // would hide a bug where the account it holds is not the one it thinks.
    await seed(PLAYER, ACCOUNT);

    expect((await erase()).status).toBe(204);
    expect((await erase()).status).toBe(404);
  });
});
