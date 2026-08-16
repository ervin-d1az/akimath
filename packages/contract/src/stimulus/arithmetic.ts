import { z } from "zod";

import type { StimulusRejectionTag } from "./rejection.js";

/**
 * `04 Error` diagnoses a fraction sum, so every term is a rational and an
 * integer is one with `den: 1`. One shape rather than a union keeps the term
 * tile's renderer from branching on which kind of number it was handed.
 */
export const TermSchema = z.strictObject({
  num: z.int(),
  den: z.int().min(1),
});

export const ARITHMETIC_OPERATORS = ["+", "-", "×", "÷"] as const;

export const ArithmeticPayloadSchema = z.strictObject({
  operator: z.enum(ARITHMETIC_OPERATORS),
  left: TermSchema,
  right: TermSchema,
});

export type ArithmeticPayload = z.infer<typeof ArithmeticPayloadSchema>;

export function checkArithmetic(payload: ArithmeticPayload): StimulusRejectionTag | null {
  const dividesByZero: boolean = payload.operator === "÷" && payload.right.num === 0;
  return dividesByZero ? "division_by_zero_term" : null;
}
