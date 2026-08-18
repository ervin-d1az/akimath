import { describe, expect, it } from "vitest";

import {
  CONTRACTED_OPERATIONS,
  matchesTemplate,
  OPS_ROUTES,
  route,
  type Response,
} from "../src/routing.js";
import { validatesAsError } from "./support/contract.js";

const VERSION = "1.2.3";

const call = (method: string, path: string): Response => route(method, path, VERSION);

describe("health is still health", () => {
  it("reports health for GET /health", () => {
    expect(call("GET", "/health")).toEqual({
      status: 200,
      body: { status: "ok", service: "akimath-api", version: VERSION },
    });
  });
});

describe("a path parameter is part of the path", () => {
  it("a concrete id matches its template", () => {
    // A contract with a path parameter that only ever matched the literal text
    // `{packId}` would route nothing at all.
    expect(call("GET", "/packs/2f1c9b0e-0000-4000-8000-000000000000").status).toBe(401);
  });

  it("a parameter matches one segment, not several", () => {
    expect(call("GET", "/packs/a/b").status).toBe(404);
  });

  it("an empty segment is not a parameter", () => {
    // `/packs/` is a malformed request, not a pack whose id is the empty string.
    expect(call("GET", "/packs/").status).toBe(404);
  });

  it("the literal text of the template is not a special case", () => {
    // It matches because `{packId}` accepts any segment, not because anything
    // recognises the braces.
    expect(call("GET", "/packs/%7BpackId%7D").status).toBe(401);
  });
});

describe("a template segment is a parameter only with both braces", () => {
  it("a well-formed parameter matches any non-empty segment", () => {
    expect(matchesTemplate("/packs/{packId}", "/packs/x")).toBe(true);
  });

  it("a half-written parameter is a literal, not a wildcard", () => {
    // A typo in a template would otherwise open every path under it. Tested
    // here rather than through `route` because the table holds no malformed
    // template — and the rule is what stops one being harmless.
    expect(matchesTemplate("/packs/{packId", "/packs/x")).toBe(false);
    expect(matchesTemplate("/packs/packId}", "/packs/x")).toBe(false);
    expect(matchesTemplate("/packs/{packId", "/packs/{packId")).toBe(true);
  });

  it("a literal segment matches only itself", () => {
    expect(matchesTemplate("/me/history", "/me/standing")).toBe(false);
  });
});

describe("a contracted operation says what is true", () => {
  it("every one of them answers 401", () => {
    // The contract declares `401 — No valid session` on all of them and there
    // is no session mechanism at all, so this is the true answer rather than a
    // placeholder. It also degrades correctly: when auth lands, an operation
    // with no body still answers 401 for the old reason.
    expect(CONTRACTED_OPERATIONS.length).toBeGreaterThan(0);

    for (const operation of CONTRACTED_OPERATIONS) {
      const concrete = operation.path.replace(
        "{packId}",
        "2f1c9b0e-0000-4000-8000-000000000000",
      );
      const response = call(operation.method, concrete);
      expect(response.status, `${operation.method} ${operation.path}`).toBe(401);
    }
  });

  it("is not a 404", () => {
    // `404` is *no such resource*, and `/me` is a resource that exists and is
    // unbuilt. A client cannot act on the two the same way.
    expect(call("GET", "/me").status).not.toBe(404);
  });
});

describe("a wrong method is not a wrong path", () => {
  it("a known path with an unrouted method answers 405", () => {
    expect(call("DELETE", "/health").status).toBe(405);
    expect(call("PUT", "/me").status).toBe(405);
  });

  it("a path the table does not hold answers 404", () => {
    expect(call("GET", "/nonsense").status).toBe(404);
  });

  it("DELETE /me is routed, so it is not the 405 case", () => {
    // The one path carrying two methods. A table that dropped the second would
    // answer 405 here, which is why this is asserted rather than assumed.
    expect(call("DELETE", "/me").status).toBe(401);
  });
});

describe("every error the router emits is on-contract", () => {
  const errors: readonly Response[] = [
    call("GET", "/me"),
    call("GET", "/nonsense"),
    call("DELETE", "/health"),
  ];

  it("covers every error status the router can produce", () => {
    // A sweep asserting a property of an empty list passes by finding nothing.
    expect(new Set(errors.map((r) => r.status))).toEqual(new Set([401, 404, 405]));
  });

  it("every body validates against the frozen Error schema", () => {
    // Today's `{ error: "not_found" }` omits the required `message`, so the one
    // error the server can emit is already off-contract.
    for (const response of errors) {
      expect(validatesAsError(response.body), JSON.stringify(response)).toBe(true);
    }
  });

  it("each error carries the tag a client switches on", () => {
    // The status alone is not the contract's error: a client branches on the
    // tag, so an empty or wrong one is a break even with the right status.
    expect(call("GET", "/me").body).toMatchObject({ error: "unauthenticated" });
    expect(call("DELETE", "/health").body).toMatchObject({
      error: "method_not_allowed",
    });
    expect(call("GET", "/nonsense").body).toMatchObject({ error: "not_found" });
  });

  it("the message is not the tag repeated", () => {
    // A message restating its tag tells a client nothing the tag did not.
    for (const response of errors) {
      const body = response.body as { error: string; message: string };
      expect(body.message.length).toBeGreaterThan(body.error.length);
      expect(body.message).not.toBe(body.error);
      expect(body.message).not.toBe(body.error.replace(/_/g, " "));
    }
  });

  it("a 2xx carries no error body", () => {
    expect(validatesAsError(call("GET", "/health").body)).toBe(false);
  });
});

describe("the ops routes are named, not inferred", () => {
  it("health is the only one", () => {
    // The parity gate excuses these by name. A prefix or a predicate would
    // excuse the next one silently.
    expect(OPS_ROUTES).toEqual([{ method: "GET", path: "/health" }]);
  });
});
