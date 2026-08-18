import { describe, expect, it } from "vitest";

import { CONTRACTED_OPERATIONS, OPS_ROUTES, route } from "../src/routing.js";
import { contractedOperations } from "./support/contract.js";

/**
 * The route table against the committed contract, both directions.
 *
 * R2 in its API form: `contract/openapi.json` and `src/routing.ts` are two
 * descriptions of the same surface, and until this gate existed nothing
 * compared them. The server routed one endpoint the contract does not name and
 * none of the eight it does.
 */
const key = (r: { method: string; path: string }): string => `${r.method} ${r.path}`;

describe("the route table matches the contract", () => {
  it("reports what it compared", () => {
    // PROC-10: a gate that found no operations would otherwise pass by finding
    // nothing at all.
    expect(contractedOperations.length).toBeGreaterThan(0);
    console.log(
      `  api parity · ${contractedOperations.length} contracted operations → ` +
        `${CONTRACTED_OPERATIONS.length} routed, ${OPS_ROUTES.length} ops route outside it`,
    );
  });

  it("every contracted operation is routed", () => {
    const routed = new Set(CONTRACTED_OPERATIONS.map(key));
    const missing = contractedOperations.filter((op) => !routed.has(key(op)));

    expect(missing.map((op) => `${key(op)} (${op.operationId})`)).toEqual([]);
  });

  it("every routed operation is contracted, or named as an ops route", () => {
    const contracted = new Set(contractedOperations.map(key));
    const excused = new Set(OPS_ROUTES.map(key));
    const stray = [...CONTRACTED_OPERATIONS, ...OPS_ROUTES].filter(
      (r) => !contracted.has(key(r)) && !excused.has(key(r)),
    );

    expect(stray.map(key)).toEqual([]);
  });

  it("the ops allowlist is a list of routes, not a pattern", () => {
    // A prefix or a predicate would excuse the next route added outside the
    // contract silently, which is the failure this gate exists to prevent.
    expect(OPS_ROUTES.every((r) => !r.path.includes("*") && !r.path.includes("{"))).toBe(
      true,
    );
    expect(OPS_ROUTES).toHaveLength(1);
  });
});

describe("the status the router returns is one the contract declares", () => {
  it("401 is declared on every contracted operation", () => {
    // The router answers 401 for all of them, so if any operation did not
    // declare it the server would be emitting an undocumented status.
    for (const operation of contractedOperations) {
      expect(operation.statuses, key(operation)).toContain("401");
    }
  });

  it("405 is declared, because the router can return it", () => {
    for (const operation of contractedOperations) {
      expect(operation.statuses, key(operation)).toContain("405");
    }
  });

  it("every status the router actually emits is declared somewhere", () => {
    // Generated rather than listed: a status added to `route()` and forgotten
    // here would be caught, which a hand-kept list would not do.
    const declared = new Set(contractedOperations.flatMap((op) => op.statuses));
    const emitted = new Set(
      [
        ...contractedOperations.map((op) =>
          route(op.method, op.path.replace("{packId}", "abc"), "1.0.0"),
        ),
        route("GET", "/nonsense", "1.0.0"),
        route("PUT", "/me", "1.0.0"),
      ]
        .map((r) => r.status)
        .filter((status) => status >= 400),
    );

    expect(emitted.size).toBeGreaterThan(0);
    for (const status of emitted) {
      expect(declared, `the router returns ${status}`).toContain(String(status));
    }
  });
});
