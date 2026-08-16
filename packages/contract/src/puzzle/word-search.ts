import { z } from "zod";

import { firstRejection } from "./board.js";
import type { PuzzleRejectionTag } from "./rejection.js";

/**
 * Sopa de letras. Nothing here is a numeric board, so it carries a letter grid
 * and the words hidden in it. A word the grid does not hold is unwinnable and
 * a word it holds twice makes two different answers correct — both are
 * rejections, not warnings.
 */
export const WordSearchPayloadSchema = z.strictObject({
  grid: z.array(z.array(z.string().regex(/^[A-ZÑ]$/u))).min(3).max(8),
  words: z.array(z.string().regex(/^[A-ZÑ]{3,8}$/u)).min(1).max(8),
});

export type WordSearchPayload = z.infer<typeof WordSearchPayloadSchema>;

const DIRECTIONS: readonly (readonly [number, number])[] = [
  [0, 1],
  [0, -1],
  [1, 0],
  [-1, 0],
  [1, 1],
  [1, -1],
  [-1, 1],
  [-1, -1],
];

function isRectangular(grid: WordSearchPayload["grid"]): boolean {
  const width: number = grid[0]?.length ?? 0;
  return width > 0 && grid.every((row) => row.length === width);
}

function readsAs(
  grid: WordSearchPayload["grid"],
  word: string,
  placement: { readonly row: number; readonly col: number; readonly step: readonly [number, number] },
): boolean {
  return [...word].every((letter, offset) => {
    const row: number = placement.row + placement.step[0] * offset;
    const col: number = placement.col + placement.step[1] * offset;
    return grid[row]?.[col] === letter;
  });
}

export function countOccurrences(grid: WordSearchPayload["grid"], word: string): number {
  let found = 0;
  for (const [row, letters] of grid.entries()) {
    for (const col of letters.keys()) {
      for (const step of DIRECTIONS) {
        if (readsAs(grid, word, { row, col, step })) {
          found += 1;
        }
      }
    }
  }
  return found;
}

export function checkWordSearch(payload: WordSearchPayload): PuzzleRejectionTag | null {
  return firstRejection([
    () => (isRectangular(payload.grid) ? null : "solution_shape"),
    () =>
      firstRejection(
        payload.words.map((word) => () => {
          const found: number = countOccurrences(payload.grid, word);
          if (found === 0) {
            return "word_not_found";
          }
          return found > 1 ? "word_occurs_twice" : null;
        }),
      ),
  ]);
}
