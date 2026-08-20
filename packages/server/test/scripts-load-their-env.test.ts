import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

/**
 * Every script that needs a secret loads the file the secrets are in.
 *
 * **This exists because the server had never started.** `.env.local` held all
 * three variables — the connection strings and the auth base URL — and
 * `npm run dev` was `tsx watch src/main.ts`, which reads none of them. So the
 * process refused to boot with *"NEON_AUTH_BASE_URL is not set"*, which was
 * true of the environment and false of the repository, and `CLAUDE.md` recorded
 * the wrong explanation for weeks: that nobody had pasted the value in.
 *
 * The refusal itself is right and stays — a server with no key set answering
 * 401 to everything reads as broken authentication rather than as a missing
 * variable. What was wrong is that nothing handed it the variable it was
 * refusing over.
 *
 * A test over `package.json` rather than over code, because that is where the
 * defect was. It reports what it scanned and fails at zero (PROC-10).
 */
interface Manifest {
  readonly scripts: Readonly<Record<string, string>>;
}

const manifest = JSON.parse(
  readFileSync(fileURLToPath(new URL("../package.json", import.meta.url)), "utf8"),
) as Manifest;

/** The local secrets file, gitignored, that every one of these needs. */
const ENV_FILE = ".env.local";

/**
 * The scripts that run the product against a real environment.
 *
 * Named rather than derived: `test` and `typecheck` must **not** load it — a
 * suite that silently picked up a live connection string would be a suite
 * pointed at production, which is the accident this list is shaped to prevent.
 */
const NEEDS_SECRETS: readonly string[] = ["dev", "migrate", "retention"];

describe("a script that needs a secret loads the file it is in", () => {
  it("names every script it checked, and there is at least one", () => {
    expect(NEEDS_SECRETS.length).toBeGreaterThan(0);
    for (const name of NEEDS_SECRETS) {
      expect(manifest.scripts, `no script named "${name}"`).toHaveProperty(name);
    }
  });

  it.each(NEEDS_SECRETS)("%s reads .env.local", (name) => {
    expect(manifest.scripts[name]).toContain(`--env-file=${ENV_FILE}`);
  });

  it("and the suite deliberately does not", () => {
    // A test run that picked up `DATABASE_URL` from a developer's machine would
    // be a test run against Neon. `TEST_DATABASE_URL` is set by hand, and
    // `.env.local` deliberately does not carry it.
    for (const name of ["test", "typecheck", "verify", "coverage"]) {
      expect(manifest.scripts[name] ?? "").not.toContain("--env-file");
    }
  });
});
