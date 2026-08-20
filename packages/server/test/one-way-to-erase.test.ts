import { readdirSync, readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const SRC = fileURLToPath(new URL("../src", import.meta.url));

/**
 * The only two files allowed to name the erasure role, named rather than
 * matched.
 *
 * `app_request` holds DELETE on no table, and that is what makes `CLAUDE.md`'s
 * append-only-attempts invariant structural instead of a promise.
 * `inErasureRole` is the one sanctioned way past it, and the invariant says
 * exactly which path may take it: `DELETE /v1/me`. A pattern — "anything under
 * adapters/" — would excuse the next handler that quietly starts deleting,
 * which is the whole failure this gate exists to prevent.
 *
 * Same shape as `one-way-to-log.test.ts`, for the same reason.
 */
const THE_DEFINITION = "adapters/request-database.ts";
const THE_CALLER = "adapters/http-server.ts";

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

describe("there is one way to delete a player", () => {
  const sources = sourcesUnder(SRC);
  const naming = (needle: RegExp): readonly string[] =>
    sources.filter((relative) => needle.test(readFileSync(join(SRC, relative), "utf8")));

  it("reports what it scanned, and scanning nothing is a failure", () => {
    // PROC-10, and this one resolves its root from `import.meta.url`, which
    // Stryker's sandbox copy relocates.
    expect(sources.length).toBeGreaterThan(0);
    console.log(`  one way to erase · scanned ${sources.length} source file(s)`);
  });

  it("the erasure role is named in exactly two files: its definition and its caller", () => {
    expect([...naming(/\binErasureRole\b/)].sort()).toEqual([THE_CALLER, THE_DEFINITION].sort());
  });

  it("and nothing else in the request path writes a DELETE", () => {
    // The repository is where SQL lives, so a second `DELETE FROM` there would
    // pass the check above while being unreachable — or worse, reachable from
    // `inRequestRole`, where it would fail at runtime as a 500 rather than at
    // build time. `adapters/retention-job.ts` is the batch job and is excused
    // by name; it connects as `retention_job` through its own credential.
    const excused = "adapters/retention-job.ts";
    expect(sources).toContain(excused);
    expect(naming(/DELETE\s+FROM/i).filter((relative) => relative !== excused)).toEqual([
      "adapters/player-repository.ts",
    ]);
  });
});
