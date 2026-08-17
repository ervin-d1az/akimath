import { describe, expect, it } from "vitest";

import * as contract from "../src/index.js";

/**
 * `design.md` D9 gives the package a public surface that re-exports and holds
 * no logic of its own. `f1-contract-emitter` inherits this package, so the
 * names it can reach are part of the contract, not an implementation detail.
 */
describe("the package's public surface", () => {
  it("exposes the pack parser and its format version", () => {
    expect(contract.PACK_FORMAT_VERSION).toBe(1);
    expect(typeof contract.parsePack).toBe("function");
  });

  it("exposes both canonicalization directions, the renderer and the fold map", () => {
    expect(typeof contract.canonicalize).toBe("function");
    expect(typeof contract.requireStoredCanonical).toBe("function");
    expect(typeof contract.renderCanonicalAnswer).toBe("function");
    expect(contract.CHAR_MAP["−"]).toBe("-");
  });

  it("exposes the digest, which is the only door pack content has to one", () => {
    expect(typeof contract.answerDigest).toBe("function");
    expect(typeof contract.digestStoredAnswer).toBe("function");
  });

  it("exposes the diagnosis lookup and the canon golden builder", () => {
    expect(typeof contract.lookupDiagnosis).toBe("function");
    expect(typeof contract.buildCanonGolden).toBe("function");
  });

  it("exposes every closed enum the format freezes", () => {
    expect(contract.STIMULUS_KINDS.length).toBe(6);
    expect(contract.PUZZLE_KINDS.length).toBe(5);
    expect(contract.KEYPAD_LAYOUTS.length).toBe(3);
    expect(contract.SKILL_NODE_STATES.length).toBe(4);
    expect(contract.ANSWER_SHAPES.length).toBe(2);
  });

  it("exposes exactly this surface and no more", () => {
    // **Set equality, because the assertions above cannot see an addition.**
    // Each of them checks a name it already knows, so a new export ships with
    // no test at all — which is how `renderCanonicalAnswer` would have arrived
    // unnoticed.
    //
    // Writing this list down was itself the finding: the surface is **36**
    // names, and the five assertions above between them mention sixteen. Twenty
    // exports — every schema, `canonicalJson`, `checkDistractors`,
    // `declaredState`, the parsers — had no surface coverage at all.
    // `f1-contract-emitter` inherits this package, so what it can reach is part
    // of the contract rather than an implementation detail, and adding to it
    // should be a decision. This is what makes it one.
    const exported = Object.keys(contract).sort();

    expect(exported).toEqual(
      [
        "ANSWER_SHAPES",
        "AnswerSpecSchema",
        "CANON_INPUTS",
        "CHAR_MAP",
        "DIAGNOSIS_VERSION",
        "DiagnosisCopySchema",
        "DiagnosisPayloadSchema",
        "DigestSchema",
        "ItemSchema",
        "KEYPAD_LAYOUTS",
        "KeypadLayoutSchema",
        "PACK_FORMAT_VERSION",
        "PUZZLE_KINDS",
        "PUZZLE_PAYLOAD_SCHEMAS",
        "PackSchema",
        "PuzzleEnvelopeSchema",
        "SKILL_NODE_STATES",
        "STIMULUS_KINDS",
        "STIMULUS_PAYLOAD_SCHEMAS",
        "SkillFallbackSchema",
        "SkillNodeSchema",
        "StimulusEnvelopeSchema",
        "answerDigest",
        "buildCanonGolden",
        "canonicalJson",
        "canonicalize",
        "checkDistractors",
        "declaredState",
        "digestStoredAnswer",
        "fallbackForSkill",
        "lookupDiagnosis",
        "parsePack",
        "parsePuzzle",
        "parseStimulus",
        "renderCanonicalAnswer",
        "requireStoredCanonical",
      ].sort(),
    );

    // PROC-11: `[] === []` passes for a module that failed to load.
    expect(exported.length).toBeGreaterThan(0);
    // eslint-disable-next-line no-console
    console.log(`  contract public surface · ${exported.length} exports`);
  });
});
