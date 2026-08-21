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

  it("nothing is rated for an account with no player, and nothing is written", async () => {
    await db.client.query("DELETE FROM players WHERE id = $1", [PLAYER]);

    const response = await sync([]);

    expect(response.status).toBe(404);
    expect(await classes()).toEqual([]);
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
