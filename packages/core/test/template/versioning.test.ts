import { describe, expect, it } from "vitest";

import { rederive, registryOf } from "../../src/registry.js";
import type { TemplateRef } from "../../src/template.js";
import { arithIntegerSubtractV1 } from "../../src/templates/arith-integer-subtract/v1.js";
import { arithIntegerSubtractV2 } from "../../src/templates/arith-integer-subtract/v2.js";

const registry = registryOf([arithIntegerSubtractV1, arithIntegerSubtractV2]);

const at = (version: number, seed: bigint, ladderStep: number): TemplateRef => ({
  templateId: "arith.integer.subtract",
  templateVersion: version,
  seed,
  ladderStep,
});

describe("a revision does not rewrite history", () => {
  it("the two versions genuinely differ at the same seed", () => {
    // **Asserted, not assumed.** Without this the whole file passes for two
    // identical versions, and a versioning test that cannot tell versions apart
    // proves nothing at all. v2 orders the terms below step 3; v1 does not, so
    // a seed that draws a smaller minuend separates them.
    let differed = 0;
    for (let seed = 0n; seed < 200n; seed += 1n) {
      const one = rederive(registry, at(1, seed, 2));
      const two = rederive(registry, at(2, seed, 2));
      if (one.prompt[0]?.kind === "text" && two.prompt[0]?.kind === "text") {
        if (one.prompt[0].value !== two.prompt[0].value) differed += 1;
      }
    }
    expect(differed, "v1 and v2 are indistinguishable").toBeGreaterThan(0);
  });

  it("v1 still produces exactly what it always produced", () => {
    // The committed anchor: the shipped starter pack's `sub-2`.
    const item = rederive(registry, at(1, 389n, 3));
    expect(item.left).toEqual({ num: 8, den: 1 });
    expect(item.right).toEqual({ num: 15, den: 1 });
    expect(item.answer).toEqual({ numerator: -7n, denominator: 1n });
  });

  it("above the ladder's negative threshold the two agree", () => {
    // v2's change is scoped to steps below 3, so at step 3 and up the streams
    // coincide — which is what makes the difference above a real behavioural
    // change rather than a different PRNG walk.
    for (let seed = 0n; seed < 50n; seed += 1n) {
      expect(rederive(registry, at(1, seed, 3))).toEqual(
        rederive(registry, at(2, seed, 3)),
      );
    }
  });

  it("the ladder step is part of the key, not decoration", () => {
    // The fourth field earns its place here: same template, same version, same
    // seed, different step, different item. This is why the schema records it.
    const three = rederive(registry, at(1, 389n, 3));
    const five = rederive(registry, at(1, 389n, 5));
    expect(three).not.toEqual(five);
  });
});
