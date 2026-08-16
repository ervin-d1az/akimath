import {
  checkBlockedCells,
  checkCageCoverage,
  checkGivenCells,
  checkSolutionShape,
  firstRejection,
  type Board,
  type CageCells,
} from "./board.js";
import type { PuzzleRejectionTag } from "./rejection.js";
import { checkUniqueSolution, givenRegions, latinRegions, type Region } from "./uniqueness.js";

/**
 * KenKen and Killer are the same board with different cage arithmetic: a Latin
 * square partitioned into cages that must force exactly one solution. Only the
 * cage rule and its reachability test differ, so only those are parameters.
 */
export interface CagedBoard {
  readonly board: Board;
  readonly cages: readonly CageCells[];
  readonly domain: readonly number[];
  readonly cageRegions: readonly Region[];
  readonly targetsReachable: () => PuzzleRejectionTag | null;
}

export function checkCagedBoard(caged: CagedBoard): PuzzleRejectionTag | null {
  return firstRejection([
    () => checkBlockedCells(caged.board),
    () => checkGivenCells(caged.board),
    () => checkSolutionShape(caged.board, caged.board.size),
    () => checkCageCoverage(caged.board, caged.cages),
    caged.targetsReachable,
    () =>
      checkUniqueSolution({
        board: caged.board,
        domain: caged.domain,
        regions: [
          ...latinRegions(caged.board),
          ...givenRegions(caged.board),
          ...caged.cageRegions,
        ],
      }),
  ]);
}
