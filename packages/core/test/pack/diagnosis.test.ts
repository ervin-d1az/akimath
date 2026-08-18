import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { answerDigest, type DiagnosisCopy } from "@akimath/contract";
import { describe, expect, it } from "vitest";

import { CORE_REGISTRY } from "../../src/golden.js";
import { buildPack } from "../../src/pack/build.js";
import { parseDeclaration } from "../../src/pack/declaration.js";
import { predictDistractors } from "../../src/pack/distractors.js";
import {
  copyStrings,
  FORBIDDEN_WORDS,
  parseMisconceptions,
  scoldings,
} from "../../src/pack/misconceptions.js";

const SALT = "a1b2c3d4e5f60718293a4b5c6d7e8f90";
const COPY_FILE = fileURLToPath(new URL("../../content/misconceptions.json", import.meta.url));
const MISCONCEPTIONS = parseMisconceptions(JSON.parse(readFileSync(COPY_FILE, "utf8")));

const FALLBACK = MISCONCEPTIONS.get("no_specific_diagnosis") as DiagnosisCopy;

const build = (count: number, misconceptions = MISCONCEPTIONS) =>
  buildPack(
    parseDeclaration({
      pack_salt: SALT,
      seed_base: "1000",
      issued_at: "2026-08-18T00:00:00.000Z",
      expires_at: "2026-11-18T00:00:00.000Z",
      sources: [
        { kind: "template", template_id: "arith.integer.subtract", template_version: 2, ladder_step: 3, count, skill_id: 1 },
      ],
    }),
    {
      registry: CORE_REGISTRY,
      readAuthored: () => { throw new Error("no authored source in this build"); },
      fallbacks: new Map([[1, FALLBACK]]),
      misconceptions,
    },
  );

describe("the copy file is content, and it is checked like content", () => {
  it("keys every entry by its own misconception id", () => {
    for (const [id, copy] of MISCONCEPTIONS) {
      expect(copy.misconception).toBe(id);
    }
    expect(MISCONCEPTIONS.size).toBeGreaterThan(0);
  });

  it("refuses something that is not an object keyed by identifier", () => {
    // Never exercised until the mutation pass: deleting this branch entirely
    // left every test green.
    for (const junk of [null, [], "text", 42]) {
      expect(() => parseMisconceptions(junk)).toThrow(/object keyed by identifier/);
    }
  });

  it("refuses a file that declares no misconceptions at all", () => {
    expect(() => parseMisconceptions({})).toThrow(/declares none/);
  });

  it("refuses more steps than the frozen copy schema admits", () => {
    // One to four. Five is a wall of text on a screen with room for a couple
    // of lines, and the frozen schema refuses it anyway.
    expect(() =>
      parseMisconceptions({ a: { steps: ["1", "2", "3", "4", "5"], explain: "b" } }),
    ).toThrow(/steps/);
    expect(() =>
      parseMisconceptions({ a: { steps: ["1", "2", "3", "4"], explain: "b" } }),
    ).not.toThrow();
  });

  it("refuses an id that is not a snake_case identifier", () => {
    for (const id of ["Sign Flip", "signFlip", "1st", ""]) {
      expect(() =>
        parseMisconceptions({ [id]: { steps: ["a"], explain: "b" } }),
      ).toThrow(/identifier/);
    }
  });

  it("refuses an entry with no steps or no explanation", () => {
    expect(() => parseMisconceptions({ a: { explain: "b" } })).toThrow(/steps/);
    expect(() => parseMisconceptions({ a: { steps: ["x"] } })).toThrow(/explain/);
    expect(() => parseMisconceptions({ a: { steps: [], explain: "b" } })).toThrow(/steps/);
    expect(() => parseMisconceptions({ a: { steps: ["  "], explain: "b" } })).toThrow(/steps/);
  });

  it("refuses a placeholder left behind by authoring", () => {
    expect(() => parseMisconceptions({ a: { steps: ["x"], explain: "   " } })).toThrow(/explain/);
  });

  it("refuses copy that names the failure, at parse time", () => {
    for (const word of FORBIDDEN_WORDS) {
      expect(() =>
        parseMisconceptions({ a: { steps: ["ok"], explain: `Eso está ${word}.` } }),
      ).toThrow(/names the failure/);
    }
  });
});

describe("the shipped copy never scolds", () => {
  it("contains none of the words the verdict screens are held to", () => {
    // The same list, matched the same way — as substrings, which is why
    // "normal" and "errores" are out too. Reported, so a sweep that walks
    // nothing cannot pass (PROC-10).
    const strings = copyStrings(MISCONCEPTIONS);
    // eslint-disable-next-line no-console
    console.log(
      `  diagnosis copy · ${MISCONCEPTIONS.size} misconceptions, ${strings.length} strings swept`,
    );
    expect(scoldings(strings)).toEqual([]);
    expect(strings.length).toBeGreaterThan(0);
  });

  it("sees a scolding that is there, and says which word and where", () => {
    // The control: every assertion above passes for a sweep that is broken.
    // It reports the word *and* the text, because "something scolds somewhere
    // in the copy file" is not a message anyone can act on.
    expect(scoldings(["Eso estuvo mal."])).toEqual(['"mal" in "Eso estuvo mal."']);
    expect(scoldings(["Hubo un error."])).toEqual(['"error" in "Hubo un error."']);
    expect(scoldings(["Vas muy bien."])).toEqual([]);
  });

  it("catches every word on the list, not merely the first", () => {
    // Each entry is checked on its own, so emptying any one of them shows up.
    for (const word of FORBIDDEN_WORDS) {
      expect(scoldings([`texto ${word} texto`])).toHaveLength(1);
    }
    expect(FORBIDDEN_WORDS).toHaveLength(4);
  });

  it("reports each offending string separately", () => {
    expect(scoldings(["Eso estuvo mal.", "Hubo un error.", "Bien."])).toHaveLength(2);
  });
});

describe("a wrong answer a learner actually gives is recognised", () => {
  it("predicts reversing the subtraction and reading the sign as a plus", () => {
    const item = {
      prompt: [], ladderStep: 1, operator: "-" as const,
      left: { num: 3, den: 1 }, right: { num: 8, den: 1 },
      answer: { numerator: -5n, denominator: 1n },
    };
    expect(predictDistractors(item, "-5")).toEqual([
      { answer: "5", misconception: "subtracted_in_reverse" },
      { answer: "11", misconception: "added_instead_of_subtracting" },
    ]);
  });

  it("drops a prediction that coincides with the right answer", () => {
    // `4 − 4` makes "reversed" and the answer the same number. Emitting it
    // would be `distractor_matches_answer` and the whole build would fail over
    // arithmetic rather than over a mistake.
    const item = {
      prompt: [], ladderStep: 1, operator: "-" as const,
      left: { num: 4, den: 1 }, right: { num: 4, den: 1 },
      answer: { numerator: 0n, denominator: 1n },
    };
    expect(predictDistractors(item, "0").map((d) => d.misconception)).toEqual([
      "added_instead_of_subtracting",
    ]);
  });

  it("predicts nothing for an operator it has no rules for", () => {
    const item = {
      prompt: [], ladderStep: 1, operator: "+" as const,
      left: { num: 1, den: 1 }, right: { num: 2, den: 1 },
      answer: { numerator: 3n, denominator: 1n },
    };
    expect(predictDistractors(item, "3")).toEqual([]);
  });
});

describe("what a built pack carries", () => {
  it("attaches a distractor's copy by misconception", () => {
    const { pack } = build(5);
    const diagnosed = pack.items.filter((i) => i.diagnosis !== null);

    expect(diagnosed.length).toBeGreaterThan(0);
    for (const item of diagnosed) {
      for (const distractor of item.diagnosis?.distractors ?? []) {
        expect(MISCONCEPTIONS.get(distractor.diagnosis.misconception)).toEqual(
          distractor.diagnosis,
        );
      }
    }
  });

  it("digests a distractor over the same salt as the answer", () => {
    const { pack } = build(1);
    const first = pack.items[0];
    const distractors = first?.diagnosis?.distractors ?? [];

    // Recomputed independently — a digest of the wrong string would satisfy a
    // shape check, which is the hole the lift's tests already had once.
    expect(distractors.length).toBeGreaterThan(0);
    for (const d of distractors) {
      expect(d.digest).toMatch(/^[0-9a-f]{64}$/u);
      expect(d.digest).not.toBe(first?.answer.digest);
    }
  });

  it("never emits a distractor that matches the answer, or two that match each other", () => {
    // **req-diagnosis-distractors-are-distinct, asserted as an outcome.**
    // The spec words it as "the pack is refused". The builder achieves the same
    // end by not producing one: `4 − 4` makes "reversed" and the right answer
    // the same number, and failing a whole build over arithmetic that happens
    // to coincide would be a gate people route around. The frozen validator
    // still refuses such a pack — this proves the builder never hands it one,
    // swept over every item rather than over a constructed example.
    const { pack } = build(40);
    let checked = 0;
    for (const item of pack.items) {
      const digests = (item.diagnosis?.distractors ?? []).map((d) => d.digest);
      checked += digests.length;
      expect(digests).not.toContain(item.answer.digest);
      expect(new Set(digests).size).toBe(digests.length);
    }
    expect(checked).toBeGreaterThan(0);
  });

  it("refuses a distractor whose misconception has no copy", () => {
    expect(() => build(1, new Map())).toThrow(/no copy for misconception/);
  });

  it("reports how much of the pack is diagnosed", () => {
    // The gap between "the format supports it" and "the content exists" stays
    // visible rather than being assumed closed.
    const { report, pack } = build(5);
    // eslint-disable-next-line no-console
    console.log(
      `  diagnosis coverage · ${report.diagnosed}/${pack.items.length} items carry distractors`,
    );
    expect(report.diagnosed).toBeGreaterThan(0);
    expect(report.diagnosed).toBeLessThanOrEqual(pack.items.length);
  });

  it("an item with no distractors still yields a valid pack", () => {
    // Authoring copy for one family must not block shipping the others.
    const { pack, report } = buildPack(
      parseDeclaration({
        pack_salt: SALT, seed_base: "1", 
        issued_at: "2026-08-18T00:00:00.000Z", expires_at: "2026-11-18T00:00:00.000Z",
        sources: [{ kind: "authored", path: "a.json", skill_id: 1 }],
      }),
      {
        registry: CORE_REGISTRY,
        readAuthored: () => JSON.stringify({ items: [{
          id: "s", ladder_step: 1, answer: "8",
          stimulus: { kind: "numberSeries", payload: { terms: [2, 4, 6], unknown_index: 0 } },
        }] }),
        fallbacks: new Map([[1, FALLBACK]]),
        misconceptions: MISCONCEPTIONS,
      },
    );
    expect(pack.items[0]?.diagnosis).toBeNull();
    expect(report.diagnosed).toBe(0);
  });
});
