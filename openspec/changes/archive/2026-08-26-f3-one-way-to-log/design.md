# Design

## D1 — Written, not installed, and the numbers say why

`pino` is the obvious answer and it was audited properly before being turned down.

```
$ npm install --package-lock-only pino
packages added: 14
@pinojs/redact, atomic-sleep, on-exit-leak-free, pino, pino-abstract-transport,
pino-std-serializers, process-warning, quick-format-unescaped, real-require,
safe-stable-stringify, sonic-boom, split2, thread-stream, …
```

**Fourteen packages.** That is the same number ADR 0001 rejected `swagger_dart_code_generator`
over — *"14 net-new runtime packages against a floor of zero"* — and the floor here is genuinely
zero: `hono`, `@hono/node-server` and `jose` each brought nothing transitive, which is the standard
this repository has set for itself three times running.

Against that, what pino buys at this scale is throughput this server will not reach for years, and
a transport system it has no use for. What it does not buy is the thing that actually matters here:
a redactor that catches a token nobody remembered to name. Pino's redaction is path-based —
`redact: ['req.headers.authorization']` — so it protects the fields you thought of.

So: about 160 lines, pure, with one adapter. If a second long-running process appears, this moves
to a workspace package; today `packages/server` is the only thing that logs.

## D2 — Redaction over values, because the message is a free string

Two layers.

**By field name**, a lower-cased substring match over eight needles, so `apiToken`, `SECRET_KEY`
and `connectionString` are all caught without a list of spellings. `session` is deliberately absent:
`sessionToken` is caught by `token`, and the bare word would redact `sessionCount` for nothing.

**By value shape**, over every string emitted — including `msg`. This is the layer that matters,
because a field name is something you remember and a message is something you type. A JWT, a
`Bearer …` header and the `user:password@` of any URL are replaced wherever they appear, at any
depth.

A database password reached this repository's own transcript earlier in its history. That is the
whole argument.

The connection-string case keeps the host and the database. A redactor that blanks the entire value
teaches people to log around it, and *which server was reached* is usually the reason the line was
written.

## D3 — Never throw

This runs on the request path, so a logger that throws turns a logged 404 into an unlogged 500.
Cycles become `[circular]`, `BigInt` becomes a string, `NaN` and `Infinity` become their names, an
`Error` becomes `{name, message}` — `JSON.stringify(new Error("boom"))` is `{}`, the least useful
line a logger can emit.

The tests assert **what came out**, not that nothing was thrown: a formatter that dropped every
field would also not throw, and that is the failure worth catching in a logger.

## D4 — One line per request, the kind of caller and not the caller

`method`, `path`, `status`, `ms`, `caller`. The caller is `absent` / `refused` / `session` — never
the user id. A user id on every access line is a per-request record of who was awake; the *kind* is
what makes a 401 spike diagnosable, and it is all that does.

The duration made the JWKS cache visible on the first run: `ms: 16` on the first verified request,
`ms: 0` on the ones after.

## D5 — Standardised by a red build

`test/one-way-to-log.test.ts` scans every `.ts` under `src/` and fails on `console.*` or a direct
`process.stdout` / `process.stderr` write outside the one named file. Two prohibitions because they
fail differently: `console` is the habit, and `process.stdout.write` is what somebody reaches for
after being told not to use `console`.

The allowed file is **named**, not matched by directory. "Anything under `adapters/`" would excuse
the next file that quietly starts printing, which is the failure this gate exists to prevent.

## D6 — What mutation testing changed, again

`log.ts` came in at **71.65**. Almost every survivor pointed at the same weakness: the tests said
*it did not throw* and *the secret is not in there*, and both are true of a formatter that emits
nothing. Rewritten as exact-value assertions — the whole redacted string, the whole field map — and
the score went to 89.76.

The remaining twelve were one finding: a guard for `function`, `symbol` and `undefined` whose ten
mutants **all** survived, because the `typeof value !== "object"` line below already covers all
three. Dead code, deleted, and the line below went from unreachable to covered. `log.ts` is now
**99.12**, its one survivor an equivalent mutant (`\w+` → `\w` in the URL scheme, which produces a
byte-identical result because the replacement re-emits the captured prefix).

Package: **98.58**, up from 98.32 before this change.

## Out of scope, and why

`packages/core`'s three build scripts keep `console.log`. Their output is a developer watching
`npm run emit` print `wrote golden/foo`; JSON would be worse for the only reader they have. They
are excluded by living in another package rather than by an exception in the gate.

The Flutter client needs nothing, and this was checked rather than assumed: `avoid_print` is active
through `flutter_lints`, `flutter analyze --fatal-infos` is the enforced gate, and `app/lib`
contains zero `print`, `debugPrint` or `developer.log` calls today.
