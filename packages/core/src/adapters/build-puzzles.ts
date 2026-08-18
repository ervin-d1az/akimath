import { mkdirSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import path from "node:path";

import { generateCagedBatch, type PuzzleCopy } from "../puzzles/batch.js";
import { flag } from "./flags.js";
import type { CagedKind } from "../puzzles/caged.js";

/**
 * Writes a batch of caged boards.
 *
 * **The one adapter.** Everything it does with the contents is
 * `src/puzzles/`'s; this reads flags, hands them over, and writes the result.
 * It reads no clock and draws no randomness of its own — the seed comes from
 * the command line, so the same command produces the same file and a diff
 * means something.
 *
 * A board is not a pack. This writes envelopes for someone to paste into an
 * authored pack, deliberately: which boards ship is a content decision, and a
 * generator that appended to the pack directly would be making it.
 */
const CAGED_KINDS: readonly CagedKind[] = ["kenken", "killer"];

/** The es-MX copy each kind carries, the same lines the authored boards use. */
const COPY: Readonly<Record<CagedKind, PuzzleCopy>> = Object.freeze({
  kenken: {
    tutorialSteps: [
      "Cada fila y cada columna llevan cada número una vez.",
      "La esquina de la jaula dice el resultado y con qué operación.",
    ],
    referenceSheet: [
      "Los números van del 1 al tamaño del cuadro.",
      "Una jaula de una sola celda ya trae su número.",
    ],
  },
  killer: {
    tutorialSteps: [
      "Cada fila y cada columna llevan cada número una vez.",
      "La esquina de la jaula dice a cuánto suman sus celdas.",
    ],
    referenceSheet: [
      "Dentro de una jaula no se repite ningún número.",
      "Los números van del 1 al tamaño del cuadro.",
    ],
  },
});

function requireKind(raw: string): CagedKind {
  const found = CAGED_KINDS.find((kind) => kind === raw);
  if (found === undefined) {
    throw new TypeError(`--kind must be one of ${CAGED_KINDS.join(", ")}, not ${raw}`);
  }
  return found;
}

function requirePositive(name: string, raw: string): number {
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1) {
    throw new TypeError(`--${name} must be a positive whole number, not ${raw}`);
  }
  return value;
}

function main(): void {
  const kind = requireKind(flag("kind", "kenken"));
  const size = requirePositive("size", flag("size", "4"));
  const count = requirePositive("count", flag("count", "3"));
  const firstSeed = BigInt(flag("seed", "1"));
  const out = path.resolve(flag("out", `puzzles-${kind}-${size}.json`));

  const batch = generateCagedBatch({ kind, size, count, firstSeed }, COPY[kind]);

  // **Written through a temporary file**, for the reason `build-pack.ts`
  // records: `> out` truncates before the producer has run, so a refusal used
  // to leave the committed artifact destroyed.
  mkdirSync(path.dirname(out), { recursive: true });
  const temporary = `${out}.tmp`;
  try {
    writeFileSync(temporary, `${JSON.stringify(batch.boards, null, 2)}\n`, "utf8");
    renameSync(temporary, out);
  } catch (cause) {
    try {
      unlinkSync(temporary);
    } catch {
      // Nothing to clean up. The original is untouched either way.
    }
    throw cause;
  }

  const refused = Object.entries(batch.report.refused)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([tag, n]) => `${tag} ${n}`)
    .join(", ");
  // eslint-disable-next-line no-console
  console.log(
    `puzzles: ${batch.report.accepted}/${count} ${kind} ${size}×${size} ` +
      `in ${batch.report.attempts} attempts → ${out}\n` +
      `         refused: ${refused === "" ? "nothing" : refused}` +
      (batch.report.exhausted ? "\n         BUDGET EXHAUSTED — fewer boards than asked for" : ""),
  );
}

try {
  main();
} catch (cause) {
  // eslint-disable-next-line no-console
  console.error(`puzzles: ${cause instanceof Error ? cause.message : String(cause)}`);
  process.exitCode = 1;
}
