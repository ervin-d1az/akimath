# Design

## D1 — Two halves, and the seam is where the network is

`readCredential` is pure and exhaustive: it decides whether the caller *offered* a credential.
`createSessionVerifier` holds a key set and can reach the network: it decides whether the
credential is *good*. Keeping them apart is what lets the first be tested to exhaustion with no
mock and the second be tested against real Ed25519 keys with no server.

**The key set is a parameter, not a URL.** `createRemoteJWKSet` and `createLocalJWKSet` both return
a `JWTVerifyGetKey`, so the tests run the production function with the source swapped — real
signature check, real expiry check, real algorithm pinning, only the HTTP fetch absent. A verifier
that took a URL could only ever be tested against a fake of itself.

## D2 — Three cases, not two

A 401 that means both "you never linked" and "what you sent is broken" is a 401 nobody can act on.
So `Caller` has three shapes and the two refusals carry different tags — `unauthenticated` and
`invalid_session` — with the second carrying the reason it was given.

**Refusals never quote the token**, and that is a test rather than a habit: these strings are
logged and returned, and a token in one of them is a live credential in a log file.

## D3 — 501, because 401 would be a lie

`route()` answered 401 to all eight operations with *"there is no way to open one yet"*. True when
written; false the moment a session can exist. Refusing a caller who **did** authenticate, with a
reason saying they did not, is a lie the client retries forever. 404 is worse: the path is real and
the contract names it.

So an authenticated request to an unwritten operation answers **501**, declared per operation in
`contract/openapi.json` — spread separately from the four permanent errors, because this one is
temporary. `contract-parity.test.ts` holds the declarations to exactly the operations the router
still answers 501 for, **in both directions**, so the diff that implements an endpoint is also the
diff that stops it advertising itself as missing. Neither half can be satisfied by doing nothing.

oasdiff's verdict on the addition: eight `response-non-success-status-added`, all **info**. Not
breaking, so no label.

## D4 — Refuse to start, rather than refuse every request

A server with no key set answers 401 to everything, and an operator reads that as "authentication
is broken" rather than "I forgot a variable". `readAuthConfig` is pure and returns a **problem**;
`main.ts` is the one line that prints it and exits 1.

Two facts come out of one variable, because two that can disagree eventually will. The issuer is
the base URL's **origin** — Neon's own troubleshooting note is explicit that a Neon Auth URL of
`https://ep-xx.aws.neon.tech/neondb/auth` issues tokens whose `iss` is `https://ep-xx.aws.neon.tech`,
and getting it wrong rejects every valid token with an error that blames the token. The JWKS URL is
`/.well-known/jwks.json` beneath the base, unless `NEON_AUTH_JWKS_URL` was set, which wins because
Neon injects it into its own runtimes and an authoritative value must beat a derivation.

Plaintext is refused off loopback. A bearer token travels in a header; over `http` it is not a
secret. All three loopback spellings are allowed, because a developer told to use https for
`127.0.0.1` would reasonably conclude the check is broken.

## D5 — What mutation testing changed

The first green version scored **90.80**, down from 98.59, and the report was worth reading rather
than rounding off:

- **A dead branch.** `session.ts` had a "scheme present, token empty" case, reported as covered by
  no test. It is unreachable: the header is trimmed first, so it never ends in whitespace, so
  whatever follows the first space contains a non-space — `Bearer ` arrives as `Bearer` and is
  refused two checks earlier. Deleted, and the reason written where the branch was.
- **Three refusals, one assertion.** Every malformed test asserted `kind === "malformed"`, which is
  true of all of them, so mutants that swapped one reason for another survived. Now each asserts
  its own wording, plus one that asserts the three reasons are three distinct strings — the failure
  that no single-case test can see.
- **Tags nobody checked.** `"invalid_session"` and `"not_implemented"` could both be mutated to `""`
  and pass, because the tests compared them to each other rather than to anything.
- **Untested edges in the config**: `127.0.0.1`, `[::1]`, a doubled trailing slash, and whitespace
  around either variable.

After: `session.ts` **100.00** (41 mutants), `auth-config.ts` **100.00** (42), `routing.ts` **99.07**
with no survivors, package **98.32**. The remaining `routing.ts` gap is a pre-existing uncovered
`??` in `matchesTemplate`, and `migrate.ts`'s three survivors are string concatenation in error
messages, both older than this change.

## D6 — Exercised end to end, over a real socket

The one thing the unit tests replace is `createRemoteJWKSet`'s HTTP fetch, so it was run for real: a
throwaway JWKS server on loopback, an Ed25519 key pair, and the actual `main.ts` pointed at it.

| request | answer |
|---|---|
| `GET /health`, no credential | 200 |
| `GET /me`, no credential | 401 `unauthenticated` |
| `GET /me`, `Basic …` | 401 `invalid_session` — "accepts one scheme" |
| `GET /me`, `Bearer not.a.jwt` | 401 `invalid_session` — "JWS Protected Header is invalid" |
| `GET /me`, expired token | 401 `invalid_session` — `"exp" claim timestamp check failed` |
| `GET /me`, good token | 501 `not_implemented` |
| `PATCH /me`, good token | 405 |
| `GET /nope`, good token | 404 |

And the caching claim was measured rather than asserted: **two JWKS fetches in total, then ten
consecutive verified requests adding none.** Startup refusal was exercised too — no
`NEON_AUTH_BASE_URL` and a plaintext one both exit 1 with the variable named.
