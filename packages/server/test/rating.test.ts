import { initialSkill, rateSession, type Skill } from "@akimath/core";
import { describe, expect, it } from "vitest";

import {
  difficultyKey,
  elapsedDays,
  rateAttempts,
  ratingPeriods,
  type RatedAttempt,
  type StoredSkill,
} from "../src/rating.js";

const SESSION_A = "018f4e3c-0000-7000-8000-00000000aaa1";
const SESSION_B = "018f4e3c-0000-7000-8000-00000000aaa2";
const NOW = new Date("2026-08-20T12:00:00.000Z");

function answered(over: Partial<RatedAttempt> = {}): RatedAttempt {
  return {
    sessionId: SESSION_A,
    skillId: 1,
    ladderStep: 3,
    isCorrect: true,
    answeredAt: new Date("2026-08-20T11:00:00.000Z"),
    ...over,
  };
}

/** A difficulty class the players have already measured. */
const MEASURED: Skill = { rating: 1500, deviation: 120 };

function calibrated(
  entries: readonly (readonly [number, number, Skill])[],
): ReadonlyMap<string, Skill> {
  return new Map(entries.map(([skill, step, at]) => [difficultyKey(skill, step), at]));
}

describe("a rating period is one session of one skill", () => {
  it("splits a batch that carries two sessions", () => {
    // The journal flushes days later, so one batch routinely carries several
    // sessions. Rating them as one period is the per-request grouping
    // ARCHITECTURE.md §3 argues against by name.
    const periods = ratingPeriods([
      answered({ sessionId: SESSION_A }),
      answered({ sessionId: SESSION_B }),
      answered({ sessionId: SESSION_A }),
    ]);

    expect(periods).toHaveLength(2);
    expect(periods.map((p) => p.attempts.length)).toEqual([2, 1]);
  });

  it("and splits one session that spans two skills", () => {
    // `user_skills` is one row per (player, skill). A period covering two
    // skills has nowhere to be written.
    const periods = ratingPeriods([
      answered({ skillId: 1 }),
      answered({ skillId: 2 }),
    ]);

    expect(periods).toHaveLength(2);
    expect(periods.map((p) => p.skillId)).toEqual([1, 2]);
  });

  it("orders periods by when they finished, oldest first", () => {
    // Successive sessions are successive rating periods, so a batch carrying a
    // week of play must apply them in the order they happened.
    //
    // **PROC-11: the later-keyed session is the one that finished first.** The
    // first version of this test had `SESSION_A` both earlier and lower-keyed,
    // so the expected order was the same under the timestamp and under the
    // tie-break — and a mutant that read no timestamp at all passed it.
    const periods = ratingPeriods([
      answered({ sessionId: SESSION_A, answeredAt: new Date("2026-08-19T10:00:00.000Z") }),
      answered({ sessionId: SESSION_B, answeredAt: new Date("2026-08-18T10:00:00.000Z") }),
    ]);

    expect(periods.map((p) => p.sessionId)).toEqual([SESSION_B, SESSION_A]);
  });

  it("and breaks a tie by the key, so an order always exists", () => {
    // Two sessions that ended in the same millisecond still have to come back
    // in one order, or a batch would rate differently depending on how a `Map`
    // happened to enumerate. Inserted against the key order, so a comparator
    // that stopped at the timestamp would leave them as they arrived.
    const together = new Date("2026-08-19T10:00:00.000Z");
    const periods = ratingPeriods([
      answered({ sessionId: SESSION_B, answeredAt: together }),
      answered({ sessionId: SESSION_A, answeredAt: together }),
    ]);

    expect(periods.map((p) => p.sessionId)).toEqual([SESSION_A, SESSION_B]);
  });

  it("keeps every answer of a class, not just the first", () => {
    const periods = ratingPeriods([answered(), answered(), answered()]);

    expect(periods).toHaveLength(1);
    expect(periods[0]!.attempts).toHaveLength(3);
  });

  it("a period ends at its last answer, which is what orders it", () => {
    // A long session that started before a short one still finished after it.
    // Ordering on the *first* answer instead would apply them backwards, and
    // the two disagree only when one period straddles the other — which is
    // exactly what a player who left a session open does.
    const straddling = [
      answered({ sessionId: SESSION_A, answeredAt: new Date("2026-08-19T10:00:00.000Z") }),
      answered({ sessionId: SESSION_A, answeredAt: new Date("2026-08-19T10:20:00.000Z") }),
    ];
    const inTheMiddle = answered({
      sessionId: SESSION_B,
      answeredAt: new Date("2026-08-19T10:10:00.000Z"),
    });

    const periods = ratingPeriods([...straddling, inTheMiddle]);

    expect(periods.map((p) => p.sessionId)).toEqual([SESSION_B, SESSION_A]);
    expect(periods[1]!.endedAt.toISOString()).toBe("2026-08-19T10:20:00.000Z");
  });
});

describe("the opponent is measured, never declared", () => {
  it("an answer against a class nobody has measured does not move the player", () => {
    // **The honesty rule, made a test.** With no evidence about the item there
    // is one equation and two unknowns, and answering it with a constant is
    // what would make the rating `1500 + k x correct` wearing a Glicko hat.
    const update = rateAttempts({
      attempts: [answered()],
      skills: new Map(),
      difficulties: new Map(),
      now: NOW,
    });

    expect(update.skills).toEqual([]);
    expect(update.calibrating).toBe(1);
  });

  it("but it does teach the class, so the next player is rated against evidence", () => {
    const update = rateAttempts({
      attempts: [answered()],
      skills: new Map(),
      difficulties: new Map(),
      now: NOW,
    });

    expect(update.difficulties).toHaveLength(1);
    const [only] = update.difficulties;
    // The player got it right, so the class lost and is now rated below the
    // 1500 it started from.
    expect(only?.rating).toBeLessThan(initialSkill().rating);
    expect(only?.skillId).toBe(1);
    expect(only?.ladderStep).toBe(3);
  });

  it("an answer against a measured class moves the player", () => {
    const update = rateAttempts({
      attempts: [answered()],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.skills).toHaveLength(1);
    expect(update.skills[0]?.rating).toBeGreaterThan(initialSkill().rating);
    expect(update.calibrating).toBe(0);
  });

  it("the step names the class and never sets its worth", () => {
    // **PROC-11.** An implementation that mapped `ladder_step` onto the rating
    // scale would pass a fixture whose measured order agrees with its step
    // order, so this one makes them disagree: the *low* step is the class the
    // players found hard. Beating it must be worth more than beating the high
    // step, which a declared scale gets exactly backwards.
    const hardAtStepOne: Skill = { rating: 1900, deviation: 60 };
    const easyAtStepNine: Skill = { rating: 1100, deviation: 60 };
    const difficulties = calibrated([
      [1, 1, hardAtStepOne],
      [1, 9, easyAtStepNine],
    ]);

    const beatStepOne = rateAttempts({
      attempts: [answered({ ladderStep: 1 })],
      skills: new Map(),
      difficulties,
      now: NOW,
    });
    const beatStepNine = rateAttempts({
      attempts: [answered({ ladderStep: 9, sessionId: SESSION_B })],
      skills: new Map(),
      difficulties,
      now: NOW,
    });

    expect(beatStepOne.skills[0]!.rating).toBeGreaterThan(beatStepNine.skills[0]!.rating);
  });

  it("an attempt whose item records no difficulty is rated by nothing, and says so", () => {
    // A pack row that names no content has no ladder step to read, so there is
    // no class to place the answer in. Reported rather than silently dropped.
    const update = rateAttempts({
      attempts: [answered({ ladderStep: null })],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.skills).toEqual([]);
    expect(update.difficulties).toEqual([]);
    expect(update.unplaced).toBe(1);
  });
});

describe("the class and the player are measured against each other", () => {
  it("both are updated from the player's strength before the period, not after", () => {
    // Otherwise the two halves of one observation disagree about who the
    // player was, and the order the loop happens to run in decides the answer.
    const prior: StoredSkill = { rating: 1400, deviation: 90, updatedAt: NOW };
    const update = rateAttempts({
      attempts: [answered(), answered({ ladderStep: 4 })],
      skills: new Map([[1, prior]]),
      difficulties: calibrated([
        [1, 3, MEASURED],
        [1, 4, MEASURED],
      ]),
      now: NOW,
    });

    const expectedClass = rateSession(MEASURED, [
      { opponentRating: prior.rating, opponentDeviation: prior.deviation, score: 0 },
    ]);
    for (const measured of update.difficulties) {
      expect(measured.rating).toBeCloseTo(expectedClass.rating, 4);
      expect(measured.deviation).toBeCloseTo(expectedClass.deviation, 4);
    }
  });

  it("a wrong answer raises the class and lowers the player", () => {
    const update = rateAttempts({
      attempts: [answered({ isCorrect: false })],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.skills[0]!.rating).toBeLessThan(initialSkill().rating);
    expect(update.difficulties[0]!.rating).toBeGreaterThan(MEASURED.rating);
  });

  it("a class never decays, because an item does not get harder while it waits", () => {
    // `decay` models a person changing between measurements. Applying it to a
    // class would forget calibration that is still true.
    const stale = new Date("2020-01-01T00:00:00.000Z");
    const update = rateAttempts({
      attempts: [answered()],
      skills: new Map([[1, { ...MEASURED, updatedAt: stale }]]),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    // The player's uncertainty has grown back to the unrated ceiling over six
    // years away; the class's has not.
    expect(update.difficulties[0]!.deviation).toBeLessThan(MEASURED.deviation);
  });
});

describe("time only makes the player less certain", () => {
  it("a player away for a year is rated as though nobody had seen them", () => {
    const away: StoredSkill = {
      rating: 1700,
      deviation: 50,
      updatedAt: new Date("2025-08-20T12:00:00.000Z"),
    };
    const fresh: StoredSkill = { ...away, updatedAt: NOW };

    const stale = rateAttempts({
      attempts: [answered()],
      skills: new Map([[1, away]]),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });
    const recent = rateAttempts({
      attempts: [answered()],
      skills: new Map([[1, fresh]]),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    // Glickman's Step 1 before Step 2: a decayed prior is less certain, so one
    // answer moves it further.
    expect(stale.skills[0]!.deviation).toBeGreaterThan(recent.skills[0]!.deviation);
    expect(Math.abs(stale.skills[0]!.rating - away.rating)).toBeGreaterThan(
      Math.abs(recent.skills[0]!.rating - fresh.rating),
    );
  });

  it("a clock that went backwards ages nothing rather than throwing", () => {
    // `decay` refuses a negative span, and a row written by a transaction that
    // committed a moment after this one read `now` is not a reason to fail a
    // sync.
    expect(elapsedDays(new Date("2026-08-20T12:00:01.000Z"), NOW)).toBe(0);
    expect(elapsedDays(NOW, new Date("2026-08-21T12:00:00.000Z"))).toBe(1);
  });
});

describe("two sessions are two periods, and that is not the same as one", () => {
  it("splitting them gives a different answer from rating them together", () => {
    // PROC-11: the whole point of the grouping. If these agreed, the decision
    // ARCHITECTURE.md §3 records would be untestable and unenforced.
    const two = rateAttempts({
      attempts: [
        answered({ sessionId: SESSION_A }),
        answered({ sessionId: SESSION_B, isCorrect: false }),
      ],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });
    const one = rateAttempts({
      attempts: [
        answered({ sessionId: SESSION_A }),
        answered({ sessionId: SESSION_A, ladderStep: 4, isCorrect: false }),
      ],
      skills: new Map(),
      difficulties: calibrated([
        [1, 3, MEASURED],
        [1, 4, MEASURED],
      ]),
      now: NOW,
    });

    expect(two.skills[0]!.deviation).not.toBeCloseTo(one.skills[0]!.deviation, 3);
  });

  it("the second period is rated from what the first one left, not from the stored row", () => {
    // Inside one batch the periods are sequential, so the later session must
    // meet the player the earlier one produced. Reading the stored prior again
    // would silently discard the first session — and a device that had been
    // offline for a week sends exactly this shape.
    const twoSessions = rateAttempts({
      attempts: [
        answered({ sessionId: SESSION_A, answeredAt: new Date("2026-08-19T10:00:00.000Z") }),
        answered({ sessionId: SESSION_B, answeredAt: new Date("2026-08-20T10:00:00.000Z") }),
      ],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });
    const oneSession = rateAttempts({
      attempts: [answered({ sessionId: SESSION_A })],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    // Two wins beat one, and both are more certain than one.
    expect(twoSessions.skills[0]!.rating).toBeGreaterThan(oneSession.skills[0]!.rating);
    expect(twoSessions.skills[0]!.deviation).toBeLessThan(oneSession.skills[0]!.deviation);
  });

  it("every answer against a class counts, not just the first of them", () => {
    // Two answers at the same step in one session are two games against that
    // class. Keeping one would make a session's evidence depend on how many
    // distinct steps it happened to touch.
    const twice = rateAttempts({
      attempts: [answered(), answered()],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });
    const once = rateAttempts({
      attempts: [answered()],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(twice.difficulties[0]!.rating).toBeLessThan(once.difficulties[0]!.rating);
    expect(twice.skills[0]!.rating).toBeGreaterThan(once.skills[0]!.rating);
  });

  it("the order of answers inside one session does not matter", () => {
    const forward = rateAttempts({
      attempts: [answered(), answered({ ladderStep: 4, isCorrect: false })],
      skills: new Map(),
      difficulties: calibrated([
        [1, 3, MEASURED],
        [1, 4, MEASURED],
      ]),
      now: NOW,
    });
    const backward = rateAttempts({
      attempts: [answered({ ladderStep: 4, isCorrect: false }), answered()],
      skills: new Map(),
      difficulties: calibrated([
        [1, 3, MEASURED],
        [1, 4, MEASURED],
      ]),
      now: NOW,
    });

    expect(forward.skills).toEqual(backward.skills);
  });

  it("an empty batch changes nothing", () => {
    expect(
      rateAttempts({ attempts: [], skills: new Map(), difficulties: new Map(), now: NOW }),
    ).toEqual({ skills: [], difficulties: [], deltas: [], unplaced: 0, calibrating: 0 });
  });
});

describe("what is written back is what the columns hold", () => {
  it("every figure survives a float32 round trip", () => {
    // `user_skills` and `difficulty_ratings` are both `real`. The engine
    // narrows on the way out; this is the check that nothing here widens it
    // again, so a rating read back and re-rated does not drift.
    const update = rateAttempts({
      attempts: [answered(), answered({ skillId: 2, ladderStep: 7, isCorrect: false })],
      skills: new Map(),
      difficulties: calibrated([
        [1, 3, MEASURED],
        [2, 7, MEASURED],
      ]),
      now: NOW,
    });

    expect(update.skills).not.toHaveLength(0);
    expect(update.difficulties).not.toHaveLength(0);
    for (const { rating, deviation } of [...update.skills, ...update.difficulties]) {
      expect(Math.fround(rating)).toBe(rating);
      expect(Math.fround(deviation)).toBe(deviation);
    }
  });

  it("a skill nothing rated is not written back at all", () => {
    // An untouched row rewritten with the same numbers still moves
    // `updated_at`, which is what `decay` reads — so a no-op write would
    // quietly reset the clock on a rating nobody measured.
    const update = rateAttempts({
      attempts: [answered({ skillId: 1 }), answered({ skillId: 2, ladderStep: null })],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.skills.map((s) => s.skillId)).toEqual([1]);
  });
});

describe("what a session did to a rating is recorded while it is knowable", () => {
  /** The prior a player nobody has rated is measured against. */
  const UNRATED = initialSkill();

  it("a rated period records the movement it produced, and nothing rounds", () => {
    // **The whole reason the table behind this exists.** A delta is a
    // difference between two instants, and the first one is gone the moment
    // the row is written: the classes move, so the same batch replayed
    // tomorrow produces a different figure. Recomputing it later is the
    // dishonesty this is here to avoid, so it is captured while both ends of
    // the subtraction still exist.
    const update = rateAttempts({
      attempts: [answered()],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    const engine = rateSession(UNRATED, [
      { opponentRating: MEASURED.rating, opponentDeviation: MEASURED.deviation, score: 1 },
    ]);
    expect(update.deltas).toEqual([
      { sessionId: SESSION_A, skillId: 1, change: engine.rating - UNRATED.rating },
    ]);
  });

  it("a right answer against a measured class records a rise", () => {
    const update = rateAttempts({
      attempts: [answered({ isCorrect: true })],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.deltas[0]!.change).toBeGreaterThan(0);
  });

  it("and a wrong one records a fall", () => {
    // PROC-11: the pair is the test. Either one alone passes for a module that
    // subtracts its two operands the other way round.
    const update = rateAttempts({
      attempts: [answered({ isCorrect: false })],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.deltas[0]!.change).toBeLessThan(0);
  });

  it("a period that only calibrated records nothing at all", () => {
    // **Nothing, not zero.** Nobody measured the player — the answers taught
    // the class instead — and `ratingDelta` is an *integer* on the wire, so a
    // measured change of a third of a point already renders as `0`. A zero
    // here would make "we did not measure you" indistinguishable from "we
    // measured you and you held", which is the one distinction that field has
    // room for.
    const update = rateAttempts({
      attempts: [answered()],
      skills: new Map(),
      difficulties: new Map(),
      now: NOW,
    });

    expect(update.calibrating).toBe(1);
    expect(update.deltas).toEqual([]);
  });

  it("a period nothing could place records nothing either", () => {
    const update = rateAttempts({
      attempts: [answered({ ladderStep: null })],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.unplaced).toBe(1);
    expect(update.deltas).toEqual([]);
  });

  it("a partly calibrating period still records what the rated half did", () => {
    // The engine ran, on one answer of two. That is a measurement, and the
    // other answer teaching a class does not make it less of one.
    const update = rateAttempts({
      attempts: [answered({ ladderStep: 3 }), answered({ ladderStep: 9 })],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.calibrating).toBe(1);
    expect(update.deltas).toHaveLength(1);
    expect(update.deltas[0]!.change).not.toBe(0);
  });

  it("one change per session, named by the session that caused it", () => {
    const update = rateAttempts({
      attempts: [
        answered({ sessionId: SESSION_A }),
        answered({ sessionId: SESSION_B, isCorrect: false }),
      ],
      skills: new Map(),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.deltas.map((delta) => delta.sessionId)).toEqual([SESSION_A, SESSION_B]);
    // The second period is measured against what the first left behind, so the
    // two changes compose into the one row `user_skills` ends up holding.
    const total = update.deltas.reduce((sum, delta) => sum + delta.change, 0);
    expect(update.skills[0]!.rating).toBeCloseTo(UNRATED.rating + total, 4);
  });

  it("and one change per skill, because that is the unit the engine works in", () => {
    // A session spanning two skills is two rating periods and two real
    // movements. Both are recorded; whether either can be *reported* is
    // `GET /me/history`'s question, not this one's.
    const update = rateAttempts({
      attempts: [answered({ skillId: 1 }), answered({ skillId: 2, isCorrect: false })],
      skills: new Map(),
      difficulties: calibrated([
        [1, 3, MEASURED],
        [2, 3, MEASURED],
      ]),
      now: NOW,
    });

    expect(update.deltas.map((delta) => [delta.sessionId, delta.skillId])).toEqual([
      [SESSION_A, 1],
      [SESSION_A, 2],
    ]);
    expect(update.deltas[0]!.change).toBeGreaterThan(0);
    expect(update.deltas[1]!.change).toBeLessThan(0);
  });

  it("the change added to where the player was is where the player now is", () => {
    // **Named for what it checks.** The tempting name is "measured from the
    // decayed prior", and this body cannot check that: `decay` grows the
    // deviation and leaves the rating alone, so the decayed prior's *rating*
    // is the stored rating and the two readings agree by construction
    // (PROC-11's fourth bullet).
    //
    // What it does pin is that the recorded change and the written rating are
    // one calculation. A client that adds up its history must land on the
    // figure `GET /me/standing` reports, and this is the arithmetic that makes
    // that true — with a stored prior, so a module returning the new rating
    // itself rather than the difference fails here.
    const stored: StoredSkill = {
      rating: 1400,
      deviation: 60,
      updatedAt: new Date("2026-02-20T12:00:00.000Z"),
    };
    const update = rateAttempts({
      attempts: [answered()],
      skills: new Map([[1, stored]]),
      difficulties: calibrated([[1, 3, MEASURED]]),
      now: NOW,
    });

    expect(update.deltas[0]!.change).toBe(update.skills[0]!.rating - stored.rating);
  });
});
