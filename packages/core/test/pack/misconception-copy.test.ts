import { describe, expect, it } from "vitest";

import { MISCONCEPTION_COPY } from "../../src/pack/misconception-copy.js";
import {
  FALLBACK_MISCONCEPTION,
  fallbackDiagnosis,
  FORBIDDEN_WORDS,
  misconceptionCopy,
  parseMisconceptions,
  scoldings,
} from "../../src/pack/misconceptions.js";

/**
 * The copy is a value now, and this is what it used to get from being a file.
 *
 * `test/pack/cli.test.ts` used to point the build script at a copy file with no
 * fallback and assert it exited 1. That scenario cannot happen any more — there
 * is no file to point at — so the guarantee moved here rather than evaporating.
 */
describe("the diagnosis copy is validated, not trusted", () => {
  it("parses, and reports how many entries it checked", () => {
    const parsed = misconceptionCopy();

    expect(parsed.size).toBe(Object.keys(MISCONCEPTION_COPY).length);
    expect(parsed.size).toBeGreaterThan(0);
    console.log(`  misconception copy · ${parsed.size} entr(ies), all parsed`);
  });

  it("every entry keeps the shape the schema demands", () => {
    for (const [id, copy] of misconceptionCopy()) {
      expect(id, id).toMatch(/^[a-z][a-z0-9_]*$/u);
      expect(copy.steps.length, id).toBeGreaterThanOrEqual(1);
      expect(copy.steps.length, id).toBeLessThanOrEqual(4);
      expect(copy.explain.length, id).toBeGreaterThan(0);
    }
  });

  it("and the parser still refuses what it always refused", () => {
    // The control. Without it, "the copy parses" is a claim about a parser that
    // might accept anything.
    expect(() => parseMisconceptions({ "Not Snake Case": { steps: ["x"], explain: "y" } }))
      .toThrow(/snake_case/);
    expect(() => parseMisconceptions("nope")).toThrow(/must be an object/);
  });

  it("the fallback exists, because a pack without one is refused", () => {
    // `missing_skill_fallback` is a frozen rejection tag: a skill with items and
    // no fallback makes the whole pack invalid. So this is not decoration, and
    // it is checked at load rather than at the moment a request needs it.
    expect(misconceptionCopy().has(FALLBACK_MISCONCEPTION)).toBe(true);
    expect(fallbackDiagnosis().steps.length).toBeGreaterThan(0);
    expect(fallbackDiagnosis().explain).not.toBe("");
  });

  it("and nothing in it scolds", () => {
    // The one rule the copy itself has to keep: Aki does not tell a learner off.
    // Asked of the module's own list rather than of a regex written here — a
    // second list is a second thing to keep in agreement, and this one would
    // quietly stop matching the day a word is added.
    for (const [id, copy] of misconceptionCopy()) {
      expect(scoldings([copy.explain, ...copy.steps]), id).toEqual([]);
    }
  });

  it("every forbidden word is a word that actually gets caught", () => {
    // Each entry, one at a time. Blanking any of them left the list shorter and
    // every test still green, which is a list that only looks like a rule.
    expect(FORBIDDEN_WORDS.length).toBeGreaterThan(0);
    for (const word of FORBIDDEN_WORDS) {
      expect(scoldings([`Eso estuvo ${word} otra vez`]), word).toHaveLength(1);
      expect(
        () => parseMisconceptions({ a_thing: { steps: [`x ${word}`], explain: "y" } }),
        word,
      ).toThrow(/names the failure/);
    }
    console.log(`  scolding sweep · ${FORBIDDEN_WORDS.length} forbidden word(s), each proven`);
  });

  it("it catches a word inside another and reports where", () => {
    // Substrings on purpose: "errores" and "normal" carry "error" and "mal",
    // and copy that says either has still said it.
    expect(scoldings(["hubo errores"])).toEqual(['"error" in "hubo errores"']);
    expect(scoldings(["ESO ESTUVO MAL"])).toHaveLength(1);
    expect(scoldings(["todo bien"])).toEqual([]);
    expect(scoldings([])).toEqual([]);
  });

  it("a key that is not exactly an identifier is refused", () => {
    // The `^` and `$` are load-bearing, the same way they were in the server's
    // uuid patterns: without them a key with anything around it passes.
    for (const key of ["Uppercase", "1leading_digit", " leading_space", "trailing ", "has-dash", ""]) {
      expect(
        () => parseMisconceptions({ [key]: { steps: ["x"], explain: "y" } }),
        JSON.stringify(key),
      ).toThrow(/snake_case/);
    }
    // And a single letter is a valid identifier, so the rule is not "at least
    // two characters" by accident.
    expect(parseMisconceptions({ a: { steps: ["x"], explain: "y" } }).size).toBe(1);
  });
});
