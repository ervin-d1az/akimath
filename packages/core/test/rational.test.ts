import { describe, expect, it } from "vitest";

import {
  abs,
  add,
  compare,
  divide,
  equals,
  isInteger,
  multiply,
  negate,
  rationalOf,
  reciprocal,
  signOf,
  subtract,
  type Rational,
} from "../src/rational.js";

const r = (numerator: bigint, denominator: bigint = 1n): Rational =>
  rationalOf(numerator, denominator);

/** The pair, for asserting normal form directly. */
const pair = (value: Rational): [bigint, bigint] => [
  value.numerator,
  value.denominator,
];

describe("a rational is always in normal form", () => {
  it("reduces to lowest terms", () => {
    expect(pair(r(4n, 8n))).toEqual([1n, 2n]);
    expect(pair(r(6n, 4n))).toEqual([3n, 2n]);
    expect(pair(r(100n, 10n))).toEqual([10n, 1n]);
  });

  it("keeps the sign on the numerator", () => {
    expect(pair(r(1n, -2n))).toEqual([-1n, 2n]);
    expect(pair(r(-1n, -2n))).toEqual([1n, 2n]);
    expect(pair(r(-3n, 6n))).toEqual([-1n, 2n]);
  });

  it("has exactly one representation of zero", () => {
    // Two zeroes that are not `equals` would be a defect nothing else in this
    // file could see, so the property is pinned across every sign of
    // denominator — including the negative one, which is the case an earlier
    // version of `rationalOf` carried a dead branch and a false comment for.
    // BigInt has no negative zero (`-0n === 0n`), and `gcd(0, d)` is `|d|`, so
    // the general reduction already lands on `0/1`. The branch is gone; the
    // property is still checked.
    for (const [n, d] of [
      [0n, 1n],
      [0n, 5n],
      [0n, -5n],
      [-0n, 3n],
    ] as const) {
      expect(pair(r(n, d))).toEqual([0n, 1n]);
    }
  });

  it("refuses a zero denominator", () => {
    expect(() => r(1n, 0n)).toThrow(/denominator/);
    expect(() => r(0n, 0n)).toThrow(/denominator/);
  });

  it("two equal values are indistinguishable", () => {
    // The property normal form exists for: if `4/8` and `1/2` differed, every
    // comparison and every lookup downstream would be subtly wrong.
    expect(pair(r(4n, 8n))).toEqual(pair(r(1n, 2n)));
    expect(equals(r(4n, 8n), r(1n, 2n))).toBe(true);
  });

  it("and unequal values are distinguishable", () => {
    // Every other assertion about `equals` in this file asserts `true`, which
    // is satisfied by a function that returns `true`. Both fields matter, so
    // both are varied independently.
    expect(equals(r(1n, 2n), r(1n, 3n))).toBe(false); // same numerator
    expect(equals(r(1n, 2n), r(3n, 2n))).toBe(false); // same denominator
    expect(equals(r(1n, 2n), r(-1n, 2n))).toBe(false); // sign only
    expect(equals(r(0n), r(1n))).toBe(false);
  });

  it("is frozen, so a caller cannot reshape it", () => {
    const value = r(1n, 2n);
    expect(Object.isFrozen(value)).toBe(true);
    expect(() => {
      (value as { numerator: bigint }).numerator = 9n;
    }).toThrow(TypeError);
  });
});

describe("the arithmetic is exact", () => {
  it("adds without touching a float", () => {
    // 1/3 + 1/6 = 1/2. In binary floating point this is 0.49999999999999994.
    expect(pair(add(r(1n, 3n), r(1n, 6n)))).toEqual([1n, 2n]);
    // The starter pack's own fraction items.
    expect(pair(add(r(3n, 4n), r(2n, 4n)))).toEqual([5n, 4n]);
    expect(pair(add(r(1n, 2n), r(1n, 3n)))).toEqual([5n, 6n]);
  });

  it("subtracts, including past zero", () => {
    expect(pair(subtract(r(5n, 8n), r(1n, 8n)))).toEqual([1n, 2n]);
    expect(pair(subtract(r(8n), r(15n)))).toEqual([-7n, 1n]);
    expect(pair(subtract(r(1n, 2n), r(1n, 2n)))).toEqual([0n, 1n]);
  });

  it("multiplies and divides", () => {
    expect(pair(multiply(r(2n), r(3n, 4n)))).toEqual([3n, 2n]);
    expect(pair(divide(r(3n, 4n), r(1n, 2n)))).toEqual([3n, 2n]);
    expect(pair(divide(r(-1n, 2n), r(2n)))).toEqual([-1n, 4n]);
  });

  it("refuses division by zero, blaming the division and not a denominator", () => {
    // The message is the assertion. Delete either guard and the operation still
    // throws — from `rationalOf`, about a denominator the caller never wrote —
    // so matching on `/zero/` alone passes for a guard that is gone. The
    // mutation report caught exactly that.
    expect(() => divide(r(1n), r(0n))).toThrow(/divide a rational by zero/);
    expect(() => reciprocal(r(0n))).toThrow(/no reciprocal/);
  });

  it("holds at magnitudes no double could", () => {
    // The reason for BigInt rather than a numerator/denominator pair of
    // numbers: past 2^53 a double silently stops counting.
    const huge = 9007199254740993n; // 2^53 + 1
    expect(pair(add(r(huge), r(1n)))).toEqual([9007199254740994n, 1n]);
    expect(pair(multiply(r(huge), r(huge)))).toEqual([huge * huge, 1n]);
  });

  it("does not grow denominators without reducing", () => {
    // A naive add leaves 1/6 + 1/6 as 12/36. Unreduced, two equal values stop
    // being equal and the magnitudes explode over a long computation.
    expect(pair(add(r(1n, 6n), r(1n, 6n)))).toEqual([1n, 3n]);
  });
});

describe("comparison and inspection", () => {
  it("orders values, including across zero", () => {
    expect(compare(r(1n, 3n), r(1n, 2n))).toBeLessThan(0);
    expect(compare(r(1n, 2n), r(1n, 3n))).toBeGreaterThan(0);
    expect(compare(r(2n, 4n), r(1n, 2n))).toBe(0);
    expect(compare(r(-1n, 2n), r(1n, 3n))).toBeLessThan(0);
  });

  it("reports a sign, an absolute value and integrality", () => {
    expect(signOf(r(-3n, 4n))).toBe(-1);
    expect(signOf(r(0n))).toBe(0);
    expect(signOf(r(3n, 4n))).toBe(1);

    expect(pair(abs(r(-3n, 4n)))).toEqual([3n, 4n]);
    expect(pair(negate(r(3n, 4n)))).toEqual([-3n, 4n]);
    expect(pair(negate(r(0n)))).toEqual([0n, 1n]);

    expect(isInteger(r(4n, 2n))).toBe(true);
    expect(isInteger(r(3n, 2n))).toBe(false);
  });
});
