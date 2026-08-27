# One way to write a log line

## Why

Eleven `console.*` calls, no shape in common, no level, no timestamp, and nothing stopping the
twelfth from printing a bearer token. That last part is not hypothetical: a database password
reached this repository's own transcript earlier in its history, and the request path now handles
JWTs on every call.

## What changes

- **`src/log.ts` (PURE)** — an event becomes one JSON line, or `null` if the level filters it out.
  Every rule about what a line contains lives here and is tested by comparing two strings.
- **`src/adapters/logger.ts`** — the only file in the package allowed to touch a stream. It owns
  the clock and `process.stdout` and nothing else.
- **Redaction that runs over values, not only field names**, because the message is a free string.
  A JWT, a `Bearer` header and the password inside a connection string are replaced wherever they
  appear — including nested, including inside the message itself.
- **One line per request** in the Hono adapter: method, path, status, duration, and the *kind* of
  caller rather than the caller.
- **A gate**: nothing under `src/` may call `console` or write to a stream except the one named
  file. Standardised by a red build rather than by intention.

## Out of scope

`packages/core`'s three build scripts still use `console.log`, and deliberately. Their output is a
developer watching `npm run emit` — `wrote golden/foo` — not a log; JSON there would be worse for
the only reader it has.

The Flutter client needs nothing: `avoid_print` is already active through `flutter_lints` and
`flutter analyze --fatal-infos` is the enforced gate, so `app/lib` has zero prints **by rule**.
Verified rather than assumed.
