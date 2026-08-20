import { afterEach, beforeEach, expect, it } from "vitest";

import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
import { HISTORY_LIMIT } from "../src/history.js";
import type { Caller } from "../src/routing.js";
import { describeWithDatabase, freshDatabase, type TestDatabase } from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-00000000cd01";
const OTHER_ACCOUNT = "6f2b1c8d-0000-4000-8000-00000000cd02";
const PLAYER = "018f4e3c-0000-7000-8000-00000000cd01";
const OTHER_PLAYER = "018f4e3c-0000-7000-8000-00000000cd02";
const PACK = "018f4e3c-0000-7000-8000-00000000cd03";
const AT = "2026-08-19T09:15:00.000Z";

interface Entry {
  readonly kind: string;
  readonly title: string;
  readonly at: string;
  readonly score: string;
  readonly ratingDelta: number | null;
}

describeWithDatabase("GET /me/history, against a real database", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;
  let nextIndex = 0;

  const history = async (account: string = ACCOUNT): Promise<Response> =>
    createApp({
      version: "1.2.3",
      verify: () => Promise.resolve({ kind: "session", userId: account } as Caller),
      log: createLogger({ level: "error", write: () => {}, now: () => new Date(AT) }),
      handlers: createHandlers(requests),
    }).fetch(new Request("http://localhost/me/history", { method: "GET" }));

  const entries = async (account: string = ACCOUNT): Promise<Entry[]> =>
    ((await (await history(account)).json()) as { entries: Entry[] }).entries;

  /** One attempt, in `session`, `minutes` after the hour. */
  const answered = async (options: {
    player?: string;
    session: string;
    correct: boolean;
    minutes: number;
    skillId?: number;
  }): Promise<void> => {
    await db.client.query(
      `INSERT INTO attempts
         (id, player_id, pack_id, pack_index, skill_id, is_correct, elapsed_ms,
          answered_at, session_id)
       VALUES (gen_random_uuid(), $1, $2, $3::smallint, $4::smallint, $5, 4200,
               $6::timestamptz, $7)`,
      [
        options.player ?? PLAYER,
        PACK,
        nextIndex++,
        options.skillId ?? 1,
        options.correct,
        new Date(Date.UTC(2026, 7, 19, 9, options.minutes)).toISOString(),
        options.session,
      ],
    );
  };

  const uuid = (tail: number): string =>
    `018f4e3c-0000-7000-8000-${tail.toString(16).padStart(12, "0")}`;

  beforeEach(async () => {
    db = await freshDatabase();
    requests = createRequestDatabase(db.url);
    nextIndex = 0;
    for (const [player, account] of [
      [PLAYER, ACCOUNT],
      [OTHER_PLAYER, OTHER_ACCOUNT],
    ]) {
      await db.client.query(
        "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', $2)",
        [player, account],
      );
    }
    // One pack per player, so the attempts have somewhere to hang.
    for (const [id, player] of [
      [PACK, PLAYER],
      [uuid(0xdd), OTHER_PLAYER],
    ]) {
      await db.client.query(
        `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
         VALUES ($1, $2, '[]'::jsonb, '\\x00', now() + interval '30 days')`,
        [id, player],
      );
    }
  });

  afterEach(async () => {
    await requests.close();
    await db.close();
  });

  it("a session becomes one entry, scored", async () => {
    const session = uuid(0x51);
    await answered({ session, correct: true, minutes: 1 });
    await answered({ session, correct: true, minutes: 2 });
    await answered({ session, correct: false, minutes: 3 });

    expect(await entries()).toEqual([
      {
        kind: "series",
        title: "Restas",
        // The last answer, which is when the session reads as having happened.
        at: "2026-08-19T09:03:00.000Z",
        score: "2/3",
        ratingDelta: null,
      },
    ]);
  });

  it("newest first, because that is the end a player reads from", async () => {
    await answered({ session: uuid(0x61), correct: true, minutes: 10 });
    await answered({ session: uuid(0x62), correct: false, minutes: 40 });
    await answered({ session: uuid(0x63), correct: true, minutes: 25 });

    expect((await entries()).map((entry) => entry.at)).toEqual([
      "2026-08-19T09:40:00.000Z",
      "2026-08-19T09:25:00.000Z",
      "2026-08-19T09:10:00.000Z",
    ]);
  });

  it("nobody else's sessions are in it", async () => {
    await answered({ session: uuid(0x71), correct: true, minutes: 5 });
    await answered({ player: OTHER_PLAYER, session: uuid(0x72), correct: true, minutes: 6 });

    expect(await entries()).toHaveLength(1);
    expect(await entries(OTHER_ACCOUNT)).toHaveLength(1);
  });

  it("a session spanning two skills is not named after one of them", async () => {
    // `min(skill_id)` would call it "Restas" because 1 sorts first, which is not
    // a fact about the session. No content can produce this yet; the query
    // answers correctly for the day it can.
    const session = uuid(0x81);
    await answered({ session, correct: true, minutes: 1, skillId: 1 });
    await answered({ session, correct: true, minutes: 2, skillId: 4 });

    expect((await entries())[0]?.title).toBe("Serie de retos");
  });

  it("a player who has played nothing gets a list, not a 404", async () => {
    const response = await history();

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ entries: [] });
  });

  it("an account with no player is told to link one first", async () => {
    await db.client.query("DELETE FROM players WHERE auth_user_id = $1", [ACCOUNT]);

    const response = await history();

    expect(response.status).toBe(404);
    expect(((await response.json()) as { error: string }).error).toBe("no_player");
  });

  it("and it carries at most the cap, newest kept", async () => {
    for (let n = 0; n < HISTORY_LIMIT + 3; n += 1) {
      await answered({ session: uuid(0x100 + n), correct: true, minutes: n });
    }

    const all = await entries();
    expect(all).toHaveLength(HISTORY_LIMIT);
    // The three oldest are the ones dropped.
    expect(all[all.length - 1]?.at).toBe("2026-08-19T09:03:00.000Z");
  });
});
