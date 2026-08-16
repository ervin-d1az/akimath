import { describe, expect, it } from "vitest";

import { readFixture } from "./fixture-files.js";
import { canonicalize, CHAR_MAP, requireStoredCanonical } from "../src/canon.js";
import { buildCanonGolden, CANON_INPUTS } from "../src/canon-vectors.js";

const ARABIC_INDIC_ZERO = "٠";
const ZERO_WIDTH_SPACE = "​";
const COMBINING_ACUTE = "́";
const MINUS_SIGN = "−";

describe("canonicalize — learner input", () => {
  it("rejects an empty answer", () => {
    expect(canonicalize("")).toEqual({ ok: false, tag: "empty" });
  });

  it("rejects a zero denominator", () => {
    expect(canonicalize("1/0")).toEqual({ ok: false, tag: "zero_denominator" });
  });

  it("rejects an answer that is not a number", () => {
    expect(canonicalize("x+1")).toEqual({ ok: false, tag: "non_numeric" });
  });

  it("rejects an Arabic-Indic digit", () => {
    expect(canonicalize(ARABIC_INDIC_ZERO)).toEqual({ ok: false, tag: "non_ascii_digit" });
  });

  it("rejects a zero-width space rather than stripping it", () => {
    expect(canonicalize(`1${ZERO_WIDTH_SPACE}2`)).toEqual({
      ok: false,
      tag: "invisible_character",
    });
  });

  it("rejects a combining mark rather than stripping it", () => {
    expect(canonicalize(`1${COMBINING_ACUTE}`)).toEqual({ ok: false, tag: "combining_mark" });
  });

  it("folds the keypad's U+2212 minus sign to ASCII", () => {
    expect(canonicalize(`${MINUS_SIGN}5`)).toEqual({ ok: true, value: "-5" });
  });

  it("folds the answer draft's placeholder spaces away", () => {
    expect(canonicalize(" 5 ")).toEqual({ ok: true, value: "5" });
  });

  it("folds leading zeros so 007 and 7 reach the same bytes", () => {
    expect(canonicalize("007")).toEqual({ ok: true, value: "7" });
  });

  it("folds negative zero to zero", () => {
    expect(canonicalize("-0")).toEqual({ ok: true, value: "0" });
  });

  it("keeps a fraction unreduced, because 2/4 and 1/2 are different answers", () => {
    expect(canonicalize("2/4")).toEqual({ ok: true, value: "2/4" });
  });

  it("accepts a canonical fraction unchanged", () => {
    expect(canonicalize("1/2")).toEqual({ ok: true, value: "1/2" });
  });

  it("rejects a fraction with a negative denominator", () => {
    expect(canonicalize("1/-2")).toEqual({ ok: false, tag: "non_numeric" });
  });
});

describe("requireStoredCanonical — pack content", () => {
  it("rejects an empty stored answer", () => {
    expect(requireStoredCanonical("")).toEqual({ ok: false, tag: "empty" });
  });

  it("rejects a stored zero denominator", () => {
    expect(requireStoredCanonical("1/0")).toEqual({ ok: false, tag: "zero_denominator" });
  });

  it("rejects a stored answer that is not a number", () => {
    expect(requireStoredCanonical("x+1")).toEqual({ ok: false, tag: "non_numeric" });
  });

  it("rejects a stored Arabic-Indic digit", () => {
    expect(requireStoredCanonical(ARABIC_INDIC_ZERO)).toEqual({
      ok: false,
      tag: "non_ascii_digit",
    });
  });

  it("rejects a stored zero-width space", () => {
    expect(requireStoredCanonical(`1${ZERO_WIDTH_SPACE}2`)).toEqual({
      ok: false,
      tag: "invisible_character",
    });
  });

  it("rejects a stored combining mark", () => {
    expect(requireStoredCanonical(`1${COMBINING_ACUTE}`)).toEqual({
      ok: false,
      tag: "combining_mark",
    });
  });

  it("rejects a stored U+2212 that the learner direction would have folded", () => {
    expect(requireStoredCanonical(`${MINUS_SIGN}5`)).toEqual({ ok: false, tag: "not_canonical" });
  });

  it("rejects stored leading zeros that the learner direction would have folded", () => {
    expect(requireStoredCanonical("007")).toEqual({ ok: false, tag: "not_canonical" });
  });

  it("accepts a stored answer that is already canonical", () => {
    expect(requireStoredCanonical("1/2")).toEqual({ ok: true, value: "1/2" });
  });
});

describe("the committed canon.golden.json", () => {
  it("is what the code produces, not a hand-written vector", () => {
    expect(readFixture("canon.golden.json")).toEqual(JSON.parse(JSON.stringify(buildCanonGolden())));
  });

  it("records both directions for every row of the table", () => {
    const golden = buildCanonGolden();
    expect(golden.vectors.length).toBe(CANON_INPUTS.length);
    for (const vector of golden.vectors) {
      expect(vector).toHaveProperty("learner");
      expect(vector).toHaveProperty("stored");
    }
  });

  it("records the fold map the two stacks must share", () => {
    expect(buildCanonGolden().char_map).toEqual(CHAR_MAP);
  });
});
