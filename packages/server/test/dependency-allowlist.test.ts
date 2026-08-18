import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

/**
 * The runtime packages `@akimath/server` is allowed to ship.
 *
 * This list is the contract, and it mirrors `app/`'s
 * `dependency_allowlist_test.dart` deliberately: the test cannot judge whether a
 * dependency collects data, so it fails on *any* addition and summons a human
 * who can. DEP-1 names the allowlist as the audit's home, so the audit is a
 * comment on the entry rather than a line in a commit message nobody greps.
 */
const ALLOWED_RUNTIME_DEPENDENCIES: ReadonlySet<string> = new Set([
  // Added 2026-08-17 by `f1-schema-freeze`. The Postgres client. There is no
  // database without one, and `ARCHITECTURE.md` §5 picks `pg` over the Neon
  // serverless driver by name: the sync batch computes Glicko in TypeScript
  // between an INSERT's `RETURNING` and a `user_skills` upsert, which is an
  // interactive transaction the HTTP driver cannot run.
  //
  // **DEP-1 audit, performed before the addition and recorded here because the
  // rule requires it in the same change:**
  // · It opens a TCP socket to the database it is configured for, and to
  //   nothing else. No telemetry endpoint, no update check, no analytics.
  // · It has no postinstall script. Verified against the resolved package's
  //   own `package.json`, which is what the assertion below re-checks on every
  //   run, because a postinstall is how a package reaches the network at a time
  //   nobody is watching.
  // · **It never ships to a device.** The under-13 constraint that governs
  //   `app/` does not reach a server dependency — which is exactly why this is
  //   written down rather than waved through. "The rule is about the client" is
  //   how the first unaudited dependency gets in.
  // · Pinned **exactly**, not with a caret, matching `zod@4.4.3` in
  //   `packages/contract`.
  "pg",
]);

interface Manifest {
  readonly dependencies?: Readonly<Record<string, string>>;
  readonly devDependencies?: Readonly<Record<string, string>>;
}

function readManifest(relative: string): Manifest {
  const path = fileURLToPath(new URL(relative, import.meta.url));
  return JSON.parse(readFileSync(path, "utf8")) as Manifest;
}

/** An exact pin: no caret, no tilde, no range. */
function isExactlyPinned(range: string): boolean {
  return /^\d+\.\d+\.\d+$/.test(range);
}

describe("the runtime dependency list is a committed allowlist", () => {
  const manifest = readManifest("../package.json");
  const declared = Object.keys(manifest.dependencies ?? {});

  it("declares no runtime dependency the allowlist does not", () => {
    expect(new Set(declared)).toEqual(ALLOWED_RUNTIME_DEPENDENCIES);
  });

  it("reports what it scanned, and scanning nothing is a failure", () => {
    // A reader one typo away from matching nothing passes forever.
    expect(declared.length).toBeGreaterThan(0);
    console.log(
      `  dependency allowlist · runtime → ${declared.length} package(s)`,
    );
  });

  it("pins every runtime dependency exactly", () => {
    for (const [name, range] of Object.entries(manifest.dependencies ?? {})) {
      expect(
        isExactlyPinned(range),
        `${name} is declared as "${range}"; runtime dependencies are pinned exactly`,
      ).toBe(true);
    }
  });

  it("ships nothing with a postinstall script", () => {
    // The audit above claims `pg` has none. This is that claim re-checked
    // against the resolved package on every run rather than trusted to the day
    // it was written — a postinstall is how a package reaches the network at a
    // moment nobody is watching.
    for (const name of declared) {
      const resolved = readManifest(
        `../node_modules/${name}/package.json`,
      ) as Manifest & { scripts?: Record<string, string> };
      expect(
        resolved.scripts?.postinstall,
        `${name} declares a postinstall script`,
      ).toBeUndefined();
    }
  });

  it("dev dependencies are out of scope", () => {
    // They do not ship. Sweeping them in would make the gate fire on every
    // test-tooling bump and get disabled within a week.
    expect(Object.keys(manifest.devDependencies ?? {}).length).toBeGreaterThan(
      0,
    );
    for (const name of Object.keys(manifest.devDependencies ?? {})) {
      expect(ALLOWED_RUNTIME_DEPENDENCIES.has(name)).toBe(false);
    }
  });
});
