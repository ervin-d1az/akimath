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

/**
 * The owner connection, which is the wider door and had no gate at all.
 *
 * `asOwner` runs work as the login role that **owns the schema**, with no
 * transaction and no `SET LOCAL ROLE`. It is strictly more powerful than
 * `inErasureRole`: the owner holds DELETE on every table, where `retention_job`
 * holds it on the ones it was granted. So
 * `database.asOwner((client) => deletePlayerForAccount(client, id))` from a
 * handler would have erased a player through the request path while leaving
 * **both** assertions below green — `inErasureRole` still named in two files,
 * `DELETE FROM` still in one.
 *
 * It is off the interface handlers hold now, so that call no longer compiles.
 * This is the second half, because a type is one edit from being widened and
 * `vitest` does not typecheck: exactly one file under `src/` may say the name,
 * and it is the one that defines it. There is no sanctioned caller.
 */
const THE_OWNER_DOOR = "adapters/request-database.ts";

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

/**
 * A file's code, without its prose.
 *
 * **The gate below reads for `DELETE FROM`, and a doc comment saying "accepts
 * no UPDATE and no DELETE from the request path" matches it.** That is not a
 * hypothetical: `attempt-repository.ts` explains the invariant it upholds and
 * was reported as breaking it. A rule that fires on its own explanation gets
 * switched off, so the prose comes out first — the same fix
 * `app/test/design/no_spinner_test.dart` needed for the same reason.
 *
 * Block comments and whole-line `//` comments only. A trailing `//` is left
 * alone because stripping it would have to understand strings, and nothing
 * here writes SQL after one.
 */
function codeOf(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .split("\n")
    .filter((line) => !/^\s*(\/\/|\*)/.test(line))
    .join("\n");
}

describe("there is one way to delete a player", () => {
  const sources = sourcesUnder(SRC);
  const naming = (needle: RegExp): readonly string[] =>
    sources.filter((relative) => needle.test(codeOf(readFileSync(join(SRC, relative), "utf8"))));

  it("reports what it scanned, and scanning nothing is a failure", () => {
    // PROC-10, and this one resolves its root from `import.meta.url`, which
    // Stryker's sandbox copy relocates.
    expect(sources.length).toBeGreaterThan(0);
    console.log(`  one way to erase · scanned ${sources.length} source file(s)`);
  });

  it("the erasure role is named in exactly two files: its definition and its caller", () => {
    expect([...naming(/\binErasureRole\b/)].sort()).toEqual([THE_CALLER, THE_DEFINITION].sort());
  });

  it("and the owner connection is named in exactly one: the file that defines it", () => {
    expect([...naming(/\basOwner\b/)]).toEqual([THE_OWNER_DOOR]);
  });

  it("the prose is stripped before the scan, and the stripping works", () => {
    // The control for `codeOf`. Without it the two assertions below pass for a
    // reason unrelated to the code they are about.
    expect(codeOf("/** DELETE FROM x */\nconst a = 1;")).not.toMatch(/DELETE\s+FROM/i);
    expect(codeOf("// DELETE FROM x\nconst a = 1;")).not.toMatch(/DELETE\s+FROM/i);
    expect(codeOf(' * no DELETE from anywhere\nconst a = 1;')).not.toMatch(/DELETE\s+FROM/i);
    expect(codeOf('client.query("DELETE FROM players");')).toMatch(/DELETE\s+FROM/i);
    // The same control for the owner door, whose definition explains itself at
    // length in prose that names the very thing the scan reads for.
    expect(codeOf("/** why asOwner is not for handlers */\nconst a = 1;")).not.toMatch(/\basOwner\b/);
    expect(codeOf("readonly asOwner: () => void;")).toMatch(/\basOwner\b/);
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
