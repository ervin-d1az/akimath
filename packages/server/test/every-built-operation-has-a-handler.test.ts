import { describe, expect, it } from "vitest";

import { createHandlers } from "../src/adapters/http-server.js";
import { IMPLEMENTED_OPERATIONS } from "../src/routing.js";
import type { RequestDatabase } from "../src/adapters/request-database.js";

/**
 * `IMPLEMENTED_OPERATIONS` against the handlers that are supposed to exist.
 *
 * **The gate `http-server.ts` already claimed.** Its `run()` says the missing-
 * handler branch is "unreachable while the test holding `IMPLEMENTED_OPERATIONS`
 * to these keys passes" — and no such test existed, so the branch was reachable
 * and the comment was a CMT-2 defect. Written now, in the diff that adds the
 * eighth operation, because this is precisely the pairing that change relies on:
 * `route()` dispatches on the list, and a name in the list with nothing behind
 * it is a 500 that only production would find.
 *
 * **Both directions.** A handler with no route never runs and is dead code
 * pretending to be an endpoint; a route with no handler is the 500. Neither
 * half can be satisfied by doing nothing.
 *
 * The database is never touched: `createHandlers` only closes over it, and
 * building the map is what is under test.
 */
const NEVER_CONNECTED = {
  inRequestRole: () => Promise.reject(new Error("the handler map must not query")),
  inErasureRole: () => Promise.reject(new Error("the handler map must not query")),
  asOwner: () => Promise.reject(new Error("the handler map must not query")),
  close: () => Promise.resolve(),
} as unknown as RequestDatabase;

describe("every operation the router calls built has a handler", () => {
  const handlers = createHandlers(NEVER_CONNECTED);

  it("reports what it compared", () => {
    // PROC-10: an empty list on either side would make the two assertions below
    // pass by comparing nothing.
    expect(IMPLEMENTED_OPERATIONS.length).toBeGreaterThan(0);
    expect(Object.keys(handlers).length).toBeGreaterThan(0);
    console.log(
      `  handler parity · ${IMPLEMENTED_OPERATIONS.length} built operation(s) → ` +
        `${Object.keys(handlers).length} handler(s)`,
    );
  });

  it("the two lists are the same list", () => {
    expect(Object.keys(handlers).sort()).toEqual([...IMPLEMENTED_OPERATIONS].sort());
  });

  it("and every one of them is callable", () => {
    // The control for the comparison above, which only reads key names: a key
    // whose value is not a function would satisfy it and still 500.
    for (const operationId of IMPLEMENTED_OPERATIONS) {
      expect(typeof handlers[operationId], operationId).toBe("function");
    }
  });
});
