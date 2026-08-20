import { describe, expect, it } from "vitest";

import * as core from "../src/index.js";

/**
 * What `@akimath/core` exposes, exactly.
 *
 * **Set equality, not a pile of `typeof` checks.** The sibling package's
 * surface test asserts five things about five named exports, so a sixth export
 * ships uncovered and nobody finds out. This one fails when the surface changes
 * in either direction, which is the only form that makes adding to it a
 * decision.
 *
 * The rule it exists to hold is in `rational.ts`: nothing here may render a
 * value as text. `packages/contract` already decides what `5/4` means, its rule
 * is golden-tested from TypeScript and from Dart, and a second implementation
 * is how the two silently disagree (risk R2). A reducing renderer would make
 * `4/8` and `6/4` — both in the shipped starter pack — ungradeable.
 */
const PUBLIC_SURFACE = [
  // Rationals.
  "abs",
  "add",
  "compare",
  "divide",
  "equals",
  "isInteger",
  "multiply",
  "negate",
  "rationalOf",
  "reciprocal",
  "signOf",
  "subtract",
  // The PRNG.
  "drawBelow",
  "intBetween",
  "mix64",
  "rejectionLimit",
  "wordAt",
  // The rederivation machine, and the versions this build ships. The server
  // grades an attempt by resolving the recorded reference and regenerating the
  // item, so these are the surface it consumes. `coreRegistry()` is a call and
  // not the constant, because every export here is a function — a registry is a
  // `Map` behind an interface, and a `Map` carries methods. It holds retired
  // versions too: an issued item can never stop being rederivable.
  "issuable",
  "rederive",
  "registryOf",
  "resolve",
  "coreRegistry",
  // How a reference is written into `offline_packs.template_refs` and read
  // back. Both ends are here because two packages have to agree about it and
  // neither owned it — the reader matched a comment rather than a producer.
  "toManifestEntry",
  "fromManifestEntry",
  // The diagnosis copy, as a value. `packages/server` issues packs inside a
  // request and needs the same words the build script uses; a file read in a
  // request path is ambient IO in the one package that forbids it.
  "misconceptionCopy",
  "fallbackDiagnosis",
].sort();

/** Anything that turns a value into text belongs in the contract, not here. */
const RENDERING = /render|format|canonical|stringify|toString|print|display/i;

describe("the public surface is what it says it is", () => {
  const exported = Object.keys(core).sort();

  it("exports exactly the declared surface", () => {
    expect(exported).toEqual(PUBLIC_SURFACE);
  });

  it("exported something, so the comparison means something", () => {
    // PROC-11: `[] === []` passes for a module that failed to load.
    expect(exported.length).toBeGreaterThan(0);
    // eslint-disable-next-line no-console
    console.log(`  core public surface · ${exported.length} exports`);
  });

  it("exposes nothing that renders a value as text", () => {
    const renderers = exported.filter((name) => RENDERING.test(name));
    expect(
      renderers,
      "core must not render an answer; that rule lives in packages/contract",
    ).toEqual([]);
  });

  it("the rendering check would catch one", () => {
    // The control. Without it, the assertion above passes for a regex that
    // matches nothing — including a mistyped one.
    expect(RENDERING.test("renderCanonicalAnswer")).toBe(true);
    expect(RENDERING.test("rationalToString")).toBe(true);
    expect(RENDERING.test("formatFraction")).toBe(true);
    // And does not fire on the surface's real names.
    expect(RENDERING.test("rationalOf")).toBe(false);
    expect(RENDERING.test("compare")).toBe(false);
  });

  it("no export is a class or carries methods", () => {
    // A method-free interface is the structural half of the rule: with no
    // `Rational` class there is no `toString` to add without noticing.
    for (const [name, value] of Object.entries(core)) {
      expect(typeof value, `${name} should be a function`).toBe("function");
      expect(
        value.prototype === undefined || Object.getOwnPropertyNames(value.prototype).length <= 1,
        `${name} carries a prototype with methods`,
      ).toBe(true);
    }
  });
});
