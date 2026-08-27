# Hono owns the socket; `route()` still decides

## Why

`packages/server` has no framework: `adapters/http-server.ts` is fifteen lines of `node:http`.
That was right while the only endpoint was `GET /health`, and it stops being right at the first
operation that takes a JSON body or needs a session checked — the second of which is
authentication, and `CLAUDE.md` forbids hand-writing that.

`ARCHITECTURE.md` §5 already names the replacement: *"Hono confirmed (4.13.x)"*.

I held this change back once, on the grounds that a framework with no consumer is exactly what
the dependency rule exists to catch. It has one now: the server runs locally against Neon, an
interactive transaction was proven from this machine, and ADR 0002 puts a Neon Auth session
check on the path of every linked request.

## What changes

- Hono and `@hono/node-server` own the socket.
- **`route()` is untouched.** Hono's own router is deliberately unused: the app's surface lives
  in `CONTRACTED_OPERATIONS`, where `contract-parity.test.ts` holds it to `contract/openapi.json`
  in both directions. Registering routes with Hono would move that surface out of the gate's
  reach.
- A test that the transport returns exactly what the policy decided, for every route the app
  has.

## Out of scope

Any endpoint's behaviour. This changes what listens, not what it says.
