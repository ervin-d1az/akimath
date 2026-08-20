import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";

/**
 * The plaintext answers the built pack only ever carries as digests.
 *
 * **The one place they exist in the open**, which is the point: the pack the
 * server issues records `HMAC(pack_salt, canonical answer)` and nothing else,
 * so a test proving the loop closes on authored content has to get the answer
 * from the authoring source. If this file could read it from anywhere the
 * server can reach, the claim "the server never learns an authored answer"
 * would be false.
 *
 * **Walked up rather than counted in `..` segments**, the same as
 * `support/contract.ts`: Stryker runs the suite from a sandbox copy, so a fixed
 * relative path lands nowhere — and a test whose fixture cannot be read does
 * not fail under Stryker, it covers nothing.
 *
 * The order is the built pack's own: the declaration lists the authored source
 * first, so authored item *n* is pack item *n*. `test/issue-pack.test.ts` only
 * relies on the first two, and the alignment is asserted rather than assumed by
 * comparing digests.
 */
function findAuthored(start: string): string {
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

export function authoredAnswers(): readonly string[] {
  const source = JSON.parse(readFileSync(findAuthored(process.cwd()), "utf8")) as {
    items: { answer: string }[];
  };
  if (source.items.length === 0) {
    throw new Error("the authored pack declares no items, so nothing could be proven with it");
  }
  return source.items.map((item) => item.answer);
}
