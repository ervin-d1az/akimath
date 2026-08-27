## 1. The decision

- [x] 1.1 Audit `pino`: 14 transitive packages against a floor of zero. Written instead.

## 2. The line

- [x] 2.1 Red → green: one JSON object, `at`/`level`/`msg`, fields at the top level, a field that
      cannot rename the line.
- [x] 2.2 Level filtering, and an unrecognised `LOG_LEVEL` that says so.
- [x] 2.3 Never throws: cycles, `BigInt`, `NaN`, `Error`, and the values `JSON` drops.

## 3. Redaction

- [x] 3.1 By field name, eight needles.
- [x] 3.2 By value shape, at any depth, message included — JWT, `Bearer …`, URL userinfo.
- [x] 3.3 The connection string keeps its host.

## 4. Standardising

- [x] 4.1 `main.ts` and both CLIs converted.
- [x] 4.2 One line per request, carrying the kind of caller and not the caller.
- [x] 4.3 A gate: nothing else under `src/` writes to a stream.

## 5. Evidence

- [x] 5.1 Tier 1 with counts.
- [x] 5.2 Tier 1b: mutation read and acted on — a second dead branch found and deleted.
- [x] 5.3 Tier 2: real lines from the running server, and the level switches exercised.
