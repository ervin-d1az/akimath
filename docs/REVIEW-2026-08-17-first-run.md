# Review round — `f2-onboarding-first-run`, 2026-08-17

One change: the first run. `0.2 Bienvenida`, `0.3 Primer reto`, the flag that makes it happen once,
and the gate that reads it.

**Outcome: 4 critical bugs, 3 blocking conventions findings, all closed.** Suite 610 → **622**. Three
rules added to the rulebook, because three findings had no ID to cite.

Every one of the four criticals was **live on `dev` with a green suite**, and three of them were on
the path a child walks in their first sixty seconds.

---

## The four criticals

### Every first verdict in the app reported a negative time

```dart
late DateTime _startedAt = widget.now();
```

A `late` field with an initializer evaluates it on **first read**. Nothing reads `_startedAt` while
the item is on screen, so its first read was inside `_submit()` — *after* `finishedAt` had been
captured three lines above. The subtraction therefore ran backwards.

The `TIEMPO` tile read **`−7,4 s`**. On items 2..n it was right, because `_next()` assigns the field
before the initializer can fire — so the bug was invisible to anyone who kept tapping, and unmissable
on the one screen that has only ever one item.

Time is the single thing the app promises to measure (`req-quiet-timing`: *no visible timer, time is
measured quietly*), and the only place it surfaces printed a negative. Fixed by assigning in
`initState`. Found by the bug hunt; it predates this change by nine commits.

### "Intentar otro" completed the first run

`onFinished` was bound to `_next`, and `_next` is the target of *every* forward affordance in the
round — including the verdict screen's continue button, whose label the verdict picks:

```dart
label: _correct ? 'Siguiente' : 'Intentar otro',
```

So on the one-item tutorial, a wrong answer offered **"Intentar otro"** — *try another* — and tapping
it wrote `akimath.onboarding_complete.v1` and left for the home. **The child who answered wrong, the
one who most needs the screen whose whole job is teaching the answer format, was the one who
permanently lost it, by tapping the button the app offered them.** No settings screen reads that flag
and nothing else clears it: recovery is a reinstall.

The callback was bound to the *verb* rather than to the *event*. The first run now completes when the
item is **solved**, which is what `req-first-run` said all along: *"from the welcome screen to a
solved item"*.

### "Saltar este reto" completed it too

The same root cause, one row lower. Skipping routes to `_next`, and on the last item `_next` finished
the round — so one tap on the skip control ended the first run with nothing solved.

Fixed structurally rather than by a flag: **a round shows the skip control only when it has another
item to skip to.** Derived from `items.length`, so a one-item round cannot be built with the control
by accident, and the general case is right too — skipping was already a no-op on a one-item round, it
just did damage on the way.

### The tutorial claimed a streak, and the home behind it disagreed

`_submit` appended `finishedAt` to the streak days unconditionally, so a round with no `DayLogStore`
— the teaching item, deliberately — still reported `streakLength([finishedAt], finishedAt) == 1`.

A first-run player answered the teaching item, was shown **`RACHA 1`**, tapped `Siguiente`, and
landed on a home reading **`0`**, because the home reads the store and the store had never been
written.

That is precisely the shape `StreakPolicy` was fixed for one round ago — *"two screens, one morning,
neither number right"* — reintroduced in the other direction, on a player's very first result. The
figure shown is now the figure the store will yield: today counts only if today was recorded.

---

## Three blocking conventions findings

**A test whose name said the opposite of its body.** `'skipping the item is not finishing it either'`
asserted `expect(finished, 1)` — that skipping *does* finish it. It was written while I was looking
at the behaviour and mistook it for the intent. A grep for the rule would have returned a false
positive on a test proving the reverse. This is PROC-11's fourth instance, and the worst kind: not a
claim larger than the check, but a claim inverted from it.

**Two doc comments describing behaviour the code did not have.** `first_item_screen.dart` said *"the
flag is set by answering, not by escaping"* above a screen with two escapes that set it, and *"it
measures nothing"* above one that displayed `RACHA 1`. No rule ID covered comment *accuracy* —
CMT-1 governs whether a comment should exist, not whether it is true — so **CMT-2** was added.

**A parenthesised scope in two commit subjects.** `feat(onboarding):` against GIT-2's *no scope in
parentheses*, and the only two such subjects in a 42-commit history. Amended before pushing.

---

## Two instrument defects, found while writing the tests

Neither was in the product. Both were tests that could not fail.

**`pumpWidget` twice is not a second launch.** The trees are structurally identical, so Flutter
*updates* the existing elements: `initState` never runs again and the flag is never re-read. The
"second launch goes straight to the home" test passed for that reason, and would have passed with the
flag deleted. `_relaunch` unmounts first, and a control test asserts that a run which *did not*
finish still opens on the welcome.

**"No pack was read" is also true of a harness that reads nothing.** The asset-channel recorder now
has a control that watches `HomeRoute` read the pack through the same `rootBundle`, so the silence in
the other test is evidence rather than an absence of evidence.

---

## Three rules added

Each because a real finding had no ID and had to be filed under something adjacent.

- **CMT-2** — a comment that states behaviour the code does not have is a defect, fixed with the code
  in the same commit.
- **PROC-12** — the change satisfies its approved delta spec; a `SHALL` the code does not meet is
  blocking. Two of the four criticals violated a `SHALL` and were both filed under PROC-11 for want
  of an ID.
- **PROC-8** gained a clause. Its first sentence — *git cannot prove anything about a path it does
  not track* — reads as "`git diff` is never proof", and a ledger in this very change said so. For a
  **tracked** file `git diff --quiet` *is* the proof; the checksum is the substitute for the
  untracked case.

---

## What Tier 2 found that 610 green tests could not

The teaching item was `7 + 6`. So is `add-1` — the starter pack's **first** item, which means the home
previews it as `RETO DEL DÍA` and `Empezar la serie` opens with it. A new player solved it in the
tutorial and met it twice on the next screen.

Invisible by construction: the screen is handed its item and the home tests are handed a fixture, so
the two never met. Two launches on a simulator showed it in seconds. It is now `5 + 8`, and a gate
reads the **real** pack and fails on any collision.

Also seen on the device and deliberately not changed: the teaching item wears the series'
`Reto 1` / `Nivel 1` header. `docs/decisions/OPEN.md` §5.

---

## Evidence

- `flutter analyze --fatal-infos` — *No issues found!*
- `flutter test` — **622 green** (610 before the fixes, 571 before the change).
- Tier 1b, four falsifications on `round_screen.dart`, each reddening only its own tests:
  the streak (1), the wrong-verdict continue (2), the lazy start instant (2), the skip control (3).
  Restored from a backup copy and proved byte-identical with `diff -q` — the file is tracked *and*
  had uncommitted work on it, so neither `git checkout` nor a bare `git diff` was usable.
- Tier 2 — iPhone 17 simulator: both screens, the write observed in the simulator's own defaults, and
  an unmodified second launch opening on the home.

## Still open

- The tap-through from `0.2` to a submitted answer is not automated: no assistive access for
  `osascript` (`-1719`), no `simctl tap`, no `idb`. Mechanising it wants `integration_test`, which is
  a decision of its own.
- `docs/decisions/OPEN.md` §5 — the tutorial's `Reto 1` / `Nivel 1` header.
- A one-item round still labels its retry *"Intentar otro"* — *try another* — when there is no other.
  Copy is design's; the behaviour behind it is now correct.
