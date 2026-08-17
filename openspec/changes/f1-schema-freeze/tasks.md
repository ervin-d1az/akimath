# Tasks — the schema freezes here

**The `[db]` lane stopped being blocked partway through this change.** It was written on the premise
that no Postgres existed — no Neon project, no `psql`, no `pg_dump`, no Docker. Ervin then asked
whether one could simply be installed, and it could: `brew install postgresql@17`. Every **[db]**
task below therefore **ran**, against a real PostgreSQL 17.11, and three defects that no amount of
review would have found came out of it (design D12). What is still not provisioned is a *deployed*
database — see 8.3.

## 1 · The dependency

- [x] 1.1 Add `pg` to `packages/server/package.json` as its first runtime dependency, pinned exactly,
      with `@types/pg` as a dev dependency. Record the DEP-1 audit **in the same change** — design D8
      has the wording; it goes next to the dependency, not in a commit message that nobody greps.
      **Check:** `npm run verify` green in `packages/server`; the `dependencies` key exists for the
      first time and holds exactly one entry.

## 2 · The migration planner — pure, and testable today

- [x] 2.1 Write `packages/server/test/migration.test.ts` for the ordering case: given files on disk
      and rows already recorded, the planner returns the unrecorded files in filename order and
      nothing else.
      **Check:** red — `src/migrate.ts` does not exist.
- [x] 2.2 Add the checksum-refusal case: a recorded file whose checksum no longer matches makes the
      planner return an error **naming that file**, and no plan.
      **Check:** red. Assert on the message containing the filename, not just on the error type — the
      point of the refusal is that a human knows which file.
- [x] 2.3 Add the case that proves the refusal is not vacuous: a recorded file whose checksum still
      matches plans nothing and errors on nothing (PROC-11 — an error that fires for every input is
      not a check).
      **Check:** red, then all three green once `src/migrate.ts` is written.
- [x] 2.4 Write `packages/server/src/migrate.ts`. **PURE** — no `fs`, no `pg`, no clock. Inputs are
      two lists; output is a plan or a named error.
      **Check:** `npm run verify` green with the count stated; `npm run mutation` covers it.

## 3 · The migration

- [x] 3.1 Write `packages/server/migrations/0001_initial.sql`: `schema_migrations`, `players`,
      `issued_items`, `attempts`, `user_skills`, `template_stats` (with `sum_expected` and
      `sum_user_rating`), `offline_packs`, `diag_events`. `timestamptz` throughout. `players.id` is a
      client-minted UUIDv7 with **no server default** — `ARCHITECTURE.md` §5 puts identity on the
      client so phase-2 attempts have a foreign key with no server involved.
      **Check:** the file is one transaction's worth of DDL and mentions no role yet.
- [x] 3.2 Add `players.age_band text NOT NULL` with a `CHECK` over `under_13`, `13_17`, `adult`
      (design D4). The three values appear **once** in the SQL and once in the TypeScript that names
      them, and nowhere else.
      **Check:** `grep -c` for each value across `packages/server/src` and the migration returns the
      expected counts; a third occurrence is a review finding.
- [x] 3.3 Add the grants (design D5): `app_request` gets SELECT + INSERT on `attempts` and **no
      DELETE on any table**; `retention_job` gets DELETE on **every table holding player data** and no
      INSERT or UPDATE anywhere. Wider than the nightly job needs, because `ARCHITECTURE.md`:242 puts
      the erasure path `DELETE /v1/me` under the same role, and the grants ship frozen.
      **Check:** written into the migration, not applied by hand — a grant applied by hand is a grant
      that does not exist on the next database.

## 4 · The runner — the adapter half

- [x] 4.1 Write `packages/server/src/adapters/migrate-runner.ts`: read the directory, hash the files,
      read `schema_migrations`, hand both to the planner, execute each file in its own transaction,
      record it. Direct connection string, never the pooler (`ARCHITECTURE.md` §5).
      **Check:** `npm run verify` green; the adapter holds no decision the planner could have made.
- [x] 4.2 **[db]** Apply to an empty database twice: the first run applies everything, the second
      applies nothing.
      **Check:** `packages/server/test/migration.test.ts`, CI job `integration`.
- [x] 4.3 **[db]** Prove the partial-failure contract: a file that raises partway leaves nothing
      applied and is not recorded, so re-running retries it whole.
      **Check:** same file, `integration`. This is the scenario that justifies one transaction per
      file rather than one for the run.

## 5 · The snapshot

- [x] 5.1 **[db]** Generate `packages/server/schema.sql` with `pg_dump --schema-only`, with the
      client version **pinned** (design D3).
      **Check:** re-generating produces no diff — verified, `1ad6c0ad…` twice.
      **It was not deterministic and the pin was not enough.** `pg_dump` 17.6+ emits
      `\restrict <random token>`, regenerated every run, so the dump differed from itself and the
      gate would have failed on its first green build. `scripts/dump-schema.sh` passes
      `--restrict-key` and strips the two version-header comments, with the reason written above the
      command. 369 lines, 15 GRANTs — the grants are in the snapshot, which is the point of having
      one.
- [x] 5.2 Add the `integration` CI job: spin an ephemeral branch on a **separate CI project**, apply,
      dump, `git add -A -- packages/server/schema.sql`, `git diff --cached --exit-code`. Staged,
      because a bare `git diff` is blind to a snapshot the author never committed — the same lesson
      the `contract` job already carries.
      **Check:** the job is wired into `gate`'s `needs` list; `.github/workflows/ci.yml` parses.
- [x] 5.3 Add the `protected-paths` job with `packages/server/migrations/` and
      `packages/server/schema.sql` as its first entries (`ARCHITECTURE.md` §8). It does not exist
      today because there was nothing to protect.
      **Check:** the job fails on a branch that edits a migration, and is wired into `gate`.

## 6 · Retention

- [x] 6.1 Write `packages/server/test/retention.test.ts`: `retentionCutoffs(now)` returns
      `now − 400d` for attempts and `now − 30d` for diagnosis events.
      **Check:** red.
- [x] 6.2 Add the daylight-saving case: a cutoff spanning a 23- or 25-hour local day is still exactly
      400 × 24 h. Absolute elapsed time is the decision (design D6), and the Dart side already paid
      for the other reading.
      **Check:** red, and run it under `TZ=America/Tijuana` as well as UTC — CI runs UTC, so a
      zone-dependent bug is invisible unless the zone is named. `f2-day-log` added exactly this step
      to CI for `StreakPolicy`; follow it.
- [x] 6.3 Add the single-source case: the figures 400 and 30 appear in exactly one module.
      **Check:** a test that greps the source, reporting how many files it scanned so a mistyped glob
      cannot pass vacuously (PROC-10).
- [x] 6.4 Write `packages/server/src/retention.ts`. **PURE** — takes `now`, returns cutoffs, reads no
      clock and opens nothing.
      **Check:** green; `npm run mutation` covers it.
- [x] 6.5 Write `packages/server/src/adapters/retention-job.ts`: read the clock, connect as
      `retention_job`, delete, report counts.
      **Check:** `npm run verify` green.
- [x] 6.6 **[db]** Run the job twice with the same injected instant: the second deletes zero, both
      report their counts, and `template_stats` is unchanged by either.
      **Check:** `packages/server/test/retention.test.ts`, `integration`.
- [x] 6.7 Add `.github/workflows/retention.yml` on a schedule, with the credential in
      `RETENTION_DATABASE_URL` (design D7).
      **Check:** the workflow parses and carries `timeout-minutes`, like every other job here.

## 7 · The invariants, as tests

- [x] 7.1 **[db]** `packages/server/test/grants.test.ts`: the request-path role's DELETE and UPDATE
      against `attempts` are refused, and the grant catalogue shows it holding only SELECT and
      INSERT. Assert **both directions over every table** — the request path deletes from nothing, and
      the retention role deletes from everything holding player data — because a later migration
      forgetting either grant is the realistic failure and a test naming two tables cannot see it
      (design D5).
      **Check:** `integration`; the test reports how many tables it swept.
- [x] 7.2 **[db]** `packages/server/test/players.test.ts`: an insert with no band is refused; an
      insert with a fourth band is refused; and `information_schema.columns` over every table this
      migration creates holds no name and no day, month or year of birth.
      **Check:** `integration`.
- [x] 7.3 **[db]** `packages/server/test/offline-packs.test.ts`: a fifty-item pack is one row
      carrying fifty references, and no table in the schema is keyed per offline item.
      **Check:** `integration`. **Structural claims only** — that the server can *rederive* an item
      from those references is `f1-core-rederivation`'s capability and there is no `packages/core` to
      test it against, so this requirement asserts the storage shape and stops there.

## 8 · Evidence

- [x] 8.1 **Tier 1** — `npm run verify` in `packages/server`: **46 tests green** (3 before). `app/`
      untouched and unmoved: analyze clean, **623 tests**, the same count as before this change.
- [x] 8.2 **Tier 1b** — **95.31%** mutation score (`retention.ts` and `routing.ts` at 100,
      `migrate.ts` at 91.67), `npm run dry`: **0 clones** over 396 lines.
      It started at **59.79** and every point of the climb was a real finding:
      · `src/cli/**` was being mutated and is an entry-point adapter, like `main.ts` and `adapters/`.
      · The error messages' *guidance* was unasserted — a refusal that names a file but not the
        remedy sends a reader to the git history for the rule. Now asserted, checksums included.
      · Five survivors on the sort comparator were **equivalent mutants**: they differed only when
        two migration names are equal, which cannot happen. The comparator became two-way and the
        unreachable branch went with them (design D13).
      · One "survivor" cluster was a `coverageAnalysis: "perTest"` artifact — reverting the
        comparator by hand reddened a test. Switched to `"all"`.
      **And the mutation run found a defect in a test of mine:** the "figures live in one module"
      gate reads `src/` from disk, and Stryker runs against an instrumented copy whose files carry
      numeric mutant ids. It reported a duplication that existed only inside the mutation sandbox. It
      now skips under Stryker, with the reason written down.
- [x] 8.3 **Tier 2 — the real thing, exercised.** PostgreSQL **17.11** (Homebrew), a cluster created
      for this change. The migration applied through the real runner; **46 tests green**, of which 21
      only exist against a live database — grants refused, constraints rejected, the catalogue swept,
      the job idempotent, the snapshot byte-identical twice.
      **What is still not done, and is nobody-but-Ervin's to do:** there is no *deployed* database.
      CI now runs its own `postgres:17` service container, so the gate needs no account (design D11),
      but a Neon project, its connection strings, and `RETENTION_DATABASE_URL` as a secret are
      account actions. `retention.yml` will not run until `vars.RETENTION_ENABLED` is `true` — it
      refuses rather than succeeding nightly against nothing, which is the most expensive kind of
      green.
- [x] 8.4 Update `CLAUDE.md`'s "What exists today": the database section currently reads *"Does not
      exist. No database, no migrations…"* and would be wrong the moment 3.1 lands.
