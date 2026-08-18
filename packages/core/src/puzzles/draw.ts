import { intBetween } from "../prng/splitmix64.js";

/** Draws an integer in `0..bound`, inclusive, and advances. */
export type Draw = (bound: number) => number;

/**
 * A cursor over one seed's stream.
 *
 * **PURE, and stateful only within a call.** `intBetween` is addressed by
 * index, which is what makes it a function of `(seed, index)` rather than of a
 * generator's history; this threads the index so a caller composing twenty
 * draws does not thread it by hand — the same trade `intBetween`'s own doc
 * describes, one level up.
 *
 * A bound of zero or less draws nothing and consumes no index: a Fisher–Yates
 * swap with itself and a one-cage board both ask for it, and spending a word on
 * a choice with one option would make the stream depend on the *shape* of the
 * board rather than only on its seed.
 */
export function drawsFrom(seed: bigint): Draw {
  let index = 0;
  return (bound: number): number => {
    if (bound <= 0) {
      return 0;
    }
    const drawn = intBetween(seed, index, 0n, BigInt(bound));
    index = drawn.nextIndex;
    return Number(drawn.value);
  };
}

/**
 * `0..size-1`, shuffled by Fisher–Yates off the caller's stream.
 *
 * Shared by the Latin square and the choice of which cages print a cell —
 * one shuffle, not two implementations of it. The draw is passed in rather
 * than the seed, so several shuffles in a row consume one stream instead of
 * repeating an identical one.
 */
export function shuffledIndices(size: number, draw: Draw): number[] {
  const order = Array.from({ length: size }, (_, i) => i);
  for (let i = size - 1; i > 0; i -= 1) {
    const j = draw(i);
    const swap = order[i]!;
    order[i] = order[j]!;
    order[j] = swap;
  }
  return order;
}
