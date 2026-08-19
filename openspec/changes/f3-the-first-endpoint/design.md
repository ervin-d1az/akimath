# Design

## D1 — The seam offers one way in

`RequestDatabase` exposes `inRequestRole` and nothing that queries without it. The restriction is
structural rather than a convention someone has to remember: a handler cannot accidentally run as
the owner because it is never handed a client that is.

**`SET LOCAL ROLE`, inside a transaction.** The connection string belongs to a login role that owns
the schema; `app_request` is `NOLOGIN` and exists to be switched into. A bare `SET ROLE` persists on
a pooled connection, so the switch is scoped to a transaction that always ends — and the test that
matters is not "`current_user` is `app_request`" but "the next user of this connection is not",
because the first passes for a seam that only reports a name.

One transaction per unit of work is also what makes a handler that throws half way through safe.

`asOwner` exists solely so that test can be written, and says so in its own doc comment. Nothing
under `src/` calls it.

## D2 — The router decides who answers, not just what to say

`route()` returns a `Decision`: an answer, or an `operationId` and the user id to run it for.

The alternative — a handler map that does its own matching — would move the surface out of
`contract-parity.test.ts`'s reach. That is the same trade this package already refused when it
declined to use Hono's router, and refusing it twice for the same reason is the point.

Two things fell out of it that were worth having on their own:

- **The route table now carries `operationId`**, checked against the committed contract. It was
  compared on method and path alone, so the contract could rename an operation and nothing on the
  server would notice — and ADR 0001's hand-written Dart client keys off exactly those names.
- **`IMPLEMENTED_OPERATIONS` is the 501 list, inverted**, and the parity gate holds the contract's
  declarations to it in both directions. `getMe` drops its `501` in the same diff that implements
  it, because the gate fails otherwise.

## D3 — 404, not 401, for an account with no player

The caller authenticated. There is no player under that account yet, which is the ordinary state of
an adult who has made an account and not linked a device. A 401 would send a client holding a
perfectly good session off to fetch another one, forever.

The body names `POST /players/link`, so the client is told what to do rather than left to infer it.

## D4 — A bad subject is refused before it can be a 500

`players.auth_user_id` is a `uuid` and `neon_auth.user.id` is a `uuid` — read from the catalogue,
not assumed. A verified token whose `sub` is anything else would reach Postgres as
`invalid input syntax for type uuid`: a 500 for a request that deserves a 401, and a stack trace in
the log for a request that was simply not ours.

Checked in `session.ts`, so it is pure, and so the refusal happens before a connection is borrowed.

## D5 — A handler's failure says nothing to the client

A database error quotes the SQL it failed on. That is a schema description handed to whoever asked
for it, so the client gets a fixed 500 body and the log gets the cause — where the redactor has
already been over it.

The "no handler for this operation" branch is unreachable while the parity test passes. It answers
rather than throws anyway: if it is ever reached it should be one bad endpoint, not a crashed
process.

## D6 — A gate that had been passing by luck

`retention.test.ts` asserts the figure `400` appears only in `retention.ts`, and skips itself under
Stryker because the instrumented copy of `src/` is full of numeric mutant ids. It read
`STRYKER_MUTATOR_RUNNER` — **which is not set during the dry run**. So the gate did run against the
instrumented tree, every time, and passed only because no rewritten file happened to contain a bare
`400`.

Adding source files shifted the ids, one landed on 400, and the entire mutation run aborted before
a single mutant on a failure with nothing to do with retention. The guard now asks whether the
files carry Stryker's own marker, which is the fact rather than a proxy for it, and cannot go stale
when an environment variable is renamed.

## D7 — Exercised for real, end to end

Not a fake anywhere in the chain: a JWKS server on loopback with a real Ed25519 key pair, the real
`main.ts`, and a real PostgreSQL 18 with all three migrations applied.

| request | before a player exists | after linking one |
|---|---|---|
| `GET /me`, good token | 404 `no_player` | **200** with the player |
| `GET /me`, no credential | 401 `unauthenticated` | 401 |
| `GET /me/history`, good token | 501 | 501 |
| `GET /health` | 200 | 200 |

The log line for the 200 reads
`{"method":"GET","path":"/me","status":200,"caller":"session","operation":"getMe","ms":3,…}` — the
operation named, the caller's *kind* and not the caller, and no token anywhere.
