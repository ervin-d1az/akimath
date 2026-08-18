import { z } from "zod";

import { BoardSchema, CellSchema, checkSumReachable, digitsUpTo, firstRejection } from "./board.js";
import { checkCagedBoard } from "./caged-board.js";
import type { PuzzleRejectionTag } from "./rejection.js";
import type { Region } from "./uniqueness.js";

/** Killer: a Latin square whose cages carry a sum and repeat no digit inside. */
export const KillerPayloadSchema = z.strictObject({
  board: BoardSchema,
  cages: z
    .array(z.strictObject({ cells: z.array(CellSchema).min(1), target: z.int().min(1) }))
    .min(1),
});

export type KillerPayload = z.infer<typeof KillerPayloadSchema>;

export function checkKiller(payload: KillerPayload): PuzzleRejectionTag | null {
  const digits: readonly number[] = digitsUpTo(payload.board.size);
  const cageRegions: readonly Region[] = payload.cages.map((cage) => ({
    cells: cage.cells,
    rule: { kind: "sum", target: cage.target, distinct: true } as const,
  }));
  return checkCagedBoard({
    board: payload.board,
    cages: payload.cages,
    domain: digits,
    cageRegions,
    targetsReachable: () =>
      firstRejection(
        payload.cages.map((cage) => () => checkSumReachable(cage.cells.length, cage.target, digits)),
      ),
  });
}
