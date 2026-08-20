/**
 * `@akimath/core` — the rederivation machine.
 *
 * Re-export only, no logic: the precedent `packages/contract`'s own index sets,
 * and it is what lets `test/public_surface.test.ts` assert the whole public
 * surface in one place.
 *
 * Zero runtime dependencies, enforced by reading the manifest
 * (`test/dependency-allowlist.test.ts`), and no ambient IO, enforced by walking
 * the AST (`test/determinism.test.ts`).
 */
export {
  abs,
  add,
  compare,
  divide,
  equals,
  isInteger,
  multiply,
  negate,
  rationalOf,
  reciprocal,
  signOf,
  subtract,
  type Rational,
} from "./rational.js";

export {
  drawBelow,
  intBetween,
  mix64,
  rejectionLimit,
  wordAt,
  type WordSource,
} from "./prng/splitmix64.js";

export {
  issuable,
  rederive,
  registryOf,
  resolve,
  type TemplateRegistry,
} from "./registry.js";

export { coreRegistry } from "./templates/index.js";

export type {
  GeneratedItem,
  PromptToken,
  Template,
  TemplateRef,
  Term,
} from "./template.js";
