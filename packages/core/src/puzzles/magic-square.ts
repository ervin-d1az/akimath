import { drawsFrom, shuffledIndices, type Draw } from "./draw.js";

/**
 * The largest square whose uniqueness the frozen validator can actually decide.
 *
 * **The format permits 6; the solver cannot verify it.** A magic square draws
 * from 1..size², so a 6×6 is 36 distinct values over 36 cells and the search
 * outruns `SEARCH_NODE_BUDGET` — measured at **0 accepted out of 60**, across
 * printed fractions of 0.4, 0.5 and 0.6, every one of them
 * `search_budget_exhausted`. Offering it would spend the whole attempt budget
 * on boards the contract was always going to refuse.
 *
 * This is a limit of the verifier, not of the format, which is why it is stated
 * here rather than in the schema.
 */
export const LARGEST_VERIFIABLE_SIZE = 5;

/**
 * How much of the board is printed, by size — measured, not chosen.
 *
 * Over twenty seeds per cell, accepted candidates ran:
 *
 * | | 0.4 | 0.5 | 0.6 |
 * |---|---|---|---|
 * | 4×4 | 5/20 | 14/20 | **18/20** |
 * | 5×5 | 0/20 | 2/20 | **11/20** |
 *
 * Below 0.6 the failures are `search_budget_exhausted` rather than
 * `solution_not_unique` — the boards are not *worse*, they are unverifiable,
 * and a board whose uniqueness nobody can confirm is one a player may not be
 * able to finish. A 3×3 needs none of this: at 0.3 it accepts 35 of 40.
 */
function printedFraction(size: number): number {
  return size <= 3 ? 0.3 : 0.6;
}

export interface MagicSquareCandidate {
  readonly kind: "magicSquare";
  readonly payload: Record<string, unknown>;
}

/**
 * A candidate magic square, or the name of the reason there is none.
 *
 * **PURE, and it judges nothing.** Every cell holds a different number from 1
 * to size² and each line's target is what that line adds up to, so the
 * *arithmetic* is true by construction and only the **uniqueness** is in doubt.
 * That is `parsePuzzle`'s to decide — the caged generator's design D1, and the
 * same reason there is no solver in this file.
 */
export function magicSquareCandidate(
  seed: bigint,
  size: number,
): MagicSquareCandidate | string {
  if (size < 3) {
    return "size_below_the_format";
  }
  if (size > LARGEST_VERIFIABLE_SIZE) {
    return "size_not_verifiable";
  }

  const draw: Draw = drawsFrom(seed);
  const cells = size * size;

  // A permutation of 1..size² in reading order: distinctness is the format's
  // rule, and this satisfies it by construction rather than by search.
  const values = shuffledIndices(cells, draw).map((at) => at + 1);
  const solution: number[][] = <number[][]>[];
  for (let row = 0; row < size; row += 1) {
    solution.push(values.slice(row * size, row * size + size));
  }

  const wanted = Math.max(1, Math.round(cells * printedFraction(size)));
  const given = shuffledIndices(cells, draw)
    .slice(0, wanted)
    .map((at) => ({ row: Math.floor(at / size), col: at % size }))
    // Sorted, so the payload's shape does not depend on draw order — the pack
    // is byte-diffed and a stable order is what makes that readable.
    .sort((a, b) => a.row - b.row || a.col - b.col);

  return {
    kind: "magicSquare",
    payload: {
      board: { size, blocked: [], given, solution },
      row_targets: solution.map((row) => row.reduce((a, b) => a + b, 0)),
      column_targets: Array.from({ length: size }, (_, col) =>
        solution.reduce((total, row) => total + row[col]!, 0),
      ),
    },
  };
}
