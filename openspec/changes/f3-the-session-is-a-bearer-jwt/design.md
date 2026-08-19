# Design

## D1 — A bearer JWT, because that is what the provider issues

Read off Neon's own documentation rather than chosen from taste. Neon Auth's access token is a
**JWT signed with EdDSA (Ed25519)**, it **expires in 15 minutes**, its issuer is the origin of the
Neon Auth URL, its `sub` is the user id, and it is verified against a **JWKS endpoint** at
`/.well-known/jwks.json`. Neon's own backend example attaches it as `Authorization: Bearer <jwt>`.

The database agrees: `neon_auth` carries a `jwks` table — read from the catalogue, never its rows —
which is the JWT plugin's, and a `session` table whose `token` column is the opaque cookie-side
credential.

That leaves two possible credentials and the choice matters:

- **The opaque session token**, verified by asking the provider or by reading `neon_auth.session`.
  Rejected. The first is a network round trip on every request; the second couples us to the
  internal schema of a managed service that owns and migrates it.
- **The JWT**, verified locally against JWKS. Chosen. One fetch per key rotation, no coupling, and
  the short expiry is the provider's problem rather than ours.

**Not a cookie**, which is Better Auth's default. A cookie is a browser mechanism — it needs an
origin and rides along on requests nobody wrote — and the client is a Flutter app with no browser
under it. A header is what a mobile client can attach and drop deliberately.

## D2 — At the root, not per operation

OpenAPI lets a requirement be declared once and overridden per operation. Repeating it eight times
buys nothing and costs the ninth, where somebody forgets the line and ships an open endpoint. So it
is declared once, and a test asserts that **no operation overrides it** — an unauthenticated
operation has to be written deliberately, in a diff a reviewer can see.

`/health` is not an exception here. It is not in this document at all: it is an ops route, excused
by name in `OPS_ROUTES`, and the parity gate has always reported it as *"1 ops route outside it"*.

## D3 — The gate is between two artifacts, again

The contract says a session is required; `route()` is what would enforce it. Nothing connected the
two. So `contract-parity.test.ts` now routes every secured operation and asserts a 401, and routes
the ops route and asserts a 200. Today all eight are 401 for the old reason — there is no session
mechanism — and the gate is still worth having, because it is what stops an operation going public
by omission the day one exists.

The control matters as much as the assertion: "everything is 401" would satisfy the first half and
would be a server nobody can reach.

## D4 — This one is not breaking, and the tool says so

Checked against the pinned `oasdiff 1.29.1` rather than guessed: `api-global-security-added` and
`api-security-component-added`, both **info**, `--fail-on ERR` exits 0. So no
`allow-breaking-contract` label. One could argue a client built against the old document is broken
by this — but that client would have been refused by the server anyway, which has answered 401 to
all eight operations since the router landed. The document is catching up to the server, not
moving ahead of it.
