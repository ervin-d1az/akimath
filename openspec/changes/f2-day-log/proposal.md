## Why

The home shows a streak of **zero**, always. `StreakPolicy` is pure and tested, the pill renders, and
nothing records that a day was played — so the one figure the F2 home carries is the one figure it
cannot earn.

**Phase: F2.** It completes the streak pill `f2-home-reduced` shipped.

## What Changes

- **`features/home/policy/day_log.dart`** — the days practised, as pure data. Records a day, prunes
  to a retention window, encodes and decodes.
- **`features/home/data/day_log_store.dart`** — the storage seam, with a working in-memory
  implementation.
- **`RoundScreen`** records the day on submit, right or wrong.
- **`HomeRoute`** owns the store and **re-reads it when a series ends**, so the streak rises without
  a relaunch.

## Capabilities

### New Capabilities
- `day-log`: what the app remembers about when the player practised, and for how long it keeps it.

## Impact

- **New:** `features/home/policy/day_log.dart`, `features/home/data/day_log_store.dart`.
- **Modified:** `RoundScreen` gains an optional store; `HomeRoute` owns one and refreshes from it.
- `features/*/policy/` under the pure root goes from 6 files to 7.
- **One new runtime dependency, `shared_preferences`** — decided by Ervin 2026-08-16 after the
  allowlist gate fired, with the DEP-1 audit recorded beside the allowlist entry. It was an open
  question when this change opened and is not one now.

## Non-goals

- **Nothing here.** Persistence *was* a non-goal while the dependency was undecided; the decision
  was taken inside this change and the persistent store shipped with it. Left visible rather than
  rewritten, because the sequence — seam first, decision second, implementation third — is the point.
- **Syncing the log.** `attempts` is the server's record and arrives at F3. This is a local
  convenience for a local figure.
- **Deciding whether a zero streak should be shown at all.** A design question, still open from
  `f2-home-reduced`.

## What this builds on

`StreakPolicy`, which already counts days and takes today as an argument, so nothing about counting
changes — only where the days come from.
