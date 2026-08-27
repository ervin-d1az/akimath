# The first endpoint answers

## Why

Everything is in place and nothing is served. The contract names eight operations, the router knows
them, the session verifies, the column that links a player to an account exists — and every request
still ends in 501.

`GET /me` is the smallest one that proves the whole path: verify a token, connect as the restricted
role, read one row, answer the frozen shape. It writes nothing, so it can be wrong without costing
anything.

## What changes

- **A request-path database seam.** `inRequestRole` opens a transaction, `SET LOCAL ROLE
  app_request`, runs the work, commits or rolls back. There is no method that queries without one.
- **The router dispatches.** `route()` now returns *an answer* or *whose handler should produce
  one*, so the surface stays in `routing.ts` where the parity gate reads it.
- **`GET /me`** — pure `profileResponse`, one repository query, and 404 rather than 401 when the
  account has no player.
- **A token whose `sub` is not a uuid is refused at verification**, so it can never reach the
  database as `invalid input syntax for type uuid` — a 500 for a request that deserves a 401.
- The contract drops `501` from `getMe`, in the same diff that implements it, which the parity gate
  now checks in both directions against `IMPLEMENTED_OPERATIONS`.

## Out of scope

The other seven operations. Each is now a handler and one line in a list.
