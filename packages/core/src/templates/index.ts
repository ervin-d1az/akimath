import { registryOf, type TemplateRegistry } from "../registry.js";
import { arithIntegerSubtractV1 } from "./arith-integer-subtract/v1.js";
import { arithIntegerSubtractV2 } from "./arith-integer-subtract/v2.js";

/**
 * Every template version this build ships, in one registry.
 *
 * **Retired versions belong here too.** An issued item can never stop being
 * rederivable, so this is the set the server resolves a recorded reference
 * against; `issuable()` is the narrower question of what may be handed out
 * next, and it is asked separately.
 *
 * It used to live in `golden.ts`, which is about emitting an artifact. A
 * registry production resolves against is not a golden-test detail, and reading
 * it out of that file made it look like one.
 */
export const CORE_REGISTRY: TemplateRegistry = registryOf([
  arithIntegerSubtractV1,
  arithIntegerSubtractV2,
]);

/**
 * The shipped registry, as a call rather than as the constant itself.
 *
 * **`test/public_surface.test.ts` holds every export to being a function**, and
 * the reason is structural: with nothing but functions crossing the boundary
 * there is no object to grow a `toString` on, which is the rule `rational.ts`
 * exists to protect. A `TemplateRegistry` is a `Map` behind an interface and a
 * `Map` carries methods, so it goes out through a call.
 *
 * The value is built once at module load and handed back; callers inside this
 * package use [CORE_REGISTRY] directly.
 */
export function coreRegistry(): TemplateRegistry {
  return CORE_REGISTRY;
}
