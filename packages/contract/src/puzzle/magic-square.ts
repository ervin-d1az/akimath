import { z } from "zod";

import {
  BoardSchema,
  boardLines,
  checkBlockedCells,
  checkGivenCells,
  checkSolutionShape,
  digitsUpTo,
  fillableCells,
  firstRejection,
} from "./board.js";
import type { PuzzleRejectionTag } from "./rejection.js";
import { checkUniqueSolution, givenRegions, type Region } from "./uniqueness.js";

/**
 * The magic square: every cell holds a different number and every row and
 * column reaches its own target — the 54×62 chips the design draws down the
 * side and across the top.
 */
export const MagicSquarePayloadSchema = z.strictObject({
  board: BoardSchema,
  row_targets: z.array(z.int().min(1)).min(3).max(6),
  column_targets: z.array(z.int().min(1)).min(3).max(6),
});

export type MagicSquarePayload = z.infer<typeof MagicSquarePayloadSchema>;

function targetsMatchBoard(payload: MagicSquarePayload): PuzzleRejectionTag | null {
  const matched: boolean =
    payload.row_targets.length === payload.board.size &&
    payload.column_targets.length === payload.board.size;
  return matched ? null : "solution_shape";
}

function lineRegions(payload: MagicSquarePayload): readonly Region[] {
  return boardLines(payload.board.size).flatMap((line, index): readonly Region[] => [
    {
      cells: line.row,
      rule: { kind: "sum", target: payload.row_targets[index] ?? 0, distinct: false },
    },
    {
      cells: line.column,
      rule: { kind: "sum", target: payload.column_targets[index] ?? 0, distinct: false },
    },
  ]);
}

export function checkMagicSquare(payload: MagicSquarePayload): PuzzleRejectionTag | null {
  const reach: number = payload.board.size * payload.board.size;
  return firstRejection([
    () => checkBlockedCells(payload.board),
    () => checkGivenCells(payload.board),
    () => targetsMatchBoard(payload),
    () => checkSolutionShape(payload.board, reach),
    () =>
      checkUniqueSolution({
        board: payload.board,
        domain: digitsUpTo(reach),
        regions: [
          { cells: fillableCells(payload.board), rule: { kind: "distinct" } },
          ...lineRegions(payload),
          ...givenRegions(payload.board),
        ],
      }),
  ]);
}
