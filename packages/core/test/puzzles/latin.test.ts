import { describe, expect, it } from "vitest";

import { latinSquare } from "../../src/puzzles/latin.js";

const rows = (square: readonly (readonly number[])[]): readonly (readonly number[])[] => square;

const columns = (square: readonly (readonly number[])[]): readonly number[][] =>
  square[0]!.map((_, col) => square.map((row) => row[col]!));

describe("a generated square is Latin", () => {
  it("every row and every column is a permutation, at every supported size", () => {
    for (let size = 3; size <= 6; size += 1) {
      const square = latinSquare(1234n, size);
      const wanted = new Set(Array.from({ length: size }, (_, i) => i + 1));

      expect(square, `size ${size}`).toHaveLength(size);
      for (const line of [...rows(square), ...columns(square)]) {
        expect(new Set(line), `size ${size}: ${line.join(",")}`).toEqual(wanted);
      }
    }
  });

  it("the same seed is the same square", () => {
    expect(latinSquare(77n, 5)).toEqual(latinSquare(77n, 5));
  });

  it("the square is not always the same one", () => {
    // A cyclic square used unshuffled would satisfy every assertion above and
    // make every KenKen in the pack the same puzzle wearing different cages.
    const seen = new Set(
      Array.from({ length: 12 }, (_, i) => JSON.stringify(latinSquare(BigInt(i), 4))),
    );
    expect(seen.size).toBeGreaterThan(1);
  });

  it("it is not the cyclic square", () => {
    // Named explicitly, because "more than one" would still pass if the
    // shuffle only ever permuted symbols and left the diagonal structure.
    const cyclic = Array.from({ length: 4 }, (_, r) =>
      Array.from({ length: 4 }, (_, c) => ((r + c) % 4) + 1),
    );
    const squares = Array.from({ length: 12 }, (_, i) => latinSquare(BigInt(i), 4));

    expect(squares.some((s) => JSON.stringify(s) !== JSON.stringify(cyclic))).toBe(true);
  });

  it("a size below three has no board to make", () => {
    expect(() => latinSquare(1n, 2)).toThrow(RangeError);
  });
});
