import { z } from "zod";

import {
  BoardSchema,
  CellSchema,
  checkBlockedCells,
  checkGivenCells,
  checkRunCoverage,
  checkSolutionShape,
  checkSumReachable,
  digitsUpTo,
  firstRejection,
} from "./board.js";
import type { PuzzleRejectionTag } from "./rejection.js";
import { checkUniqueSolution, givenRegions, type Region } from "./uniqueness.js";

/**
 * Kakuro: runs of cells summing to a clue, no digit repeated inside a run.
 * Runs cross, so a cell belongs to two of them and coverage is "at least
 * once" rather than the partition KenKen and Killer want.
 */
export const KAKURO_DIGIT_CEILING = 9;

export const KakuroPayloadSchema = z.strictObject({
  board: BoardSchema,
  runs: z
    .array(z.strictObject({ cells: z.array(CellSchema).min(2), sum: z.int().min(3) }))
    .min(1),
});

export type KakuroPayload = z.infer<typeof KakuroPayloadSchema>;

export function checkKakuro(payload: KakuroPayload): PuzzleRejectionTag | null {
  const digits: readonly number[] = digitsUpTo(KAKURO_DIGIT_CEILING);
  const runRegions: readonly Region[] = payload.runs.map((run) => ({
    cells: run.cells,
    rule: { kind: "sum", target: run.sum, distinct: true } as const,
  }));
  return firstRejection([
    () => checkBlockedCells(payload.board),
    () => checkGivenCells(payload.board),
    () => checkSolutionShape(payload.board, KAKURO_DIGIT_CEILING),
    () => checkRunCoverage(payload.board, payload.runs),
    () =>
      firstRejection(
        payload.runs.map((run) => () => checkSumReachable(run.cells.length, run.sum, digits)),
      ),
    () =>
      checkUniqueSolution({
        board: payload.board,
        domain: digits,
        regions: [...givenRegions(payload.board), ...runRegions],
      }),
  ]);
}
