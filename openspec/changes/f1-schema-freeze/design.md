## Context

`packages/server` today is `src/routing.ts` (pure), `src/adapters/http-server.ts` (the socket) and
three tests. It has **no `dependencies` key**, no database, and no configuration of any kind. See
`proposal.md` — Why for motivation, and `specs/data-schema/spec.md` for the requirements this has to
satisfy.

Three constraints shape everything below.

- **Forward-only.** `ARCHITECTURE.md` §9 freezes the schema at F1. After this merges, a column is
  added by a new file and never by editing this one, so every choice here is expensive to reverse and
  cheap to extend.
- **`pg` over TCP, not the Neon serverless driver** (`ARCHITECTURE.md` §5). The sync batch computes
  Glicko in TypeScript *between* an INSERT's `RETURNING` and a `user_skills` upsert — an interactive
  transaction the HTTP driver cannot run. Pooler string at runtime, **direct** string for migrations.
- **Nothing to run against.** No Postgres client, no Docker, no Neon project on this machine. The
  design therefore has to put as much as possible on the side of the boundary that a unit test can
  reach, and be explicit about the rest.

## Goals / Non-Goals

**Goals**

- Two compliance invariants become grants rather than sentences: `attempts` accepts no UPDATE, and
  only the retention role deletes.
- Every figure with a legal consequence — 400 days, 30 days, the three age bands — appears exactly
  once in the source.
- The half that needs no database is genuinely testable today: the runner's ordering and checksum
  logic, and the retention cutoffs.

**Non-Goals** (beyond `proposal.md`'s)

- No index tuning. Indices that exist here are the ones a stated query needs; performance work is a
  later forward-only migration with a measurement behind it.
- No seed or fixture data. An empty database is a valid database.
- No connection pooling policy beyond what `ARCHITECTURE.md` §5 already fixes.

## Decisions

### D1 · A hand-written runner, not a migration library

~40 lines: read `migrations/*.sql` sorted by filename, compare against `schema_migrations`, apply the
rest in one transaction each, record `(filename, checksum, applied_at)`.

*Alternatives.* `drizzle-kit` — rejected, and specifically: `ARCHITECTURE.md` §3 names `drizzle-orm`
as the dependency an agent adds in a one-line diff, and a migration tool is precisely the thing that
arrives holding one. `node-pg-migrate` — a real option, and rejected for a smaller reason: it owns
the ledger table's shape, and this change's whole point is that the ledger is ours to assert on.

**The runner splits PURE / adapter like everything else here.** `src/migrate.ts` is pure: given the
list of files on disk with their checksums and the list of rows already recorded, it returns the
ordered plan or an error naming the offending file. It touches no filesystem and no socket, so the
"a migration was edited after it shipped" scenario is a unit test with no database.
`src/adapters/migrate-runner.ts` reads the directory, opens the connection and executes the plan.
That is the same split `src/routing.ts` versus `src/adapters/` already sets in this package.

### D2 · Checksums, and what the runner does with them

SHA-256 of the file bytes, stored with the row. A recorded file whose checksum no longer matches is a
**refusal to start**, not a warning and not a re-apply: re-applying is how a partial schema happens,
and warning is how nobody notices. This is the same reasoning as the `contract/` byte-for-byte gate,
which is already load-bearing in this repository.

### D3 · The snapshot is `pg_dump --schema-only`, and the client version is pinned

`packages/server/schema.sql` is the committed dump; CI applies the migrations to an empty database,
dumps, and diffs. **Pin the `pg_dump` client version in the workflow.** An unpinned client re-orders
and re-words its own output across releases, so the gate would fail on a runner-image bump and get
disabled within a week — which is the failure mode `ARCHITECTURE.md` §8 already worries about for the
`contract` job.

*Alternative:* trust the migrations and skip the snapshot. Rejected: the snapshot is the only artifact
a human can read to answer "what is the schema right now" without replaying eleven files.

### D4 · `age_band` is `text` with a `CHECK`, not a Postgres enum

Both satisfy the requirement. The enum wins on storage and loses on evolution: `ALTER TYPE … ADD
VALUE` cannot run inside a transaction block on older servers and a value can never be removed, while
a CHECK constraint is replaced by one forward-only statement. Given that Gate A may return a different
set — that is the recorded assumption in `proposal.md` — the constraint that is cheap to replace is
the right one. A lookup table was considered and rejected: three values that change once a decade do
not need referential integrity, and a join.

The three values are `under_13`, `13_17`, `adult`, and the enumeration lives in **one** place in the
source, next to the retention figures, for the same reason.

### D5 · Three roles, and the owner is not one of them

| Role | Holds |
|---|---|
| owner / migrator | DDL. Used by the runner on the **direct** connection string, never at runtime. |
| `app_request` | SELECT + INSERT on `attempts`; SELECT/INSERT/UPDATE elsewhere as each table needs. **No DELETE on any table.** |
| `retention_job` | DELETE on every table holding player data. No INSERT and no UPDATE anywhere. |

**`retention_job`'s DELETE is wider than the retention job, and that is deliberate.**
`ARCHITECTURE.md` §5 puts *two* callers under this role: the retention job, which touches `attempts`
and `diag_events`, and **the erasure path `DELETE /v1/me`**, which has to clear a player from every
table that holds them. An earlier draft of this design granted the role only the two tables the
nightly job uses, which would have left erasure with nowhere to run — and the grants ship frozen, so
that is a mistake discovered at F3 rather than here. The role's grant set is therefore the union of
what both callers need; the job simply uses less of it than the endpoint will.

Grants are the enforcement. A trigger refusing UPDATE was considered as belt-and-braces and rejected:
the owner bypasses it anyway, so it would add a second mechanism that is weaker than the first and
invites the reader to trust whichever they find.

**The grant test enumerates every table, not the two named ones.** A later migration that creates a
table and forgets its grants is the realistic failure, and a test naming `attempts` cannot see it. It
asserts both directions: `app_request` holds DELETE nowhere, and `retention_job` holds DELETE
everywhere a player leaves a row.

Better Auth's tables are not in this set because they do not exist yet (see `proposal.md` —
Non-goals). Their grants, and `ARCHITECTURE.md` §5's point that erasure must also clear
`account.password` and `verification.identifier`, land with them at F3.

### D6 · `retention.ts` is PURE and holds the only copy of the two figures

`retentionCutoffs(now)` takes the instant as a parameter and returns
`{ attempts: now − 400d, diagEvents: now − 30d }`. No clock, no environment, no connection — the same
shape `routing.ts` sets, and `openspec/config.yaml` cites that file by name as this package's
precedent. `src/adapters/retention-job.ts` reads the clock, opens the connection under
`retention_job`, and reports the counts it deleted.

**Absolute elapsed time, deliberately.** 400 days means 400 × 24 h, not a walk back over local
midnights. The Dart side already paid for the other reading: `StreakPolicy` counted calendar days with
`subtract(Duration(days: 1))` and lost a child's whole streak across a Tijuana daylight-saving
transition. Here the calendar reading would be the bug, so the spec pins it with its own scenario.

### D7 · Scheduling is a GitHub Actions cron, recorded as a default

`.github/workflows/retention.yml` runs the job with the `retention_job` credential. It is free,
visible in the same place as every other gate, and needs no database extension. Whether Neon offers
`pg_cron` on the Free plan is **unverified and not assumed**. If it turns out to be available and
preferable, moving is a workflow deletion and a migration.

### D8 · `pg` is pinned exactly

`packages/server`'s first runtime dependency. Pinned to an exact version rather than a caret, matching
`zod@4.4.3` in `packages/contract`. The audit DEP-1 asks for is recorded in the same change: `pg`
opens a socket to the database it is configured for and does nothing else — no telemetry, no update
check, no analytics — and it never ships to a device, so the under-13 constraint that governs `app/`
does not reach it. It is still stated rather than assumed, because "the rule is about the client" is
exactly how the first unaudited dependency gets in.

### D9 · `diag_events` is defined here, with its shape recorded as a default

It is the only table the project knows solely by a retention number, and a number with no referent is
not a decision. Default shape: one row per diagnosis resolved at sync —
`(player_id, attempt_id, misconception_id | null, created_at)` — where the misconception is null for
the generic fallback the pack carries. Thirty days.

### D10 · Testing splits along the same boundary as the code

- **Runs today, no database**: the migration planner (ordering, checksum refusal, partial-failure
  contract), and the retention cutoffs. These are the `packages/server` unit suite, and they carry the
  Tier 1b mutation pass the package already runs.
- **Needs the `integration` job**: grants, the NOT NULL and CHECK rejections, the
  `information_schema` sweep for names and birth dates, the double-apply, the snapshot diff, and the
  idempotent second run.

The integration job gets **a separate CI Postgres project**, per `ARCHITECTURE.md` §8, so a CI run can
never truncate anything a person is using.

### D11 · CI uses a `postgres:17` service container, not an ephemeral Neon branch

`ARCHITECTURE.md` §8 job 7 says "ephemeral Neon branch (a separate `akimath-ci` project)". This
change runs a service container instead, and the deviation is deliberate rather than a shortcut: a
container needs no account, no project and no secret, so the gate works on day one and on a fork,
where a Neon branch needs a credential a fork cannot have.

What these suites assert — grants, constraints, the catalogue, an idempotent job, a schema dump —
is plain PostgreSQL behaviour. The day a test depends on the pooler, on autosuspend or on branch
semantics, it wants a real Neon branch, and the comment above the job in `ci.yml` says so.

### D12 · Three things only a real database could say

Recorded because each was wrong in a way review would not have caught.

- **The ledger cannot live in a migration.** `0001_initial.sql` created `schema_migrations` and so
  did the runner, which has to create it before it can read it. A migration cannot create the table
  that records whether that migration ran. The ledger belongs to the runner.
- **Nothing granted `USAGE` on the schema.** A stock `public` grants it to PUBLIC, so the omission
  was invisible until the test harness recreated the schema. A frozen schema should not lean on a
  default it never wrote down, so the grant is now explicit.
- **`pg_dump` is not deterministic out of the box.** Version 17.6+ opens with
  `\restrict <random token>`, regenerated per run, so the snapshot differed from itself and the
  diff gate would have failed on its first green build. `--restrict-key` pins it, and the two
  version-header comments are stripped, because they churn on a patch bump and say nothing about
  the schema. `scripts/dump-schema.sh` carries both, with the reason.

### D13 · A three-way comparator had five unkillable mutants, so it became two-way

The migration sort read `a.name < b.name ? -1 : a.name > b.name ? 1 : 0`. Five mutants survived,
and every one of them differed from the original *only when two names are equal* — which cannot
happen, because a filename is unique in a directory. Equivalent mutants are not a scoring problem;
they are a branch nobody can reach. `(a, b) => (a.name > b.name ? 1 : -1)` says the same thing with
no unreachable case, and the module went from 75% to 91.67%.

Recorded because the temptation is to read the number and add a test. The report was right and the
code was wrong.

## Risks / Trade-offs

- **The `integration` job cannot run until a database exists** → every scenario that needs one is
  marked in `tasks.md` and stays unrun. Stated, not skipped; the unit half still lands green.
- **`pg_dump` output churns across client versions** → pin the client in the workflow (D3). Without
  the pin the gate cries wolf and gets removed.
- **Forward-only means a mistake ships permanently** → the snapshot makes the whole schema reviewable
  in one file at review time, which is the only real mitigation.
- **Grants drift as tables are added** → the grant test enumerates every table rather than the named
  ones (D5).
- **Retention deletes rows a future feature wanted** → safe today only because `template_stats` is
  maintained on write (`ARCHITECTURE.md` §5); the idempotency scenario asserts the aggregates are
  unchanged, so a future path that starts deriving from raw rows breaks a test rather than a child's
  history.
- **`age_band` may be wrong** → it is the recorded gate assumption, it is a CHECK rather than an enum
  (D4), and changing it is one forward-only statement.

## Migration Plan

There is nothing deployed, so there is nothing to roll back. The order is: migration file, then
runner, then grants, then retention, then the two CI jobs. Deployment against a real database happens
in `f3-server-foundation`, which is the first change with somewhere to deploy.

## Open Questions

Each of these can be answered later without changing the specs, the approach or the task breakdown —
every one of them is a forward-only migration.

- The index set beyond primary and foreign keys. `f3-attempt-sync` will have a query to measure.
- Whether `issued_items` needs a retention figure of its own. It is not in decision #3, and nothing
  reads it after rederivation.
- Whether the seven-day delta stays derived from `attempts`. Recorded as the default in
  `proposal.md`; a rating-history table is additive if `f3-profile-read` finds the derivation too
  slow.
