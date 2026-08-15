# AkiMath

Math challenges in Mexican Spanish. Adaptive difficulty, a dog called Aki, and
grid puzzles. Flutter client, TypeScript backend, Postgres on Neon.

One repository, because six contracts cross the TypeScript↔Dart boundary and a
contract change has to be a single commit that either compiles or doesn't. See
[ARCHITECTURE.md](ARCHITECTURE.md) §1.

## Layout

```
contract/          the pinned boundary: openapi.json, canonicalization fixtures
packages/
  core/            the domain. zero dependencies — enforced in CI
  contract/        Zod schemas, route definitions, the OpenAPI emitter
  server/          Hono, Drizzle, Better Auth, batch jobs
app/               the Flutter client; lib/api/ is generated, never hand-edited
docs/adr/
```

`packages/core` and `packages/contract` do not exist yet. `packages/server` is a
scaffold. `app/` holds the finished brand layer and Aki's character sheet.

## Working on it

```sh
# Flutter
cd app && flutter pub get && flutter analyze && flutter test

# TypeScript
cd packages/server && npm install && npm run verify
```

The workspace is declared for pnpm (`pnpm-workspace.yaml`) but not yet migrated
onto it — `packages/server` still carries its own npm lockfile. Switching is a
separate, deliberate step.

## Branches

`main` is protected: no direct pushes, no force-push, no deletion. Work lands on
`dev` and reaches `main` through a pull request.
