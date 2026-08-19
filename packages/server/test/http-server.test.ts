import { describe, expect, it } from "vitest";

import { createApp } from "../src/adapters/http-server.js";
import { CONTRACTED_OPERATIONS, OPS_ROUTES, route } from "../src/routing.js";

const VERSION = "1.2.3";

/** A request through the whole adapter, without opening a socket. */
async function call(method: string, path: string): Promise<Response> {
  return createApp(VERSION).fetch(
    new Request(`http://localhost${path}`, { method }),
  );
}

describe("the transport returns exactly what the policy decided", () => {
  it("for every route the app has, and for one it does not", async () => {
    // **The whole job of this adapter.** A transport that reshaped a status or
    // a body would put the contract parity gate one layer away from what a
    // client actually receives.
    const paths: readonly { method: string; path: string }[] = [
      ...OPS_ROUTES,
      ...CONTRACTED_OPERATIONS.map((operation) => ({
        method: operation.method,
        path: operation.path.replace("{packId}", "2f1c9b0e"),
      })),
      { method: "GET", path: "/nonsense" },
      { method: "PUT", path: "/me" },
    ];

    expect(paths.length).toBeGreaterThan(1);
    for (const { method, path } of paths) {
      const expected = route(method, path, VERSION);
      const response = await call(method, path);

      expect(response.status, `${method} ${path}`).toBe(expected.status);
      expect(await response.json(), `${method} ${path}`).toEqual(expected.body);
    }
  });

  it("every response is JSON", async () => {
    for (const path of ["/health", "/me", "/nonsense"]) {
      const response = await call("GET", path);
      expect(response.headers.get("content-type")).toContain("application/json");
    }
  });
});

describe("the framework does not route", () => {
  it("a path Hono has never heard of still reaches the policy", async () => {
    // Hono's own router is deliberately unused: the surface lives in
    // `CONTRACTED_OPERATIONS` where the parity gate can read it. If Hono were
    // routing, this would be its 404 rather than ours — and ours carries a
    // `message`, which the frozen `Error` schema requires.
    const response = await call("GET", "/a/path/nobody/registered");

    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({
      error: "not_found",
      message: "There is nothing at that path.",
    });
  });

  it("a method Hono would reject reaches it too", async () => {
    const response = await call("PATCH", "/health");

    expect(response.status).toBe(405);
    expect(await response.json()).toMatchObject({ error: "method_not_allowed" });
  });
});

describe("the version it was given is the version it reports", () => {
  it("health carries it", async () => {
    const response = await call("GET", "/health");

    expect(await response.json()).toMatchObject({ version: VERSION });
  });

  it("a query string is not part of the path", async () => {
    // `route` matches on the path alone; a transport that passed the whole URL
    // would turn every link with a `?utm_source` into a 404.
    const response = await createApp(VERSION).fetch(
      new Request("http://localhost/health?from=somewhere"),
    );

    expect(response.status).toBe(200);
  });
});
