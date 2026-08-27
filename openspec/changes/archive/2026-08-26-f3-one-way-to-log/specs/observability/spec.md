## Purpose

What a log line is, and what it may never contain.

## ADDED Requirements

### Requirement: req-one-line-one-event · Structured, one object per line

A log line SHALL be a single JSON object carrying the time, the level and the message.

#### Scenario: The shape

- **WHEN** an event is formatted
- **THEN** it is one JSON object ending in exactly one newline, with `at`, `level` and `msg`
  → `packages/server/test/log.test.ts`

#### Scenario: A field cannot rename the line

- **WHEN** a caller passes a field called `level`, `msg` or `at`
- **THEN** the line keeps its own — a field that could overwrite them makes the line lie about
  itself
  → `packages/server/test/log.test.ts`

#### Scenario: A message containing a newline

- **WHEN** the message or a field holds a newline
- **THEN** the emitted line still contains exactly one, at the end
  → `packages/server/test/log.test.ts`

### Requirement: req-no-credential-in-a-log · The logger cannot print a secret

Redaction SHALL apply to values as well as to field names.

#### Scenario: By the name of the field

- **WHEN** a field is named for a password, token, key, cookie, credential or authorization header
- **THEN** its value is replaced, whatever it looks like
  → `packages/server/test/log.test.ts`

#### Scenario: By the shape of the value

- **WHEN** a JWT, a `Bearer …` header or a URL carrying a password appears anywhere — the message
  included, nested objects and arrays included
- **THEN** it is replaced; the connection string keeps its host and database, because which server
  was reached is what makes the line worth writing
  → `packages/server/test/log.test.ts`

#### Scenario: A request never logs its credential

- **WHEN** a request arrives carrying a bearer token
- **THEN** the request line names the *kind* of caller and not the caller, and contains no part of
  the token
  → `packages/server/test/http-server.test.ts`

### Requirement: req-never-throw · A logger that throws hides the thing it was logging

Formatting SHALL NOT throw on any value.

#### Scenario: Values JSON refuses

- **WHEN** a field holds a cycle, a `BigInt`, a function, a symbol, `NaN` or an `Error`
- **THEN** a line is still produced — and the `Error` becomes a name and a message rather than `{}`
  → `packages/server/test/log.test.ts`

### Requirement: req-one-writer · Standardised by a red build

No source file except the logger adapter SHALL write to a stream.

#### Scenario: The sweep

- **WHEN** every `.ts` file under `src/` is scanned
- **THEN** none but the one named file calls `console` or `process.stdout`/`process.stderr`, and
  the gate reports how many files it scanned
  → `packages/server/test/one-way-to-log.test.ts`
