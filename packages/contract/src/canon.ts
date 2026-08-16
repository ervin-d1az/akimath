/**
 * Answer canonicalization — the one module both stacks must agree on
 * character for character. `ARCHITECTURE.md` §1 lists it as a cross-stack
 * contract; drift here makes a right answer wrong on one platform only.
 *
 * It runs in one direction and carries two obligations (design.md D5):
 * `canonicalize` folds what a keypad or a keyboard can legitimately produce,
 * and `requireStoredCanonical` refuses pack content that is not already
 * canonical, so two spellings of one answer can never produce two digests.
 */

/** Every way an answer can fail to be canonical. Closed on purpose. */
export type RejectionTag =
  | "empty"
  | "zero_denominator"
  | "non_numeric"
  | "non_ascii_digit"
  | "invisible_character"
  | "combining_mark"
  | "not_canonical";

export interface AnswerAccepted {
  readonly ok: true;
  readonly value: string;
}

export interface AnswerRejected {
  readonly ok: false;
  readonly tag: RejectionTag;
}

export type CanonResult = AnswerAccepted | AnswerRejected;

/**
 * The characters a learner can legitimately produce that mean an ASCII one.
 * U+2212 is the answer draft's `neg` key and the space is the placeholder an
 * empty field renders so the slot never collapses (plan §3.4).
 */
export const CHAR_MAP: Readonly<Record<string, string>> = Object.freeze({
  "−": "-",
  "⁄": "/",
  " ": "",
});

const INVISIBLE = /[\u00AD\u200B-\u200F\u2028\u2029\u2060\uFEFF]/u;
const COMBINING_MARK = /\p{M}/u;
const DECIMAL_DIGIT = /\p{Nd}/u;
const CANONICAL_SHAPE = /^(-?)(\d+)(?:\/(\d+))?$/u;

function hasNonAsciiDigit(raw: string): boolean {
  for (const character of raw) {
    if (DECIMAL_DIGIT.test(character) && !(character >= "0" && character <= "9")) {
      return true;
    }
  }
  return false;
}

function fold(raw: string): string {
  let folded = "";
  for (const character of raw) {
    folded += CHAR_MAP[character] ?? character;
  }
  return folded;
}

function stripLeadingZeros(digits: string): string {
  const stripped: string = digits.replace(/^0+/u, "");
  return stripped === "" ? "0" : stripped;
}

function joinCanonical(sign: string, numerator: string, denominator: string | undefined): string {
  const magnitude: string = stripLeadingZeros(numerator);
  const signed: string = magnitude === "0" ? magnitude : `${sign}${magnitude}`;
  return denominator === undefined ? signed : `${signed}/${stripLeadingZeros(denominator)}`;
}

function reject(tag: RejectionTag): AnswerRejected {
  return { ok: false, tag };
}

/**
 * Learner input in, the canonical answer out. Invisible characters and
 * combining marks are rejected rather than stripped: silently deleting a
 * character a child cannot see is how a wrong answer becomes a right one.
 */
export function canonicalize(raw: string): CanonResult {
  if (INVISIBLE.test(raw)) {
    return reject("invisible_character");
  }
  if (COMBINING_MARK.test(raw)) {
    return reject("combining_mark");
  }
  if (hasNonAsciiDigit(raw)) {
    return reject("non_ascii_digit");
  }

  const folded: string = fold(raw);
  if (folded === "") {
    return reject("empty");
  }

  const shape: RegExpExecArray | null = CANONICAL_SHAPE.exec(folded);
  if (shape === null) {
    return reject("non_numeric");
  }

  const [, sign = "", numerator = "", denominator] = shape;
  if (denominator !== undefined && stripLeadingZeros(denominator) === "0") {
    return reject("zero_denominator");
  }

  return { ok: true, value: joinCanonical(sign, numerator, denominator) };
}

/**
 * Pack content in, the same string out — or a rejection. A pack states its
 * answers already canonical, so nothing here folds: `not_canonical` is what a
 * stored spelling the learner direction *would* have folded earns, which is
 * what stops one answer from producing two digests (design.md D5).
 */
export function requireStoredCanonical(stored: string): CanonResult {
  const folded: CanonResult = canonicalize(stored);
  if (!folded.ok) {
    return folded;
  }
  return folded.value === stored ? folded : reject("not_canonical");
}
