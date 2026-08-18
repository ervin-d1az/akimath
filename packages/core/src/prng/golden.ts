import { intBetween, wordAt } from "./splitmix64.js";

/**
 * The PRNG's committed vector, built by the code that it checks.
 *
 * **This is a regression gate, not a correctness proof, and the distinction is
 * the whole design.** A vector the code emits and then asserts against itself
 * is circular. Correctness comes from `test/prng/reference.test.ts`, which
 * compares against outputs produced by compiling Vigna's own C, and from the
 * differential oracle beside it. This layer catches an accidental change to a
 * kernel that was already right.
 *
 * Values are strings, never JSON numbers: `JSON.parse` rounds anything past
 * 2^53, and a seed off by one rederives an unrelated item. That defect already
 * cost a migration in `f1-schema-freeze`.
 */
export interface PrngGolden {
  readonly seeds: ReadonlyArray<{
    readonly seed: string;
    readonly words: readonly string[];
    readonly d6: readonly string[];
  }>;
}

const GOLDEN_SEEDS: readonly bigint[] = [
  0n,
  1n,
  9223372036854775807n,
  -9223372036854775808n,
  1477776061723855037n,
];

export function buildPrngGolden(): PrngGolden {
  return {
    seeds: GOLDEN_SEEDS.map((seed) => {
      const d6: string[] = [];
      let cursor = 0;
      for (let i = 0; i < 8; i += 1) {
        const drawn = intBetween(seed, cursor, 1n, 6n);
        cursor = drawn.nextIndex;
        d6.push(drawn.value.toString());
      }
      return {
        seed: seed.toString(),
        words: Array.from({ length: 8 }, (_, index) => wordAt(seed, index).toString()),
        d6,
      };
    }),
  };
}
