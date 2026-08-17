import { canonicalize, CHAR_MAP, requireStoredCanonical, type CanonResult } from "./canon.js";

/**
 * The parity table both stacks are measured against. It is **emitted from the
 * code**, never hand-written: `ARCHITECTURE.md` §3 records what a hand-written
 * golden vector cost when the canonical snippet turned out not to produce the
 * vector that was claimed.
 *
 * Every row of design.md D5's table is here, in both directions, plus the
 * folds a keypad and a keyboard produce. `f1b-content-reader` runs the Dart
 * canonicalizer over the same inputs and compares.
 */
export const CANON_INPUTS: readonly string[] = [
  "",
  " ",
  "1/0",
  "x+1",
  "٠",
  "1​2",
  "1́",
  "−5",
  "-5",
  " 5 ",
  "007",
  "-0",
  "0",
  "7",
  "1/2",
  "2/4",
  "1⁄2",
  "1/-2",
  "12/007",

  // Added by `f1-core-rederivation`: every shape `renderCanonicalAnswer` can
  // produce, so the cross-language fixture covers the renderer's whole output
  // and not only what a learner types.
  //
  // **The set had a hole exactly here.** Its nineteen original vectors contain
  // no negative-zero fraction, and that is the gap through which a `-0/5`
  // defect shipped in Dart: the two canonicalisers disagreed and nothing
  // compared them on the one input where they did. The Dart parity test
  // iterates whatever this list contains, so these five buy that coverage with
  // no Dart edit at all.
  "0/5",
  "-0/5",
  "-3/4",
  "4/1",
  "12/7",
];

export interface CanonVector {
  readonly raw: string;
  readonly learner: CanonResult;
  readonly stored: CanonResult;
}

export interface CanonGolden {
  readonly char_map: Readonly<Record<string, string>>;
  readonly vectors: readonly CanonVector[];
}

export function buildCanonGolden(): CanonGolden {
  return {
    char_map: CHAR_MAP,
    vectors: CANON_INPUTS.map((raw) => ({
      raw,
      learner: canonicalize(raw),
      stored: requireStoredCanonical(raw),
    })),
  };
}
