import { describe, expect, it } from "vitest";

import {
  type Caller,
  CONTRACTED_OPERATIONS,
  IMPLEMENTED_OPERATIONS,
  OPS_ROUTES,
  route,
} from "../src/routing.js";
import {
  contractedOperations,
  requiresSession,
  securitySchemeNames,
} from "./support/contract.js";

/**
 * The route table against the committed contract, both directions.
 *
 * R2 in its API form: `contract/openapi.json` and `src/routing.ts` are two
 * descriptions of the same surface, and until this gate existed nothing
 * compared them. The server routed one endpoint the contract does not name and
 * none of the eight it does.
 */
const key = (r: { method: string; path: string }): string => `${r.method} ${r.path}`;

/** A template cannot be requested; any non-empty segment matches. */
const concrete = (path: string): string => path.replace(/\{[^}]+\}/g, "any-id");

const NOBODY: Caller = { kind: "absent" };
const LINKED: Caller = { kind: "session", userId: "3f1a2b4c-0000-7000-8000-00000000abcd" };

/**
 * Every status `route()` can produce for an operation, over every caller.
 *
 * A dispatch has no status of its own — the handler decides — so it is left
 * out. That is why the 501 gate below reads `IMPLEMENTED_OPERATIONS` rather
 * than inferring "answers 501" from this set: an implemented operation
 * contributes nothing here for the authenticated caller, and "no status" and
 * "not 501" are not the same claim.
 */
const statusesFor = (op: { method: string; path: string }): ReadonlySet<number> => {
  const statuses = new Set<number>();
  for (const caller of [NOBODY, { kind: "refused", why: "x" } as Caller, LINKED]) {
    const decision = route(op.method, concrete(op.path), "1.0.0", caller);
    if (decision.kind === "answer") {
      statuses.add(decision.response.status);
    }
  }
  return statuses;
};

/** The status of a decision that is known to be an answer. */
const statusOf = (
  method: string,
  path: string,
  caller: Caller = NOBODY,
): number => {
  const decision = route(method, path, "1.0.0", caller);
  if (decision.kind !== "answer") {
    throw new Error(`${method} ${path} dispatched to ${decision.operationId}`);
  }
  return decision.response.status;
};

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
        ...contractedOperations.flatMap((op) => [...statusesFor(op)]),
        statusOf("GET", "/nonsense"),
        statusOf("PUT", "/me"),
      ].filter((status) => status >= 400),
    );

    expect(emitted.size).toBeGreaterThan(0);
    for (const status of emitted) {
      expect(declared, `the router returns ${status}`).toContain(String(status));
    }
  });
});

describe("what the contract secures is what the router refuses", () => {
  it("reports what it compared", () => {
    const secured = contractedOperations.filter((op) => requiresSession(op.method, op.path));
    expect(secured.length).toBeGreaterThan(0);
    console.log(
      `  api security · ${securitySchemeNames.length} scheme(s) → ` +
        `${secured.length} of ${contractedOperations.length} operations secured, ` +
        `${OPS_ROUTES.length} ops route outside the contract`,
    );
  });

  it("every operation the contract secures is refused without a credential", () => {
    // **The two artifacts have to agree about who may knock.** The contract says
    // a session is required and the router is what enforces it; today it refuses
    // all eight because no session mechanism exists, and when one lands this
    // gate is what stops an operation going public by omission.
    const open = contractedOperations
      .filter((op) => requiresSession(op.method, op.path))
      .filter((op) => statusOf(op.method, concrete(op.path)) !== 401);

    expect(open.map((op) => `${op.method} ${op.path} (${op.operationId})`)).toEqual([]);
  });

  it("the route outside the contract is not secured by it, and answers", () => {
    // The control. "Everything is 401" would satisfy the test above and would be
    // a server nobody can reach — and `/health` is the one route that must
    // answer an unauthenticated caller, because a probe carries no session.
    for (const ops of OPS_ROUTES) {
      expect(document_describes(ops.path)).toBe(false);
      expect(statusOf(ops.method, ops.path, NOBODY)).toBe(200);
      expect(statusOf(ops.method, ops.path, LINKED)).toBe(200);
    }
  });

  function document_describes(path: string): boolean {
    return contractedOperations.some((op) => op.path === path);
  }
});

describe("what the router answers is what the operation declares", () => {
  it("every status an operation can answer is declared on that operation", () => {
    // **Per operation, not merely somewhere in the document.** The older gate
    // above pools every declared status and asks whether the router's are among
    // them, which a document declaring 501 on one operation would satisfy for
    // all eight. This asks each operation the question separately.
    const undeclared = contractedOperations.flatMap((op) =>
      [...statusesFor(op)]
        .filter((status) => !op.statuses.includes(String(status)))
        .map((status) => `${key(op)} answers ${status} and does not declare it`),
    );
    expect(undeclared).toEqual([]);
  });

  it("and 501 is declared by exactly the operations that are not built", () => {
    // **Both directions, so the list prunes itself.** 501 means "not built yet";
    // an operation that has been built and still advertises it is telling
    // clients to expect a status it can no longer return, and one that is
    // *not* built and does not advertise it is worse. Neither half can be
    // satisfied by doing nothing.
    const unbuilt = contractedOperations
      .filter((op) => !IMPLEMENTED_OPERATIONS.includes(op.operationId))
      .map(key);
    const declares = contractedOperations
      .filter((op) => op.statuses.includes("501"))
      .map(key);

    expect(declares.sort()).toEqual(unbuilt.sort());
    console.log(
      `  api readiness · ${contractedOperations.length} operations → ` +
        `${IMPLEMENTED_OPERATIONS.length} built, ${unbuilt.length} still answer 501`,
    );
  });

  it("an implemented operation dispatches instead of answering", () => {
    // The control for the gate above, which reads a list. This checks the list
    // is describing the router rather than a wish: every id in it really does
    // reach a handler, and no other operation does.
    const dispatched = contractedOperations.filter((op) => {
      const decision = route(op.method, concrete(op.path), "1.0.0", LINKED);
      return decision.kind === "dispatch" && decision.operationId === op.operationId;
    });

    expect(dispatched.map((op) => op.operationId).sort()).toEqual(
      [...IMPLEMENTED_OPERATIONS].sort(),
    );
  });

  it("every operation id in the route table is the contract's own", () => {
    // Until the table carried ids it was compared on method and path alone, so
    // the contract could rename an operation and nothing here would notice —
    // and the hand-written Dart client keys off exactly those names (ADR 0001).
    const contracted = new Map(contractedOperations.map((op) => [key(op), op.operationId]));
    const wrong = CONTRACTED_OPERATIONS.filter(
      (route_) => contracted.get(key(route_)) !== route_.operationId,
    );

    expect(
      wrong.map((r) => `${key(r)} is ${r.operationId}, the contract says ${contracted.get(key(r))}`),
    ).toEqual([]);
  });
});
