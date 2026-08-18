/**
 * splitmix64, vendored.
 *
 * Transcribed from Sebastiano Vigna's public-domain reference, fetched
 * 2026-08-17 from <https://prng.di.unimi.it/splitmix64.c>, sha256
 * `071795a8e29978a5cbd7015ce8f7d772e7ab4631e574e9102b748fe99105ff3d`:
 *
 * ```c
 * static uint64_t x;
 * uint64_t next() {
 *   uint64_t z = (x += 0x9e3779b97f4a7c15);
 *   z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9;
 *   z = (z ^ (z >> 27)) * 0x94d049bb133111eb;
 *   return z ^ (z >> 31);
 * }
 * ```
 *
 * **Zero imports, by rule.** `ARCHITECTURE.md` §3 requires the package to ship
 * no dependency, and a PRNG is the one place where reaching for a library is
 * most tempting and most fatal: the server must reconstruct the exact problem
 * years later, so the algorithm has to be in the repository, not in a version
 * range.
 *
 * **BigInt and not `Number`.** A seed arrives from a Postgres `bigint`, and
 * `Number` cannot hold one. A stray `Number(someBigInt)` in this file would
 * round *identically on every machine*, so it would be deterministically wrong
 * everywhere and no cross-machine test could ever see it — which is why
 * `determinism.test.ts` refuses the call rather than trusting review.
 */

/** 2^64 − 1. Every operation below is reduced modulo 2^64 by masking. */
const MASK64 = 0xffff_ffff_ffff_ffffn;

/** Vigna's fixed increment: the 64-bit golden ratio. */
const GOLDEN_GAMMA = 0x9e37_79b9_7f4a_7c15n;

const MULTIPLIER_1 = 0xbf58_476d_1ce4_e5b9n;
const MULTIPLIER_2 = 0x94d0_49bb_1331_11ebn;

const SHIFT_1 = 30n;
const SHIFT_2 = 27n;
const SHIFT_3 = 31n;

/**
 * Vigna's mixing function, applied to an already-advanced state.
 *
 * In the C this is the body of `next()` after `x += GAMMA`; splitting it out is
 * what lets the stream be addressed by index instead of walked.
 */
export function mix64(state: bigint): bigint {
  let z = state & MASK64;
  z = ((z ^ (z >> SHIFT_1)) * MULTIPLIER_1) & MASK64;
  z = ((z ^ (z >> SHIFT_2)) * MULTIPLIER_2) & MASK64;
  return z ^ (z >> SHIFT_3);
}

/**
 * The word at `index` in the stream for `seed`, without walking to it.
 *
 * splitmix64's state advance is `x += GAMMA`, so the state before the *n*-th
 * output is `seed + (n + 1) × GAMMA` — the increment is a constant, which makes
 * the walk a multiplication. This is **counter-linearity**, and it is verified
 * against a stateful walk rather than assumed
 * (`test/prng/counter_linearity.test.ts`).
 *
 * **Why it matters more than the small efficiency.** With no cursor there is
 * nothing to forget to reset and nothing to advance twice, so a generator
 * cannot accidentally depend on how many draws the generator before it took.
 * Rederivation years later needs the *n*-th draw to be a function of
 * `(seed, n)` and of nothing else, and this makes that structural instead of a
 * discipline every caller has to keep.
 *
 * A negative `seed` is welcome: a Postgres `bigint` is signed, and masking maps
 * it onto the same 64-bit space the C uses.
 */
export function wordAt(seed: bigint, index: number): bigint {
  if (!Number.isInteger(index) || index < 0) {
    throw new RangeError(`a stream index must be a non-negative integer: ${index}`);
  }
  return mix64((seed + BigInt(index + 1) * GOLDEN_GAMMA) & MASK64);
}

/**
 * The number of whole 64-bit words that map onto `span` without bias, times
 * `span` — i.e. the exclusive limit above which a draw must be rejected.
 *
 * Taking `wordAt(...) % span` directly biases the low values whenever `span`
 * does not divide 2^64: with 2^64 = q·span + r, the first r residues get one
 * extra chance each. Rejecting everything at or above `q·span` removes it.
 *
 * **Exported so its removal is catchable.** The bias it prevents is invisible
 * in any golden vector — the vector simply records whatever the biased draw
 * produced — so a test has to assert the threshold itself, and it cannot do
 * that if the threshold is a local.
 */
export function rejectionLimit(span: bigint): bigint {
  if (span <= 0n) {
    throw new RangeError(`a span must be positive: ${span}`);
  }
  return ((MASK64 + 1n) / span) * span;
}

/**
 * A uniform integer in `[low, high]`, inclusive at both ends, drawn from the
 * stream for `seed` starting at `index`.
 *
 * Returns the value and the next free index, so a caller composing several
 * draws threads a number rather than a generator — the same reason `wordAt`
 * takes an index. Rejected words consume indices, which is what keeps the draw
 * a pure function of `(seed, index)`.
 */
export function intBetween(
  seed: bigint,
  index: number,
  low: bigint,
  high: bigint,
): { readonly value: bigint; readonly nextIndex: number } {
  if (high < low) {
    throw new RangeError(`an empty range has nothing to draw: [${low}, ${high}]`);
  }
  const span = high - low + 1n;
  const limit = rejectionLimit(span);

  const drawn = drawBelow(limit, index, (at) => wordAt(seed, at));
  return { value: low + (drawn.word % span), nextIndex: drawn.nextIndex };
}

/** Where a word comes from. A value, not an interface — PURE-1's discipline. */
export type WordSource = (index: number) => bigint;

/**
 * The first word below `limit`, and the index after it.
 *
 * Split out from `intBetween` so the bound below is reachable from a test: with
 * the real kernel it is unreachable by construction, which is exactly what
 * makes it the kind of guard that rots unverified.
 */
export function drawBelow(
  limit: bigint,
  index: number,
  words: WordSource,
): { readonly word: bigint; readonly nextIndex: number } {
  let cursor = index;
  for (let attempt = 0; attempt < MAX_REJECTIONS; attempt += 1) {
    const word = words(cursor);
    cursor += 1;
    if (word < limit) {
      return { word, nextIndex: cursor };
    }
  }
  throw new Error(
    `rejection sampling did not converge in ${MAX_REJECTIONS} draws; ` +
      "the limit or the kernel is wrong",
  );
}

/**
 * The point at which a rejection loop stops being unlucky and starts being
 * broken.
 *
 * The worst *correct* case is a span just over half the word space, which
 * rejects a little under half the time; a hundred consecutive rejections there
 * has probability below 2^-100, so this bound cannot fire on a working kernel.
 *
 * **It exists because a broken one hangs.** Falsifying `MASK64` by one bit
 * during task 2.6 did not fail the suite — it made this loop spin forever, and
 * the run had to be killed. A hang reports nothing: no failing test, no message,
 * just a job that eventually hits a timeout somebody has to go and read. The
 * repository already knows this shape — `vitest.config.ts` in the sibling
 * package records that a synchronous infinite loop is not interruptible by the
 * test runner at all. Turning it into a thrown error makes the corrupted build
 * say so.
 */
const MAX_REJECTIONS = 100;
