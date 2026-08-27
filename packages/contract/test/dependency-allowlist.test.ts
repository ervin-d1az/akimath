import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

/**
 * The runtime packages `@akimath/contract` is allowed to ship.
 *
 * This list is the contract, and it mirrors `packages/server`'s and
 * `packages/core`'s deliberately: the test cannot judge whether a dependency
 * collects data, so it fails on *any* addition and summons a human who can.
 * DEP-1 names the allowlist as the audit's home, so the audit is a comment on
 * the entry rather than a line in a commit message nobody greps.
 *
 * **Why this file exists.** It did not until 2026-08-27, and the package was
 * covered only *at a distance*: `packages/server`'s allowlist asserts that its
 * first-party dependencies bring nothing but `zod`. Measured — add a runtime
 * dependency here and this package's own 248 tests stay green; only the
 * server's suite goes red. That coverage is contingent on the server continuing
 * to depend on this package, and it reads one level deep: it sees a new direct
 * dependency of this manifest and not that dependency's own children. Both
 * holes close here.
 */
const ALLOWED_RUNTIME_DEPENDENCIES: ReadonlySet<string> = new Set([
  // Added by `f1-contract-freeze`. The schema validator: this package is the
  // frozen acceptor for the offline pack format, and parsing is the whole job.
  // `CLAUDE.md` records it as the repository's first runtime dependency.
  //
  // **DEP-1 audit, re-verified 2026-08-27 against the resolved package:**
  // · **It declares no dependencies of its own.** The assertion below re-checks
  //   that on every run rather than trusting the day it was written, which is
  //   the half the server's cross-package check could not see.
  // · **No install-time script** — no `preinstall`, no `install`, no
  //   `postinstall`. Re-checked below. A postinstall is how a package reaches
  //   the network at a moment nobody is watching. (`zod` does declare
  //   `postbuild` and `prepublishOnly`; neither runs on install, and neither is
  //   shipped to a consumer.)
  // · It is a pure TypeScript validator operating on values already in memory.
  //   No socket, no telemetry endpoint, no update check, no analytics.
  // · **Pinned exactly**, not with a caret, because `npm run emit` is byte-for-
  //   byte diffed in CI: a patch bump that changed one error string would move
  //   `contract/` and fail a gate nobody could explain.
  "zod",
]);

interface Manifest {
  readonly name?: string;
  readonly dependencies?: Readonly<Record<string, string>>;
  readonly devDependencies?: Readonly<Record<string, string>>;
  readonly peerDependencies?: Readonly<Record<string, string>>;
  readonly optionalDependencies?: Readonly<Record<string, string>>;
  readonly version?: string;
  readonly scripts?: Readonly<Record<string, string>>;
}

function readManifest(relative: string): Manifest {
  const path = fileURLToPath(new URL(relative, import.meta.url));
  return JSON.parse(readFileSync(path, "utf8")) as Manifest;
}

/** An exact pin: no caret, no tilde, no range. */
function isExactlyPinned(range: string): boolean {
  return /^\d+\.\d+\.\d+$/.test(range);
}

const manifest = readManifest("../package.json");

describe("the runtime dependency list is a committed allowlist", () => {
  const declared = Object.keys(manifest.dependencies ?? {});

  it("read the manifest it thinks it read", () => {
    // Without this, the assertions below are also true of a file that does not
    // exist, a manifest for another package, and `{}`. "One dependency" has to
    // be distinguishable from "nothing was read" (PROC-11).
    expect(manifest.name).toBe("@akimath/contract");
  });

  it("declares no runtime dependency the allowlist does not", () => {
    // Both directions. A package that stops being depended on should leave the
    // list, or the list stops describing anything.
    expect(new Set(declared)).toEqual(ALLOWED_RUNTIME_DEPENDENCIES);
  });

  it("declares no runtime dependency by the quieter routes", () => {
    // The two ways a shipping dependency arrives without appearing under
    // `dependencies`. `packages/core`'s gate checks both; the server's does
    // not, and this package is the one that actually ships something.
    expect(manifest.peerDependencies).toBeUndefined();
    expect(manifest.optionalDependencies).toBeUndefined();
  });

  it("pins every runtime dependency exactly", () => {
    // The pack determinism gate is byte-for-byte, so a caret here is a diff in
    // `contract/` that arrives on somebody else's install.
    for (const [name, range] of Object.entries(manifest.dependencies ?? {})) {
      expect(
        isExactlyPinned(range),
        `${name} is declared as "${range}"; runtime dependencies are pinned exactly`,
      ).toBe(true);
    }
  });

  it("resolves each runtime dependency to the version it pinned", () => {
    // A pin nothing installed against is a comment. This is the pin checked
    // against what is actually on disk.
    for (const [name, range] of Object.entries(manifest.dependencies ?? {})) {
      const resolved = readManifest(`../node_modules/${name}/package.json`);
      expect(resolved.version, `${name} resolved to ${resolved.version}`).toBe(
        range,
      );
    }
  });

  it("and each one brings nothing of its own", () => {
    // The transitive half, and the reason this file is not redundant with the
    // server's cross-package check: that one reads this manifest, so it sees a
    // new entry here and never what such an entry would drag in behind it.
    const brought = new Set<string>();
    for (const name of declared) {
      const resolved = readManifest(`../node_modules/${name}/package.json`);
      for (const dependency of Object.keys(resolved.dependencies ?? {})) {
        brought.add(dependency);
      }
      for (const dependency of Object.keys(resolved.peerDependencies ?? {})) {
        brought.add(dependency);
      }
    }
    expect(
      [...brought].sort(),
      `the runtime tree grew: ${[...brought].join(", ")}`,
    ).toEqual([]);
  });

  it("ships nothing with an install-time script", () => {
    // All three hooks, not just `postinstall`: `preinstall` and `install` run
    // at the same unwatched moment and reach the network just as well.
    for (const name of declared) {
      const resolved = readManifest(`../node_modules/${name}/package.json`);
      for (const hook of ["preinstall", "install", "postinstall"] as const) {
        expect(
          resolved.scripts?.[hook],
          `${name} declares a ${hook} script`,
        ).toBeUndefined();
      }
    }
  });

  it("reports what it scanned, and scanning nothing is a failure", () => {
    // A reader one typo away from matching nothing passes forever.
    expect(declared.length).toBeGreaterThan(0);
    // eslint-disable-next-line no-console
    console.log(
      `  dependency allowlist · runtime → ${declared.length} package(s), 0 transitive`,
    );
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
