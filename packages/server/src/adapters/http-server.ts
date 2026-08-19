import { serve, type ServerType } from "@hono/node-server";
import { Hono } from "hono";

import { route } from "../routing.js";

/**
 * The boundary that owns the socket.
 *
 * **Hono transports; `route()` decides.** Hono has a router of its own and it
 * is deliberately not used for the app's paths — the surface lives in
 * `CONTRACTED_OPERATIONS`, where `contract-parity.test.ts` holds it to
 * `contract/openapi.json` in both directions. Registering the routes with Hono
 * instead would move that surface somewhere the gate cannot read, and trade a
 * checked contract for a framework's convenience.
 *
 * So this is one catch-all handler that hands method and path to the pure
 * policy and returns what it says. What Hono is *for* is everything around
 * that: web-standard `Request`/`Response`, a JSON body parser for the
 * operations that will take one, and a middleware chain for the session check
 * that arrives with linking — none of which `node:http` gives without being
 * hand-written, and one of which is authentication, which `CLAUDE.md` forbids
 * hand-writing.
 *
 * It also drops two defaults the old adapter needed. `request.url ?? "/"` and
 * `request.method ?? "GET"` were papering over a `node:http` type, and a
 * request with no method silently became a `GET` of `/health`.
 */
export function createApp(version: string): Hono {
  const app = new Hono();

  app.all("*", (context) => {
    const path = new URL(context.req.url).pathname;
    const result = route(context.req.method, path, version);

    return context.json(
      result.body as Record<string, unknown>,
      result.status as ContentfulStatus,
    );
  });

  return app;
}

/** Every status `route()` can return. Hono types its own set; this is ours. */
type ContentfulStatus = 200 | 401 | 404 | 405;

export function startHttpServer(version: string, port: number): ServerType {
  return serve({ fetch: createApp(version).fetch, port });
}
