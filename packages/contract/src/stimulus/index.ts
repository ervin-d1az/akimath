import { z } from "zod";

import { AnalogyPayloadSchema, checkAnalogy } from "./analogy.js";
import { ArithmeticPayloadSchema, checkArithmetic } from "./arithmetic.js";
import { checkFigurate, FiguratePayloadSchema } from "./figurate.js";
import { checkHiddenOperation, HiddenOperationPayloadSchema } from "./hidden-operation.js";
import { checkMatrix, MatrixPayloadSchema } from "./matrix.js";
import { checkNumberSeries, NumberSeriesPayloadSchema } from "./number-series.js";
import type { StimulusRejectionTag } from "./rejection.js";

/**
 * The prompt travels as `{ kind, payload }`, not as a token stream: a 3×3
 * matrix, a function machine, seven elastic tiles, two pair-cards and a
 * figurate figure are not a flat list (design.md D1, correcting
 * `ARCHITECTURE.md`:179).
 *
 * The envelope keeps the payload opaque, which is the only variance
 * `ARCHITECTURE.md` §2 permits — no `oneOf`, no discriminator. The per-kind
 * schema is applied by `parseStimulus`, not by the envelope.
 */
export const STIMULUS_KINDS = [
  "arithmetic",
  "numberSeries",
  "matrix",
  "analogy",
  "hiddenOperation",
  "figurate",
] as const;

export type StimulusKind = (typeof STIMULUS_KINDS)[number];

export const StimulusEnvelopeSchema = z.strictObject({
  kind: z.enum(STIMULUS_KINDS),
  payload: z.record(z.string(), z.unknown()),
});

export type StimulusEnvelope = z.infer<typeof StimulusEnvelopeSchema>;

/** Reads an opaque payload and reports the first thing wrong with it. */
export type PayloadValidator = (payload: unknown) => StimulusRejectionTag | null;

function validator<Payload>(
  schema: z.ZodType<Payload, unknown>,
  check: (payload: Payload) => StimulusRejectionTag | null,
): PayloadValidator {
  return (payload: unknown): StimulusRejectionTag | null => {
    const parsed: z.ZodSafeParseResult<Payload> = schema.safeParse(payload);
    return parsed.success ? check(parsed.data) : "payload_shape";
  };
}

/** The six payload schemas, for the emitter and for anyone reading the format. */
export const STIMULUS_PAYLOAD_SCHEMAS: Readonly<Record<StimulusKind, z.ZodType>> = Object.freeze({
  arithmetic: ArithmeticPayloadSchema,
  numberSeries: NumberSeriesPayloadSchema,
  matrix: MatrixPayloadSchema,
  analogy: AnalogyPayloadSchema,
  hiddenOperation: HiddenOperationPayloadSchema,
  figurate: FiguratePayloadSchema,
});

const STIMULUS_VALIDATORS: Readonly<Record<StimulusKind, PayloadValidator>> = Object.freeze({
  arithmetic: validator(ArithmeticPayloadSchema, checkArithmetic),
  numberSeries: validator(NumberSeriesPayloadSchema, checkNumberSeries),
  matrix: validator(MatrixPayloadSchema, checkMatrix),
  analogy: validator(AnalogyPayloadSchema, checkAnalogy),
  hiddenOperation: validator(HiddenOperationPayloadSchema, checkHiddenOperation),
  figurate: validator(FiguratePayloadSchema, checkFigurate),
});

/** The envelope, then the payload schema its own kind names. */
export function parseStimulus(stimulus: unknown): StimulusRejectionTag | null {
  const envelope: z.ZodSafeParseResult<StimulusEnvelope> =
    StimulusEnvelopeSchema.safeParse(stimulus);
  if (!envelope.success) {
    return "payload_shape";
  }
  return STIMULUS_VALIDATORS[envelope.data.kind](envelope.data.payload);
}
