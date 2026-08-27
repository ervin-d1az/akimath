<!--
  The title is the commit subject. Merges here are squashes, so whatever you type
  in the title box is what lands on `main` for ever — it obeys GIT-2 like any
  other subject: a conventional prefix, then a short lowercase description, no
  ticket id and no scope in parentheses.

      feat: let a suite pre-order choose its delivery hour
      fix: the commit gate scopes itself against the trunk that exists
      docs: the specs catch up with the code
      test: record why getNextItem is the operation still answering 501
      chore: archive the completed changes whose deltas apply

  Delete any section below that has nothing true to say. An empty heading is
  worse than an absent one — it reads as covered.
-->

## What lands

<!-- The change in a few sentences. What a reader has to know to review it. -->

## Why

<!-- The defect, the need, or the decision this carries out. If it fixes
     something, say what was broken and how it showed. -->

## Evidence

<!-- State the tier you reached, with the numbers. "It compiles" and "it should
     work" are not evidence, and skipping a tier silently is a violation —
     saying you skipped one is not. -->

**Tier 1 — the committed suite.**

| | |
|---|---|
| `flutter analyze --fatal-infos` | |
| `flutter test` | |
| `dart run dart_code_linter:metrics analyze lib --set-exit-on-violation-level=warning` | |
| `packages/server` · `npm run verify` | |
| `packages/contract` · `npm run verify` | |
| `packages/core` · `npm run verify` | |

<!-- Drop the rows the change does not touch. The metrics command needs its
     flag: without it the tool prints its violations and still exits 0. -->

**Tier 1b — show the tests bite.** <!-- Stryker and jscpd on the TypeScript
side; on the Dart side the falsification step from the rulebook's PROC-5, which
edits versioned code and reverts it. Say which mutant survived, if any. -->

**Tier 2 — exercise the real thing.** <!-- The app on a device or simulator when
the change surfaces visually, or the endpoint called for real. `flutter test`
does not reach `integration_test/` — say so if you did not run it. -->

## What this does not do

<!-- Scope you deliberately left out, a follow-up you filed, a tier you could not
     reach and why. This section is the one most worth writing: it is where a
     reviewer stops guessing. -->

## After it merges

<!-- Migrations to run, a service to deploy, a change to archive, a document to
     delete. Nothing to do is an answer — write "nothing". -->
