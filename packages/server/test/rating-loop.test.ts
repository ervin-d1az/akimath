import { initialSkill } from "@akimath/core";
import { afterEach, beforeEach, expect, it } from "vitest";

import { createApp, createHandlers } from "../src/adapters/http-server.js";
import { createLogger } from "../src/adapters/logger.js";
import { createRequestDatabase, type RequestDatabase } from "../src/adapters/request-database.js";
import { readShippedPacks } from "../src/adapters/shipped-packs.js";
import type { Caller } from "../src/routing.js";
import { authoredAnswers } from "./support/authored.js";
import { describeWithDatabase, freshDatabase, type TestDatabase } from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-00000000ac01";
const PLAYER = "018f4e3c-0000-7000-8000-00000000ac01";
const FIRST_SESSION = "018f4e3c-0000-7000-8000-00000000ac02";
const SECOND_SESSION = "018f4e3c-0000-7000-8000-00000000ac03";
const AT = "2026-08-19T09:15:00.000Z";
/** An hour after `AT`, for the one test that reads the order of two sessions. */
const LATER = "2026-08-19T10:15:00.000Z";

/**
 * The rating, end to end, against a real database.
 *
 * **This is the file that says F4 happened.** Everything else proves a piece:
 * that the engine matches Glickman, that a period is a session, that the insert
 * reports what landed. This one issues the pack the app actually ships, answers
 * it, and reads a number back out of `GET /me/standing` — the endpoint that has
 * answered `skills: []` for every player alive since it was built.
 */
describeWithDatabase("the rating, from answering to GET /me/standing", () => {
  let db: TestDatabase;
  let requests: RequestDatabase;

  const shipped = readShippedPacks().get("starter")!.pack;
  const answers = authoredAnswers();

  /**
   * Two pack indices per difficulty class, so a first session can measure the
   * class and a second can be rated against it.
   *
   * Taken from the shipped pack rather than written down: the content is a
   * product decision and it moves, and a hard-coded index would drift into
   * testing a different item without saying so.
   */
  const indicesForStep = (step: number): readonly number[] =>
    shipped.items
      .map((item, index) => ({ item, index }))
      .filter(({ item, index }) => item.ladder_step === step && index < answers.length)
      .map(({ index }) => index);

  const FIRST_STEP = indicesForStep(1);
  const SECOND_STEP = indicesForStep(2);

  const app = () =>
    createApp({
      version: "1.2.3",
      verify: () => Promise.resolve({ kind: "session", userId: ACCOUNT } as Caller),
      log: createLogger({ level: "error", write: () => {}, now: () => new Date(AT) }),
      handlers: createHandlers(requests),
    });

  const issue = async (): Promise<{ packId: string }> =>
    (await (
      await app().fetch(new Request("http://localhost/packs", { method: "POST" }))
    ).json()) as { packId: string };

  const sync = async (attempts: unknown[]): Promise<Response> =>
    app().fetch(
      new Request("http://localhost/attempts", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ attempts }),
      }),
    );

  /** One answered item, answered correctly unless told otherwise. */
  const answer = (
    packId: string,
    index: number,
    sessionId: string,
    correctly = true,
  ): Record<string, unknown> => ({
    packRef: { packId, index },
    sessionId,
    answer: correctly ? answers[index]! : `${answers[index]!}0000`,
    clientTs: AT,
    elapsedMs: 4200,
  });

  interface Standing {
    readonly playerId: string;
    readonly skills: readonly {
      readonly skillId: number;
      readonly rating: number;
      readonly deviation: number;
      readonly updatedAt: string;
    }[];
  }

  const standing = async (): Promise<Standing> =>
    (await (
      await app().fetch(new Request("http://localhost/me/standing"))
    ).json()) as Standing;

  interface HistoryEntry {
    readonly title: string;
    readonly score: string;
    readonly ratingDelta: number | null;
  }

  /** The entries `GET /me/history` answers, newest first. */
  const history = async (): Promise<readonly HistoryEntry[]> =>
    (
      (await (
        await app().fetch(new Request("http://localhost/me/history"))
      ).json()) as { entries: HistoryEntry[] }
    ).entries;

  /** What was written down about each rating period, unrounded. */
  const recorded = async (): Promise<
    readonly { session_id: string; skill_id: number; rating_delta: number }[]
  > =>
    (
      await db.client.query(
        `SELECT session_id, skill_id, rating_delta
           FROM session_deltas ORDER BY created_at, skill_id`,
      )
    ).rows;

  const classes = async (): Promise<
    readonly { skill_id: number; ladder_step: number; rating: number; deviation: number }[]
  > =>
    (
      await db.client.query(
        `SELECT skill_id, ladder_step, rating, deviation
           FROM difficulty_ratings ORDER BY skill_id, ladder_step`,
      )
    ).rows;

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

  it("the shipped pack covers each class more than once, or nothing here proves anything", () => {
    // PROC-10. Both lists feed every test below; if the content ever stopped
    // repeating a class, they would all pass by measuring nothing.
    expect(FIRST_STEP.length).toBeGreaterThan(1);
    expect(SECOND_STEP.length).toBeGreaterThan(1);
    console.log(
      `  rating · step 1 at ${FIRST_STEP.length} indices, step 2 at ${SECOND_STEP.length}`,
    );
  });

  it("the first session measures the classes and leaves the player unrated", async () => {
    // **The honest answer, and it is still `skills: []`.** Nothing in the
    // database says how hard these items are until somebody has answered them,
    // and a first rating computed against an assumed difficulty would be a
    // function of accuracy dressed as a measurement.
    const { packId } = await issue();

    const response = await sync([
      answer(packId, FIRST_STEP[0]!, FIRST_SESSION),
      answer(packId, SECOND_STEP[0]!, FIRST_SESSION),
    ]);

    expect(response.status).toBe(200);
    expect((await standing()).skills).toEqual([]);

    const measured = await classes();
    expect(measured.map((c) => c.ladder_step)).toEqual([1, 2]);
    // The player got both right, so both classes are now rated below the 1500
    // they started at, and both are more certain than the unrated 350.
    for (const one of measured) {
      expect(one.rating).toBeLessThan(initialSkill().rating);
      expect(one.deviation).toBeLessThan(initialSkill().deviation);
    }
  });

  it("and the second session is rated against what the first measured", async () => {
    // **The number becomes real here.** Every input is recorded evidence: the
    // classes' ratings came from play, and the player's comes from meeting
    // them.
    const { packId } = await issue();
    await sync([
      answer(packId, FIRST_STEP[0]!, FIRST_SESSION),
      answer(packId, SECOND_STEP[0]!, FIRST_SESSION),
    ]);

    await sync([
      answer(packId, FIRST_STEP[1]!, SECOND_SESSION),
      answer(packId, SECOND_STEP[1]!, SECOND_SESSION),
    ]);

    const { skills } = await standing();
    expect(skills).toHaveLength(1);
    expect(skills[0]!.skillId).toBe(1);
    expect(skills[0]!.rating).toBeGreaterThan(initialSkill().rating);
    expect(skills[0]!.deviation).toBeLessThan(initialSkill().deviation);
    expect(new Date(skills[0]!.updatedAt).getTime()).toBeGreaterThan(0);
  });

  it("a wrong answer against a measured class lowers the rating", async () => {
    // The control: without it, "the rating moved" is satisfied by a number that
    // only ever goes up, which is a score and not a rating.
    const { packId } = await issue();
    const measure = async (): Promise<void> => {
      await sync([
        answer(packId, FIRST_STEP[0]!, FIRST_SESSION),
        answer(packId, SECOND_STEP[0]!, FIRST_SESSION),
      ]);
    };
    await measure();

    await sync([
      answer(packId, FIRST_STEP[1]!, SECOND_SESSION, false),
      answer(packId, SECOND_STEP[1]!, SECOND_SESSION, false),
    ]);

    expect((await standing()).skills[0]!.rating).toBeLessThan(initialSkill().rating);
  });

  it("**a resent batch does not move the rating twice**", async () => {
    // The load-bearing one. `attempts` accepts no UPDATE and no DELETE from the
    // request path, so a rating that double-counted a retry could never be
    // repaired — and a sync that timed out and was retried is the ordinary
    // case, not the exotic one.
    const { packId } = await issue();
    await sync([
      answer(packId, FIRST_STEP[0]!, FIRST_SESSION),
      answer(packId, SECOND_STEP[0]!, FIRST_SESSION),
    ]);

    const batch = [
      answer(packId, FIRST_STEP[1]!, SECOND_SESSION),
      answer(packId, SECOND_STEP[1]!, SECOND_SESSION),
    ];
    const first = await sync(batch);
    const skillsOnce = (await standing()).skills;
    const classesOnce = await classes();

    const second = await sync(batch);

    expect(await second.json()).toEqual(await first.json());
    expect((await standing()).skills).toEqual(skillsOnce);
    // The classes must not move either: a replay teaches nothing new.
    expect(await classes()).toEqual(classesOnce);
  });

  it("an item named in upper case is still the item that was rated", async () => {
    // **Silent and unrepairable if it were wrong.** The frozen `uuid` pattern
    // accepts either case and the reader keeps what it was sent, but Postgres
    // canonicalises to lower case — so the id that comes back from `RETURNING`
    // is not textually the id that went in. Matching those two by raw string
    // would record the attempt and rate nothing, and a resend could not fix it:
    // the row already exists, so the second batch lands nothing either.
    const { packId } = await issue();
    await sync([
      answer(packId, FIRST_STEP[0]!, FIRST_SESSION),
      answer(packId, SECOND_STEP[0]!, FIRST_SESSION),
    ]);

    const shouted = {
      ...answer(packId, FIRST_STEP[1]!, SECOND_SESSION),
      packRef: { packId: packId.toUpperCase(), index: FIRST_STEP[1]! },
    };
    const response = await sync([shouted]);

    expect(response.status).toBe(200);
    expect((await standing()).skills).toHaveLength(1);
  });

  it("nothing is rated for an account with no player, and nothing is written", async () => {
    await db.client.query("DELETE FROM players WHERE id = $1", [PLAYER]);

    const response = await sync([]);

    expect(response.status).toBe(404);
    expect(await classes()).toEqual([]);
  });

  it("a session that only calibrated reports no movement, and records none", async () => {
    // **The end `GET /me/history` reads from.** Nothing measured the player —
    // both classes were new — so there is no movement to record and the entry
    // says so with a null rather than with a zero it would have to invent.
    const { packId } = await issue();

    await sync([
      answer(packId, FIRST_STEP[0]!, FIRST_SESSION),
      answer(packId, SECOND_STEP[0]!, FIRST_SESSION),
    ]);

    expect(await recorded()).toEqual([]);
    expect(await history()).toEqual([
      { kind: "series", title: "Restas", at: AT, score: "2/2", ratingDelta: null },
    ]);
  });

  it("and the session that was rated reports the movement, in whole points", async () => {
    const { packId } = await issue();
    await sync([
      answer(packId, FIRST_STEP[0]!, FIRST_SESSION),
      answer(packId, SECOND_STEP[0]!, FIRST_SESSION),
    ]);

    // **An hour later, spelled out.** Every other test here answers at `AT`,
    // which leaves the two sessions tied on `max(answered_at)` and "newest
    // first" satisfied by either order. This test reads the order, so it has
    // to earn one.
    await sync([
      { ...answer(packId, FIRST_STEP[1]!, SECOND_SESSION), clientTs: LATER },
      { ...answer(packId, SECOND_STEP[1]!, SECOND_SESSION), clientTs: LATER },
    ]);

    const moved = (await standing()).skills[0]!.rating - initialSkill().rating;
    expect(moved).not.toBe(0);
    const written = await recorded();
    expect(written).toHaveLength(1);
    expect(written[0]!.session_id).toBe(SECOND_SESSION);
    expect(written[0]!.rating_delta).toBeCloseTo(moved, 3);

    // Newest first, so the rated session leads and the calibrating one keeps
    // its null underneath — the two facts side by side in one answer.
    expect((await history()).map((entry) => entry.ratingDelta)).toEqual([
      Math.round(moved),
      null,
    ]);
  });

  it("**a resent batch does not record a second movement**", async () => {
    // Inherited from 0004 rather than re-implemented: nothing lands, so no
    // rating period is formed and there is nothing to write. The assertion is
    // still worth making, because "the rating did not move twice" and "the
    // history did not report the move twice" are two rows in two tables.
    const { packId } = await issue();
    await sync([
      answer(packId, FIRST_STEP[0]!, FIRST_SESSION),
      answer(packId, SECOND_STEP[0]!, FIRST_SESSION),
    ]);
    const batch = [
      answer(packId, FIRST_STEP[1]!, SECOND_SESSION),
      answer(packId, SECOND_STEP[1]!, SECOND_SESSION),
    ];
    await sync(batch);
    const once = await recorded();

    await sync(batch);

    expect(once).toHaveLength(1);
    expect(await recorded()).toEqual(once);
    expect(await history()).toEqual(await history());
  });

  it("a session synced in two batches records what both of them moved", async () => {
    // **The other half of idempotency, and a different branch.** A resend
    // lands nothing and never reaches the upsert; a device that flushed
    // mid-session and answered more of it does land, on a session that already
    // has a row. What that row must hold is everything the session moved, so
    // the two writes add rather than the second replacing the first.
    const { packId } = await issue();
    await sync([
      answer(packId, FIRST_STEP[0]!, FIRST_SESSION),
      answer(packId, SECOND_STEP[0]!, FIRST_SESSION),
    ]);

    await sync([answer(packId, FIRST_STEP[1]!, SECOND_SESSION)]);
    const afterFirstFlush = (await standing()).skills[0]!.rating;
    expect((await recorded())[0]!.rating_delta).toBeCloseTo(
      afterFirstFlush - initialSkill().rating,
      3,
    );

    await sync([answer(packId, SECOND_STEP[1]!, SECOND_SESSION, false)]);

    const afterSecondFlush = (await standing()).skills[0]!.rating;
    // **The two readings have to disagree, or this proves nothing** (PROC-11).
    // The second flush is a wrong answer, so it moves the rating the other way
    // and `EXCLUDED.rating_delta` alone is a visibly different number from the
    // sum. Replacing instead of adding would record only that second movement.
    expect(afterSecondFlush).not.toBeCloseTo(afterFirstFlush, 3);
    const written = await recorded();
    expect(written).toHaveLength(1);
    expect(written[0]!.rating_delta).toBeCloseTo(
      afterSecondFlush - initialSkill().rating,
      3,
    );
    expect(written[0]!.rating_delta).not.toBeCloseTo(
      afterSecondFlush - afterFirstFlush,
      3,
    );
  });

  it("the rating survives the player being erased, minus the player", async () => {
    // `difficulty_ratings` is an aggregate over everyone; erasing one player
    // must take their `user_skills` row and leave the calibration standing.
    const { packId } = await issue();
    await sync([answer(packId, FIRST_STEP[0]!, FIRST_SESSION)]);
    await sync([answer(packId, FIRST_STEP[1]!, SECOND_SESSION)]);
    expect((await standing()).skills).toHaveLength(1);

    await app().fetch(new Request("http://localhost/me", { method: "DELETE" }));

    const skills = await db.client.query("SELECT 1 FROM user_skills WHERE player_id = $1", [
      PLAYER,
    ]);
    expect(skills.rowCount).toBe(0);
    expect((await classes()).length).toBeGreaterThan(0);
  });
});
