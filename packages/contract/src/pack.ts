import { z } from "zod";

import { AnswerSpecSchema } from "./answer.js";
import {
  checkDistractors,
  DiagnosisPayloadSchema,
  fallbackForSkill,
  SkillFallbackSchema,
} from "./diagnosis.js";
import { KeypadLayoutSchema } from "./keypad-layout.js";
import { parsePuzzle, PuzzleEnvelopeSchema } from "./puzzle/index.js";
import type { PuzzleRejectionTag } from "./puzzle/rejection.js";
import { declaredState, SkillNodeSchema } from "./skill-map.js";
import { parseStimulus, StimulusEnvelopeSchema } from "./stimulus/index.js";
import type { StimulusRejectionTag } from "./stimulus/rejection.js";

/**
 * The offline pack format. Frozen here so both stacks read the same bytes:
 * `ARCHITECTURE.md` §1 lists it among the cross-stack contracts, and §6 makes
 * the boundary a directory of pinned artifacts rather than a handoff.
 *
 * Field names are snake_case, matching `offline_packs` and the plan
 * (design.md D7); the API response shapes stay camelCase. A pack is a data
 * artifact, a response is an API, and neither is renamed to match the other.
 */
export const PACK_FORMAT_VERSION = 1 as const;

export const ItemSchema = z.strictObject({
  skill_id: z.int().min(1),
  ladder_step: z.int().min(1).max(20),
  keypad: KeypadLayoutSchema,
  stimulus: StimulusEnvelopeSchema,
  answer: AnswerSpecSchema,
  diagnosis: z.union([DiagnosisPayloadSchema, z.null()]),
});

export type Item = z.infer<typeof ItemSchema>;

export const PackSchema = z.strictObject({
  pack_format_version: z.literal(PACK_FORMAT_VERSION),
  pack_salt: z.string().regex(/^[0-9a-f]{32}$/u),
  issued_at: z.iso.datetime(),
  expires_at: z.iso.datetime(),
  skill_nodes: z.array(SkillNodeSchema),
  skill_fallbacks: z.array(SkillFallbackSchema),
  items: z.array(ItemSchema),
  puzzles: z.array(PuzzleEnvelopeSchema),
});

export type Pack = z.infer<typeof PackSchema>;

export type PackRejectionTag =
  | "schema_violation"
  | "undeclared_skill_node"
  | "missing_skill_fallback"
  | "duplicate_distractor_digest"
  | "distractor_matches_answer"
  | StimulusRejectionTag
  | PuzzleRejectionTag;

export interface PackAccepted {
  readonly ok: true;
  readonly pack: Pack;
}

export interface PackRejected {
  readonly ok: false;
  readonly tag: PackRejectionTag;
}

export type PackResult = PackAccepted | PackRejected;

function firstContentRejection(pack: Pack): PackRejectionTag | null {
  for (const item of pack.items) {
    if (declaredState(pack.skill_nodes, item.skill_id) === null) {
      return "undeclared_skill_node";
    }
    if (fallbackForSkill(pack.skill_fallbacks, item.skill_id) === null) {
      return "missing_skill_fallback";
    }
    const distractors: PackRejectionTag | null = checkDistractors(
      item.diagnosis,
      item.answer.digest,
    );
    if (distractors !== null) {
      return distractors;
    }
    const stimulus: StimulusRejectionTag | null = parseStimulus(item.stimulus);
    if (stimulus !== null) {
      return stimulus;
    }
  }
  for (const puzzle of pack.puzzles) {
    const board: PuzzleRejectionTag | null = parsePuzzle(puzzle);
    if (board !== null) {
      return board;
    }
  }
  return null;
}

/**
 * Bytes in, a pack or a stable tag out. Nothing throws: a malformed pack is a
 * verdict the caller reports, and every rejection names itself so the Dart
 * side can be compared against the same tag.
 */
export function parsePack(value: unknown): PackResult {
  const parsed: z.ZodSafeParseResult<Pack> = PackSchema.safeParse(value);
  if (!parsed.success) {
    return { ok: false, tag: "schema_violation" };
  }
  const rejection: PackRejectionTag | null = firstContentRejection(parsed.data);
  return rejection === null ? { ok: true, pack: parsed.data } : { ok: false, tag: rejection };
}
