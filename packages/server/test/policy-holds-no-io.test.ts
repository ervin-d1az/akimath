import { readdirSync, readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const SRC = fileURLToPath(new URL("../src", import.meta.url));

/**
 * The structural rule this repository is built on, made a red build on the
 * server side too.
 *
 * `CLAUDE.md`'s architecture rule is "pure policy separated from IO", and the
 * Dart half has enforced it since `pure_boundary_test.dart` landed — it walks
 * the import graph and fails the build. The TypeScript half had only a habit
 * and a doc comment saying **PURE** at the top of each policy module. A comment
 * claiming a property nothing checks is exactly what CMT-3 is about: it retires
 * the question instead of answering it.
 *
 * **The modules are named, not matched by a pattern.** "Everything not under
 * `adapters/`" would silently excuse the next policy file somebody adds, which
 * is the failure this exists to prevent — the same reasoning
 * `one-way-to-log.test.ts` gives for naming its one writer.
 */
const POLICY = [
  "attempts.ts",
  "auth-config.ts",
  "database-config.ts",
  "erasure.ts",
  "health.ts",
  "history.ts",
  "link.ts",
  "log.ts",
  "migrate.ts",
  "packs.ts",
  "players.ts",
  "rating.ts",
  "retention.ts",
  "routing.ts",
  "session.ts",
  "standing.ts",
] as const;

/**
 * What a pure module may not reach for.
 *
 * `pg` is the socket, `./adapters/` is where every socket, clock and file
 * lives, and `node:` is the platform — a policy that reads the filesystem or
 * the clock is a policy that needs a fake to test, which is PURE-1's own
 * criterion.
 *
 * `@akimath/core` and `@akimath/contract` are deliberately absent: both are
 * pure under their own enforced gates — `packages/core`'s determinism AST walk
 * bans `Date` and `Math.random` outright — so importing them moves no IO across
 * this line.
 */
const FORBIDDEN: readonly { readonly what: string; readonly pattern: RegExp }[] = [
  { what: "the database driver", pattern: /from\s+"pg"/u },
  { what: "an adapter", pattern: /from\s+"\.\/adapters\//u },
  { what: "the platform", pattern: /from\s+"node:/u },
];

/** A byte no source file of ours has a reason to carry. */
function isUnprintable(byte: number): boolean {
  const TAB = 0x09;
  const NEWLINE = 0x0a;
  return byte < 0x20 && byte !== TAB && byte !== NEWLINE;
}

function sourcesUnder(directory: string, prefix = ""): readonly string[] {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    const relative = prefix === "" ? entry : `${prefix}/${entry}`;
    if (statSync(path).isDirectory()) {
      return sourcesUnder(path, relative);
    }
    return entry.endsWith(".ts") ? [relative] : [];
  });
}

const sources = sourcesUnder(SRC);

describe("the source tree is text, so the gates that scan it can see it", () => {
  it("reports what it scanned, and scanning nothing is a failure", () => {
    // PROC-10, and this file resolves its root from `import.meta.url`, which
    // Stryker's sandbox copy relocates.
    expect(sources.length).toBeGreaterThan(0);
    console.log(`  source is text · scanned ${sources.length} file(s)`);
  });

  it("no file carries a byte that makes a text tool skip it", () => {
    // **Measured, not theoretical.** `src/rating.ts` was written with a literal
    // NUL as a map-key separator. The code ran and all 418 tests passed, but
    // `file` reported the source as `data` and **grep matched nothing in it, in
    // silence** — so `one-way-to-log.test.ts` and every other scanning gate in
    // this package would have read it as clean whatever it contained. A file
    // the gates cannot see is worse than a gate nobody wrote, because the suite
    // still reports success.
    const unreadable = sources.filter((file) =>
      readFileSync(join(SRC, file)).some(isUnprintable),
    );

    expect(unreadable, "these files are not plain text").toEqual([]);
  });

  it("and the check would catch one", () => {
    // The control: without it the assertion above passes for a predicate that
    // can never fire, including one whose comparison is the wrong way round.
    expect(Buffer.from("a\u0000b", "utf8").some(isUnprintable)).toBe(true);
    expect(Buffer.from("a\tb\nc — é", "utf8").some(isUnprintable)).toBe(false);
  });
});

describe("policy performs no IO, and that is a build failure rather than a comment", () => {
  it("every named policy module is on disk", () => {
    // A typo in the list above would otherwise excuse a real module by pointing
    // this gate at a file that does not exist.
    for (const module of POLICY) {
      expect(sources, `${module} is named as policy but is not under src/`).toContain(module);
    }
    console.log(`  policy holds no IO · ${POLICY.length} pure module(s) checked`);
  });

  it("none of them imports a socket, an adapter or the platform", () => {
    const offences: string[] = [];
    for (const module of POLICY) {
      const text = readFileSync(join(SRC, module), "utf8");
      for (const { what, pattern } of FORBIDDEN) {
        if (pattern.test(text)) {
          offences.push(`${module} imports ${what}`);
        }
      }
    }

    expect(offences, "policy must be testable without a fake").toEqual([]);
  });

  it("the import check would catch one", () => {
    // Fired against an adapter, which legitimately does all three — so the
    // patterns are known to match real code rather than nothing.
    const adapter = readFileSync(join(SRC, "adapters/request-database.ts"), "utf8");
    const caught = FORBIDDEN.filter(({ pattern }) => pattern.test(adapter));

    expect(caught.map(({ what }) => what)).toContain("the database driver");
  });
});
