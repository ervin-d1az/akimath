# Tasks — the day log

- [x] 1.1 `DayLog`, test-first: days not moments, bounded retention, a round trip, and a decoder
      that never throws.
      **Done.** 11 tests. One found a real trap: `DateTime.tryParse('2026-13-45')` **parses**,
      rolling over into February 2027, so a corrupt entry would have recorded a day the player was
      not there. The decoder now requires the parse to round-trip to its own text.
- [x] 1.2 `DayLogStore` seam plus `InMemoryDayLogStore`.
      **Done.** 6 tests. In memory is not a stub — it is the correct implementation of "remember
      within a session", and it makes the streak true rather than decorative.
- [x] 1.3 `RoundScreen` records the day on submit, **right or wrong**.
      **Done.** The streak counts days practised, not days won.
- [x] 1.4 `HomeRoute` owns the store and re-reads it when a series ends.
      **Done.** Re-reads rather than incrementing a local tally: the store is the source of truth,
      and a screen keeping its own count is a second answer to the same question.

## 2 · Evidence

- [x] 2.1 **Tier 1** — analyze clean, **532 Flutter tests** green (513 before).
- [x] 2.2 **Tier 1b** — the round-trip requirement in 1.1 is the falsification: written against a
      decoder that accepted `2026-13-45`, it failed with
      `Expected: empty / Actual: [DateTime:2027-02-14 00:00:00.000]`.
- [ ] 2.3 **Tier 2 — not run, and why.** The behaviour is a sequence of taps: start a series, answer,
      return, and watch the pill rise. `xcrun simctl` cannot drive a tap, so a device pass would show
      only the same static home already captured in `f2-home-reduced`. The full sequence **is**
      covered end to end by `home_route_test.dart`, through the real widgets. Stated rather than
      skipped (PROC-5), and it lands the moment there is a reason to run the app by hand.

## 3 · The decision this change does not take

**Persisting between launches needs a plugin**, and adding one is DEP-1's — see design D1. The audit
is done so the answer is a yes or a no: `shared_preferences` and `path_provider` are both Flutter-team
packages wrapping platform storage, neither makes a network request, and `shared_preferences` is the
smaller surface for one string under one key. `dependency_allowlist_test` will go red on the addition
by design, and amending it is the other half of the same decision.
