import { describe, expect, it } from "vitest";

import { DigestSchema } from "@akimath/contract";

import {
  fromManifestEntry,
  templateRefOf,
  toDigestEntry,
  toManifestEntry,
} from "../../src/manifest.js";
import type { TemplateRef } from "../../src/template.js";

const INT64_MAX = 9223372036854775807n;
const INT64_MIN = -9223372036854775808n;

const ref = (seed: bigint): TemplateRef => ({
  templateId: "arith.integer.subtract",
  templateVersion: 2,
  seed,
  ladderStep: 3,
});

describe("a reference survives being written down", () => {
  it("round-trips, including both ends of the signed range", () => {
    // The whole point. A seed past 2^53 is where the naive encoding breaks, and
    // it breaks silently: splitmix64 avalanches, so an item rederived from a
    // seed off by one is unrelated rather than similar.
    for (const seed of [0n, 1n, 389n, 9007199254740993n, INT64_MAX, INT64_MIN]) {
      const read = fromManifestEntry(toManifestEntry(ref(seed)));
      expect(read?.kind, seed.toString()).toBe("template");
      expect(templateRefOf(read!), seed.toString()).toEqual(ref(seed));
    }
  });

  it("and the seed is written as a string, never as a number", () => {
    expect(toManifestEntry(ref(INT64_MAX)).seed).toBe("9223372036854775807");
    expect(typeof toManifestEntry(ref(1n)).seed).toBe("string");
  });

  it("it says which kind it is, rather than leaving it to be inferred", () => {
    // Guessing from the fields present is how a typo in `template_id` quietly
    // becomes "this must be a digest". Nothing has issued a pack in
    // production, so there is no kindless entry to be lenient about.
    expect(toManifestEntry(ref(1n)).kind).toBe("template");
    expect(fromManifestEntry({ ...toManifestEntry(ref(1n)), kind: undefined })).toBeNull();
    expect(fromManifestEntry({ ...toManifestEntry(ref(1n)), kind: "templates" })).toBeNull();
  });

  it("the field names are the column's, not the API's", () => {
    // `offline_packs.template_refs` and the pack format are snake_case; a
    // response is camelCase. Renaming either to match the other is how the two
    // stop being the same thing.
    expect(Object.keys(toManifestEntry(ref(1n))).sort()).toEqual([
      "kind",
      "ladder_step",
      "seed",
      "template_id",
      "template_version",
    ]);
  });
});

describe("and an entry that is not one is refused", () => {
  const entry = (over: Record<string, unknown> = {}): unknown => ({
    ...toManifestEntry(ref(1n)),
    ...over,
  });

  it("a numeric seed, which migration 0002 refuses for the same reason", () => {
    // By the time it is a JSON number it has already lost precision, so it is
    // refused rather than converted — converting would launder the bug.
    expect(fromManifestEntry(entry({ seed: 1477776061723855037 }))).toBeNull();
    expect(fromManifestEntry(entry({ seed: 1 }))).toBeNull();
  });

  it("a seed that is a string but not a number", () => {
    for (const seed of ["", "1.5", "0x10", "1e3", " 1", "nine"]) {
      expect(fromManifestEntry(entry({ seed })), seed).toBeNull();
    }
    // A negative one is fine: the column is signed.
    expect(templateRefOf(fromManifestEntry(entry({ seed: "-1" }))!)?.seed).toBe(-1n);
  });

  it("a missing or mistyped field", () => {
    for (const over of [
      { template_id: undefined },
      { template_id: 7 },
      { template_version: "2" },
      { template_version: 2.5 },
      { ladder_step: undefined },
      { ladder_step: "3" },
      { ladder_step: 3.5 },
    ]) {
      expect(fromManifestEntry(entry(over)), JSON.stringify(over)).toBeNull();
    }
  });

  it("and something that is not an object at all", () => {
    for (const value of [null, undefined, 3, "x", [toManifestEntry(ref(1n))]]) {
      expect(fromManifestEntry(value), JSON.stringify(value ?? null)).toBeNull();
    }
  });
})
describe("and an item nobody can rederive is written down by its digest", () => {
  const DIGEST = "a".padEnd(64, "b");

  it("round-trips", () => {
    const entry = toDigestEntry({ digest: DIGEST, skillId: 1 });

    expect(entry).toEqual({ kind: "digest", digest: DIGEST, skill_id: 1 });
    expect(fromManifestEntry(entry)).toEqual(entry);
  });

  it("and has no reference, which is the whole reason it exists", () => {
    // An authored item carries no template, so `(packId, index)` could not
    // address it and nothing could grade it. The digest is what identifies it.
    expect(templateRefOf(toDigestEntry({ digest: DIGEST, skillId: 1 }))).toBeNull();
  });

  it("it carries a skill, because `attempts.skill_id` is NOT NULL", () => {
    // There is no template to ask. The pack's own item says which skill it
    // exercises; this is that fact written where the server can reach it.
    expect(toDigestEntry({ digest: DIGEST, skillId: 4 }).skill_id).toBe(4);
    expect(fromManifestEntry({ kind: "digest", digest: DIGEST })).toBeNull();
    expect(fromManifestEntry({ kind: "digest", digest: DIGEST, skill_id: 0 })).toBeNull();
    expect(fromManifestEntry({ kind: "digest", digest: DIGEST, skill_id: 1.5 })).toBeNull();
  });

  it("a digest that is not one is refused", () => {
    for (const digest of [
      "",
      "abc",
      "A".padEnd(64, "b"), // uppercase
      "a".padEnd(63, "b"), // too short
      "a".padEnd(65, "b"), // too long
      `${"a".padEnd(64, "b")} `, // the anchors
    ]) {
      expect(fromManifestEntry({ kind: "digest", digest, skill_id: 1 }), digest).toBeNull();
    }
  });

  it("and its shape agrees with the contract's, which is the authority", () => {
    // This package may not import `packages/contract` — the public surface
    // imports no package at all — so the rule exists twice. Both are run over
    // the same probes, which is the arrangement used everywhere a rule has to.
    const probes = [
      "a".padEnd(64, "b"),
      "0".padEnd(64, "9"),
      "",
      "A".padEnd(64, "b"),
      "a".padEnd(63, "b"),
      "a".padEnd(65, "b"),
      "g".padEnd(64, "a"),
    ];
    expect(probes.length).toBeGreaterThan(0);
    for (const probe of probes) {
      const contractAccepts = DigestSchema.safeParse(probe).success;
      const mineAccepts =
        fromManifestEntry({ kind: "digest", digest: probe, skill_id: 1 }) !== null;
      expect(mineAccepts, probe).toBe(contractAccepts);
    }
  });
});
