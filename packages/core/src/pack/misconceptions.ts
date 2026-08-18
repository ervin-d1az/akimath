import type { DiagnosisCopy } from "@akimath/contract";

/**
 * The Spanish a wrong answer is met with.
 *
 * **PURE** — decoded JSON in, a lookup out. Reading the file is the CLI's.
 *
 * **Copy lives in data, not in TypeScript.** It is prose about a specific
 * mistake, written and rewritten by whoever is best at writing it. In source,
 * every comma is a code review and the eventual translation pass becomes a
 * search through modules. The frozen `DiagnosisCopySchema` already requires
 * `misconception` to be a snake_case identifier, so the format anticipated a
 * keyed file.
 *
 * The key **is** the misconception, so the file does not repeat it inside each
 * entry — a shape that lets the two disagree.
 *
 * Identifiers are English and the copy is es-MX, which is the repository's rule
 * everywhere: only what a player reads is Spanish.
 */

/**
 * Words the copy may never contain.
 *
 * The same list `verdict_screen_test.dart` holds the verdict screens to, and
 * matched the same way — as substrings, which is why "normal" and "errores" are
 * also out. `req-diagnosis-copy` is about the product, not about one screen: a
 * diagnosis that opens by telling a learner they were wrong has spent its one
 * chance to be read.
 */
export const FORBIDDEN_WORDS: readonly string[] = [
  "incorrecto",
  "error",
  "fallaste",
  "mal",
];

const MISCONCEPTION_ID = /^[a-z][a-z0-9_]*$/u;

/** Every forbidden word found in a run of copy, for a caller that reports. */
export function scoldings(strings: Iterable<string>): readonly string[] {
  const found: string[] = [];
  for (const text of strings) {
    const lower = text.toLowerCase();
    for (const word of FORBIDDEN_WORDS) {
      if (lower.includes(word)) {
        found.push(`"${word}" in ${JSON.stringify(text)}`);
      }
    }
  }
  return found;
}

/** Every string of copy in a lookup, so a sweep can count what it checked. */
export function copyStrings(
  lookup: ReadonlyMap<string, DiagnosisCopy>,
): readonly string[] {
  return [...lookup.values()].flatMap((copy) => [copy.explain, ...copy.steps]);
}

export function parseMisconceptions(
  value: unknown,
): ReadonlyMap<string, DiagnosisCopy> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new TypeError("misconceptions: must be an object keyed by identifier");
  }

  const lookup = new Map<string, DiagnosisCopy>();
  for (const [id, raw] of Object.entries(value as Record<string, unknown>)) {
    if (!MISCONCEPTION_ID.test(id)) {
      throw new TypeError(`misconceptions: "${id}" is not a snake_case identifier`);
    }
    const entry = raw as { steps?: unknown; explain?: unknown };
    const steps = entry.steps;
    if (
      !Array.isArray(steps) ||
      steps.length < 1 ||
      steps.length > 4 ||
      steps.some((s) => typeof s !== "string" || s.trim().length === 0)
    ) {
      throw new TypeError(`misconceptions: "${id}" needs one to four non-empty steps`);
    }
    if (typeof entry.explain !== "string" || entry.explain.trim().length === 0) {
      throw new TypeError(`misconceptions: "${id}" needs a non-empty explain`);
    }
    lookup.set(id, {
      misconception: id,
      steps: steps as string[],
      explain: entry.explain,
    });
  }

  if (lookup.size === 0) {
    throw new TypeError("misconceptions: the file declares none");
  }

  // Swept at parse time, so copy that scolds cannot reach a pack even if the
  // caller forgets to look.
  const offences = scoldings(copyStrings(lookup));
  if (offences.length > 0) {
    throw new TypeError(`misconceptions: the copy names the failure — ${offences.join("; ")}`);
  }

  return lookup;
}
