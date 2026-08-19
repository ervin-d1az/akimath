import { serve, type ServerType } from "@hono/node-server";
import { Hono } from "hono";

import { route } from "../routing.js";
import type { Logger } from "./logger.js";
import type { SessionVerifier } from "./session-verifier.js";

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
 *
 * **The verifier and the logger are injected**, so this file holds no key set,
 * no URL and no stream. The one thing it does with a credential is resolve it
 * before routing: `route()` is synchronous and pure, and verification is
 * neither.
 */
export interface AppOptions {
  readonly version: string;
  readonly verify: SessionVerifier;
  readonly log: Logger;
}

export function createApp({ version, verify, log }: AppOptions): Hono {
  const app = new Hono();

  app.all("*", async (context) => {
    const startedAt = Date.now();
    const path = new URL(context.req.url).pathname;
    // **Resolved for every request, including the ones that will 404.** The
    // alternative is to route first and verify only when the path matched,
    // which makes the answer to "does this path exist" measurably faster for an
    // unauthenticated caller than for an authenticated one. The paths are all
    // published in `contract/openapi.json`, so the leak is small — and so is
    // the cost of not having it, since a verified key set is cached in memory.
    const caller = await verify(context.req.header("Authorization"));
    const result = route(context.req.method, path, version, caller);

    // **One line per request, and `caller` is the kind rather than the who.**
    // A user id in every access line is a per-request record of who was awake;
    // the kind is what makes a 401 spike diagnosable, and it is all that does.
    // The token cannot appear here even by accident — `log.ts` redacts values,
    // not only field names.
    log.info("request", {
      method: context.req.method,
      path,
      status: result.status,
      caller: caller.kind,
      ms: Date.now() - startedAt,
    });

    return context.json(
      result.body as Record<string, unknown>,
      result.status as ContentfulStatus,
    );
  });

  return app;
}

/** Every status `route()` can return. Hono types its own set; this is ours. */
type ContentfulStatus = 200 | 401 | 404 | 405 | 501;

export function startHttpServer(options: AppOptions & { readonly port: number }): ServerType {
  return serve({ fetch: createApp(options).fetch, port: options.port });
}
