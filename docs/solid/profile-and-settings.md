# SOLID audit — `profile/`, `preferences/`, `states/`, `stats/`, `character_sheet/`

Audited at `653a17b` (`main`). 48 files, 6 469 lines of `lib/`, 5 864 lines of test.

## Verdict

This module is in good shape, and unusually so in the places that normally rot: every decision
that could be a decision is in a `policy/` file, every screen draws what it is handed, and the
absent-affordance rule (a control that cannot act is not drawn) is applied consistently across
six settings screens rather than argued about once. The expensive thing is not any of that. **The
most expensive thing in this module is that the app's one irreversible act — erasure — is the one
request with no seam.** `ProfileRoute` takes `link`, `whoAmI`, `fetchHistory` and `auth` as
injectable closures precisely so a `testWidgets` can drive them, and then constructs an
`ApiClient` inline inside `_openEraseFlow` (`app/lib/features/profile/ui/profile_route.dart:413`),
so the composition that ends a player's account — the door, the flow, the pop, the
`onSessionChanged(null)` — is executed only in production. Everything else here is cheaper: a
directory boundary that does not match its owners, an invariant the file states and then applies
in half its call sites, and some documentation that has drifted past the code.

The second-order theme worth naming: `features/states/` is grouped by *design-document chapter*
(the eight screens numbered 4.8–4.15), not by reason to change. That is a defensible grouping
while the screens are being drawn and an expensive one once they are wired, because it puts the
streak's screens in one directory and the streak's policy in another and makes the two import each
other.

---

## Findings

### 1. The erasure seam stops one level short of the actor that needs it

**Principle:** Feathers — a seam is where behaviour can be changed without editing in place; where
there is no seam, that is the finding. Also DIP, in the form this project actually practises it
(a closure parameter, not a container).

`app/lib/features/preferences/ui/erase_account_route.dart:30` takes its request as
`Future<EraseResult> Function() erase`, and its doc at lines 9–20 states the reason: a real socket
inside a fake-async zone hangs on `!timersPending`. That is the best dependency inversion in the
module and `app/test/features/preferences/ui/erase_account_route_test.dart` is the proof it works.

The caller does not offer the same seam. `ProfileRoute`'s constructor
(`app/lib/features/profile/ui/profile_route.dart:45-60`) has thirteen parameters, four of them
request closures — `link`, `whoAmI`, `fetchHistory`, `auth` — and **no `erase`**.
`_openEraseFlow` (`:407-433`) builds the client itself at `:413-419` and hard-wires
`Endpoints.apiBaseUrl`.

**Cost.** Grep confirms no test in `test/` or `integration_test/` reaches `_openEraseFlow`;
`erase_account_route_test.dart:19` pumps `EraseAccountRoute` directly and
`account_screen_test.dart` pumps `AccountScreen` with a counter. So the `onClose` body at
`:421-432` — pop, the `!erased || !mounted` guard, `setState(_accountState = none)`,
`onSessionChanged(null)` — has never executed under a test. That body is the code that stops the
app from continuing to flush an attempt journal under a token whose row the server has just
deleted, and it is the code with a `mounted` check written on the assumption that the request can
outlive the screen. A change to it cannot be proven; a regression in it is discovered by a player.
This is also the *only* one of the six operations `ProfileRoute` performs whose end-to-end wiring
is untested, which is a change-amplification trap in reverse: the pattern says "there will be a
test", and for this one path there cannot be.

**Direction.** Add `erase` to `ProfileRoute` as a nullable closure defaulting to the socket, the
exact shape `link`, `whoAmI` and `fetchHistory` already have three lines apart in the same file.
The seam is already written four times over; this is the fifth.

---

### 2. `features/states/` is grouped by design-document chapter, and cycles with `features/home/`

**Principles:** CCP (gather what changes for the same reason) and ADP (no cycles). ADP is
objective and was checked rather than reasoned about.

The cycle is real and runs both ways at directory granularity:

- `app/lib/features/states/policy/streak_notice.dart:13` imports `home/policy/streak_state.dart`
- `app/lib/features/states/ui/streak_lost_screen.dart:8` imports `home/policy/broken_run.dart`
- against `app/lib/features/home/ui/home_route.dart:38-43`, which imports six things from
  `states/` — the notice policy, the notice store, and three screens.

And the ownership does not match the directory anywhere in it. Of the eleven things under
`states/`:

- the two streak screens, their policy and their store are the **home's** — `HomeRoute` pushes
  them, holds the log and the clock, and owns the only test that walks them
  (`test/features/home/ui/streak_notice_route_test.dart`);
- `offline_screen.dart` and `offline_bag.dart` are the **home's** too (`home_route.dart:41-42`),
  and `account_state_view.dart:37-43` explains at length why the *profile* cannot open `4.9`
  because it holds no pack;
- `account_state.dart` is the **profile and account** policy: five importers
  (`profile/ui/profile_route.dart:10`, `profile/ui/profile_screen.dart:14`,
  `profile/policy/profile_readout.dart:4`, `preferences/ui/account_screen.dart:8`,
  `preferences/policy/erasure.dart:2`), none of them in `states/` except the view beside it.

What is left that `states/` genuinely owns is `server_error_screen.dart` plus the three screens
nothing routes to.

**Cost.** Three concrete ones. *Change amplification:* the streak is one feature and lives in two
directories, so a change to what a run means touches `home/policy/` and `states/policy/` and
`states/ui/` together. *Cognitive load:* the cycle means neither directory can be read, moved or
extracted alone — you cannot answer "what does `states/` depend on" without reading `home/`, and
vice versa. *Unknown unknowns:* a newcomer told "the cross-cutting state screens live in
`states/`" will look there for the streak notice trigger and find only half of it; the other half
is a `HomeRoute` field. This audit's own brief carried the same confusion, which is the evidence
that the boundary misleads.

CLAUDE.md decides that `HomeRoute` *pushes* the notices — it has the log, the pack and the
navigator, and that is right. It decides nothing about the directory.

**Direction.** The seam is that nothing outside `home/` imports the streak or offline halves:
moving `streak_notice.dart`, `streak_notice_store.dart`, `streak_at_risk_screen.dart`,
`streak_lost_screen.dart`, `offline_bag.dart` and `offline_screen.dart` under `home/` breaks the
cycle and costs six import lines and their test paths. `account_state.dart` and
`account_state_view.dart` belong beside the account they describe. What remains in `states/` is
then honestly "the screens no feature owns yet", which is a true name.

**Second, smaller cycle, same principle.** `shell/ui/root_scaffold.dart:13` imports
`profile/ui/profile_route.dart` while `profile/ui/profile_route.dart:22-23` imports
`shell/policy/visible_tabs.dart` and `shell/ui/app_shell.dart`. This one costs much less and the
direction is narrower than it looks: the `policy/` edge is a leaf and creates nothing — the cycle
runs entirely through `AppShell`, a frame widget every feature draws inside. Moving `AppShell` to
`design/widgets/` would end it. Worth doing when something else touches the shell, not on its own.

---

### 3. `_stillOn` states an invariant and is applied in two of its four places

**Principle:** the file's own rule, in PROC-13's family — *any callback whose inputs are captured
is a place a data path can go wrong silently*. Cost vocabulary: unknown unknowns.

`app/lib/features/profile/ui/profile_route.dart:344-350` states it:

> **`mounted` is not enough once there are two awaits.** A session can arrive while the probe is
> in flight … and writing the old session's verdict over the new one's would put a conflict banner
> on an account that never had a conflict (PROC-13).

`_link` (`:316`) and `_refineConflict` (`:335`) obey it. Two other async writers do not:

- `_askForHistory` (`:241-250`) captures `widget.session` at `:242`, awaits at `:247`, guards
  `mounted` only at `:248`, then writes `_history`.
- `_askWhoIAm` (`:374-380`) takes a bare `accessToken`, guards `mounted` only at `:378`, then
  writes `_accountState` — which is exactly the field the quoted comment is about.

**Cost.** `didUpdateWidget` (`:204-209`) fires a new `_askForHistory` on every token change without
cancelling the one in flight, so a slow response for account A can land after account B's and
paint A's session list under B's address on `4.1`. `_askWhoIAm` is reachable from the banner retry
(`:627`) and can write the previous session's `AccountState` — the precise defect `_stillOn` was
written to prevent, arriving through the one door it was not applied to. Neither is loud: both
produce a plausible screen. And the cost compounds, because a reader who finds `_stillOn` and its
paragraph reasonably concludes the file has settled this question.

**Direction.** `_askWhoIAm` is the odd one out because it takes a token where every other path
takes a `LinkedSession`; give it the session and the guard follows. For `_askForHistory` the seam
is the same `_stillOn` call, since it already captures the session at `:242`.

---

### 4. Which rows Ajustes draws is decided in two files, and the comment that would tell you is wrong

**Principles:** CCP, and CMT-2 (a comment stating behaviour the code does not have).

`app/lib/features/preferences/ui/settings_detail_routes.dart:12-16` states the rule the settings
list follows:

> It is the same shape `ProfileRoute` uses for `Cuenta`, written here because the four screens it
> opens need nothing a caller holds: no session, no token, no address. A row that can build its
> own destination does, and only the two that cannot — `Cuenta`, which needs the signed-in
> address — stay callbacks on `SettingsListScreen`.

It says "the two" and names one. The second is `Cómo se leen los retos`, and
`app/lib/features/preferences/ui/legend_screen.dart:27` is
`const LegendScreen({super.key, required this.onBack})` — it needs nothing a caller holds. It is
nevertheless pushed by `ProfileRoute._openSettings` at
`app/lib/features/profile/ui/profile_route.dart:504`. `ChangePasswordScreen`
(`app/lib/features/preferences/ui/change_password_screen.dart:20`) is the same: nothing but
`onBack`, pushed from `_openAccountDetail` at `:524`.

**Cost.** Adding or moving a row in Ajustes means deciding *which of two mechanisms* it uses, and
the file that documents the choice states a rule the code does not follow — so the decision has to
be re-derived from four call sites each time. That is change amplification with a false map over
it, which is worse than no map: CMT-2's argument is that a reviewer reading a comment believes it,
and a reader who believes this one will conclude that `LegendScreen` must need something from the
route and go looking for what.

**Direction.** Either move Legend and ChangePassword onto `pushSettingsDetail` (the rule the file
already states, and it leaves `Cuenta` as the one true callback), or correct the sentence to say
what the split actually is. The first is two line moves; the second is one line. Do not do
neither — the cost here is entirely in the disagreement.

---

### 5. `TextSizeStep` is persisted by ordinal while the other two settings are persisted by meaning

**Principle:** Ousterhout — a decision that leaks its representation across a durable boundary.
No SOLID name fits and none is needed; the cost is what matters.

Three stores write an enum to `shared_preferences` and read it back
(`app/lib/features/preferences/data/prefs_settings_stores.dart`). Two write a **stable domain
key**:

- `:51` writes `settings.reminderTime.label` and `:40` reads it back through
  `reminderTimeNamed(hour)` — a name.
- `:123` writes `settings.volume.level` and `:112` reads it through `volumeStepAtLevel(level)`,
  which *searches* for a step whose `level` matches (`sound_settings.dart:17,21-28`) rather than
  indexing.

The third writes an **ordinal**: `:87` writes `settings.textSize.index`, and
`accessibility_settings.dart:26-29` reads it as `TextSizeStep.values[index]`.

**Cost.** The declaration order of `TextSizeStep` is now a persisted data format, and nothing
says so. Inserting a step, or reordering the four to put the default first, silently reinterprets
every device's stored value — a player who chose `largest` gets whatever now sits at position 3.
Nothing today catches it: the fixtures at `prefs_settings_stores_test.dart:87` and `:99` exercise
a valid step and an out-of-range `9`, which is the right pair for *this* code and blind to a
reordering. It is a real instance of PROC-11's last bullet in the general case — the two
alternatives (an ordinal and a domain number) produce identical output for every fixture, so the
test documents an intention it cannot enforce. A pin such as
`textSizeStepAt(3) == TextSizeStep.largest` would see it, and nobody has written one.

Note that the neighbouring comment (`prefs_settings_stores.dart:14-15`) already states the right
principle for *keys* — "named for what it holds rather than for the screen, so a later reader of
the device's storage can tell what it is". The same reasoning applied to *values* forbids the
ordinal.

**Direction.** Give `TextSizeStep` the same shape `VolumeStep` has — a domain number (its `scale`
is one already, or a `step` counting from one) plus a lookup that searches rather than indexes.
`volumeStepAtLevel` is the seam and the pattern, eight lines away in the same package.

---

### 6. One product rule — "which failures are ours to apologise for" — is stated twice, and both are drawn on one screen

**Principle:** DRY, in Metz's form — the copies must change together, and these do.

`app/lib/features/states/policy/account_state.dart:121-131` (`isOurFault`) and
`app/lib/features/profile/policy/history_view.dart:72-79` (`isOurProblem`) answer the same
question over two enums and return the same answer: `serverError || rejected` is ours, everything
else including `offline` is not. `history_view.dart:70-71` says so out loud — "the same judgement
`isOurFault` makes for the account section, and it drives the same hue".

They are consumed on the **same screenful**: `states/ui/account_state_view.dart:146` draws the
account banner and `profile/ui/profile_screen.dart:414` draws the history banner, and each picks
its `BannerKind` from its own copy of the rule.

**Cost.** Small today and visible when it bites. The day the product decides a refused session is
not the app's fault — plausible, since a refused session is arguably the player's to fix — one of
the two gets edited and `4.1` draws two banners about the same server in two different hues, on
one screenful. Nothing goes red: both functions are exhaustive switches with their own passing
tests, and neither test knows the other exists.

**Direction.** Not a shared enum — that is the wrong abstraction, and the three state vocabularies
(`AccountState`, `HistoryState`, `ErasureStep`) are genuinely different closed sets. The cheap
fix is at the one call site that draws both: let `ProfileScreen` derive both `BannerKind`s from
one reading, or have one of the two predicates delegate to the other with a mapping, so the rule
has one home even though the enums have two.

---

### 7. Three of the six `ProfileRoute` tests live under `test/features/preferences/`

**Principle:** REP — what is released together belongs together, read here as *what is exercised
together should be findable together*.

`test/features/preferences/account_door_test.dart:1`,
`test/features/preferences/account_rows_test.dart:8` and
`test/features/preferences/link_on_session_test.dart:7` all import and pump
`features/profile/ui/profile_route.dart`. They are residue from the rename that made `ProfileRoute`
the root; nothing under `test/features/preferences/` other than these three touches it, and
nothing under `test/features/profile/ui/` covers what they cover — the account door's
`authBaseUrl` gate, reachability of `4.3`'s two rows, and linking on a session appearing.

**Cost.** A developer changing `ProfileRoute` and running `flutter test test/features/profile`
runs half its suite and sees green. The full suite catches it, so this is a local-loop cost rather
than a merge risk — but it is exactly the kind of cost that turns into "I didn't know that test
existed" during a refactor.

**Direction.** Move the three files to `test/features/profile/ui/`. No code changes.

---

### 8. Two documents state retired facts about this module

**Principle:** CMT-2, and CMT-3's shape — a document claiming a gate that says the opposite of
what the gate says.

- `CLAUDE.md:146-147` says the settings list *"holds **two rows, because two destinations
  exist**; the other four are absent … and a test pins `Accesibilidad` absent so it turns red the
  day that row lands."* The code draws **six** rows (`settings_list_screen.dart:48,83-112`) and
  the test asserts `Accesibilidad` **present**, twice
  (`test/features/preferences/ui/settings_list_test.dart:69,101`). Four settings screens landed
  and CLAUDE.md did not move with them.
- `app/lib/features/profile/policy/history_view.dart:4` opens *"What `Avance` is showing"*.
  `Avance` was absorbed into Perfil; the file describes a screen that no longer exists, and every
  other `Avance` reference in `lib/` is correctly in the past tense or about the enum arm.

**Cost.** Low individually, and worth stating because CLAUDE.md is the entry point and is declared
to win over everything else. A reader who takes `CLAUDE.md:146` at face value believes there is a
gate holding a row absent, will not go looking for the four screens that exist, and will
mis-scope any change to Ajustes. This is the failure CMT-3 was added for, one level up from a
code comment.

**Direction.** Correct both in whichever session next touches this module, per PROC-6's
same-session rule. This audit deliberately did not edit them.

---

## What this module gets right, and why

These are worth copying, not just praising.

**One place per state, and the incident that proved it.**
`app/lib/features/states/policy/account_state.dart:133-160` puts *what to offer the player* in a
single exhaustive `switch`, and its doc records why: `otherDevice` was drawn as a banner with no
action for as long as it existed, "because whether a state had a door was three separate
expressions on a widget and none of them mentioned it". The remedy is structural — adding a member
to `AccountState` now breaks `accountDoorFor`, `isOurFault`, `erasureOffered` and the view's
message switch at compile time. This is the correct use of an exhaustive switch over a closed set:
the compiler is the reviewer.

**Absent, not zero; absent, not empty.** The same rule reappears in four unrelated places and each
one records the untruth it prevents: `LocalStats.accuracy` returns null over no answers
(`stats/policy/local_stats.dart:155-164` — "a new player is not 0 % accurate"), `profileTiles`
drops a tile rather than printing a dash (`profile/policy/profile_readout.dart:181-205`),
`historyWorthDrawing` removes the whole `HISTORIAL` heading
(`profile/policy/history_view.dart:81-102`), and DR-P2 removes a settings row with nowhere to go
(`preferences/ui/settings_list_screen.dart:20-25`). One product rule, four surfaces, and none of
them re-argues it.

**The closure seam.** `preferences/ui/erase_account_route.dart:30` is the cleanest dependency
inversion in the repository, and the reason is empirical rather than doctrinal: a real socket
inside a fake-async zone hangs on `!timersPending`, so the seam is what makes the sequence
testable at all. Judged against the alternative the brief offered — that it is an inconsistency
with how other features reach the network — it is not: `ProfileRoute` uses the same shape for
`link`, `whoAmI` and `fetchHistory`, and finding 1 is that it stops one short, not that it is odd.

**`features/stats/` is a complete small module.** A pure value (`AnsweredItem`), a pure aggregate
(`LocalStats`), a pure windowing function (`recordedWith`) and one adapter with two
implementations, and the arithmetic lives in exactly one of them. `answersKept = 200` carries the
product reason for the window ("after a thousand items … the number stops being feedback and
becomes a birth certificate") *and* the reason it is not `journalLimit` despite sharing a value.
This is Ousterhout's deep module: a two-getter interface over a real decision.

**`PreferenceValues` is one swallow, not eleven.** `preferences/data/preference_values.dart:21-76`
holds the single broad `catch` for three screens' worth of keys, with the reason it is broad (a
`TypeError` is an `Error`, not an `Exception`) and the reason `_prefs` is resolved *inside* the
try (the constructor itself throws when the plugin did not link, which has happened here). Eleven
`try`/`catch` blocks written eleven times would have one written differently, and it would be the
one that takes a launch down.

**Screens draw and do not decide.** `ProfileScreen` (469 lines) contains no branch that is not
about layout; every question it could have answered — which tiles exist, what the door says,
whether the section appears, which hue the banner takes — is a call into `policy/`. A long
`build` is not a cost when it is only composing, and this one is only composing.

---

## Coverage

**Read completely:** `CLAUDE.md` (790 lines) and `.claude/conventions/craftsmanship.md` (522
lines) before any source. Then all 48 files of `app/lib/features/{profile,preferences,states,
stats,character_sheet}/`, plus `features/shell/policy/visible_tabs.dart`,
`features/shell/ui/root_scaffold.dart` (the switch arms only) and `api/me_result.dart` where the
module's imports led there.

**Checked and clean:**

- **ADP, mechanically.** Every `../../` import edge out of the five directories, and every inbound
  edge from the rest of `lib/`, was enumerated. Two cycles found, both reported in finding 2. No
  cycle *within* the module: `profile → preferences → states` and `profile → stats` are all
  one-way.
- **PURE.** Not re-derived. The four `policy/` directories here are covered by
  `app/test/architecture/pure_boundary_test.dart`'s `features/*/policy/` glob, which is a red
  build; `states/data/`, `stats/data/` and `preferences/data/` are adapters by name and hold no
  arithmetic that I could find (`PrefsAnswerRecordStore` delegates the window to `recordedWith`
  and the figures to `LocalStats`, as `answer_record_store.dart:62-63` claims).
- **LSP.** Hunted specifically, per the brief. Five sealed result families cross this module
  (`MeResult`, `LinkResult`, `HistoryResult`, `EraseResult`, plus `Verdict`); every consumer is an
  exhaustive switch that returns a value on every arm, and no subtype throws where a sibling
  returns. The one `throw` in the module is `AnsweredItem.fromJson`
  (`stats/policy/local_stats.dart:43,49`), which is a parse refusal caught by its own adapter at
  `answer_record_store.dart:129`, not a subtype narrowing a contract.
- **The settings round trip.** All three stores were traced write-to-read.
  `NotificationSettings` and `SoundSettings` round-trip through stable keys and are correct;
  `AccessibilitySettings` is finding 5.
- **UI atom reuse.** `SettingsDetailScaffold`, `SettingsToggleRow`, `SettingsChoiceRow` and
  `VolumeBars` each have two or more callers inside `preferences/ui/`; none is a wrapper with one
  client, so there is no shallow-module finding there.
- **`AppTab.progress`.** Asked about in the brief; it costs nothing. It is three switch arms
  (`shell/ui/root_scaffold.dart:287`, `shell/ui/nav_bar.dart:57,172`), the last of which returns
  `SizedBox.shrink()`, and it is gated: `test/features/shell/policy/visible_tabs_test.dart:65-66,81`
  pins it *out* of `rootsPresentToday` and out of `visibleTabs`. Holding a name for something that
  does not exist is cheap when the list that moves is a separate constant, which is what
  `rootsPresentToday` is. This is the pattern to imitate, not a defect.

**Observations — decided on purpose, recorded so the next reader does not re-litigate them:**

- **Three state screens are unwired.** `EmptyStateScreen`, `SkillMasteredScreen` and
  `TopicExhaustedScreen` have zero callers in `lib/`; their only non-test reference is
  `test/design/screen_registry.dart`. Each doc comment names the reason and the trigger
  (`empty_state_screen.dart:11-22`, `skill_mastered_screen.dart:13-19`,
  `topic_exhausted_screen.dart:14-19`), and the reasoning is DR-P2's — routing a screen that would
  show for ever is the defect `historyWorthDrawing` exists to prevent. Deliberate. The residual
  worth one line: **nothing will go red on the day the trigger lands and the wiring does not.**
  `home_route_test.dart` is the precedent that exists for puzzles, written after four of five
  formats were unreachable with a green suite; no equivalent exists here.
- **Three settings screens record values nothing reads.** Confirmed by grep: no consumer of
  `AccessibilitySettings`, `SoundSettings` or `NotificationSettings` exists outside
  `features/preferences/`. This is decided, documented at
  `notifications_screen.dart:14-19`, `sound_screen.dart:17-20` and
  `accessibility_screen.dart:24-28`, and stated to the player in a footer on each screen. The
  distinction the code draws — a switch that records a real answer has done what it claims; a
  button whose action does not exist has not (`data_privacy.dart:7-13`) — is a good one.
- **`ProfileFigures.rating` and `ratingThisWeek` are null from every caller**, and
  `headlineLead`'s rating branch (`profile_readout.dart:159-165`) with its `NoteTone.gain` path
  is unreachable in production. Speculative generality by the book, and decided out loud at
  `profile_readout.dart:50-58` and in CLAUDE.md's "no rating" rule. Left alone.
- **`character_sheet/`** is a design-reference render, not a feature; it is decided in CLAUDE.md
  ("a parser test can say the geometry lands inside its viewBox and cannot say the flame looks
  like a flame"). It is the only file in this module with **no test of its own** — its coverage is
  the generic gates it earns by being in the screen registry.
- **`AccountStateView._openServerError`** (`states/ui/account_state_view.dart:171-187`) pushes from
  a view rather than from a route, against the module's own convention. Self-declared at
  `:163-170`, with the condition for retiring it written down. Left as-is.
- **`settings_list_test.dart:55`** is named "the design's five rows" and asserts six, and
  `:52`'s `expect(rows, SettingsListScreen.rowCount)` is near-tautological. The label list at
  `:66-73` carries the real weight, so this is a naming wrinkle, not a gate that cannot fail.
- **`4.12 Racha en riesgo` is absent from `screen_registry.dart`** with a touch-target violation at
  textScaler 1.3. Already reported elsewhere; it does not bear on any finding above, since the
  screen's design and its policy are both sound and the gap is registration.

**Could not judge:**

- Whether the design documents actually draw six settings rows in the order
  `settings_list_test.dart:66-73` pins. The source of truth is the Claude Design project, which
  this audit did not open; the tests and comments are internally consistent about it and I took
  them at their word.
- Runtime behaviour. Nothing was executed — no `flutter test`, no simulator. Every claim above is
  from the source at `653a17b`, and the reachability claims are from exhaustive greps over `lib/`,
  `test/` and `integration_test/`, including same-directory relative imports (which caught
  `ServerErrorScreen`, reachable via `account_state_view.dart:11` after a first pass had it wrong).

**Candidates discarded: seventeen.** The largest groups were things a committed gate already owns
(colour literals, blur, overflow, touch targets, the PURE split, `dart_code_linter`'s length and
parameter thresholds), things decided on purpose in CLAUDE.md or in a file's own doc comment (the
six listed under Observations), and things that are Dart idiom rather than defects — six families
of exhaustive switch over sealed result types, `ProfileRoute`'s 680 lines and thirteen
constructor parameters (a route composes, and the parameters *are* the seams), and the three
parallel state-enum families, of which only the one genuinely duplicated rule survived as
finding 6. Also discarded: the four inline `ApiClient` constructions in `profile_route.dart` —
three of them are the production halves of real seams and the fourth is finding 1, so reporting
them as duplication would double-count; `PrefsAnswerRecordStore`'s unguarded read-modify-write,
which has one writer; and the five `preferences/ui/` atoms as candidate shallow modules, which
each have two or more clients.
