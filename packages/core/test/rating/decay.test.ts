import { describe, expect, it } from "vitest";

import { decay } from "../../src/rating/decay.js";
import { INITIAL_DEVIATION, type Skill } from "../../src/rating/glicko.js";

const sharp: Skill = { rating: 1600, deviation: 50 };

describe("uncertainty grows with days away, not with sessions", () => {
  it("zero days changes nothing at all", () => {
    expect(decay(sharp, 0)).toEqual(sharp);
  });

  it("the rating itself never moves", () => {
    // Time tells you nothing about how good someone is, only about how sure you
    // can be. A decay that nudged the rating would be inventing evidence.
    for (const days of [1, 30, 365, 5000]) {
      expect(decay(sharp, days).rating).toBe(sharp.rating);
    }
  });

  it("more days means more uncertainty, monotonically", () => {
    let previous = sharp.deviation;
    for (const days of [1, 7, 30, 90, 200]) {
      const grown = decay(sharp, days).deviation;
      expect(grown, `${days} days`).toBeGreaterThan(previous);
      previous = grown;
    }
  });

  it("a well-measured rating reaches the unrated deviation after a year", () => {
    // The judgement call in `decay.ts`, pinned so changing it is deliberate.
    expect(decay(sharp, 365).deviation).toBeCloseTo(INITIAL_DEVIATION, 0);
  });

  it("and never exceeds it, however long the absence", () => {
    // Past the unrated deviation the system knows nothing about the player, and
    // there is nothing further to forget.
    for (const days of [400, 1000, 100_000]) {
      expect(decay(sharp, days).deviation).toBe(INITIAL_DEVIATION);
    }
  });

  it("an inactive player does decay — the whole point of counting days", () => {
    // With the session as the rating period, a child who never opens the app
    // has no periods, so a per-period decay would leave a year-old rating
    // looking as certain as yesterday's.
    expect(decay(sharp, 365).deviation).toBeGreaterThan(sharp.deviation * 6);
  });

  it("refuses a negative or non-finite span", () => {
    expect(() => decay(sharp, -1)).toThrow(/zero or more/);
    expect(() => decay(sharp, Number.NaN)).toThrow(/zero or more/);
    expect(() => decay(sharp, Number.POSITIVE_INFINITY)).toThrow(/zero or more/);
  });

  it("is narrowed to what the schema stores", () => {
    const aged = decay(sharp, 42);
    expect(Math.fround(aged.deviation)).toBe(aged.deviation);
    expect(Math.fround(aged.rating)).toBe(aged.rating);
  });

  it("a fractional day is not rounded away", () => {
    // Elapsed time arrives as a real quantity; truncating to whole days would
    // make a player who returns twice a day never decay at all.
    expect(decay(sharp, 0.5).deviation).toBeGreaterThan(sharp.deviation);
    expect(decay(sharp, 0.5).deviation).toBeLessThan(decay(sharp, 1).deviation);
  });
});
