import { buildHealthReport } from "./health.js";

export interface Response {
  readonly status: number;
  readonly body: unknown;
}

/** One entry in the route table: a method and a path template. */
export interface Route {
  readonly method: string;
  readonly path: string;
}

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
  { method: "POST", path: "/attempts" },
  { method: "GET", path: "/items/next" },
  { method: "DELETE", path: "/me" },
  { method: "GET", path: "/me" },
  { method: "GET", path: "/me/history" },
  { method: "GET", path: "/me/standing" },
  { method: "GET", path: "/packs/{packId}" },
  { method: "POST", path: "/players/link" },
];

/**
 * Routes that are deliberately outside the client-facing contract.
 *
 * **One entry, named.** The parity gate excuses these by name rather than by a
 * prefix or a predicate, so the next route added outside the contract has to be
 * argued for in the diff.
 */
export const OPS_ROUTES: readonly Route[] = [{ method: "GET", path: "/health" }];

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
export function route(method: string, path: string, version: string): Response {
  if (method === "GET" && path === "/health") {
    return { status: 200, body: buildHealthReport("akimath-api", version) };
  }

  const routed = ALL_ROUTES.some(
    (candidate) => candidate.method === method && matchesTemplate(candidate.path, path),
  );
  if (routed) {
    // **Every contracted operation answers 401 until auth exists** (design D2).
    // The contract declares `401 — No valid session` on all of them and there is
    // no session mechanism at all, so this is the true answer rather than a
    // placeholder — and it degrades correctly, because an operation with no
    // body still answers 401 for the old reason once auth lands.
    return error(
      401,
      "unauthenticated",
      "This operation needs a session, and there is no way to open one yet.",
    );
  }

  const pathExists = ALL_ROUTES.some((candidate) => matchesTemplate(candidate.path, path));
  if (pathExists) {
    // Not a 404: a client retrying with the right method needs to be able to
    // tell a wrong method from a wrong path.
    return error(
      405,
      "method_not_allowed",
      `That path exists, but it does not answer ${method}.`,
    );
  }

  return error(404, "not_found", "There is nothing at that path.");
}
