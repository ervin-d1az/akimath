import { describe, expect, it } from "vitest";

import { intBetween } from "../../src/prng/splitmix64.js";
import { drawsFrom } from "../../src/puzzles/draw.js";

describe("a cursor over one seed's stream", () => {
  it("its draws are the stream's, in order", () => {
    // Not "some number in range": the exact words `intBetween` yields at index
    // 0, 1, 2. A cursor that reset its index every call would still return
    // values in range, forever.
    const draw = drawsFrom(99n);
    const first = intBetween(99n, 0, 0n, 5n);
    const second = intBetween(99n, first.nextIndex, 0n, 5n);

    expect(draw(5)).toBe(Number(first.value));
    expect(draw(5)).toBe(Number(second.value));
  });

  it("two cursors on one seed agree", () => {
    const a = drawsFrom(7n);
    const b = drawsFrom(7n);
    expect([a(9), a(9), a(9)]).toEqual([b(9), b(9), b(9)]);
  });

  it("different seeds do not", () => {
    const a = drawsFrom(7n);
    const b = drawsFrom(8n);
    expect([a(99), a(99), a(99)]).not.toEqual([b(99), b(99), b(99)]);
  });
});

describe("a choice with one option costs nothing", () => {
  it("a bound of zero draws zero", () => {
    expect(drawsFrom(1n)(0)).toBe(0);
  });

  it("a negative bound draws zero rather than throwing", () => {
    // `grow` and Fisher–Yates both reach it: an empty neighbourhood and a
    // one-element tail are ordinary, not errors.
    expect(drawsFrom(1n)(-1)).toBe(0);
  });

  it("it consumes no index", () => {
    // The behaviour that matters: spending a word on a choice with one option
    // would make the stream depend on the *shape* of the board rather than only
    // on its seed, so two boards differing in one cage size would diverge from
    // that point on.
    const withZeros = drawsFrom(5n);
    withZeros(0);
    withZeros(0);
    const plain = drawsFrom(5n);

    expect([withZeros(9), withZeros(9)]).toEqual([plain(9), plain(9)]);
  });
});
