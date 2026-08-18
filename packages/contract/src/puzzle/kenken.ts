import { z } from "zod";

import { CellSchema, checkSumReachable, digitsUpTo, firstRejection, BoardSchema } from "./board.js";
import { checkCagedBoard } from "./caged-board.js";
import type { PuzzleRejectionTag } from "./rejection.js";
import { CAGE_OPERATIONS, type Region } from "./uniqueness.js";

/** KenKen: a Latin square whose cages carry an operation and its result. */
export const KenKenPayloadSchema = z.strictObject({
  board: BoardSchema,
  cages: z
    .array(
      z.strictObject({
        cells: z.array(CellSchema).min(1),
        operation: z.enum(CAGE_OPERATIONS),
        target: z.int().min(1),
      }),
    )
    .min(1),
});

export type KenKenPayload = z.infer<typeof KenKenPayloadSchema>;

const BINARY_OPERATIONS: readonly string[] = ["-", "÷"];

/**
 * A difference and a quotient are defined for two numbers. A one-cell `÷` cage
 * is content nobody can solve, and without this it would surface as
 * `solution_mismatch` — a tag that blames the solution for a cage's shape.
 */
function binaryCagesArePairs(payload: KenKenPayload): PuzzleRejectionTag | null {
  const misshapen: boolean = payload.cages.some(
    (cage) => BINARY_OPERATIONS.includes(cage.operation) && cage.cells.length !== 2,
  );
  return misshapen ? "binary_cage_size" : null;
}

/**
 * Only an additive cage has a reachable range worth checking ahead of the
 * search; the other three operations are cheap enough to leave to it.
 */
function additiveCagesReachable(payload: KenKenPayload): PuzzleRejectionTag | null {
  const digits: readonly number[] = digitsUpTo(payload.board.size);
  return firstRejection(
    payload.cages
      .filter((cage) => cage.operation === "+")
      .map((cage) => () => checkSumReachable(cage.cells.length, cage.target, digits)),
  );
}

export function checkKenKen(payload: KenKenPayload): PuzzleRejectionTag | null {
  const cageRegions: readonly Region[] = payload.cages.map((cage) => ({
    cells: cage.cells,
    rule: { kind: "arithmetic", operation: cage.operation, target: cage.target } as const,
  }));
  return checkCagedBoard({
    board: payload.board,
    cages: payload.cages,
    domain: digitsUpTo(payload.board.size),
    cageRegions,
    targetsReachable: () =>
      firstRejection([() => binaryCagesArePairs(payload), () => additiveCagesReachable(payload)]),
  });
}
