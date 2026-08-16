import { z } from "zod";

import { checkUnknownIndex, type StimulusRejectionTag } from "./rejection.js";

/**
 * Figurate numbers — the authored 1 / 3 / 6 / 10 figures whose dot radius
 * shrinks with the count so the figure always fits its 52 px box. The dot
 * counts must grow, because a flat or falling sequence has no figurate rule
 * to find.
 */
export const FiguratePayloadSchema = z.strictObject({
  figures: z.array(z.strictObject({ dots: z.int().min(1) })).min(3).max(4),
  unknown_index: z.int().min(0),
});

export type FiguratePayload = z.infer<typeof FiguratePayloadSchema>;

function growsStrictly(figures: FiguratePayload["figures"]): boolean {
  return figures.every((figure, index) => index === 0 || figure.dots > (figures[index - 1]?.dots ?? 0));
}

export function checkFigurate(payload: FiguratePayload): StimulusRejectionTag | null {
  if (!growsStrictly(payload.figures)) {
    return "figures_not_increasing";
  }
  return checkUnknownIndex(payload.unknown_index, payload.figures.length);
}
