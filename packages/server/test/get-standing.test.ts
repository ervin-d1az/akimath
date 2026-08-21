import { afterEach, beforeEach, expect, it } from "vitest";

import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
import type { Caller } from "../src/routing.js";
import { describeWithDatabase, freshDatabase, type TestDatabase } from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-00000000ce01";
const OTHER_ACCOUNT = "6f2b1c8d-0000-4000-8000-00000000ce02";
const PLAYER = "018f4e3c-0000-7000-8000-00000000ce01";
const OTHER_PLAYER = "018f4e3c-0000-7000-8000-00000000ce02";
const AT = "2026-08-19T09:15:00.000Z";

interface Skill {
  readonly skillId: number;
  readonly rating: number;
  readonly deviation: number;
  readonly updatedAt: string;
}

/**
 * `GET /me/standing` against a real database.
 *
 * **The rows are seeded by hand, and that is the point.** Nothing in the server
 * writes `user_skills` — rating is F4 — so a suite that only ever saw the empty
 * case would be green against `return {skills: []}` and nobody would learn, on
 * the day a rating job lands, that the read was wrong (PROC-11). Seeding proves
 * the query, the grant and the mapping all work.
 */
describeWithDatabase("GET /me/standing, against a real database", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;

  const standing = async (account: string = ACCOUNT): Promise<Response> =>
    createApp({
      version: "1.2.3",
      verify: () => Promise.resolve({ kind: "session", userId: account } as Caller),
      log: createLogger({ level: "error", write: () => {}, now: () => new Date(AT) }),
      handlers: createHandlers(requests),
    }).fetch(new Request("http://localhost/me/standing", { method: "GET" }));

  const skills = async (account: string = ACCOUNT): Promise<Skill[]> =>
    ((await (await standing(account)).json()) as { skills: Skill[] }).skills;

  /** One `user_skills` row, as a rating job would eventually write it. */
  const rate = async (options: {
    player?: string;
    skillId: number;
    rating: number;
    deviation?: number;
    minutes?: number;
  }): Promise<void> => {
    await db.client.query(
      `INSERT INTO user_skills (player_id, skill_id, rating, deviation, updated_at)
       VALUES ($1, $2::smallint, $3::real, $4::real, $5::timestamptz)`,
      [
        options.player ?? PLAYER,
        options.skillId,
        options.rating,
        options.deviation ?? 350,
        new Date(Date.UTC(2026, 7, 19, 9, options.minutes ?? 15)).toISOString(),
      ],
    );
  };

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
  });

  afterEach(async () => {
    await requests.close();
    await db.close();
  });

  it("a rated skill comes back as the frozen entry", async () => {
    await rate({ skillId: 1, rating: 1200.5, deviation: 275 });

    const response = await standing();

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      playerId: PLAYER,
      skills: [
        {
          skillId: 1,
          rating: 1200.5,
          deviation: 275,
          updatedAt: "2026-08-19T09:15:00.000Z",
        },
      ],
    });
  });

  it("every rated skill, ordered by skill so two calls agree", async () => {
    // Without an ORDER BY, Postgres may answer these in either sequence and a
    // screen would reshuffle between refreshes.
    //
    // **The ratings deliberately disagree with the skill ids about order.** The
    // first version of this seeded 4→900, 1→1200.5, 2→1050, where sorting by
    // rating descending gives the same [1, 2, 4] — so the assertion held for a
    // query ordered by either column, and a falsification swapping `skill_id`
    // for `rating DESC` survived it (PROC-11). Highest rating is skill 4 now,
    // so only the intended order passes.
    await rate({ skillId: 4, rating: 1500 });
    await rate({ skillId: 1, rating: 900 });
    await rate({ skillId: 2, rating: 1050 });

    expect((await skills()).map((skill) => skill.skillId)).toEqual([1, 2, 4]);
  });

  it("nobody else's ratings are in it", async () => {
    await rate({ skillId: 1, rating: 1200.5 });
    await rate({ player: OTHER_PLAYER, skillId: 2, rating: 800 });

    expect((await skills()).map((skill) => skill.skillId)).toEqual([1]);
    expect((await skills(OTHER_ACCOUNT)).map((skill) => skill.skillId)).toEqual([2]);
  });

  it("a player nothing has rated gets an empty list, not a 404 and not a zero", async () => {
    // The state of every player today, because nothing writes `user_skills`.
    // A `rating: 0` here would be a figure the server invented, and the schema
    // gives no null to say "not yet" — the empty list is how absence is spelt.
    const response = await standing();

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ playerId: PLAYER, skills: [] });
  });

  it("an account with no player is told to link one first", async () => {
    await db.client.query("DELETE FROM players WHERE auth_user_id = $1", [ACCOUNT]);

    const response = await standing();

    expect(response.status).toBe(404);
    expect(((await response.json()) as { error: string }).error).toBe("no_player");
  });

  it("and it no longer answers 501", async () => {
    // The status this operation returned until this change. A route that kept
    // answering it while the handler existed would be the parity gate's other
    // direction failing in production rather than in CI.
    expect((await standing()).status).not.toBe(501);
  });

  it("the request path can read user_skills without the owner's rights", async () => {
    // `app_request` holds SELECT on the table by migration 0001, which is why
    // this needed no migration. A grant removed underneath would surface here
    // as a 500 rather than as a silently empty standing.
    await rate({ skillId: 1, rating: 1200.5 });

    const rows = await requests.inRequestRole(async (client) => {
      const result = await client.query("SELECT current_user AS who, count(*)::int AS n FROM user_skills");
      return result.rows[0] as { who: string; n: number };
    });

    expect(rows.who).toBe("app_request");
    expect(rows.n).toBe(1);
  });
});
