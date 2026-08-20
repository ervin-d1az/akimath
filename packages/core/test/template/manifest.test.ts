import { describe, expect, it } from "vitest";

import { fromManifestEntry, toManifestEntry } from "../../src/manifest.js";
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
      expect(fromManifestEntry(toManifestEntry(ref(seed))), seed.toString()).toEqual(ref(seed));
    }
  });

  it("and the seed is written as a string, never as a number", () => {
    expect(toManifestEntry(ref(INT64_MAX)).seed).toBe("9223372036854775807");
    expect(typeof toManifestEntry(ref(1n)).seed).toBe("string");
  });

  it("the field names are the column's, not the API's", () => {
    // `offline_packs.template_refs` and the pack format are snake_case; a
    // response is camelCase. Renaming either to match the other is how the two
    // stop being the same thing.
    expect(Object.keys(toManifestEntry(ref(1n))).sort()).toEqual([
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
    expect(fromManifestEntry(entry({ seed: "-1" }))?.seed).toBe(-1n);
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
});
