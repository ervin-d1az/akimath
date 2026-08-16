import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";

/**
 * Test-only reader for the committed artifacts under `contract/`. The
 * filesystem lives here rather than in `src/` so every module under test stays
 * pure (PURE-1); the emitter in `src/adapters/` is the only production code
 * that touches disk.
 */
function findContractRoot(start: string): string {
  let directory: string = start;
  for (;;) {
    const candidate: string = join(directory, "contract");
    if (existsSync(join(candidate, "fixtures"))) {
      return candidate;
    }
    const parent: string = dirname(directory);
    if (parent === directory) {
      throw new Error("contract/fixtures not found above " + start);
    }
    directory = parent;
  }
}

/**
 * Walked up rather than counted in `..` segments: Stryker runs the suite from
 * a sandbox copy of this package, where a fixed relative path lands nowhere.
 */
export const CONTRACT_ROOT = findContractRoot(import.meta.dirname);

export const FIXTURES_ROOT = join(CONTRACT_ROOT, "fixtures");

/** A fixture's stem is its wire value verbatim (design.md D7). */
export function goldenStems(group: string): readonly string[] {
  return readdirSync(join(FIXTURES_ROOT, group))
    .filter((name) => name.split(".").length === 2 && name.endsWith(".json"))
    .map((name) => name.replace(/\.json$/u, ""))
    .sort();
}

export function readFixture(relativePath: string): unknown {
  return JSON.parse(readFileSync(join(FIXTURES_ROOT, relativePath), "utf8"));
}

/** Every file under a directory, relative and sorted, for byte comparison. */
export function filesUnder(root: string, prefix = ""): readonly string[] {
  return readdirSync(join(root, prefix), { withFileTypes: true })
    .flatMap((entry) =>
      entry.isDirectory()
        ? filesUnder(root, join(prefix, entry.name))
        : [join(prefix, entry.name)],
    )
    .sort();
}
