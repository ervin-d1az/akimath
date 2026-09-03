# SOLID audit — the frame, the entry and the two roots

Scope: `app/lib/features/home/`, `shell/`, `map/`, `splash/`, `onboarding/`, read at
`653a17b`. Documentation only; no production code was changed.

## Verdict

This module is a composition layer with an unusually good policy layer under it and one
missing module in the middle. Almost every decision it makes has already been lifted into a
pure function — `visibleTabs`, `streakStateFor`, `streakNoticeFor`, `packRefresh`,
`bagWorthShowing`, `practisedWith`, `calibrationPlan`, `readSkillMap` — and the shell's own
structure (`AppTab`, `TabStack`, `RootScaffold`'s session) is the best-argued code in the
repository. What is missing is a module that owns **"a round happened."** Five play surfaces
across three features each hand-wire five recorders — the day log, the series cursor, the
practised-step record, the answer record and the attempt journal — and nothing but a doc
comment says which surface owes which. The most expensive thing in this module is that
matrix: it has already been got wrong **twice** in a shipped build — `MapRoute` recorded
neither accuracy nor attempts, and the calibration probe graded ten items and recorded none of
them — and the next play surface will be a sixth column that somebody has to fill in from
memory. `HomeRoute` is not the problem — see finding 3 for where it does overreach, which is
narrower and cheaper than its length suggests.

**Update, `fix-the-calibration-counts-where-it-should`:** the probe's cell was the one this
audit could not read as decision or omission, and it was an **omission**. The probe already
advanced the series cursor, which is what `4.1` prints as `RETOS`, and `0.7` says in its own
comment that probe items are *"challenges this player did"* — so two of the three device
figures were wired and one was not. `CalibrationItemScreen` now reports each graded item and
`OnboardingFlow` records it, the same seam `RoundScreen`/`HomeRoute` already use. **Finding 1
itself is untouched**: the fix wires a sixth surface by hand, which is exactly what the finding
says is too easy to forget.

---

## Findings, most expensive first

### 1. Nothing owns "a round happened", so five surfaces wire five recorders by hand

**Principle: SRP.** Two people ask for changes here. One owns a *screen* — where a round is
launched from, what it looks like, what happens on the way back. The other owns *what the app
records about practice* — the streak, the cursor, the ladder, accuracy, the sync journal.
Today the second person has no module: their five recorders live in `features/home/data/`,
`features/map/data/`, `features/stats/data/` and `features/sync/`, and their wiring is
re-decided at every launch site.

**Where.** The five surfaces:

| Surface | day log | series cursor | practised step | answer record | attempt journal |
|---|---|---|---|---|---|
| `home_route.dart:786` `_startSeries` | yes (795) | yes (797) | n/a | yes (811) | yes (798) |
| `home_route.dart:673` `_startPuzzle` | yes (689) | n/a | n/a | n/a | n/a, said (667) |
| `map_route.dart:464` `_practise` | yes (473) | no, said | yes (515) | yes (501) | yes (487) |
| `onboarding_flow.dart:195` probe | no, said (210) | yes (157) | n/a | yes, since `fix-the-calibration-counts-where-it-should` | n/a |
| `first_item_screen.dart:72` teaching item | no, said (16) | n/a | n/a | n/a | n/a |

*n/a* is a cell that cannot be filled — a solved board is not an answered item and leaves no
attempt row, a probe in pack order names no single family's ladder, a fixed teaching item comes
from no pack. **The probe's attempt-journal `n/a` is the one those three clauses did not reach,
and it now needs to**, because the answer-record cell beside it stopped being `no`: a reader who
accepts *the probe is practice, graded by the same `gradeItem`* will ask why those answers never
reach the server. Verified rather than inferred — `AttemptSync.record`
(`attempt_sync.dart:72-75`) returns early when `readIssuedItemId(itemId)` is null, and the probe
reads the **bundled** pack through `OnboardingFlow.reader`, whose items carry no `packId#index`
for the server to resolve. Journalling one would file a batch that can only come back a 404, and
`journalAfter` drops that. The first run also holds no session, so there would be nothing to
flush with; the address is the structural half. *said* is a real "no" with its reason written
down: `home_route.dart:667`, `onboarding_flow.dart:210`, `first_item_screen.dart:16`, and
`practised_steps.dart:6` for `_practise`'s cursor.

**That left one unexplained cell, and it was live.** The probe graded ten items with
`gradeItem` and reported none of them, so those ten were absent from the accuracy `4.1 Perfil`
prints. Whether that was a decision or an omission was not readable from the code — which was
the whole finding: nothing in the codebase could be consulted to tell them apart.

**It has since been settled as an omission, by the one fact that discriminates.** The probe
*already* moved a Perfil figure — `_afterProbe` advances the series cursor and
`profile_route._readChallenges` reads it into `RETOS` — and `0.7` states the intent
(`onboarding_flow.dart`, `challenges: 1 + _outcome.answered`, *"Both were graded on the
device, so both are challenges this player did"*). A decision that probe answers are practice
had been taken and written down; only two of the three figures were wired to it. The two
arguments for the other reading do not survive the source: `calibrationPlan(pack) =>
pack.take(10)` is pack order, so the probe has no difficulty skew to misrepresent (it serves
the very items the home would have), and the server's *"a session that only calibrated"*
(`history.ts:103`, `rating.ts:114`) is item-difficulty calibration in the rating engine, not
this probe — and what it withholds is an **unmeasured** quantity, where accuracy here was
measured on the device by the same `gradeItem` the round uses.

**Cost, now paid twice.** `map_route.dart:86-100` is the first receipt, in the code's own
words:
*"The home wires this for a series; the map did not, so five items answered from a topic moved
neither figure"* and *"a topic run reached the server as nothing: no attempt row, no history
entry, no rating."* Two of five recorders, missed on a root that shipped, found on a device.
The probe was the same shape of miss, one recorder rather than two, and it is now fixed one
surface at a time — which is the point rather than a resolution. Adding a sixth surface still
means reading four files to reconstruct a table that exists nowhere.

**Same root, second symptom: `features/home/` is a shared kernel wearing a screen's name.**
Seven files outside `home/` import from it — `map/ui/map_route.dart:14-18`,
`map/policy/skill_map.dart:35`, `map/policy/practice_series.dart:21`,
`profile/ui/profile_route.dart:11-14`, `round/ui/round_screen.dart:17`,
`states/policy/streak_notice.dart:13`, `states/ui/streak_lost_screen.dart:8`,
`onboarding/ui/first_run_gate.dart:6`, `onboarding/ui/onboarding_flow.dart:8`,
`onboarding/ui/calibration_item_screen.dart:12`. `DayLog`, `DayLogStore`,
`SeriesCursorStore`, `series_families`, `broken_run` and `streak_state` are not the home's —
they are the app's, and the directory name gives no one that warning.

**Direction.** Move the practice record into a feature of its own — `day_log.dart`,
`day_log_store.dart`, `prefs_day_log_store.dart`, `series_cursor_store.dart`,
`series_families.dart`, `broken_run.dart`, `streak_state.dart` out of `home/`; `puzzle_menu`,
`puzzle_of_day` and `offline_notice` stay, because they really are the home's. It is a
mechanical move: the `pure_boundary_test.dart` root is a glob over `features/*/policy/`, so
the new directory is gated the moment it exists. Then give that module the one thing it is
missing — a value that says what a play surface owes, so a new surface declares it rather than
remembering it, and the table above becomes a type instead of a doc comment.

---

### 2. Two owners of "which pack is in play", and they have already disagreed

**Principle: SRP / DRY.** The responsibility *decide which pack this device plays and whether
it is playable* has two implementations. Both routes resolve `_issued ?? bundled`, both call
`readIssuedPack`, both open an `ApiClient` in an identical private method, and they do not
agree on the answer.

**Where.**

- `home_route.dart:601` and `:605` — `_issued ?? snapshot.data`, then
  `pack.isExpiredAt(widget.now().toUtc())`, which draws *"Estos retos ya vencieron."*
- `map_route.dart:233` — `_issued ?? await widget.reader.load()`, and **no expiry check
  anywhere in the file**. `grep isExpiredAt lib` returns `home_route.dart:580`,
  `home_route.dart:605` and the definition at `content/model/pack.dart:85`.
- `home_route.dart:401-411` and `map_route.dart:302-312` — `_fetchOverASocket`, byte-identical.
- `home_route.dart:387-399` and `map_route.dart:288-299` — the `readIssuedPack` /
  `on FormatException` adoption, written twice.
- `home_route.dart:427-433` and `map_route.dart:536-542` — `_flush`, identical.

**Cost, live and user-visible.** The day `assets/packs/starter.json` lapses — no server
involved, no session needed — Inicio refuses to play and says so, and Mapa draws a full map of
topics with a working `Practicar 5 retos` on every one of them. Two roots of the same app
answering opposite ways about the same file. A second cost, from the same copy: `MapRoute`
has no injectable clock, so `map_route.dart:492` reads `DateTime.now()` directly into the
attempt's `at` field where `HomeRoute` threads `widget.now` through six call sites — a
practice attempt's timestamp is the one thing in the sync path no test can fix.

**Direction.** One function that answers *what pack is in play right now, and is it playable* —
it takes the issued pack, the bundled pack and a moment, and returns the pack or the reason
there is none. `_playablePack` (`home_route.dart:568`) is already three quarters of it and is
private to the wrong file. Both routes then call it, and `MapRoute` grows the `now` parameter
it needs to.

---

### 3. `HomeRoute` composes, except at the launch, where it arbitrates

**Judgement first, because the length invites the wrong one.** Most of what `HomeRoute` holds
is composition and belongs there. A route is where a pack, a navigator, a clock and four
stores meet, and it is the right place for `_startSeries`, `_startPuzzle`, `_showSolved`,
`_SeriesSession` and the `FutureBuilder`. Every leaf decision it needs has already been lifted
out — `packRefresh`, `streakStateFor`, `streakNoticeFor`, `bagWorthShowing`, `seriesPlan`,
`puzzlesOfDay`, `fetchAsk`/`issueAsk` are all pure and all tested without a widget. That is a
well-factored file, not a god object, and the audit's second-most-quotable line should be that
969 lines of route can be this disciplined.

**Principle: SRP.** One thing in it decides rather than composes: **which of the launch's
competing full-screen interruptions a player gets, and in what order.** That decision is not
in a policy. It is expressed as the await sequence in `_open` (`:236-255`) plus three pieces
of ad-hoc state — `_noticeSettled` (`:166`), `_offlineSettled` (`:172`) and `_sessionsOpen`
(`:186`) — read at `:446`, `:525` and `:533`. The invariant it enforces is real and
unwritten: *at most one uninvited full screen per launch, the streak outranks the offline
notice, and neither may land on a session the player opened themselves.*

**This is not PURE-1 restated, and the difference is why it could happen.**
`pure_boundary_test.dart` checks that whatever is inside `features/*/policy/` stays free of
IO. Nothing checks that a decision ever *reaches* `policy/` — so this one accumulated three
latches and an await order with every gate green, in a file whose neighbours are all pure.

**Cost.**

- Each of the three fields carries a multi-line comment about an ordering hazard
  (`:159-186`, `:449-451`, `:528-530`) because the rule they implement is not stated anywhere
  as a rule. A fourth interruption — a lapsed pack, a pack refresh, an account conflict — is a
  fourth latch, a new position in the await chain, and a re-derivation of all three
  interactions from scratch.
- The arbitration has no proposition to test, so its most interesting case is untested.
  `streak_notice_route_test.dart` names eleven cases and `offline_notice_route_test.dart`
  twelve, and **no file in `test/` or `integration_test/` pumps both screens** — the two
  grep sets overlap only in a comment (see Coverage). So nothing exercises a launch on which
  both are due. That case is reachable: a signed-in player, a dead network, and
  nothing solved at 20:00 gets `4.12`, taps *Más tarde*, and `_open` proceeds straight to
  `_tellOfflineIfDue` with `_sessionsOpen` back at zero — two uninvited full screens in a row.
  Whether that is right is a product question nobody has been asked, because the code never
  poses it.

**Direction.** One pure function in `features/home/policy/`, the same shape `streakNoticeFor`
already has one level down: given the streak state, `lostShownOn`, the `PackAsk`, the bag size
and `now`, return **at most one** `LaunchInterruption`. `_open` then awaits its inputs and
shows what it is handed; the two latches collapse into "this launch has been settled", and
`_sessionsOpen` stays where it is, since it is about the screen and not about the decision.

---

### 4. `AppShell`'s navigation seam has no production caller, and its only caller is its test

**Principle: SRP / ISP.** `AppShell` has two jobs. One — cream, safe area, optional banner,
child — every screen uses. The other — deciding whether a bottom bar is drawn — nothing uses.

**Where.** `app_shell.dart:16-17` declares `roots` and `navBar`; `:38-41` `_bar()` calls
`visibleTabs(roots)` and then `navBar?.call(tabs)`. `grep 'navBar:' lib test integration_test`
returns three hits, all in `test/features/shell/ui/app_shell_test.dart`. Nothing in `lib/`
passes it, so `_bar()` returns `null` on every frame the app ever draws. The real bar is
composed in `root_scaffold.dart:195` (`visibleTabs(rootsPresentToday)`) and `:226-232`.

**Cost.** Two things, and the second is the sharper one.

- Two call sites of `visibleTabs`, and a reader who changes bar composition has an even chance
  of editing the one that cannot render.
- `app_shell_test.dart` reads as coverage of *"the bar appears when a second root exists"* and
  is coverage of a code path production never runs. That is PROC-11's fifth bullet in a new
  costume: an assertion that carries no information about the shipping app. The behaviour it
  looks like it protects is protected only by `root_scaffold_test.dart` and `nav_bar_test.dart`.
- The doc comments say the opposite of what the app does, which is CMT-2: `app_shell.dart:8-10`
  — *"no bottom navigation … When the skill map lands at F5 the same rule draws it, with no
  change here"* — and `:29-34` — *"no bar exists yet: `AppBottomNav` arrives with the second
  root at F5."* The map landed, the bar exists, it is called `NavBar`, and it is drawn
  somewhere else.

**Second instance, same principle.** `puzzle_menu.dart:30` `puzzleMenu` has zero callers in
`lib/` — `home_route.dart:650` calls `puzzleName` per puzzle instead — yet
`test/features/home/policy/puzzle_menu_test.dart` is a whole file about it, and both
`home_screen.dart:192` and `CLAUDE.md` state that the home names its cards through it.

**Direction.** Delete `roots` and `navBar` from `AppShell` and let the class do the one job
every caller uses it for; move `app_shell_test.dart`'s two bar cases onto `RootScaffold`,
where they will measure the app. Either give `puzzleMenu` its caller or delete it with its
test — the two functions are one line apart and only one of them ships.

---

### 5. `RootScaffold` owns the session correctly, and holds one decision that should be below it

**Judgement.** The session belongs here and this is not a god object forming. Two roots must
agree about whether there is an account; `IndexedStack` keeps every root mounted
(`:219`), so a session held inside one could never reach another; the common ancestor is the
only place it can live. The project has already paid for the proof — PROC-13 exists because
`TabStack` captured its child once and *"signing in changed nothing in the running app"*, and
`tab_stack.dart:18-26` and `:83-91` are the fix. Five responsibilities in 289 lines
(current tab, the session, per-tab navigator keys, back handling, root construction) is what a
composition root is.

The tripwire worth naming: `_rootFor` (`:237-288`) hardwires which root receives which
cross-root fact, and today there are two facts (`visibility`, `session`). It stays a wiring
switch while that number is small. The day a third shared fact appears, this switch becomes
the place where *who needs what* is decided, and that is a different job.

**Principle: SRP, narrowly.** `_askForAToken` (`:134-153`) holds a real decision: *a build
with no `NEON_AUTH_BASE_URL` must answer `AuthUnreachable` rather than ask, so a credential is
kept rather than deleted.* Its own comment records what the alternative cost — an empty base
URL parsed to a relative `Uri`, came back 400, was read as `AuthRefused`, and **the launch
deleted a credential it had never managed to ask about**.

**Cost.** That is exactly the class of decision `sessionRestore` was made pure for, and it sits
one frame above it inside a `StatefulWidget`, next to a `debugPrint` and an `AuthClient`
constructor. It can only be checked by pumping the whole shell, and the shape of the check is
"did a store get told to forget", which is two inferences away from the rule.

**Direction.** One pure predicate beside `sessionRestore` — given the configured base URL,
either *ask* or *refuse to ask, with the reason* — and `_askForAToken` becomes the two-line
adapter that carries it out.

---

### 6. Doc comments describing a codebase from two changes ago

**Not a SOLID finding.** It is CMT-2, which this rulebook calls a defect and which no test
enforces, and it is worth an entry because in this module the doc comments *are* the design
record — CLAUDE.md is written from them.

Two would cause a reader to do wrong work:

- `home_route.dart:306-309` — *"The better thing is to persist the id and rebuild through
  `GET /packs/{packId}` … the client has no operation for it yet, and that is the next
  change."* It sits directly above `_askForPack`, which reads `_issuedPacks`, branches on
  `packRefresh`, and calls `api.fetchPack` at `:407`. The work described as pending is the
  work the function performs. A reader believes the comment and writes it again.
- `app_shell.dart:8-10` and `:29-34` — cited in finding 4. They describe the seam as staged
  and about to be consumed; it is dead.

Three are decorative and cost nothing but credibility: `nav_bar.dart:9` (*"the shell has
always accepted and never been given"* — `root_scaffold.dart:228` gives it),
`day_log_store.dart:5-15` (*"today only the in-memory side of it exists … the persistent
implementation is one file behind a decision"* — `prefs_day_log_store.dart` is the next file
in the directory), and `first_item_screen.dart:31,39` (*"the only path that completes the first
run"*, *"the flag is set by answering"* — since `OnboardingFlow` landed the flag is set at
`0.7`, by `onboarding_flow.dart:217`).

**Direction.** Fix the two load-bearing ones in the next change that touches those files.

---

## What this module gets right, and why

**`visibleTabs` and `AppTab` are an Open/Closed success, and the claim checks out.** The
comment at `visible_tabs.dart:29-32` asserts the rule has never been edited while the number
of roots went none → two → three → two → three. Verified rather than repeated: five commits
have touched the file (`ed8ba0e`, `19faca4`, `b1566ab`, `fa3ec70`, `ae026c4`), the function
body at `:56-63` appears exactly once in the whole history — as an addition in the first of
them — and **the enum at `:12` was written complete with all four tabs on day one and never
edited either**. Every one of the four later commits changed only the `rootsPresentToday`
literal at `:33`: `{home}` → `{home, profile}` → `+progress` → `−progress` → `+skills`.

Why it worked is worth copying exactly. The abstraction was fixed at **the design's** shape —
the four homes declared rule 1 names — and not at the code's shape on the day it was written.
So the thing that varies (*which homes have a destination today*) became a one-line constant,
and the thing that does not (*a bar needs two tabs, in declaration order*) became a function
nobody has had a reason to open. The tell that this is real and not luck: `rootsPresentToday`
moved in **both** directions, and removing a root cost the same one line as adding one. Copy
the split, not the file: name the closed set from the source of truth, keep today's subset as
data, and let the rule read the subset.

**Every leaf decision is already pure, and the pure/adapter seam is drawn at the right place.**
`streak_state.dart`, `streak_notice.dart`, `offline_bag.dart`, `offline_notice.dart`,
`practised_steps.dart`, `skill_map.dart`, `practice_series.dart`, `calibration.dart` and
`puzzle_of_day.dart` are all functions of their inputs, and each carries the argument for why
it is separate from its neighbour. Two are worth reading as models: `streak_notice.dart:6-10`
explains why *where the streak stands* and *whether to interrupt* are two functions rather than
one, and `broken_run.dart:10-23` explains why `dayOfNewRun` is a constant rather than a
special case inside `streakLength`. Both are refusals to overload one function with two
questions, written down at the point of refusal. That is the habit finding 3 asks the launch
arbitration to acquire.

**`OnboardingFlow` is a closed state machine, and it replaced a boolean.** `OnboardingStep`
(`onboarding_flow.dart:23-41`) has six arms and `build` (`:167-220`) is one exhaustive switch
over them, so a seventh screen is a compile error rather than a branch somebody forgets. Its
own comment records that this used to be a `bool` and why two screens fitting in a flag is not
an argument for six. The skips are data-driven too — `_afterTeachingItem` (`:145`) and
`_afterProbe` (`:151`) decide from *what there is to say*, not from a flag per screen.

**`FirstRunGate` routes; it does not decide.** It reads one boolean, owns writing it
(`:104`, `:136`), and picks a widget. The one thing that could have been a decision — what to
show while the answer is unknown — is handled by making the field `bool?` (`:79`) and treating
*unknown* as a third state with a screen of its own (`:113-119`), rather than guessing a
default. The comment at `:19-24` argues both wrong guesses and picks the honest frame. **And
the boolean has one meaning**: `store.isComplete()` says *the run has been walked*, it is
written at exactly two places, both inside the gate, and both after the last screen of the run
rather than after the teaching item — which the file's own history shows was the earlier,
wrong reading. The only wart is two pass-through parameters (`reader`, `seriesCursor` at
`:30-31`) that the gate never uses and only forwards; that is two parameters, not a finding.

**`SplashScreen` is clean.** Two variants as a closed enum, no state, no work started, a
`_gap` constant carrying its own reason, and the one unexplained-looking number (the 60px
radius at `:81`) is the one with a comment. It is the rulebook's own FUN-2 example, fixed.

---

## Coverage

**Read in full**: all 46 files under the five directories (6,605 lines), plus
`app/lib/main.dart`, `features/states/policy/streak_notice.dart`,
`features/states/policy/offline_bag.dart`, `CLAUDE.md` and
`.claude/conventions/craftsmanship.md`.

**Verified rather than assumed**: the `visibleTabs` history, with `git log -p --follow`; every
cross-feature import into `home/` and `shell/`, with grep over `lib/`; the callers of
`AppShell.navBar`/`roots`, `puzzleMenu`, `onCreateAccount` and `isExpiredAt` across `lib/`,
`test/` and `integration_test/`; and the absence of any test exercising both notice screens,
by grepping all of `test/` and `integration_test/` for `OfflineScreen` (three files) and for
`StreakAtRiskScreen|StreakLostScreen` (four files) and comparing the lists — they overlap in
exactly one file, `test/features/states/ui/offline_screen_test.dart:68`, where the other
screen appears in a comment and is never pumped.

**Not covered**: `features/profile/`, `round/`, `puzzle/`, `sync/`, `stats/`, `account/`,
`preferences/`, `auth/` and `states/` except where this module reaches into them; the design
documents behind the screens; and anything about rendering, layout or copy, which the brand
gates already measure. No production code was run — this is a reading audit, and finding 2's
expired-pack divergence is argued from the source rather than reproduced on a device.

**Discarded as taste — eleven candidates**, each considered and rejected for having no cost:

1. `_startOfDay` written privately five times (`day_log.dart`, `streak_state.dart`,
   `broken_run.dart`, `streak_notice.dart`, `streak_policy.dart`) — two lines, private,
   never drifted.
2. `SplashScreen` collapsing its enum back to `final bool onGreen` (`:38`) for four ternaries
   — a third splash treatment is speculative and nobody has asked for one.
3. `PackAsk` having three arms where the one call site (`home_route.dart:525`) distinguishes
   two — the third arm means something to a reader.
4. `FirstRunGate.reader` and `.seriesCursor` as pure pass-throughs.
5. `FirstRunGate.onCreateAccount` never wired in `main.dart:35` — DR-P2 says null draws no
   button, and the account door is on Perfil.
6. `HomeRoute`'s length and parameter count — `dart_code_linter` gates that, and length was
   never the question.
7. `_SeriesSession` as a private nested `StatefulWidget` inside `home_route.dart:889` — its
   own justification at `:883-888` holds.
8. The exhaustive switches over `Puzzle` (`home_route.dart:695`) and `AppTab`
   (`root_scaffold.dart:237`) — an exhaustive switch over a sealed type is not an OCP
   violation, and both are load-bearing: the first replaced an `is! KenKenPuzzle` guard that
   left four formats unreachable.
9. `MapRoute._read`'s `on Object catch (_)` (`:254`) — deliberately broad, with the reason
   stated, matching what `PackReader` already does.
10. Three copies of `_refreshOnComingToTheFront` (`home_route.dart:273`, `map_route.dart:216`,
    `profile_route.dart:192`) — four identical lines each, and the remedies that would remove
    them (a mixin, a base `State`) are the Java-shaped fixes this rulebook rejects. They have
    never drifted, and each copy's doc says what *that* root re-reads, which is the part worth
    keeping.
11. `AppShell.banner` looking unused from inside this module — `auth/`, `profile/` and
    `states/` pass it.
