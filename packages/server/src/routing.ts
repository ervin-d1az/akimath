import { buildHealthReport } from "./health.js";

export interface Response {
  readonly status: number;
  readonly body: unknown;
}

/**
 * Who is asking, as the adapter resolved it.
 *
 * **Three cases, because a 401 with one meaning cannot be diagnosed.** A client
 * that has never linked and a client holding something it wrongly believes is a
 * session are different bugs; they earn the same status and different tags, and
 * the second carries the reason it was refused.
 *
 * `refused` is deliberately blind to *why* — expired, wrong issuer, bad
 * signature, unreachable key set. That belongs to the verifier; this module's
 * job is to know that verification did not succeed and to pass the sentence on.
 */
export type Caller =
  | { readonly kind: "absent" }
  | { readonly kind: "refused"; readonly why: string }
  | { readonly kind: "session"; readonly userId: string };

/** One entry in the route table: a method, a path template and the contract's id. */
export interface Route {
  readonly method: string;
  readonly path: string;
  readonly operationId: string;
}

/**
 * What the router decided: an answer, or whose handler should produce one.
 *
 * **The router still owns the surface.** Dispatching by `operationId` keeps the
 * decision here — which paths exist, which need a session, which are written —
 * and leaves the adapter holding only the functions. A handler map that decided
 * its own routing would take the surface out of `contract-parity.test.ts`'s
 * reach, which is the same trade this package refused when it declined to use
 * Hono's router.
 */
export type Decision =
  | { readonly kind: "answer"; readonly response: Response }
  | {
      readonly kind: "dispatch";
      readonly operationId: string;
      readonly userId: string;
    };

/**
 * Every operation `contract/openapi.json` describes.
 *
 * **A literal, not a parse of the contract.** Deriving the table at import time
 * would make divergence impossible and would also take the whole surface out of
 * the reach of the quality gates: `routing.ts` is this package's one pure
 * module, and a module that reads a file at import is neither pure nor
 * mutation-testable. So the table is code and a *test* holds it to the
 * contract — the same shape as `canon.golden.json`, two derivations kept equal
 * by a gate that reports a count.
 *
 * `test/contract-parity.test.ts` fails on a mismatch in either direction.
 */
export const CONTRACTED_OPERATIONS: readonly Route[] = [
  { method: "POST", path: "/attempts", operationId: "submitAttempts" },
  { method: "GET", path: "/items/next", operationId: "getNextItem" },
  { method: "DELETE", path: "/me", operationId: "deleteMe" },
  { method: "GET", path: "/me", operationId: "getMe" },
  { method: "GET", path: "/me/history", operationId: "getHistory" },
  { method: "GET", path: "/me/standing", operationId: "getStanding" },
  { method: "GET", path: "/packs/{packId}", operationId: "getOfflinePack" },
  { method: "POST", path: "/players/link", operationId: "linkPlayer" },
];

/**
 * The operations a handler exists for.
 *
 * **This list is the 501 list, inverted, and both are checked.**
 * `contract-parity.test.ts` holds `contract/openapi.json`'s `501` declarations
 * to exactly the operations missing from here, in both directions — so
 * implementing one is also what stops it advertising itself as unbuilt, and
 * neither half can be satisfied by doing nothing.
 */
export const IMPLEMENTED_OPERATIONS: readonly string[] = ["getMe"];

/**
 * Routes that are deliberately outside the client-facing contract.
 *
 * **One entry, named.** The parity gate excuses these by name rather than by a
 * prefix or a predicate, so the next route added outside the contract has to be
 * argued for in the diff.
 */
export const OPS_ROUTES: readonly Route[] = [
  { method: "GET", path: "/health", operationId: "health" },
];

const ALL_ROUTES: readonly Route[] = [...OPS_ROUTES, ...CONTRACTED_OPERATIONS];

/**
 * Whether a concrete path matches a template.
 *
 * **Segment comparison, not a regular expression** (design D4). A pattern built
 * by interpolating the template would have to escape its literal segments, and
 * getting that wrong is a silent routing bug rather than a compile error.
 *
 * A parameter matches exactly one non-empty segment: `/packs/` is a malformed
 * request rather than a pack whose id is the empty string, and `/packs/a/b` is
 * a path the contract never described.
 */
export function matchesTemplate(template: string, path: string): boolean {
  const wanted = template.split("/");
  const given = path.split("/");
  if (wanted.length !== given.length) {
    return false;
  }
  return wanted.every((segment, index) => {
    const actual = given[index] ?? "";
    // **Both braces, or it is a literal.** A half-written `{packId` must match
    // only itself rather than quietly becoming a wildcard — a typo in a
    // template would otherwise open every path under it.
    if (segment.startsWith("{") && segment.endsWith("}")) {
      return actual.length > 0;
    }
    return segment === actual;
  });
}

function error(status: number, tag: string, message: string): Response {
  // Both fields, always: the frozen `Error` schema requires `error` *and*
  // `message`, and the body this replaced carried only the first — so the one
  // error the server could emit was already off-contract.
  return { status, body: { error: tag, message } };
}

/**
 * Pure routing policy: a method + path in, a status + body out.
 *
 * No sockets, no framework, no environment. This is what the quality gates
 * (coverage, mutation, CRAP, DRY) run against.
 */
export function route(
  method: string,
  path: string,
  version: string,
  caller: Caller,
): Decision {
  const answer = (response: Response): Decision => ({ kind: "answer", response });

  if (method === "GET" && path === "/health") {
    // **A probe carries no session and must not need one.** `/health` is the
    // route a load balancer calls; requiring a credential of it would make the
    // server look dead to the thing deciding whether it is.
    return answer({ status: 200, body: buildHealthReport("akimath-api", version) });
  }

  const routed = ALL_ROUTES.find(
    (candidate) => candidate.method === method && matchesTemplate(candidate.path, path),
  );
  if (routed !== undefined) {
    if (caller.kind === "absent") {
      return answer(
        error(
          401,
          "unauthenticated",
          "This operation needs a session. Send one as Authorization: Bearer <token>.",
        ),
      );
    }
    if (caller.kind === "refused") {
      // A different tag from the one above, on purpose: the client is holding
      // something, and "you sent nothing" would send it looking for a bug it
      // does not have.
      return answer(error(401, "invalid_session", caller.why));
    }
    if (IMPLEMENTED_OPERATIONS.includes(routed.operationId)) {
      return { kind: "dispatch", operationId: routed.operationId, userId: caller.userId };
    }
    // **501 once the caller has authenticated.** 401 was the true answer while
    // no session could exist and stops being true the moment one can: refusing
    // a caller who *did* authenticate, with a reason saying they did not, is a
    // lie the client would retry forever. 404 is worse — the path is real and
    // the contract names it. So the status says what is actually the case, and
    // `contract-parity.test.ts` holds the contract's 501 list to exactly the
    // operations that still answer this, so the list shrinks as they land.
    return answer(
      error(
        501,
        "not_implemented",
        "That operation is routed and your session is good; the server has not built it yet.",
      ),
    );
  }

  const pathExists = ALL_ROUTES.some((candidate) => matchesTemplate(candidate.path, path));
  if (pathExists) {
    // Not a 404: a client retrying with the right method needs to be able to
    // tell a wrong method from a wrong path.
    return answer(
      error(405, "method_not_allowed", `That path exists, but it does not answer ${method}.`),
    );
  }

  return answer(error(404, "not_found", "There is nothing at that path."));
}
