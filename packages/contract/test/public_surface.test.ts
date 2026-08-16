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

  it("exposes both canonicalization directions and the fold map", () => {
    expect(typeof contract.canonicalize).toBe("function");
    expect(typeof contract.requireStoredCanonical).toBe("function");
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
});
