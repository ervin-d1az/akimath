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
- [x] 2.3 **Tier 2 — superseded by 3.5 below**, which ran it once CocoaPods was installed. This box
      said "not run" for a day and stayed open twenty-three lines above the proof; a ledger that
      contradicts itself is worse than one that admits a gap.

## 3 · Persistence — decided, built, and blocked on tooling

- [x] 3.1 **DEP-1 decision taken by Ervin, 2026-08-16: add `shared_preferences`.**
      The gate fired first, exactly as designed:
      `Expected: {flutter, cupertino_icons, meta} / Actual: {…, shared_preferences}`.
      That failure **is** the mechanism working — it cannot judge whether a package phones home, so
      it summons someone who can.
- [x] 3.2 The audit is recorded in the allowlist itself, beside the entry, because DEP-1 requires it
      in the same change. Verified offline rather than asserted: every one of the six federated
      packages resolves to `github.com/flutter/packages`, and grepping the shipped Dart of the
      facade, the platform interface and both mobile implementations for `HttpClient`,
      `package:http`, `Socket` and `WebSocket` returns **zero files**.
- [x] 3.3 `PrefsDayLogStore` — one string under one key, behind the existing seam. 8 tests against
      the **real** `SharedPreferencesAsync` API over the plugin's in-memory backend, which is why
      `shared_preferences_platform_interface` is a **dev** dependency: it does not ship, which is the
      reason the allowlist scopes itself to runtime.
- [x] 3.4 `HomeRoute` defaults to it.
- [x] 3.5 **Tier 2 — done 2026-08-17, once CocoaPods was installed.**

      It was blocked for a day, and the blocker was the machine: `flutter run` failed with
      *"CocoaPods not installed — without CocoaPods, plugins will not work on iOS"*, so every
      screenshot taken during that attempt was of the **previously installed, plugin-free binary**.
      That is why one showed a stale verdict screen and the cold launch showed zero. Confirmed at
      the filesystem rather than guessed: the container's `Library/Preferences/` was empty and the
      key appeared nowhere under the simulator's data. Ervin installed CocoaPods 1.17.0.

      **The proof is two launches of two different binaries**, because one binary cannot show that
      a value outlived the process that wrote it.

      *Launch 1* — a harness recording **yesterday**, chosen so the streak can only read non-zero if
      the value genuinely round-tripped: `DIAG recorded, log now: [2026-08-16 00:00:00.000]`. The
      write is then verified **on disk**, not inferred from the app:

      ```
      Library/Preferences/com.akimath.akimathApp.plist
        "akimath.day_log.v1" => "2026-08-16"
      ```

      One key, a bare date, no time — `req-day-log-days-not-moments` confirmed against real device
      storage rather than a fake.

      *Launch 2* — `main.dart` restored and verified by checksum to
      `afe905a7c7128cb9e2ea6b00dcebfac104549c00c7eb3e90879f8237403601b6`, with
      `grep -c 'PrefsDayLogStore\|DIAG' lib/main.dart` returning **0**: the running build contains
      no write code at all. The home reads **1**. `evidence/launch-2-persisted.png`.

      Two things fell out of it for free. The reinstall between launches **preserved** the container,
      so persistence survives `flutter run` and not merely a relaunch. And with the stored day being
      the 16th and the run on the 17th, `StreakPolicy`'s "yesterday still counts" is now confirmed on
      a device and not only in a unit test.

## 4 · What that incident cost, and what it changed

`PrefsDayLogStore` swallowed storage errors without a word, so a store that could not write **at
all** was indistinguishable from one that worked — the app showed zero and nothing said why. That is
the defect the tests could not see, because the tests use a backend that always succeeds.

Failures are now reported through `debugPrint`. It costs nothing in release and is the difference
between a mystery and a message. Recorded here because the lesson is not "install CocoaPods" — it is
that **a tolerant adapter must still be a loud one**.

## 4b · A second silence, found the next day

The `debugPrint` above made failures **visible**. It did not make them **catchable**: both handlers
were `on Exception`, and a key holding the wrong type throws a **`TypeError`**, which is an `Error`.
So a corrupt preference did not produce a logged, tolerated, empty log — it **killed the launch**:

```
type 'bool' is not a subtype of type 'String?' in type cast
  …/shared_preferences_async.dart 84:22  SharedPreferencesAsync.getString
  …/prefs_day_log_store.dart 38:41       PrefsDayLogStore.read
```

Found while writing `OnboardingStore`, which had inherited the same narrow catch from this file.

Both handlers are now deliberately broad, and the reason is written where the next reader will meet
it: **the rule is that nothing about a stored value may prevent a launch, and that is wider than the
exception hierarchy.** Three tests reproduce it — a bool under the key, an int under the key, and a
record that repairs a wrongly-typed one.

Worth naming plainly: the fix that made this adapter *loud* was written yesterday, in this same
change, with a comment about tolerance. Tolerance and reachability are different properties, and
having thought carefully about one is no evidence about the other.

## 5 · The decision this change does not take

Whether a **zero streak should be shown at all** — still open from `f2-home-reduced`, and now more
visible, since a fresh install shows one until the first series is played.
