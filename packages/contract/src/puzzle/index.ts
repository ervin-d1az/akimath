import { z } from "zod";

import { checkKakuro, KakuroPayloadSchema } from "./kakuro.js";
import { checkKenKen, KenKenPayloadSchema } from "./kenken.js";
import { checkKiller, KillerPayloadSchema } from "./killer.js";
import { checkMagicSquare, MagicSquarePayloadSchema } from "./magic-square.js";
import type { PuzzleRejectionTag } from "./rejection.js";
import { checkWordSearch, WordSearchPayloadSchema } from "./word-search.js";

/**
 * `f6-puzzles` promises the boards play fully offline while `CLAUDE.md`
 * forbids generating one on the client, so the board, its cages, its solution,
 * its tutorial and its reference sheet all travel in the pack (design.md D2).
 *
 * Same envelope discipline as the stimulus: a closed kind and an opaque
 * payload, which is the only variance `ARCHITECTURE.md` §2 permits. The
 * tutorial and the reference sheet are shared structure — every puzzle needs
 * both to be playable with no network and no help screen behind it.
 */
export const PUZZLE_KINDS = ["kenken", "kakuro", "killer", "magicSquare", "wordSearch"] as const;

export type PuzzleKind = (typeof PUZZLE_KINDS)[number];

export const PuzzleEnvelopeSchema = z.strictObject({
  kind: z.enum(PUZZLE_KINDS),
  payload: z.record(z.string(), z.unknown()),
  tutorial_steps: z.array(z.string().min(1)).min(1).max(5),
  reference_sheet: z.array(z.string().min(1)).min(1).max(6),
});

export type PuzzleEnvelope = z.infer<typeof PuzzleEnvelopeSchema>;

export type PuzzleValidator = (payload: unknown) => PuzzleRejectionTag | null;

function validator<Payload>(
  schema: z.ZodType<Payload, unknown>,
  check: (payload: Payload) => PuzzleRejectionTag | null,
): PuzzleValidator {
  return (payload: unknown): PuzzleRejectionTag | null => {
    const parsed: z.ZodSafeParseResult<Payload> = schema.safeParse(payload);
    return parsed.success ? check(parsed.data) : "payload_shape";
  };
}

/** The five payload schemas, for the emitter and for anyone reading the format. */
export const PUZZLE_PAYLOAD_SCHEMAS: Readonly<Record<PuzzleKind, z.ZodType>> = Object.freeze({
  kenken: KenKenPayloadSchema,
  kakuro: KakuroPayloadSchema,
  killer: KillerPayloadSchema,
  magicSquare: MagicSquarePayloadSchema,
  wordSearch: WordSearchPayloadSchema,
});

const PUZZLE_VALIDATORS: Readonly<Record<PuzzleKind, PuzzleValidator>> = Object.freeze({
  kenken: validator(KenKenPayloadSchema, checkKenKen),
  kakuro: validator(KakuroPayloadSchema, checkKakuro),
  killer: validator(KillerPayloadSchema, checkKiller),
  magicSquare: validator(MagicSquarePayloadSchema, checkMagicSquare),
  wordSearch: validator(WordSearchPayloadSchema, checkWordSearch),
});

/** The envelope, then the payload schema its own kind names. */
export function parsePuzzle(puzzle: unknown): PuzzleRejectionTag | null {
  const envelope: z.ZodSafeParseResult<PuzzleEnvelope> = PuzzleEnvelopeSchema.safeParse(puzzle);
  if (!envelope.success) {
    return "payload_shape";
  }
  return PUZZLE_VALIDATORS[envelope.data.kind](envelope.data.payload);
}
