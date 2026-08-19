# The server can tell who is asking

## Why

The contract says every operation needs `Authorization: Bearer <jwt>`. The server has never read
that header. `route()` answered 401 to all eight operations with the message *"there is no way to
open one yet"* — true when it was written, and the thing this change makes false.

## What changes

- **A pure reader** for the `Authorization` header: absent, malformed, or a bearer token. Three
  cases, not two — a client that never linked and a client holding something broken are different
  bugs and one 401 for both makes the second undiagnosable.
- **A verifier** over a JWKS, with the key set injected so the tests exercise the real thing
  against real Ed25519 keys.
- **Pure configuration**: the issuer and the JWKS URL derived from the one URL Neon gives you, with
  a missing or plaintext one refused **at startup** rather than turned into a 401 per request.
- `route()` takes a caller, and an authenticated request to an operation nobody has written answers
  **501**, declared in the contract, per operation, so the list shrinks as endpoints land.

## Out of scope

Any endpoint. This change ends at 501 on purpose: the next one implements `GET /me`, which needs a
request-path database seam that does not exist yet.

## Not delivered

`NEON_AUTH_BASE_URL` is a deployment value shown on the Neon console's **Auth** page, and it is not
derivable from the connection string — probed eight candidate URLs against the project's compute
host and every one reached the SQL-over-HTTP handler instead. The code takes it from the
environment and refuses to start without it; somebody has to paste it in once.
