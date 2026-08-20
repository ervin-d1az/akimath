/**
 * The package's public surface: re-exports only, no logic (design.md D9).
 * `f1-contract-emitter` inherits this package and adds the OpenAPI half, so
 * what is reachable from here is part of the contract.
 */
export { ANSWER_SHAPES, AnswerSpecSchema, DigestSchema } from "./answer.js";
export type { AnswerShape, AnswerSpec } from "./answer.js";

export {
  canonicalize,
  CHAR_MAP,
  renderCanonicalAnswer,
  requireStoredCanonical,
} from "./canon.js";
export { storedAnswer } from "./canon.js";
export type {
  AnswerAccepted,
  AnswerRejected,
  CanonResult,
  RejectionTag,
  StoredAnswer,
} from "./canon.js";

export { buildCanonGolden, CANON_INPUTS } from "./canon-vectors.js";
export type { CanonGolden, CanonVector } from "./canon-vectors.js";

export { canonicalJson } from "./canonical-json.js";

export {
  checkDistractors,
  DIAGNOSIS_VERSION,
  DiagnosisCopySchema,
  DiagnosisPayloadSchema,
  fallbackForSkill,
  lookupDiagnosis,
  SkillFallbackSchema,
} from "./diagnosis.js";
export type { DiagnosisCopy, DiagnosisPayload, SkillFallback } from "./diagnosis.js";

export { answerDigest, digestStoredAnswer } from "./digest.js";
export type { DigestProduced, DigestRefused, DigestResult } from "./digest.js";

export { KEYPAD_LAYOUTS, KeypadLayoutSchema } from "./keypad-layout.js";
export type { KeypadLayout } from "./keypad-layout.js";

export { ItemSchema, PACK_FORMAT_VERSION, PackSchema, parsePack } from "./pack.js";
export type { Item, Pack, PackAccepted, PackRejected, PackRejectionTag, PackResult } from "./pack.js";

export { parsePuzzle, PUZZLE_KINDS, PUZZLE_PAYLOAD_SCHEMAS, PuzzleEnvelopeSchema } from "./puzzle/index.js";
export type { PuzzleEnvelope, PuzzleKind } from "./puzzle/index.js";
export type { PuzzleRejectionTag } from "./puzzle/rejection.js";

export { declaredState, SKILL_NODE_STATES, SkillNodeSchema } from "./skill-map.js";
export type { SkillNode, SkillNodeState } from "./skill-map.js";

export {
  parseStimulus,
  STIMULUS_KINDS,
  STIMULUS_PAYLOAD_SCHEMAS,
  StimulusEnvelopeSchema,
} from "./stimulus/index.js";
export type { StimulusEnvelope, StimulusKind } from "./stimulus/index.js";
export type { StimulusRejectionTag } from "./stimulus/rejection.js";
