# gate-deadlines Specification

## Purpose
Every automated check in this repository runs under a time limit, and a check that exceeds it
fails loudly, naming itself. Without this, a single unbounded loop anywhere in the codebase
presents as a frozen commit and a pull request that waits forever — a silence, not an error.

## Requirements

### Requirement: The commit gate kills a hung check and names it

The commit hook SHALL run every check under a deadline, and SHALL exit 2 with a message naming the
command that exceeded it. Exit 2 is the only code Claude Code treats as blocking, and the name is
what tells a developer which of several checks hung.

#### Scenario: A check that runs past the deadline is killed and named
- **WHEN** a check runs longer than the configured deadline
- **THEN** the hook exits 2 and its message names that specific command, not the check set
  → `.claude/hooks/verify-gate.sh` exercised with a stub command that sleeps

#### Scenario: A hung check does not leave orphaned descendants
- **WHEN** the killed command has spawned child processes of its own
- **THEN** those descendants are reaped rather than left running after the hook exits
  → `.claude/hooks/verify-gate.sh` exercised with a stub that spawns two grandchildren

#### Scenario: An ordinary failure is unaffected by the deadline
- **WHEN** a check fails on its own merits well inside the deadline
- **THEN** the hook exits 2 with that check's own output intact and no mention of a timeout
  → `.claude/hooks/verify-gate.sh` exercised with a stub that exits non-zero

#### Scenario: A green run is unaffected by the deadline
- **WHEN** every check passes well inside the deadline
- **THEN** the hook exits 0 and adds no delay of its own
  → `.claude/hooks/verify-gate.sh` exercised with stubs that all succeed

### Requirement: An unreadable deadline stops the gate rather than removing it

The deadline SHALL be overridable by environment variable, and an override that is not a positive
whole number of seconds SHALL block rather than silently fall back to running unbounded. A gate
that cannot read its own deadline must not run without one.

#### Scenario: A malformed override blocks
- **WHEN** the deadline override is set to a value that is not a positive whole number of seconds
- **THEN** the hook exits 2 and its message names the variable and the value it could not read
  → `.claude/hooks/verify-gate.sh` exercised with the override set to a non-numeric string

### Requirement: Continuous integration bounds every job

Every job in the workflow SHALL declare `timeout-minutes`, sized to that job rather than to a
single blanket figure, so a hung job fails in minutes instead of consuming the platform default.

#### Scenario: No job relies on the platform default
- **WHEN** the workflow file is read
- **THEN** every job declares its own `timeout-minutes`
  → `.github/workflows/ci.yml`, asserted by `grep -c "timeout-minutes"` against the job count

### Requirement: A hung test fails as a test

Both TypeScript packages SHALL configure a per-test timeout, so an unbounded loop inside one test
fails that test rather than hanging the suite that contains it.

#### Scenario: Each TypeScript package bounds its tests
- **WHEN** either package's vitest configuration is read
- **THEN** it declares an explicit `testTimeout`
  → `packages/server/vitest.config.ts` and `packages/contract/vitest.config.ts`
