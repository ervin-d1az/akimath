# Tasks — the first run

## 1 · The flag

- [x] 1.1 `OnboardingStore` — one boolean under one key, on the existing `shared_preferences`.
      **Check:** tested against the real `SharedPreferencesAsync` API over the plugin's in-memory
      backend, the way `PrefsDayLogStore` is.
- [x] 1.2 Unreadable storage reports **not completed**, so the welcome screen is shown (design D3).
      **Check:** red first, against a store that reported completed on failure.
- [x] 1.3 It reports its failures rather than swallowing them.
      **Check:** the `f2-day-log` lesson — a tolerant adapter must still be a loud one.

**Found while building 1.2, and it is wider than this file.** A key holding the wrong type throws a
`TypeError`, which is an **`Error` and not an `Exception`** — so `on Exception` misses it and a
launch dies on a corrupt preference. `OnboardingStore` now catches broadly, because the rule is that
nothing about a stored value may prevent a launch and that is wider than the exception hierarchy.
**`PrefsDayLogStore` has the same narrow catch** and is in the current bug hunt's scope, so it is
left for that round rather than edited underneath it.

## 2 · The screens

- [x] 2.1 `0.2 Bienvenida` — Aki, the bubble, one primary action. No account field.
- [x] 2.2 `0.3 Primer reto` — the fixed teaching item, **Aki absent**, and on submit the flow
      continues to the home.
      **Check:** assert Aki's absence directly; it is a rule the screen could break silently.
      Asserted both ways — absent while solving, present on the verdict — because asserting only
      her absence is also satisfied by deleting her from the app.
- [x] 2.3 The teaching item records **no day** for the streak (design D4).
      **Check:** rewritten. A store *handed to* the flow is a parameter the flow never uses, which
      is dead code pretending to be a test. What is asserted instead is the consequence: after the
      teaching item is answered, **storage holds nothing at all** — no day-log key. Wire a store
      into the screen and the key appears.

**`RoundScreen` gained `onFinished`.** The round cycles items forever, which is right for a
practice series and wrong for a tutorial of exactly one item. With `onFinished` set, the last item
reports and stops instead of composing a second one; with it null nothing changes, so the series is
untouched. `onClose` is routed to **going back, not finishing** — a mistaken tap on close costs
seconds rather than permanently skipping the only screen that teaches the answer format.

## 3 · The flow

- [x] 3.1 `main.dart` chooses onboarding or home from the flag, through `FirstRunGate`.
      **The flag has one owner.** The gate reads it and writes it; `OnboardingFlow` does neither and
      only reports that the run is over. And **neither branch is taken while the answer is unknown**:
      guessing *complete* flashes the home at a new player, guessing *incomplete* flashes the welcome
      at a returning one — which looks like lost progress. The gate shows cream for that frame.
- [x] 3.2 Completing the onboarding sets the flag, and the next launch goes straight to the home.
- [x] 3.3 Register both screens in `screen_registry.dart`, in the shape the app builds them —
      the welcome inside `AppShell`, the teaching item bare, because it composes `RoundScreen` and
      brings its own `Scaffold`. Both pass the shadow and overflow gates at 1.0 and 1.3.

**Found while writing 3.2, and it is wider than this file.** `pumpWidget` twice with a structurally
identical tree is **not a second launch** — Flutter updates the existing elements, `initState` never
runs again, and the flag is never re-read. The first version of the second-launch test passed for
that reason and would have passed with the flag removed entirely. `_relaunch` unmounts first, and a
control test asserts a launch that *did not* finish still opens on the welcome.

## 4 · Evidence

- [x] 4.1 **Tier 1** — `flutter analyze --fatal-infos`: *No issues found!* `flutter test`: **608
      tests, green** (571 before this change).
- [x] 4.2 **Tier 1b** — six falsifications, each reddening only its own tests, each restored and the
      restoration proved.
      · `isComplete()` hard-coded to `false` → **1 test red**: *the second launch goes straight to the
        home*.
      · `markComplete()` made a no-op → **7 tests red**, across the flow and the store.
      · the teaching item put back to `7 + 6` → **1 test red**: the pack-collision gate.
      · `if (store != null) finishedAt` made unconditional → **1 test red**: the tutorial's `RACHA`.
      · `&& solved` dropped from `_next` → **2 tests red**: *Intentar otro* finishing the run.
      · `_startedAt` returned to a `late` initializer → **2 tests red**: the negative first duration.
      · the skip control made unconditional → **3 tests red**.
      Suite back to its count after each. **On the restoration proof:** for the two files that were
      *tracked and clean*, `git diff --quiet -- <file>` is the proof, which is PROC-8's tracked
      branch — an earlier draft of this line claimed the opposite and the rule now says so
      explicitly. For `round_screen.dart`, tracked but carrying uncommitted work, neither
      `git checkout` nor a bare `git diff` was usable: a backup copy and `diff -q` were, and reported
      byte-identical.
- [x] 4.3 **Tier 2** — iPhone 17 simulator (`92FD8A62`), debug build installed with `simctl`.
      · **Launch 1, fresh install** — `0.2` renders: Aki at 200, the bubble, the tagline, one green
        action. Fonts real, nothing clipped.
      · **`0.3`** — `5 + 8 =` at 76 px in Darumadrop, the pink dashed slot, the close control, the
        keypad, `Saltar este reto`. **The `=` is not clipped**, which is the face fix holding against
        real fonts rather than against the test stand-in's ratios.
      · **The write, on real storage** — the app's own `OnboardingStore.markComplete()` run on device;
        `simctl spawn defaults read` then shows `"akimath.onboarding_complete.v1" = 1`. The key is
        stored **unprefixed**: `SharedPreferencesAsync` adds no `flutter.`, which is the one thing
        about this plugin the in-memory backend could not have told us.
      · **Launch 2, unmodified HEAD** — opens straight on the home, on the flag the app itself wrote.
        Streak `0`, so nothing recorded a day.

      · **Re-shot from the final build** (`c5c47ef`), after the fixes, so the four observations are
        one sequence rather than four builds described as one.

      **`simctl uninstall` does not clear the flag.** On a simulator the app's `NSUserDefaults` plist
      sits at `data/Library/Preferences/com.akimath.akimathApp.plist` — the device-wide preferences
      directory, *outside* the app's container — so uninstalling and reinstalling still opens on the
      home. That looks exactly like a broken gate and is not one; a genuinely fresh first run needs
      `xcrun simctl spawn <udid> defaults delete com.akimath.akimathApp`. Recorded because the next
      person to check this will otherwise file the bug I nearly filed.

      **What was not driven, and why.** The tap-through from `0.2` to a submitted answer is not
      automated here: `osascript` has no assistive access on this machine (`-1719`), `simctl` has no
      tap operation, and `idb` is not installed. `0.3` was reached by temporarily rooting `main.dart`
      at it — a versioned-code edit, restored and verified by `shasum -a 256` (PROC-8), as was the
      write probe. Making this mechanical wants `integration_test`, which is a dev dependency and a
      decision of its own rather than a line in this change.

**Found by Tier 2, and the suite could not have found it.** The teaching item was `7 + 6`, which is
`add-1` — the starter pack's **first** item, so the home previews it as `RETO DEL DÍA` and
`Empezar la serie` opens with it. A new player solved it in the tutorial and met it twice on the next
screen. Invisible to every test: this screen is handed its item and the home tests are handed a
fixture, so the two never met. It is now `5 + 8`, and
`app/test/features/onboarding/ui/teaching_item_test.dart` reads the **real** pack and fails on any
collision — falsified by putting `7 + 6` back (1 test red), restored by checksum. It reports the 20
items it compared, so a pack that read as empty cannot pass it silently (PROC-10).

One thing seen on the device and **not** changed: the teaching item wears the series' `Reto 1` /
`Nivel 1` header. Recorded as `docs/decisions/OPEN.md` §5 rather than decided in a session.

## 5 · The review round

- [x] 5.1 `craftsman-reviewer` and `craftsman-bug-hunter` over the landed commit, in parallel.
      **4 criticals, 3 blocking conventions findings, all closed.** Written up in
      `docs/REVIEW-2026-08-17-first-run.md`; three rules added to the rulebook because three findings
      had no ID to cite (CMT-2, PROC-12, and a clause on PROC-8).
- [x] 5.2 The two worst were on the first sixty seconds of a child's first launch, and both wrote the
      flag: **"Intentar otro"** — the button a *wrong* answer offers — completed the first run, and so
      did **"Saltar este reto"**. Both because `onFinished` was bound to `_next`, the target of every
      forward affordance, rather than to the event it names. The run now completes when the item is
      **solved**, and a one-item round has no skip control.
- [x] 5.3 A third was nine commits older than this change and reached every verdict in the app:
      `late DateTime _startedAt = widget.now()` evaluates on first *read*, which was inside `_submit`
      after the finish instant. Every round's first item reported a **negative** duration — the tile
      read `−7,4 s`. Now assigned in `initState`.
- [x] 5.4 Suite 610 → **622**, analyze clean.
