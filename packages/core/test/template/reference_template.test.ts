import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { rederive, registryOf } from "../../src/registry.js";
import { arithIntegerSubtractV1 } from "../../src/templates/arith-integer-subtract/v1.js";

/**
 * The reference template reproduces an item that is actually shipping.
 *
 * Grounded in `app/assets/packs/starter.json` rather than in a fixture written
 * for this test: a generator that reproduces something invented here proves the
 * plumbing and nothing about whether the plumbing carries real content.
 *
 * **The item is named.** A test that reproduces "some item in the pack" would
 * stay green while the template drifted onto a different one.
 */
const STARTER = JSON.parse(
  readFileSync(
    fileURLToPath(new URL("../../../../app/assets/packs/starter.json", import.meta.url)),
    "utf8",
  ),
) as { items: ReadonlyArray<{ id: string; ladder_step: number; answer: string; prompt: unknown[] }> };

/** The committed seed. Found by search, then written down. */
const SEED = 389n;
const ITEM_ID = "sub-2";

describe(`the reference template reproduces the shipped ${ITEM_ID}`, () => {
  const shipped = STARTER.items.find((item) => item.id === ITEM_ID);

  it("the item it claims to reproduce is in the shipped pack", () => {
    // PROC-10 in miniature: if the pack were renamed or the item removed, every
    // assertion below would be comparing against `undefined`.
    expect(shipped, `${ITEM_ID} is not in the starter pack`).toBeDefined();
    expect(STARTER.items.length).toBeGreaterThan(0);
  });

  it("reproduces its prompt exactly, glyph for glyph", () => {
    const item = rederive(registryOf([arithIntegerSubtractV1]), {
      templateId: "arith.integer.subtract",
      templateVersion: 1,
      seed: SEED,
      ladderStep: shipped!.ladder_step,
    });

    expect(item.prompt).toEqual(shipped!.prompt);
  });

  it("reproduces its answer, as an exact value rather than a string", () => {
    const item = rederive(registryOf([arithIntegerSubtractV1]), {
      templateId: "arith.integer.subtract",
      templateVersion: 1,
      seed: SEED,
      ladderStep: shipped!.ladder_step,
    });

    // `-7` in the pack. Compared through the number, because core does not
    // render — that rule is `rational.ts`'s and the contract owns the spelling.
    expect(item.answer.numerator).toBe(BigInt(shipped!.answer));
    expect(item.answer.denominator).toBe(1n);
  });

  it("a different seed does not reproduce it", () => {
    // The control. Every assertion above is satisfied by a generator that
    // ignores its seed and returns `8 − 15` always.
    const other = rederive(registryOf([arithIntegerSubtractV1]), {
      templateId: "arith.integer.subtract",
      templateVersion: 1,
      seed: SEED + 1n,
      ladderStep: shipped!.ladder_step,
    });

    expect(other.prompt).not.toEqual(shipped!.prompt);
  });
});
