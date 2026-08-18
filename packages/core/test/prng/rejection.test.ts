import { describe, expect, it } from "vitest";

import {
  drawBelow,
  intBetween,
  rejectionLimit,
  wordAt,
} from "../../src/prng/splitmix64.js";

/**
 * A bounded draw is uniform, and its bound is reachable.
 *
 * `word % span` biases the low values whenever `span` does not divide 2^64:
 * with 2^64 = q·span + r, the first r residues get one extra chance each.
 *
 * **No golden vector can catch this.** A vector records whatever the draw
 * produced, biased or not, so removing the rejection changes the recorded
 * numbers and the replay test simply records the new ones. That is why
 * `rejectionLimit` is exported and asserted directly rather than left a local.
 */
const TWO_64 = 1n << 64n;

describe("the rejection threshold is the one the range requires", () => {
  it("is 2^64 for a span that divides it", () => {
    // A power of two divides 2^64 exactly, so nothing is ever rejected.
    for (const span of [1n, 2n, 256n, 1n << 32n]) {
      expect(rejectionLimit(span)).toBe(TWO_64);
    }
  });

  it("is the largest multiple of the span at or below 2^64", () => {
    for (const span of [3n, 5n, 6n, 7n, 10n, 100n, 12345n]) {
      const limit = rejectionLimit(span);
      expect(limit % span).toBe(0n);
      expect(limit).toBeLessThanOrEqual(TWO_64);
      expect(limit + span).toBeGreaterThan(TWO_64);
    }
  });

  it("refuses a span that cannot be drawn from, and says why", () => {
    // The message matters here, not just the throw. Without the guard, a span
    // of zero divides by zero and BigInt throws a `RangeError` of its own — so
    // asserting only the *type* passes for a check that was deleted, which is
    // precisely what the mutation report caught.
    expect(() => rejectionLimit(0n)).toThrow(/span must be positive/);
    expect(() => rejectionLimit(-1n)).toThrow(/span must be positive/);
  });
});

describe("a bounded draw stays in range and reaches both ends", () => {
  it("never leaves the range", () => {
    let drawn = 0;
    for (let index = 0; index < 500; index += 1) {
      const { value } = intBetween(42n, index, 1n, 6n);
      expect(value).toBeGreaterThanOrEqual(1n);
      expect(value).toBeLessThanOrEqual(6n);
      drawn += 1;
    }
    expect(drawn).toBe(500);
  });

  it("reaches both ends of the range", () => {
    // The control for the test above, which a function returning a constant 3
    // would also pass.
    const seen = new Set<bigint>();
    for (let index = 0; index < 500; index += 1) {
      seen.add(intBetween(42n, index, 1n, 6n).value);
    }
    expect([...seen].sort((a, b) => Number(a - b))).toEqual([1n, 2n, 3n, 4n, 5n, 6n]);
  });

  it("a single-value range is the value, and consumes one index", () => {
    const { value, nextIndex } = intBetween(42n, 10, 7n, 7n);
    expect(value).toBe(7n);
    expect(nextIndex).toBe(11);
  });

  it("an empty range is refused, and says so rather than dividing by zero", () => {
    // Same shape as the span guard above: delete this check and `span` becomes
    // zero, `rejectionLimit` divides by it, and a `RangeError` still comes out —
    // from two layers down, naming nothing the caller did.
    expect(() => intBetween(42n, 0, 5n, 4n)).toThrow(/empty range/);
  });

  it("a rejected word consumes its index, so the draw stays a function of (seed, index)", () => {
    // **A small span cannot exercise rejection at all.** The first version of
    // this test used a span of 3 and searched 100,000 draws for a rejected
    // word; 2^64 mod 3 is 1, so exactly one word in 2^64 is rejected and the
    // search was never going to find it. The rejection region is large only
    // when the span is: at 2^63 + 1 the limit is 2^63 + 1 itself, so very
    // nearly half of all words are rejected.
    //
    // What is being proved: a rejected word still consumes its index, so two
    // callers starting from the same index cannot diverge.
    const high = 1n << 63n; // span = 2^63 + 1
    const limit = rejectionLimit(high + 1n);
    expect(limit).toBe(high + 1n);

    let rejectedAt = -1;
    for (let index = 0; index < 1_000 && rejectedAt < 0; index += 1) {
      if (wordAt(1n, index) >= limit) rejectedAt = index;
    }
    expect(rejectedAt, "no rejection found to exercise").toBeGreaterThanOrEqual(0);

    const { nextIndex } = intBetween(1n, rejectedAt, 0n, high);
    expect(nextIndex).toBeGreaterThan(rejectedAt + 1);
  });

  it("rejection is what keeps a near-half span unbiased", () => {
    // At span = 2^63 + 1 the naive `word % span` maps two different words onto
    // every value below 2^63 − 1 and one onto the rest, so the low half would
    // come up about twice as often. This is the case the threshold exists for,
    // and it is worth one direct measurement rather than an argument.
    const high = 1n << 63n;
    const draws = 2_000;
    let low = 0;
    let cursor = 0;
    for (let i = 0; i < draws; i += 1) {
      const drawn = intBetween(99n, cursor, 0n, high);
      cursor = drawn.nextIndex;
      if (drawn.value < high / 2n) low += 1;
    }
    // Uniform would be ~50%. The biased form would be ~67%.
    expect(low / draws).toBeGreaterThan(0.44);
    expect(low / draws).toBeLessThan(0.56);
  });

  it("the draw is reproducible from (seed, index) alone", () => {
    // The whole point. Same inputs, same answer, no matter what happened before.
    expect(intBetween(9n, 3, 1n, 1000n)).toEqual(intBetween(9n, 3, 1n, 1000n));
  });
});

describe("a broken kernel fails loudly instead of hanging", () => {
  it("gives up after a bounded number of rejections", () => {
    // **Found by falsification, not by design.** Flipping one bit of `MASK64`
    // during the 2.6 matrix did not redden the suite — it hung the run, and the
    // whole thing had to be killed. A hang reports nothing: no failing test, no
    // message, just a job that eventually trips a timeout somebody has to go
    // and read. The sibling package's `vitest.config.ts` already records that a
    // synchronous infinite loop is not interruptible by the test runner at all.
    //
    // With the real kernel this bound is unreachable by construction, which is
    // what makes it the kind of guard that rots unverified. `drawBelow` takes
    // its words as a value so a test can hand it a source that never yields.
    const alwaysRejected = (): bigint => (1n << 64n) - 1n;

    expect(() => drawBelow(1n, 0, alwaysRejected)).toThrow(/did not converge/);
  });

  it("rejects a word exactly equal to the limit", () => {
    // The limit is exclusive, and this is the one boundary the whole scheme
    // turns on: `q·span` maps onto residue 0, so accepting it is the bias the
    // rejection exists to remove. `<` versus `<=` is invisible everywhere else.
    const words = (index: number): bigint => (index === 0 ? 10n : 3n);

    expect(drawBelow(10n, 0, words)).toEqual({ word: 3n, nextIndex: 2 });
  });

  it("consumes exactly the bound before giving up", () => {
    // Pins the bound itself. Off by one either way and this fails, which is
    // what stops `< MAX` quietly becoming `<= MAX`.
    let calls = 0;
    const never = (): bigint => {
      calls += 1;
      return (1n << 64n) - 1n;
    };

    expect(() => drawBelow(1n, 0, never)).toThrow(/did not converge/);
    expect(calls).toBe(100);
  });

  it("returns as soon as a word is below the limit", () => {
    // The control: a bound that fires for everything would also pass above.
    const thirdIsFine = (index: number): bigint => (index < 2 ? 999n : 5n);

    expect(drawBelow(10n, 0, thirdIsFine)).toEqual({ word: 5n, nextIndex: 3 });
  });
});
