import { serve, type ServerType } from "@hono/node-server";
import { Hono, type Context } from "hono";

import { conflictResponse, linkOutcome, readLinkRequest } from "../link.js";
import { profileResponse } from "../players.js";
import { route, type Response as Answer } from "../routing.js";
import type { Logger } from "./logger.js";
import {
  accountForPlayer,
  findPlayerForAccount,
  insertPlayer,
  playerIdForAccount,
} from "./player-repository.js";
import type { RequestDatabase } from "./request-database.js";
import type { SessionVerifier } from "./session-verifier.js";

/**
 * What each implemented operation does, keyed by the contract's `operationId`.
 *
 * **The router chose the key; this only holds the function.** Keeping the
 * surface in `routing.ts` is what leaves it inside `contract-parity.test.ts`'s
 * reach — the same trade this file already makes by not using Hono's router.
 * `IMPLEMENTED_OPERATIONS` and these keys are held equal by a test, so a
 * handler with no route, or a route promising a handler that is not here,
 * fails rather than 500s.
 */
/**
 * What a handler is given.
 *
 * **The whole request, not just the caller.** `getMe` needs only the account,
 * and `linkPlayer` needs a body and a header the contract marks required — a
 * seam shaped for the first would have to be widened for the second anyway, and
 * widening it later means touching every handler.
 */
export interface HandlerRequest {
  /** The `sub` of a verified token. Never anything the body said. */
  readonly userId: string;
  readonly body: unknown;
  readonly header: (name: string) => string | undefined;
}

export type Handlers = Readonly<
  Record<string, (request: HandlerRequest) => Promise<Answer>>
>;

export function createHandlers(database: RequestDatabase): Handlers {
  return {
    getMe: ({ userId }) =>
      database.inRequestRole(async (client) =>
        profileResponse(await findPlayerForAccount(client, userId)),
      ),

    linkPlayer: async ({ userId, body, header }) => {
      const request = readLinkRequest(body, header("Idempotency-Key"));
      if ("status" in request) {
        return request;
      }

      // **One transaction for both reads and the write.** Two callers linking
      // the same player at once would otherwise both see no row and both try to
      // insert; the loser gets a constraint violation instead of the 409 the
      // contract describes.
      return database.inRequestRole(async (client) => {
        const outcome = linkOutcome({
          request,
          accountId: userId,
          playerForAccount: await playerIdForAccount(client, userId),
          accountForPlayer: await accountForPlayer(client, request.playerId),
        });

        switch (outcome.kind) {
          case "conflict":
            return conflictResponse(outcome.why);
          case "existing":
            // Idempotent by nature: the row it would have written is the row
            // that is already there.
            return profileResponse(await findPlayerForAccount(client, userId));
          case "create":
            return profileResponse(
              await insertPlayer(client, {
                id: request.playerId,
                ageBand: request.ageBand,
                accountId: userId,
              }),
            );
        }
      });
    },
  };
}

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
  readonly handlers: Handlers;
}

export function createApp({ version, verify, log, handlers }: AppOptions): Hono {
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
    const decision = route(context.req.method, path, version, caller);
    const result =
      decision.kind === "answer"
        ? decision.response
        : await run(handlers, decision.operationId, log, {
            userId: decision.userId,
            body: await readJsonBody(context),
            header: (name) => context.req.header(name),
          });

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
      operation: decision.kind === "dispatch" ? decision.operationId : undefined,
      ms: Date.now() - startedAt,
    });

    return context.json(
      result.body as Record<string, unknown>,
      result.status as ContentfulStatus,
    );
  });

  return app;
}

/**
 * Runs a handler, and turns anything it throws into a 500 that says nothing.
 *
 * **The message never reaches the client.** A database error quotes the SQL it
 * failed on, which is a schema description handed to whoever asked. It goes to
 * the log instead, where the redactor has already been over it.
 */
/**
 * The JSON body, or undefined where there is none.
 *
 * Never throws: a malformed body is the handler's to refuse with a 400 that
 * says so, not the transport's to turn into a 500.
 */
async function readJsonBody(context: Context): Promise<unknown> {
  try {
    return await context.req.json();
  } catch {
    return undefined;
  }
}

async function run(
  handlers: Handlers,
  operationId: string,
  log: Logger,
  request: HandlerRequest,
): Promise<Answer> {
  const handler = handlers[operationId];
  if (handler === undefined) {
    // Unreachable while the test holding `IMPLEMENTED_OPERATIONS` to these keys
    // passes. Answered rather than thrown so that if it ever *is* reached, it
    // is one bad endpoint rather than a crashed process.
    log.error("routed to a handler that does not exist", { operation: operationId });
    return { status: 500, body: { error: "internal", message: "That went wrong on our side." } };
  }

  try {
    return await handler(request);
  } catch (cause) {
    log.error("handler failed", { operation: operationId, cause });
    return { status: 500, body: { error: "internal", message: "That went wrong on our side." } };
  }
}

/** Every status `route()` and its handlers can return. Hono types its own set. */
type ContentfulStatus = 200 | 400 | 401 | 404 | 405 | 409 | 500 | 501;

export function startHttpServer(options: AppOptions & { readonly port: number }): ServerType {
  return serve({ fetch: createApp(options).fetch, port: options.port });
}
