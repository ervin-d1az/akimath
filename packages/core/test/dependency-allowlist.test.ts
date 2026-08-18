import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

/**
 * `@akimath/core` ships **nothing**. It has no `dependencies` key at all.
 *
 * `ARCHITECTURE.md` §3 is specific about why this is a test and not a pnpm
 * setting: "an agent runs `pnpm add drizzle-orm --filter @aki/core` and a
 * resolution-based invariant dies in a one-line diff". So the gate reads the
 * manifest.
 *
 * **The hard part of this gate is not being vacuous.** `packages/server`'s
 * version compares a declared set against an allowlist; against an empty set
 * that comparison passes for a manifest that was never read, a manifest for the
 * wrong package, and a manifest that is an empty object. Three of the
 * assertions below exist only to tell those apart (PROC-11).
 */
interface Manifest {
  readonly name?: string;
  readonly dependencies?: Readonly<Record<string, string>>;
  readonly devDependencies?: Readonly<Record<string, string>>;
  readonly peerDependencies?: Readonly<Record<string, string>>;
  readonly optionalDependencies?: Readonly<Record<string, string>>;
}

const manifest = JSON.parse(
  readFileSync(fileURLToPath(new URL("../package.json", import.meta.url)), "utf8"),
) as Manifest;

/**
 * Development dependencies, each with the reason it is allowed to exist.
 *
 * DEP-1 puts dev dependencies out of the shipping allowlist's scope — they do
 * not reach a device — but `@akimath/contract` is unusual enough to say out
 * loud, because a reader will ask why the zero-dependency package references
 * another package at all.
 */
const DEV_DEPENDENCY_REASONS: Readonly<Record<string, string>> = {
  // **Verification, not reuse.** Core is a producer of items; the contract is
  // the frozen acceptor. Proving a generated item is loadable is a test-time
  // concern, so the reference is a dev dependency and the `dependencies` key
  // stays absent. Putting it in `dependencies` would defeat the gate above —
  // a manifest reader cannot tell a workspace sibling from `drizzle-orm` — and
  // would drag `zod` in transitively, because the contract's index re-exports
  // every schema module.
  "@akimath/contract": "the frozen format, imported by tests to prove core's output is acceptable",
  "@stryker-mutator/core": "mutation testing (Tier 1b)",
  "@stryker-mutator/vitest-runner": "mutation testing (Tier 1b)",
  "@types/node": "types only, erased at build",
  "@vitest/coverage-v8": "coverage",
  jscpd: "duplication detection (Tier 1b)",
  tsx: "runs the golden emitter",
  typescript: "the compiler",
  vitest: "the test runner",
};

describe("the package ships nothing", () => {
  it("declares no runtime dependency of any kind", () => {
    expect(manifest.dependencies).toBeUndefined();
    // The three quieter ways a runtime dependency arrives.
    expect(manifest.peerDependencies).toBeUndefined();
    expect(manifest.optionalDependencies).toBeUndefined();
  });

  it("read the manifest it thinks it read", () => {
    // Without this, every assertion above is also true of a file that does not
    // exist, a manifest for another package, and `{}`. "No dependencies" has to
    // be distinguishable from "nothing was read".
    expect(manifest.name).toBe("@akimath/core");
    expect(Object.keys(manifest.devDependencies ?? {}).length).toBeGreaterThan(0);
  });

  it("every development dependency has a stated reason", () => {
    const declared = Object.keys(manifest.devDependencies ?? {}).sort();
    expect(declared).toEqual(Object.keys(DEV_DEPENDENCY_REASONS).sort());
    // eslint-disable-next-line no-console
    console.log(
      `  core dependencies · runtime → 0, development → ${declared.length}`,
    );
  });

  it("the frozen contract is a development dependency and not a runtime one", () => {
    // The single most likely regression in this file, and the one that would
    // quietly reintroduce `zod` into a package whose whole point is having none.
    expect(manifest.devDependencies?.["@akimath/contract"]).toBeDefined();
    expect(manifest.dependencies).toBeUndefined();
  });
});
