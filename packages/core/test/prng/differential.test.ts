import { describe, expect, it } from "vitest";

import { mix64, wordAt } from "../../src/prng/splitmix64.js";

/**
 * A second implementation, as an oracle.
 *
 * **What this buys, precisely:** the implementation reduces modulo 2^64 by
 * masking with a hexadecimal literal, and spells Vigna's three constants in
 * hex. This one reduces with `BigInt.asUintN`, which is a different mechanism,
 * and spells the same constants in **decimal**, which is a different
 * transcription. A slipped hex digit or a wrong mask has to be made twice, in
 * two notations, to survive.
 *
 * **What it does not buy:** it is not an independent authority on what
 * splitmix64 *is*. That is `reference.test.ts`, which compares against outputs
 * produced by compiling Vigna's own C. If both files were wrong in the same way
 * this one would agree with the implementation happily — so it is a
 * transcription check, and it is written down as one.
 */

/** 0x9e3779b97f4a7c15 */
const GAMMA = 11400714819323198485n;
/** 0xbf58476d1ce4e5b9 */
const M1 = 13787848793156543929n;
/** 0x94d049bb133111eb */
const M2 = 10723151780598845931n;

const u64 = (n: bigint): bigint => BigInt.asUintN(64, n);

/** Vigna's mixer, by a different route. */
function oracleMix(state: bigint): bigint {
  let z = u64(state);
  z = u64(u64(z ^ (z >> 30n)) * M1);
  z = u64(u64(z ^ (z >> 27n)) * M2);
  return u64(z ^ (z >> 31n));
}

/** The stateful form, exactly as the C walks it. */
function oracleStream(seed: bigint, count: number): bigint[] {
  let x = u64(seed);
  const out: bigint[] = [];
  for (let i = 0; i < count; i += 1) {
    x = u64(x + GAMMA);
    out.push(oracleMix(x));
  }
  return out;
}

const SEEDS: readonly bigint[] = [
  0n,
  1n,
  2n,
  255n,
  4294967295n, // 2^32 − 1, where a 32-bit implementation would break
  4294967296n, // 2^32
  9223372036854775807n, // 2^63 − 1, the top of a signed Postgres bigint
  9223372036854775808n, // 2^63
  18446744073709551615n, // 2^64 − 1
  -1n, // a signed bigint from the database
  -9223372036854775808n, // the bottom of a signed Postgres bigint
  1477776061723855037n,
];

describe("two implementations, two notations, one stream", () => {
  it("agrees with the oracle across the whole seed range", () => {
    let compared = 0;
    for (const seed of SEEDS) {
      const expected = oracleStream(seed, 16);
      for (const [index, word] of expected.entries()) {
        expect(wordAt(seed, index), `seed ${seed}, index ${index}`).toBe(word);
        compared += 1;
      }
    }
    expect(compared).toBe(SEEDS.length * 16);
    // eslint-disable-next-line no-console
    console.log(`  prng differential · ${compared} words over ${SEEDS.length} seeds`);
  });

  it("agrees on the mixer in isolation, including the extremes", () => {
    for (const state of [0n, 1n, 18446744073709551615n, 9223372036854775808n]) {
      expect(mix64(state)).toBe(oracleMix(state));
    }
  });

  it("the oracle disagrees when the implementation is wrong", () => {
    // Without this the whole file passes for two functions that both return
    // zero. A deliberately-wrong mixer must be caught by the same comparison.
    const wrong = (state: bigint): bigint => u64(state * M1);
    expect(wrong(12345n)).not.toBe(oracleMix(12345n));
  });
});
