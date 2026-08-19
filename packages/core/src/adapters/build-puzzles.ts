import { mkdirSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import path from "node:path";

import {
  generateCagedBatch,
  generateKakuroBatch,
  generateMagicSquareBatch,
  generateWordSearchBatch,
  type Batch,
  type PuzzleCopy,
} from "../puzzles/batch.js";
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

/** Every kind this generator can build. */
type BuildableKind = CagedKind | "wordSearch" | "magicSquare" | "kakuro";

const KINDS: readonly BuildableKind[] = [
  ...CAGED_KINDS,
  "wordSearch",
  "magicSquare",
  "kakuro",
];

/**
 * The words a sopa de letras may hide.
 *
 * **Content, and it lives in the adapter** for the same reason the copy does:
 * `src/puzzles/` has no business holding a Spanish word list. Unaccented and
 * uppercase, because the contract's cell is `[A-ZÑ]` — a `Ú` is not a letter
 * this format can print, and a grid that quietly dropped the accent would be
 * teaching the wrong spelling.
 */
const VOCABULARY: readonly string[] = [
  "SUMA",
  "RESTA",
  "CERO",
  "DOBLE",
  "MITAD",
  "NUMERO",
  "DECENA",
  "UNIDAD",
  "TRIPLE",
  "PARES",
  "IMPAR",
  "TOTAL",
  "MEDIDA",
  "CUENTA",
];

/** The es-MX copy each kind carries, the same lines the authored boards use. */
const COPY: Readonly<Record<BuildableKind, PuzzleCopy>> = Object.freeze({
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
  wordSearch: {
    tutorialSteps: [
      "Arrastra el dedo de la primera letra a la última.",
      "Una palabra puede ir en cualquiera de las ocho direcciones.",
    ],
    referenceSheet: [
      "Las palabras se leen en línea recta, nunca dan vuelta.",
      "Tacha la lista: terminas cuando no queda ninguna.",
    ],
  },
  magicSquare: {
    tutorialSteps: [
      "Cada fila y cada columna llegan al número de su ficha.",
      "Ningún número se repite en todo el cuadro.",
    ],
    referenceSheet: [
      "Las fichas de la orilla dicen a cuánto tiene que llegar cada línea.",
      "Se usan los números del 1 al total de casillas.",
    ],
  },
  kakuro: {
    tutorialSteps: [
      "Cada tramo suma el número de su pista.",
      "Dentro de un tramo no se repite ningún dígito.",
    ],
    referenceSheet: [
      "Los tramos van hacia la derecha y hacia abajo.",
      "Solo se usan los dígitos del 1 al 9.",
    ],
  },
});

function requireKind(raw: string): BuildableKind {
  const found = KINDS.find((kind) => kind === raw);
  if (found === undefined) {
    throw new TypeError(`--kind must be one of ${KINDS.join(", ")}, not ${raw}`);
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

function switchKind(
  kind: BuildableKind,
  size: number,
  count: number,
  firstSeed: bigint,
): Batch {
  switch (kind) {
    case "wordSearch":
      return generateWordSearchBatch(
        { size, count, firstSeed, vocabulary: VOCABULARY },
        COPY[kind],
      );
    case "magicSquare":
      return generateMagicSquareBatch({ size, count, firstSeed }, COPY[kind]);
    case "kakuro":
      return generateKakuroBatch({ size, count, firstSeed }, COPY[kind]);
    default:
      return generateCagedBatch({ kind, size, count, firstSeed }, COPY[kind]);
  }
}

function main(): void {
  const kind = requireKind(flag("kind", "kenken"));
  const size = requirePositive("size", flag("size", "4"));
  const count = requirePositive("count", flag("count", "3"));
  const firstSeed = BigInt(flag("seed", "1"));
  const out = path.resolve(flag("out", `puzzles-${kind}-${size}.json`));

  const batch: Batch = switchKind(kind, size, count, firstSeed);

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
