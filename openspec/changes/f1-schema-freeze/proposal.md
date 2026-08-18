## Why

**Phase F1** (`ARCHITECTURE.md` §9). The schema freezes at F1 — everything after it is a new
forward-only migration, never an edit — and five F3 changes are blocked on it:
`f3-server-foundation`, `f3-attempt-sync`, `f3-profile-read`, `f3-deletion-web`,
`f3-store-artifacts`. Today `packages/server` is one pure `route()` function serving `GET /health`
and **no data of any kind**: no table, no migration, no runner, no role, no connection string.

It is also where two compliance invariants stop being prose. `ARCHITECTURE.md` §5 states that
`attempts` never accepts UPDATE and accepts DELETE only under `retention_job`; `CLAUDE.md` repeats
it verbatim under "system invariants for the parts not yet built". Nothing enforces either, because
there is nothing to enforce them on. This change makes both **grants**, which a role cannot talk its
way past.

## What Changes

- **Seven tables plus a ledger**, as one forward-only migration: `players`, `issued_items`,
  `attempts` (append-only), `user_skills`, `template_stats` (with `sum_expected` and
  `sum_user_rating`), `offline_packs`, `diag_events`, and `schema_migrations`.
- **A migration runner** (~40 lines) over the `pg` client, applied on the **direct** connection
  string, recording filenames and checksums. It refuses to start when a file already recorded has
  changed, rather than applying a partial schema. No ORM and no `drizzle-kit`.
- **`packages/server/schema.sql`** — a committed `pg_dump --schema-only` snapshot, diffed in CI the
  same way `contract/` already is.
- **Roles and grants**, not discipline: the request-path role gets SELECT and INSERT on `attempts`
  and nothing else; `retention_job` alone holds DELETE.
- **`packages/server/src/retention.ts`** — PURE. `retentionCutoffs(now)` returns 400 days for
  `attempts` and 30 for `diag_events`, reads no clock, and is the only place those two figures
  appear. The adapter beside it runs the DELETE under `retention_job`.
- **`.github/workflows/retention.yml`** — a scheduled job holding the `retention_job` credential.
- **CI grows two jobs it has never had**: `integration` (an ephemeral branch on a separate CI
  Postgres project) and `protected-paths`, which `ARCHITECTURE.md` §8 lists and which is absent today
  because there was nothing to protect. `packages/server/migrations/` and `schema.sql` are its first
  entries.
- **`pg` becomes `packages/server`'s first runtime dependency.** The package has no `dependencies`
  key at all today. It is audited and pinned in the same change, the way `zod@4.4.3` was.

**Two gate answers are recorded here as decisions, and the proposal review is the gate.**

- **`players.age_band` is NOT NULL, over three values: `under_13`, `13_17`, `adult`.** The band is
  resolved before the device obtains any session — anonymous or credentialed — because a guest writes
  a `players` row at first sync, before any account exists, so collecting it at `1.2 Crear cuenta`
  would arrive after the row. Three values and not four: each of these changes something concrete
  (`under_13` triggers Families and parental consent, `13_17` is still a minor under the LFPDPPP,
  `adult` is neither), whereas splitting `13_15`/`16_17` would be precision with no consequence
  attached. The nullable-until-link alternative is rejected for the reason the plan gives: it turns a
  compliance invariant into a runtime check. **Gate A may return a different set; that is a new
  migration, and this proposal is where the assumption is visible rather than buried.**
- **`4.1`'s seven-day delta derives from `attempts`**, so no rating-history table exists. Retention
  at 400 days already outlives a seven-day window. If a history table is wanted later it arrives
  forward-only.

**BREAKING**: nothing. There is no database to break.

## Capabilities

### New Capabilities

- `data-schema`: what the database is, what may write to it, and what deletes from it — the table
  set, the forward-only migration discipline, the grants that make `attempts` append-only, and the
  retention job.

### Modified Capabilities

None. No spec on disk describes data today.

## Impact

**Created** — `packages/server/migrations/0001_initial.sql`, `packages/server/schema.sql`,
`packages/server/src/migrate.ts` and `src/adapters/migrate-runner.ts`,
`packages/server/src/retention.ts` and `src/adapters/retention-job.ts`, their tests under
`packages/server/test/`, `.github/workflows/retention.yml`.

**Modified** — `packages/server/package.json` (first `dependencies` key), `.github/workflows/ci.yml`
(`integration`, `protected-paths`, both wired into `gate`), `CLAUDE.md`'s "what exists today".

**Untouched** — `app/`, `packages/contract/`, `contract/`. No Dart file changes and no Flutter
dependency is added; F2 keeps working with no server, which is the point of the offline pack.

**Depends on** — nothing on disk. It needs a Postgres to *run* against, which the repository does not
have and this change does not provision: see Non-goals.

## Non-goals

- **Better Auth's tables** (`user`, `account`, `session`, `verification`). They are generated by that
  library's CLI at the version `f3-server-foundation` pins, and that change depends on this one —
  committing SQL at F1 that a dependency installed at F3 produces is an ordering nobody can honour.
  Nothing at F1 needs them.
- **Provisioning the database.** No Neon project, no `DATABASE_URL`, and no Postgres client exist on
  this machine — `psql`, `pg_dump` and Docker are all absent. Creating the project and adding the CI
  secrets is an account action for Ervin, not a task in this change. Every scenario that needs a live
  database is marked as such in `tasks.md` and stays unrun until then; it is stated, not skipped.
- **Any endpoint.** No route beyond `GET /health` is added. `f3-server-foundation` does that.
- **`packages/core`.** Rederivation, Glicko and the PRNG are `f1-core-rederivation`.
- **The pack builder.** `f1-5-pack-builder` emits packs; this change only defines where a pack's
  manifest row lives.
- **An ORM or a migration tool.** `ARCHITECTURE.md` §3 names `drizzle-orm` as exactly the dependency
  an agent adds in a one-line diff, and a migration tool is the kind of thing that arrives with one.
- **Gate A's authored content** — the aviso de privacidad, the términos, the tutor-consent flow and
  what it records as evidence. This change fixes the *column*; the consult decides the *policy*, and
  if it returns different bands that is a forward-only migration.
