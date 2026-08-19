# The integration job stops depending on an apt mirror

## Why

`integration` hung twice in four runs, both times in the step that adds the PGDG apt repository and
installs `postgresql-client-18`. The step has no timeout of its own, so each hang burned the job's
whole 15 minutes and reported **cancelled** — which reads like a fault in the change under test,
and cost a re-run to disprove. Both times the suites had already passed.

## What changes

- **`pg_dump` comes from the `postgres:18` service container**, through a one-line shim on `PATH`,
  instead of being installed from apt. The container *is* the server, so the major matches by
  construction rather than by two pinned numbers agreeing.
- `createdb` likewise, so the job depends on no PostgreSQL client on the runner at all.
- Both steps carry their own `timeout-minutes`, so a future hang fails in three minutes naming the
  step rather than in fifteen naming the job.

## Out of scope

Other jobs. `dart`, `ts`, `contract` and `core` install nothing over the network beyond their
package manager, which has its own retries.
