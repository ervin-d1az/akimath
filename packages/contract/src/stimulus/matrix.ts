import { z } from "zod";

import { checkUnknownIndex, type StimulusRejectionTag } from "./rejection.js";

/**
 * The 3×3 grid with pink margin arrows. `size` is declared rather than
 * inferred from the cell count so a truncated pack is a rejection instead of
 * a silently smaller matrix.
 */
export const MatrixPayloadSchema = z.strictObject({
  size: z.int().min(2).max(3),
  cells: z.array(z.int()).min(4).max(9),
  unknown_index: z.int().min(0),
});

export type MatrixPayload = z.infer<typeof MatrixPayloadSchema>;

export function checkMatrix(payload: MatrixPayload): StimulusRejectionTag | null {
  if (payload.cells.length !== payload.size * payload.size) {
    return "matrix_cell_count";
  }
  return checkUnknownIndex(payload.unknown_index, payload.cells.length);
}
