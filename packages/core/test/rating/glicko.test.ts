import { describe, expect, it } from "vitest";

import {
  INITIAL_DEVIATION,
  INITIAL_RATING,
  initialSkill,
  rateSession,
} from "../../src/rating/glicko.js";
import type { Outcome, Skill } from "../../src/rating/glicko.js";

/**
 * **The external anchor.** Every constant and every expected number below comes
 * from Mark Glickman's own worked example, "The Glicko system",
 * <https://www.glicko.net/glicko/glicko.pdf>, page 4, fetched 2026-08-17.
 *
 * As with the PRNG, nothing here was recalled. `ARCHITECTURE.md` §3's lesson is
 * that a hand-remembered reference vector enshrines a mistake permanently, and
 * a rating is worse than a PRNG in that respect: a wrong constant produces
 * plausible numbers forever.
 *
 * His example: a player rated 1500 with RD 200 meets three opponents rated
 * 1400/RD 30, 1550/RD 100 and 1700/RD 300, winning the first and losing the
 * other two. He computes r' = 1464 and RD' = 151.4.
 */
const GLICKMAN_PLAYER: Skill = { rating: 1500, deviation: 200 };

const GLICKMAN_OUTCOMES: readonly Outcome[] = [
  { opponentRating: 1400, opponentDeviation: 30, score: 1 },
  { opponentRating: 1550, opponentDeviation: 100, score: 0 },
  { opponentRating: 1700, opponentDeviation: 300, score: 0 },
];

describe("Glickman's own worked example", () => {
  const after = rateSession(GLICKMAN_PLAYER, GLICKMAN_OUTCOMES);

  it("reaches the rating he publishes", () => {
    // He rounds to 1464 in the paper.
    expect(Math.round(after.rating)).toBe(1464);
  });

  it("reaches the deviation he publishes", () => {
    // 151.4, to one decimal.
    expect(Math.round(after.deviation * 10) / 10).toBeCloseTo(151.4, 1);
  });

  it("the unrated defaults are the ones he names", () => {
    expect(INITIAL_RATING).toBe(1500);
    expect(INITIAL_DEVIATION).toBe(350);
  });

  it("the prior a caller gets is assembled from those two and nothing else", () => {
    // The server asks for this rather than for the constants, because the
    // package's front door exports only functions.
    expect(initialSkill()).toEqual({
      rating: INITIAL_RATING,
      deviation: INITIAL_DEVIATION,
    });
  });

  it("and it cannot be mutated into a different default", () => {
    const prior = initialSkill();
    expect(() => {
      (prior as { rating: number }).rating = 9999;
    }).toThrow(TypeError);
    expect(initialSkill().rating).toBe(INITIAL_RATING);
  });
});

describe("a session is one rating period, not a sequence of them", () => {
  it("rating a batch differs from rating one at a time", () => {
    // The decision `ARCHITECTURE.md` §3 records: grouping by request is
    // deterministic but not *consistent* — two children with identical play get
    // different ratings depending on whether they had a connection, in the app
    // whose promise is fair adaptive difficulty.
    const batch = rateSession(GLICKMAN_PLAYER, GLICKMAN_OUTCOMES);

    let sequential = GLICKMAN_PLAYER;
    for (const outcome of GLICKMAN_OUTCOMES) {
      sequential = rateSession(sequential, [outcome]);
    }

    expect(batch.rating).not.toBeCloseTo(sequential.rating, 3);
  });

  it("an empty session changes nothing", () => {
    // No outcomes is not the same as a loss, and it must not move the rating.
    expect(rateSession(GLICKMAN_PLAYER, [])).toEqual(GLICKMAN_PLAYER);
  });

  it("a win raises and a loss lowers, against an equal opponent", () => {
    const equal = { opponentRating: 1500, opponentDeviation: 200 };
    const won = rateSession(GLICKMAN_PLAYER, [{ ...equal, score: 1 }]);
    const lost = rateSession(GLICKMAN_PLAYER, [{ ...equal, score: 0 }]);

    expect(won.rating).toBeGreaterThan(1500);
    expect(lost.rating).toBeLessThan(1500);
  });

  it("any outcome sharpens the deviation", () => {
    // Glickman: game outcomes always decrease RD, because playing is
    // information. Only time passing increases it.
    for (const score of [0, 0.5, 1] as const) {
      const after = rateSession(GLICKMAN_PLAYER, [
        { opponentRating: 1500, opponentDeviation: 200, score },
      ]);
      expect(after.deviation).toBeLessThan(GLICKMAN_PLAYER.deviation);
    }
  });

  it("the order of outcomes within a session does not matter", () => {
    // A rating period is a set, not a sequence — the sums are commutative, and
    // if that ever stopped being true the "session" grouping would be a lie.
    const reversed = [...GLICKMAN_OUTCOMES].reverse();
    expect(rateSession(GLICKMAN_PLAYER, reversed)).toEqual(
      rateSession(GLICKMAN_PLAYER, GLICKMAN_OUTCOMES),
    );
  });
});

describe("the result is narrowed to the precision the schema stores", () => {
  it("both figures survive a float32 round trip unchanged", () => {
    // `user_skills.rating` and `.deviation` are Postgres `real`. Narrowing here
    // means what the database stores is exactly what was computed, so a rating
    // read back and re-rated does not drift.
    const after = rateSession(GLICKMAN_PLAYER, GLICKMAN_OUTCOMES);
    expect(Math.fround(after.rating)).toBe(after.rating);
    expect(Math.fround(after.deviation)).toBe(after.deviation);
  });

  it("holds against a plausible cross-engine wobble in the transcendentals", () => {
    // `Math.exp`, `Math.log` and `Math.pow` are implementation-approximated, so
    // this cannot be byte-exact the way BigInt arithmetic is. It does not need
    // to be: float32 is coarse enough to absorb far more error than any engine
    // introduces. Rather than assert that, measure it — perturb the inputs by
    // an amount larger than a real engine difference and show the stored
    // figures do not move.
    const nudge = (value: number, ulps: number): number => {
      let out = value;
      for (let i = 0; i < ulps; i += 1) out = nextAfter(out);
      return out;
    };

    const perturbed = rateSession(GLICKMAN_PLAYER, [
      { opponentRating: nudge(1400, 8), opponentDeviation: 30, score: 1 },
      { opponentRating: 1550, opponentDeviation: nudge(100, 8), score: 0 },
      { opponentRating: 1700, opponentDeviation: 300, score: 0 },
    ]);
    const clean = rateSession(GLICKMAN_PLAYER, GLICKMAN_OUTCOMES);

    expect(perturbed).toEqual(clean);
  });
});

/** The next representable double above `value`. */
function nextAfter(value: number): number {
  const buffer = new DataView(new ArrayBuffer(8));
  buffer.setFloat64(0, value);
  buffer.setBigUint64(0, buffer.getBigUint64(0) + 1n);
  return buffer.getFloat64(0);
}
