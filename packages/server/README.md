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

## The database half of the suite

`npm test` runs 325 of 454 tests and **skips 129**. The skipped ones need a
Postgres, `test/support/database.ts` reads `TEST_DATABASE_URL` to find it, and
without one `describeWithDatabase` degrades to `describe.skip` — visibly, but
still green. Run them:

```sh
# from the repository root — the linked packages are this one's sources, and
# vitest resolves @akimath/contract through a symlink and looks for zod beside
# *its* sources, so installing only this package fails at resolution
npm ci --prefix packages/contract
npm ci --prefix packages/core
npm ci --prefix packages/server

brew install postgresql@18 && brew services start postgresql@18

# from packages/server — creates akimath_dev if needed, then runs all 454
npm run test:db
```

18 because that is the major Neon provisioned and CI's service container
mirrors. `npm run db:local` does the setup half alone and prints the URL, for
when you would rather export it yourself, and `npm run verify:db` is
`typecheck` plus the complete suite.

**`npm test` and `npm run verify` remain the skipping pair on purpose.** They
are what runs on a machine with no Postgres, and what `.claude/hooks/
verify-gate.sh` invokes; making either of them require a cluster would turn a
missing brew formula into a red gate. The `:db` spellings are the complete
ones, and they are the ones to run before pushing anything that touches
`migrations/`, `src/adapters/` or a route that reaches a table.

`.env.local` holds `DATABASE_URL` and `MIGRATE_DATABASE_URL` and **deliberately
holds no `TEST_DATABASE_URL`**: the suites create `akimath_test_w<worker>`
databases on whatever server the URL names and drop their `public` schema on
every run, so a remote value there would be a test run writing to Neon.
`scripts/local-database.sh` refuses any host that is not this machine, and
`test/scripts-load-their-env.test.ts` keeps `--env-file` off every test script.

## Status

Scaffold only. The domain (`packages/core` in the plan — generators, answer
equivalence, uniqueness verification, the rating engine) is not built yet, and
neither is persistence. The architecture proposal drives what lands next.
