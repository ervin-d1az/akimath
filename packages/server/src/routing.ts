import { buildHealthReport } from "./health.js";

export interface Response {
  readonly status: number;
  readonly body: unknown;
}

const NOT_FOUND: Response = { status: 404, body: { error: "not_found" } };

/**
 * Pure routing policy: a method + path in, a status + body out.
 * No sockets, no framework, no environment. This is what the quality
 * gates (coverage, mutation, CRAP, DRY) run against.
 */
export function route(method: string, path: string, version: string): Response {
  if (method === "GET" && path === "/health") {
    return { status: 200, body: buildHealthReport("ambysmath-api", version) };
  }
  return NOT_FOUND;
}
