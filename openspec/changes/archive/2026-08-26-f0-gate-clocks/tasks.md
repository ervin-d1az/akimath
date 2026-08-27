# Tasks — gate deadlines

The code for this change **already exists in the working tree**. It was written during the review
round that followed `f0-pack-contract`, before this change was opened, which is the process defect
this document also corrects: `CLAUDE.md` requires the plan to be committed under
`openspec/changes/<change-id>/` rather than left in a scratch directory, and the plan for this
slice lived only in gitignored `tmp/planning/`. Every box below is therefore checked against code
already on disk, with its verification restated rather than re-derived.

## 1 · The commit gate

- [x] 1.1 Run each check in its own process group under a watchdog, so the deadline kills the
      group rather than the leader. Shell primitives only — GNU `timeout` is absent on macOS
      (design D1).
      **Check:** a stub that spawns two grandchildren and hangs → hook exits 2, descendants reaped.
      Verified: `EXIT=2 ELAPSED=5s`, `--- descendants --- (none — process group reaped)`.
- [x] 1.2 Name the killed command in the failure message (design D2).
      **Check:** the stub passes `run typecheck` and hangs on `test` → message reads
      `verify-gate: BLOCKED — npm test (contract) ran past 5s and was killed.`, naming the hung
      check and not the one that passed.
- [x] 1.3 Read the deadline from `AKIMATH_GATE_TIMEOUT`, defaulting to 600 s, and block on a value
      that is not a positive whole number of seconds (design D3).
      **Check:** `AKIMATH_GATE_TIMEOUT=abc` → exit 2 naming the variable.
- [x] 1.4 Leave the existing paths untouched: green stays silent, an ordinary failure keeps its
      own output and says nothing about a timeout.
      **Check:** all-green stub → `EXIT=0` in 0 s; failing stub →
      `BLOCKED — npm run typecheck (contract) failed (exit 1)` with the output intact.

## 2 · Continuous integration

- [x] 2.1 Give every job its own `timeout-minutes`, sized to the job (design D4).
      **Check:** every key under `jobs:` declares one. Count the jobs by parsing, not by
      `grep -cE '^  [a-z-]+:$'` — that pattern also matches `push:` and `pull_request:` under
      `on:` and reports 8 where there are 7, which is how this line read on its first draft.
      Currently **7 declarations for 7 jobs**: `changes`, `secrets`, `dart`, `ts`, `contract`,
      `spec`, `gate`.

## 3 · The TypeScript suites

- [x] 3.1 Set `testTimeout` in both packages, so a hung test fails as a test.
      **Check:** `grep -n "testTimeout" packages/*/vitest.config.ts` returns both files;
      both read `testTimeout: 5_000`.

## 4 · Evidence

- [x] 4.1 **Tier 1** — the four suites and the spec validator, green with this change in the tree.
      **Check:** `flutter analyze --fatal-infos` clean · `flutter test` 135 ·
      `packages/server` 3 · `packages/contract` 189 · `openspec validate --all --strict` all pass.
- [x] 4.2 **Tier 1b** — the deadline was falsified rather than assumed: each of the four hook paths
      above was exercised with a stub, and each produced the stated exit code and message. A clock
      that has never fired is not evidence that it fires.
- [x] 4.3 **Tier 2** — does not apply. No endpoint, no screen, nothing observable to a player.
      Stated rather than skipped (PROC-5).
      **Closed 2026-08-17.** The task text *was* the evidence and the box was simply never ticked;
      nothing about the change became observable in the meantime.
