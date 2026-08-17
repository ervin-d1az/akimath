import { intBetween } from "../../prng/splitmix64.js";
import { rationalOf } from "../../rational.js";
import type { GeneratedItem, Template, TemplateRef } from "../../template.js";

/**
 * `arith.integer.subtract` v1 — integer subtraction, the worked example that
 * proves the mechanism.
 *
 * One template, not a library. The library is `f1-5-pack-builder`, where the
 * content decisions live; this exists so the rederivation machinery is
 * exercised end to end by something real rather than by a stub.
 *
 * **The ladder step sets the range**, which is why the step has to be recorded
 * alongside the seed: the same seed at a different step is a different item, and
 * nothing in the seed says which step it was issued at.
 *
 * Draws are indexed from zero and threaded, so the item is a function of
 * `(seed, ladderStep)` and of nothing that happened before it.
 */
const MINUEND = 0;

function rangeFor(ladderStep: number): { readonly low: bigint; readonly high: bigint } {
  // Step 1–2 stay inside a single digit; higher steps widen. Deliberately
  // simple: the shape of the ladder is content's business, and freezing an
  // elaborate curve here would be inventing it.
  const high = BigInt(ladderStep) * 10n;
  return { low: 1n, high };
}

export function generateV1(ref: TemplateRef): GeneratedItem {
  const { low, high } = rangeFor(ref.ladderStep);

  const first = intBetween(ref.seed, MINUEND, low, high);
  const second = intBetween(ref.seed, first.nextIndex, low, high);

  const left = first.value;
  const right = second.value;

  return {
    prompt: [
      { kind: "text", value: left.toString() },
      // U+2212, the minus sign the brand requires — never a hyphen.
      { kind: "operator", glyph: "−" },
      { kind: "text", value: right.toString() },
      { kind: "operator", glyph: "=" },
    ],
    answer: rationalOf(left - right),
    ladderStep: ref.ladderStep,
    operator: "-",
    left: { num: Number(left), den: 1 },
    right: { num: Number(right), den: 1 },
  };
}

export const arithIntegerSubtractV1: Template = Object.freeze({
  id: "arith.integer.subtract",
  version: 1,
  generate: generateV1,
});
