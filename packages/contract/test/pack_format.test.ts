import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { CONTRACT_ROOT, filesUnder, goldenStems, readFixture } from "./fixture-files.js";
import { emitContract } from "../src/adapters/emit.js";
import { canonicalJson } from "../src/canonical-json.js";

import { AnswerSpecSchema, ANSWER_SHAPES } from "../src/answer.js";
import { PACK_FORMAT_VERSION, parsePack } from "../src/pack.js";

const DIGEST = "abcdef0123456789".repeat(4);

describe("PACK_FORMAT_VERSION", () => {
  it("is frozen at 1", () => {
    expect(PACK_FORMAT_VERSION).toBe(1);
  });
});

describe("AnswerSpec", () => {
  it("closes at the two shapes the six families need", () => {
    expect(ANSWER_SHAPES).toEqual(["integer", "fraction"]);
  });

  it("accepts a fraction answer, which the keypad collects as num and den", () => {
    expect(AnswerSpecSchema.safeParse({ shape: "fraction", digest: DIGEST }).success).toBe(true);
  });

  it("accepts an integer answer, which the other five families use", () => {
    expect(AnswerSpecSchema.safeParse({ shape: "integer", digest: DIGEST }).success).toBe(true);
  });

  it("rejects a third answer shape", () => {
    expect(AnswerSpecSchema.safeParse({ shape: "decimal", digest: DIGEST }).success).toBe(false);
  });

  it("rejects a digest that is not 64 lowercase hex characters", () => {
    expect(AnswerSpecSchema.safeParse({ shape: "integer", digest: "ABC" }).success).toBe(false);
    expect(AnswerSpecSchema.safeParse({ shape: "integer", digest: DIGEST.toUpperCase() }).success)
      .toBe(false);
  });

  it("rejects a digest with anything before or after the 64 hex characters", () => {
    expect(AnswerSpecSchema.safeParse({ shape: "integer", digest: `${DIGEST}0` }).success).toBe(
      false,
    );
    expect(AnswerSpecSchema.safeParse({ shape: "integer", digest: ` ${DIGEST}` }).success).toBe(
      false,
    );
  });

  it("rejects a plaintext correct answer travelling beside the digest", () => {
    expect(
      AnswerSpecSchema.safeParse({ shape: "integer", digest: DIGEST, value: "7" }).success,
    ).toBe(false);
  });
});

const MINIMAL_PACK = {
  pack_format_version: 1,
  pack_salt: "a1b2c3d4e5f60718293a4b5c6d7e8f90",
  issued_at: "2026-08-16T00:00:00.000Z",
  expires_at: "2026-09-15T00:00:00.000Z",
  skill_nodes: [{ skill_id: 1, state: "started" }],
  skill_fallbacks: [
    {
      skill_id: 1,
      diagnosis: {
        misconception: "unclassified",
        steps: ["Vuelve a ver el paso de en medio."],
        explain: "Aquí va el razonamiento completo, paso por paso.",
      },
    },
  ],
  items: [
    {
      skill_id: 1,
      ladder_step: 3,
      keypad: "item",
      stimulus: { kind: "numberSeries", payload: { terms: [2, 4, 8], unknown_index: 2 } },
      answer: { shape: "integer", digest: DIGEST },
      diagnosis: null,
    },
  ],
  puzzles: [],
};

function packWithout(field: string): Record<string, unknown> {
  const { [field]: _removed, ...rest } = MINIMAL_PACK as Record<string, unknown>;
  return rest;
}

describe("parsePack", () => {
  it("parses a minimal pack", () => {
    const parsed = parsePack(MINIMAL_PACK);
    expect(parsed.ok).toBe(true);
  });

  it("rejects a pack missing any of its required root fields", () => {
    for (const field of [
      "pack_format_version",
      "pack_salt",
      "issued_at",
      "expires_at",
      "skill_nodes",
      "skill_fallbacks",
      "items",
      "puzzles",
    ]) {
      expect(parsePack(packWithout(field))).toEqual({ ok: false, tag: "schema_violation" });
    }
  });

  it("rejects a pack claiming a format version this package does not speak", () => {
    expect(parsePack({ ...MINIMAL_PACK, pack_format_version: 2 })).toEqual({
      ok: false,
      tag: "schema_violation",
    });
  });

  it("rejects an item missing any of its required fields", () => {
    const [item] = MINIMAL_PACK.items;
    for (const field of ["skill_id", "ladder_step", "keypad", "stimulus", "answer", "diagnosis"]) {
      const { [field]: _removed, ...rest } = item as unknown as Record<string, unknown>;
      expect(parsePack({ ...MINIMAL_PACK, items: [rest] })).toEqual({
        ok: false,
        tag: "schema_violation",
      });
    }
  });

  it("rejects an item whose stimulus payload is malformed", () => {
    expect(
      parsePack({
        ...MINIMAL_PACK,
        items: [
          {
            ...MINIMAL_PACK.items[0],
            stimulus: { kind: "numberSeries", payload: { terms: [2, 4, 8], unknown_index: 9 } },
          },
        ],
      }),
    ).toEqual({ ok: false, tag: "unknown_index_out_of_range" });
  });

  it("rejects an item whose keypad is a per-key list", () => {
    expect(
      parsePack({
        ...MINIMAL_PACK,
        items: [{ ...MINIMAL_PACK.items[0], keypad: ["1", "2", "3"] }],
      }),
    ).toEqual({ ok: false, tag: "schema_violation" });
  });

  it("rejects a pack whose issued_at is not an instant", () => {
    expect(parsePack({ ...MINIMAL_PACK, issued_at: "yesterday" })).toEqual({
      ok: false,
      tag: "schema_violation",
    });
  });
});

describe("canonicalJson", () => {
  it("sorts keys, so the bytes do not depend on insertion order", () => {
    expect(canonicalJson({ b: 1, a: 2 })).toBe(canonicalJson({ a: 2, b: 1 }));
  });

  it("ends with a newline, so the file is a well-formed text file", () => {
    expect(canonicalJson({ a: 1 }).endsWith("\n")).toBe(true);
  });

  it("sorts nested keys too", () => {
    expect(canonicalJson({ outer: { z: 1, a: 2 } })).toBe('{\n  "outer": {\n    "a": 2,\n    "z": 1\n  }\n}\n');
  });

  it("leaves array order alone, because order is data there", () => {
    expect(canonicalJson([3, 1, 2])).toBe("[\n  3,\n  1,\n  2\n]\n");
  });
});

describe("the emitter", () => {
  it("produces byte-identical output on two runs", () => {
    const first: string = mkdtempSync(join(tmpdir(), "akimath-contract-"));
    const second: string = mkdtempSync(join(tmpdir(), "akimath-contract-"));
    emitContract({ sourceRoot: CONTRACT_ROOT, outputRoot: first });
    emitContract({ sourceRoot: CONTRACT_ROOT, outputRoot: second });

    const written: readonly string[] = filesUnder(first);
    expect(written.length).toBeGreaterThan(0);
    expect(filesUnder(second)).toEqual(written);
    for (const relative of written) {
      expect(readFileSync(join(first, relative))).toEqual(readFileSync(join(second, relative)));
    }
  });

  it("emits the pack schema and the two payload schema maps", () => {
    const output: string = mkdtempSync(join(tmpdir(), "akimath-contract-"));
    emitContract({ sourceRoot: CONTRACT_ROOT, outputRoot: output });
    expect(filesUnder(output)).toContain("pack.schema.json");
    expect(filesUnder(output)).toContain("stimulus.schema.json");
    expect(filesUnder(output)).toContain("puzzle.schema.json");
  });
});

describe("the recorded normalisation of every fixture", () => {
  it("sits beside its fixture and equals what the parser produces", () => {
    for (const group of ["stimulus", "puzzle", "diagnosis"] as const) {
      for (const stem of goldenStems(group)) {
        const parsed = parsePack(readFixture(`${group}/${stem}.json`));
        expect({ group, stem, recorded: readFixture(`${group}/${stem}.normalised.json`) }).toEqual({
          group,
          stem,
          recorded: JSON.parse(canonicalJson(parsed)),
        });
      }
    }
  });
});
