import { createServer, type Server } from "node:http";

import { route } from "../routing.js";

/**
 * Environmentally unsuitable boundary: owns the socket. Kept as thin as
 * possible so that nothing worth testing lives here.
 */
export function createHttpServer(version: string): Server {
  return createServer((request, response) => {
    const path = new URL(request.url ?? "/", "http://localhost").pathname;
    const result = route(request.method ?? "GET", path, version);

    response.writeHead(result.status, { "content-type": "application/json" });
    response.end(JSON.stringify(result.body));
  });
}
