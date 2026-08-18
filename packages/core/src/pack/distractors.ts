import { renderCanonicalAnswer } from "@akimath/contract";

import type { GeneratedItem } from "../template.js";

/**
 * The wrong answers worth recognising, and what each one means.
 *
 * **PURE.** A generated item in, predicted mistakes out.
 *
 * A distractor is not any wrong answer — it is a *specific* one a learner
 * arrives at by a specific misreading, which is what lets the diagnosis say
 * something better than "not that". Anything unpredicted falls to the skill's
 * fallback copy, so nothing is ever met with silence.
 *
 * Only subtraction has rules here, because `arith.integer.subtract` is the only
 * template that exists. A family with no rules yields none and its items carry
 * no diagnosis, which the frozen format permits and the build reports.
 */

export interface PredictedDistractor {
  /** The canonical answer a learner would give, holding this misconception. */
  readonly answer: string;
  /** The key into the misconception copy. */
  readonly misconception: string;
}

const whole = (term: { num: number; den: number }): number | null =>
  term.den === 1 ? term.num : null;

export function predictDistractors(
  item: GeneratedItem,
  correct: string,
): readonly PredictedDistractor[] {
  if (item.operator !== "-") {
    return [];
  }
  const left = whole(item.left);
  const right = whole(item.right);
  if (left === null || right === null) {
    return [];
  }

  const candidates: readonly PredictedDistractor[] = [
    // `3 − 8` answered as `8 − 3`. The commonest subtraction mistake there is:
    // subtraction is not commutative and addition is, and the habit carries.
    {
      answer: renderCanonicalAnswer(BigInt(right - left)),
      misconception: "subtracted_in_reverse",
    },
    // The sign read as a plus.
    {
      answer: renderCanonicalAnswer(BigInt(left + right)),
      misconception: "added_instead_of_subtracting",
    },
  ];

  const seen = new Set<string>([correct]);
  const kept: PredictedDistractor[] = [];
  for (const candidate of candidates) {
    // A distractor equal to the right answer would diagnose a correct learner,
    // and two distractors sharing an answer make one of them unreachable. Both
    // are refusals in the frozen validator; dropping them here means a build
    // does not fail over arithmetic that happens to coincide — `4 − 4` makes
    // "reversed" and the right answer the same number.
    if (seen.has(candidate.answer)) {
      continue;
    }
    seen.add(candidate.answer);
    kept.push(candidate);
  }
  return kept;
}
