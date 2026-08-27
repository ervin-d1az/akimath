## Why

**Phase F1** (`ARCHITECTURE.md` §9). `contract/openapi.json` is named in `CLAUDE.md`'s layout block
and does not exist. Until it does, three things are blocked or unguarded:

- **The Dart client has nothing to be written against.** ADR 0001 decided it is hand-written, which
  makes the committed spec the *only* thing keeping it honest — there is no generator whose output a
  diff could check. `app/lib/api/` is F3 and needs this first.
- **The `contract` CI job is half a job.** It emits and byte-diffs, and `CLAUDE.md` records that its
  `oasdiff` breaking-change half "waits on `f1-contract-emitter`". A spec nobody diffs against its
  predecessor is a spec that can break a shipped client silently.
- **`packages/contract` exists so the spec can be emitted without booting Hono or touching
  `DATABASE_URL`** (`ARCHITECTURE.md` §2). That separation only pays once something is emitted.

There is also a correction to make while here. `ARCHITECTURE.md`:202 still types the item response as
`{itemId, prompt, keypad, options?}`, and `options` contradicts §4's own resolution. It comes out.

## What Changes

- **`contract/openapi.json`, emitted and committed** — the same generate-locally-verify-in-CI
  discipline `contract/` already runs on its schemas and fixtures.
- **OpenAPI 3.0.3, not 3.1**, and that is the hard part. Zod 4's `z.toJSONSchema()` targets
  JSON Schema 2020-12 or draft-7; neither *is* 3.0.3, which uses its own extended subset. A
  down-conversion pass is the substance of this change, and it is **pure**, so it is tested without
  emitting anything.
- **Zero response polymorphism**: no `oneOf`, no `discriminator`, no `anyOf` in any response.
  Variance lives inside an opaque `payload` object, exactly as the frozen pack format already does
  for stimulus payloads. A test asserts the emitted document contains none of those keywords.
- **The request/response types for the endpoints the documents already name** — the three the ADR
  spike measured (`GET /v1/items/next`, `POST /v1/attempts`, `GET /v1/packs/{packId}`) plus
  `GET /v1/me`, `GET /v1/me/history`, `GET /v1/me/standing`, `DELETE /v1/me` and
  `POST /v1/players/link`.
- **The `oasdiff` half of the `contract` job**, which is what makes a breaking change to a shipped
  contract a red build rather than a discovery.
- **No new runtime dependency.** Zod is already the package's only one and emits the JSON Schema;
  the down-converter is ours. `oasdiff` is a CI binary, not an npm package.

**BREAKING**: none. No client consumes this yet — which is precisely why now is the cheap moment.

## Capabilities

### New Capabilities

- `api-contract`: what the emitted specification guarantees — its version, the shapes it admits, what
  it must never contain, and that it cannot change incompatibly without saying so.

### Modified Capabilities

None. `domain-core` and `data-schema` are untouched.

## Impact

**Created** — `contract/openapi.json`; `packages/contract/src/openapi/` (the pure document builder
and the 3.0.3 down-converter) and its tests; the API request/response schemas alongside the pack
schemas they sit beside.

**Modified** — `packages/contract/src/adapters/emit.ts` gains one more artifact;
`.github/workflows/ci.yml`'s `contract` job gains the `oasdiff` step; `ARCHITECTURE.md`:202 loses
`options`; `CLAUDE.md`'s layout block stops calling `contract/openapi.json` planned.

**Untouched** — `app/`, `packages/core`, `packages/server`. No endpoint is implemented here; the
spec describes what F3 will serve, which is the point of freezing it first.

## Non-goals

- **Implementing any endpoint.** `packages/server` still routes `GET /health` and nothing else.
  `f3-server-foundation` builds against this document.
- **The Dart client.** ADR 0001 settled that it is hand-written, at F3, in `app/lib/api/`.
- **Auth endpoints.** Better Auth mounts its own routes at `/v1/auth` and generates their shapes; a
  hand-written spec for somebody else's router would be a second source of truth that drifts. The
  same ordering argument that kept its tables out of `f1-schema-freeze`.
- **A JSON-Schema-to-OpenAPI library.** The conversion this needs is narrow and the package's
  dependency count is a stated invariant; a general converter is a runtime dependency plus its
  transitive tail, for a transformation that fits in one tested module.
- **Anything the documents have not already decided.** Where a shape is unstated it is recorded as an
  open question rather than invented — a spec is expensive to change once a client is written
  against it, and that is the whole reason it is being frozen early.
