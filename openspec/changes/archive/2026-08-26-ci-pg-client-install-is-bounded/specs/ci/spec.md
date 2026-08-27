## Purpose

What the integration job is allowed to depend on, and how it is bounded when a
dependency misbehaves: the tools it takes from its own service container rather
than from a network install, so a major version matches by construction and no
external mirror sits on the critical path, and the timeout each step fails
inside so a hang names itself instead of consuming the job's whole budget.

## ADDED Requirements

### Requirement: req-a-matching-pg-dump · The dump client matches the server

The job SHALL use a `pg_dump` of the server's major version, obtained without a network install.

#### Scenario: The client is the server's own

- **WHEN** the snapshot is dumped
- **THEN** `pg_dump` runs inside the `postgres:18` service container — the major matches by
  construction, and no external apt mirror is on the critical path
  → `.github/workflows/ci.yml`

#### Scenario: A step that hangs

- **WHEN** any step in this job stops making progress
- **THEN** it fails within its own `timeout-minutes` and names itself, rather than consuming the
  job's budget and reporting "cancelled"
  → `.github/workflows/ci.yml`
