# Design

## D1 — Two routers, and only one of them routes

Hono has a router. It is not used for the app's paths.

The surface lives in `CONTRACTED_OPERATIONS`, and `contract-parity.test.ts` compares that list
to the emitted `contract/openapi.json` in both directions, reporting a count. Registering
`app.get("/me", …)` and friends would move the surface into Hono's registry, where the gate
cannot read it — trading a checked contract for a framework's convenience.

So the adapter is one catch-all that hands method and path to `route()`. What Hono is *for* is
everything around that: web-standard `Request`/`Response`, a body parser for the operations that
will take one, and a middleware chain for the session check that arrives with linking.

A reviewer should ask why there are two routers. This is the answer, and it is why the answer is
written here rather than left to be inferred.

## D2 — Why now, having declined once

This change was proposed and withheld: a framework with no consumer is what the dependency rule
exists to catch, and at the time the server had none. Three things have changed. The server runs
locally and reaches Neon over TCP, with an interactive transaction proven from this machine. ADR
0002 puts a session check on every linked request. And the audit came back cleaner than
expected — **two packages, no transitive dependencies at all**.

That last point is the one that made it easy. Had Hono dragged in a tree, the right answer would
still have been to wait.

## D3 — Two defaults dropped

The old adapter read `request.url ?? "/"` and `request.method ?? "GET"`, papering over a
`node:http` type. A request with no method silently became a `GET` of `/health`. Hono's
`Request` has both, so the defaults are gone rather than preserved.
