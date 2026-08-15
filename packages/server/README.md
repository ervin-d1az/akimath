# AkiMath — API

TypeScript backend for AkiMath.

The Flutter client lives in a separate repository:
[`akimath-app`](https://github.com/ervin-d1az/akimath-app).

## Layout

```
src/
  routing.ts          pure policy: method + path in, status + body out
  health.ts
  adapters/           the environmentally unsuitable boundary — sockets live here
  main.ts             process wiring
test/
```

Business rules never import a framework, a driver, or `node:http`. Coverage and
mutation testing run against `src/` with `src/main.ts` and `src/adapters/`
excluded, because those exist only to touch the outside world and there is
nothing in them worth asserting.

## Commands

```sh
npm install
npm run typecheck
npm test
npm run coverage
npm run dev
```

Quality gates:

```sh
npm run mutation      # Stryker over src/, excluding the adapter boundary
npm run dry           # jscpd duplication report
```

## Status

Scaffold only. The domain (`packages/core` in the plan — generators, answer
equivalence, uniqueness verification, the rating engine) is not built yet, and
neither is persistence. The architecture proposal drives what lands next.
