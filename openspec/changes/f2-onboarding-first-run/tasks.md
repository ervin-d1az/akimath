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
- [x] 4.2 **Tier 1b** — falsified twice, and restored by checksum both times (PROC-8; the file is
      versioned, so `shasum -a 256` before and after is the proof, not `git diff`).
      · `isComplete()` hard-coded to `false` → **1 test red**: *the second launch goes straight to
        the home*.
      · `markComplete()` made a no-op → **7 tests red**, across the flow and the store.
      Checksum after restoring: `be68329c…` — the same file that was hashed before the first edit.
- [ ] 4.3 **Tier 2** — the two screens on the iPhone 17, and a **second launch going straight to the
      home**, which is the whole point and needs two launches to show.
