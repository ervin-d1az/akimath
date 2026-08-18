import { existsSync } from "node:fs";
import { dirname, join } from "node:path";

/**
 * Where the app's authored pack lives, found by walking up.
 *
 * **Walked up rather than counted in `..` segments.** Stryker runs this suite
 * from a sandbox copy of the package, so a fixed `../../../../app/...` lands
 * nowhere — and a test whose fixture cannot be read does not fail under
 * Stryker, it simply never covers anything. That is how the pack modules first
 * reported 57 mutants with "no coverage" while their tests were green.
 *
 * `packages/contract/test/fixture-files.ts` learned the same lesson before this
 * did and says so in the same words; this is its counterpart on the core side.
 */
function findAuthoredPack(start: string): string {
  const relative = join("app", "assets", "packs", "starter.json");
  let directory = start;
  for (;;) {
    const candidate = join(directory, relative);
    if (existsSync(candidate)) {
      return candidate;
    }
    const parent = dirname(directory);
    if (parent === directory) {
      throw new Error(`${relative} not found above ${start}`);
    }
    directory = parent;
  }
}

export const AUTHORED_PACK_PATH = findAuthoredPack(import.meta.dirname);
