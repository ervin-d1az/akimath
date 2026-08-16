import { z } from "zod";

import { checkUnknownIndex, type StimulusRejectionTag } from "./rejection.js";

const TERMS_PER_PAIR = 2;

/**
 * Two pair-cards joined by a bridge pill. `unknown_index` walks the four terms
 * in reading order — first card's left, first card's right, second card's
 * left, second card's right — so one bound covers both cards.
 */
export const AnalogyPayloadSchema = z.strictObject({
  pairs: z
    .array(z.strictObject({ left: z.int(), right: z.int() }))
    .length(2),
  unknown_index: z.int().min(0),
});

export type AnalogyPayload = z.infer<typeof AnalogyPayloadSchema>;

export function checkAnalogy(payload: AnalogyPayload): StimulusRejectionTag | null {
  return checkUnknownIndex(payload.unknown_index, payload.pairs.length * TERMS_PER_PAIR);
}
