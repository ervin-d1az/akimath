import { mkdirSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { CORE_REGISTRY } from "../golden.js";
import { buildPack } from "../pack/build.js";
import { parseDeclaration } from "../pack/declaration.js";
import { parseMisconceptions } from "../pack/misconceptions.js";
import { flag } from "./flags.js";

/**
 * Writes the committed pack.
 *
 * **The one adapter.** Everything it does with the contents is
 * `packages/core/src/pack/`'s; this reads files, hands them over, and writes
 * the result. It reads no clock — `issued_at` and `expires_at` come from the
 * declaration — so the same inputs produce the same bytes and the CI diff means
 * something.
 */

const here = (relative: string): string =>
  fileURLToPath(new URL(relative, import.meta.url));

/**
 * Paths, overridable from the command line.
 *
 * Defaults are what `npm run build:pack` uses. The overrides exist so the
 * refusal path can be exercised for real — a test that cannot point this at a
 * broken declaration can only assert that the happy path works, and "writes no
 * file when it fails" is precisely the behaviour worth proving.
 */
const DECLARATION = path.resolve(flag("declaration", here("../../content/pack.declaration.json")));
const MISCONCEPTIONS = path.resolve(flag("misconceptions", here("../../content/misconceptions.json")));
const OUT = path.resolve(flag("out", here("../../pack/starter.json")));

/** The skill every item currently belongs to, until the map exists at F5. */
const FALLBACK_MISCONCEPTION = "no_specific_diagnosis";

function main(): void {
  const misconceptions = parseMisconceptions(
    JSON.parse(readFileSync(MISCONCEPTIONS, "utf8")),
  );
  const fallbackCopy = misconceptions.get(FALLBACK_MISCONCEPTION);
  if (fallbackCopy === undefined) {
    throw new TypeError(
      `the copy file declares no "${FALLBACK_MISCONCEPTION}", so a wrong answer ` +
        `matching no distractor would have nothing to say`,
    );
  }

  const declaration = parseDeclaration(
    JSON.parse(readFileSync(DECLARATION, "utf8")),
  );

  // Puzzles belong to no skill, so only the item sources contribute one.
  const skillIds = new Set(
    declaration.sources.flatMap((source) =>
      source.kind === "puzzles" ? [] : [source.skillId],
    ),
  );

  const { pack, report } = buildPack(declaration, {
    registry: CORE_REGISTRY,
    // Relative to the declaration, so the declaration is portable and the path
    // is data rather than a constant compiled into this file.
    readAuthored: (relative) =>
      readFileSync(path.resolve(path.dirname(DECLARATION), relative), "utf8"),
    fallbacks: new Map([...skillIds].map((id) => [id, fallbackCopy])),
    misconceptions,
  });

  // **Written through a temporary file.** `> out` truncates before the producer
  // has run, so a refusal — or an unreadable source — used to leave the
  // committed artifact destroyed and the tree dirty for an unrelated reason.
  // `scripts/dump-schema.sh` did exactly that, which is why this does not.
  mkdirSync(path.dirname(OUT), { recursive: true });
  const temporary = `${OUT}.tmp`;
  try {
    writeFileSync(temporary, `${JSON.stringify(pack, null, 2)}\n`, "utf8");
    renameSync(temporary, OUT);
  } catch (cause) {
    try {
      unlinkSync(temporary);
    } catch {
      // Nothing to clean up. The original is untouched either way.
    }
    throw cause;
  }

  const puzzles = report.puzzleKinds.length === 0
    ? "no puzzles"
    : `${report.puzzleKinds.length} puzzles (${report.puzzleKinds.join(", ")})`;
  const families = [...report.byFamily.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([kind, n]) => `${kind} ${n}`)
    .join(", ");
  // eslint-disable-next-line no-console
  console.log(
    `pack: ${pack.items.length} items (${report.generated} generated, ` +
      `${report.authored} authored) — ${families}\n` +
      `      ${report.diagnosed} carry distractors, ${pack.items.length - report.diagnosed} do not\n` +
      `      ${puzzles}`,
  );
}

try {
  main();
} catch (cause) {
  // A refusal is content that needs fixing, not a crash to debug. One line,
  // and a non-zero exit so a build stops rather than committing nothing.
  process.stderr.write(`build:pack refused — ${(cause as Error).message}\n`);
  process.exitCode = 1;
}
