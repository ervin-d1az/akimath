# AkiMath — implementation plan

Status: **draft for Ervin's approval.** Written 2026-08-15 against the repository as it stands on
`dev` at `f8b24d6`, the six design digests produced by the reading pass, and the two consolidation
passes that survived it.

> **AMENDED 2026-08-29 — read [ADR 0004](adr/0004-the-game-is-for-adults.md) and its amendment
> first.** This plan was written for a product whose audience included children, and it is left
> otherwise verbatim as the record of what was planned. Four passages below are overtaken and each
> carries its own note: **`req-age-gate`** (§4, `f3-auth-screens`), which routes a band below a
> consent threshold to a tutor-consent flow — the gate now **refuses** and there is nothing to route
> into; **DR-7** in §5.2 and the *maximally-minimizing alternative* beside it; and **D13** and
> **D21** in §5.4, which both cite `CLAUDE.md`:7 by line number for an audience clause that is gone.
> Their conclusions all survive and their reasons do not, which is the failure mode ADR 0004 exists
> to name. **Two flat errors are corrected in place rather than annotated**: this document spelled
> the band set `{under_13, 13_17, 18_plus}` and the live `CHECK` has said `adult` since the
> 2026-08-17 freeze. That set is **not narrowing** — ADR 0004's amendment §3 leaves the constraint
> exactly as it is, and the two minor bands go dead by construction because a refused minor never
> links.

## How to read this

This document is an **index of OpenSpec changes**, not a substitute for them. Each change listed in
§4 still gets its `proposal.md`, `design.md`, `tasks.md` and delta specs written by `/opsx:propose`
into `openspec/changes/<change-id>/`, and **a human approves the proposal before any code**
(`CLAUDE.md` § Workflow). What this document fixes ahead of that is the part that is expensive to
change later: the change boundaries, their order, their dependencies, the component names, and the
decisions where two design documents disagree.

Every change is tagged with its phase from `ARCHITECTURE.md` §9 (`F0` … `F8`), because
`openspec/config.yaml` requires each proposal to name one.

### Sources

| Source | Path | Status |
|---|---|---|
| Six per-document digests | `/Users/ervin/.claude/jobs/1bd81de5/tmp/design/{deck,pantallas-base,perfil-estados,primera-vez-cuenta,reactivos-puzzles,teclados}.md` | Read in full |
| Feature consolidation | `.../features.md` | Read in full |
| Gap consolidation | `.../gaps.md` | Read in full |
| **Component consolidation** | `.../components.md` | **Read in full.** 481 lines, written after the six digests. Its §5 is a 21-row edit list aimed at this document's §3. |
| Three domain inventories | `.../components-{surfaces,displays,math}.md` | Read as the evidence layer behind `components.md`; every measurement and every `[stated]`/`[derived]`/`[inferred]` tag lives there. |

**§3 was rewritten against `components.md`.** The first draft of this plan recorded the component
consolidation as never produced, because the `componentes` job had failed at the time of writing;
the merge was produced afterwards and supersedes the reconstruction. §3 is now the merged 53-row
inventory, folded into this document's four-column shape. Where §3 departs from `components.md` the
departure is stated in the row.

### Document precedence, decided once

`gaps.md` §3.4 and `features.md` §B0 both propose the same rule and it is adopted here:

> **Component documents > screen documents > the deck.**

`TecladoReactivo.dc.html` defines the keypad; a screen that embeds it is a citation; the deck is
narration. The deck carries at least three stale claims (slide 08's axolotl copy, slide 04's
operator rule, the keypad palette) and is marked stale wholesale. Where two *screen* documents
disagree the conflict is resolved individually in §5.3 and §7.

### Naming and language

Code, identifiers, file names, comments and this document are in English (LANG-1). Only
player-facing strings are es-MX. Design documents are cited by their Spanish filenames and screen
labels verbatim, because those are their names.

---

## 1 · What exists today, and what does not

### 1.1 Built and tested

Verified by reading, not assumed. 18 Dart files under `app/lib/`, **5** test files, 34 tests green.
(`ARCHITECTURE.md` §6 says "6 test files"; `find app/test -name '*_test.dart'` returns five —
`aki_spec_test`, `wordmark_test`, `no_blurred_shadow_test`, `brand_colors_test`,
`splash_screen_test`. Correct §6 when it is next touched.)

```
app/lib/design/tokens/brand_colors.dart      BrandColors (14 hues) + BrandColorRole (9 roles)
app/lib/design/tokens/brand_shape.dart       borderWidth 3 · radii 18/20/28/42 · shadows
                                             (3,4)/(3,5)/(5,7)/(6,8) · space1–7 · minTouchTarget 48
app/lib/design/tokens/brand_typography.dart  BrandFonts + BrandText (display/body/caption/action/
                                             eyebrow/cardTitle/sectionTitle/descriptor)
app/lib/design/tokens/tokens.dart            barrel — re-exports all three
app/lib/design/theme.dart                    Material theme, NoSplash.splashFactory already set
app/lib/design/brand/spec/aki_spec.dart      pure geometry; AkiPose { base, correct, slip }
app/lib/design/brand/spec/brand_shapes.dart  pure geometry
app/lib/design/brand/brand_drawing_painter.dart   the adapter that paints the spec
app/lib/design/brand/aki.dart                Aki, AkiFace
app/lib/design/brand/wordmark.dart           AkiMathWordmark
app/lib/design/brand/brand_lockup.dart       BrandLockup
app/lib/design/brand/app_icon.dart           AkiAppIcon
app/lib/design/widgets/candy_surface.dart    CandySurface + .card / .pill / .tile
app/lib/design/widgets/loading_dots.dart     LoadingDots
app/lib/design/widgets/speech_bubble.dart    SpeechBubble
app/lib/features/splash/splash_screen.dart   0.1 Splash
app/lib/features/character_sheet/character_sheet_screen.dart   the live brand document
app/lib/main.dart                            one screen, no router — home is the character sheet
```

```
packages/server/src/routing.ts               pure route(); GET /health only
packages/server/src/adapters/http-server.ts  the socket
packages/server/test/                        3 tests, 100% Stryker score
```

### 1.2 Does not exist

Nothing below is on disk. Naming it here is the honest baseline for every estimate that follows.

- **No package other than `app` and `packages/server`.** `packages/core`, `packages/contract`,
  `contract/openapi.json`, `app/lib/api/` are planned in `CLAUDE.md`'s layout block and absent.
- **No database, no migration, no auth, no endpoint beyond `GET /health`, no environment, no
  deploy.**
- **No gesture handling anywhere in `app/lib/`.** A repo-wide grep for
  `GestureDetector|InkWell|onTap|onPressed` returns doc comments only. The press physics that ~50
  drawn elements specify identically is unimplemented.
- **No icon layer.** `cupertino_icons` is a glyph font and does not match the stroke language;
  DEP-1 forbids fetching another.
- **No dashed border.** Flutter's `Border` cannot draw one, and dashed-vs-solid is the load-bearing
  shape encoding (§5.3 decision D6).
- **No math compositor**, no keypad, no answer model, no offline pack, no local store, no router,
  no motion, no `intl`.
- **No `Verdict` type.** `ARCHITECTURE.md` §6 asks for one without `.color`; `BrandColorRole` still
  exposes `.color`.
- **No `pnpm`.** The root `package.json` names `pnpm@11.21.0` and the root scripts do not run. Use
  the per-package commands in `CLAUDE.md`.

### 1.3 Enforcement that exists, and where it stops

| Gate | Covers | Where it stops |
|---|---|---|
| `test/design/tokens/brand_colors_test.dart` | the role → colour map | It asserts pink is not the error/success/action colour. **It does not assert "no role resolves to pink"** — `deck.md` §9.5 says it does and is wrong; `primera-vez-cuenta.md` §7.2 is right. Adding `BrandColorRole.focus(pink)` passes today. It also cannot see a widget writing `pct >= 90 ? green : pink`. |
| `test/design/no_blurred_shadow_test.dart` | gradient / blur / spread / elevation on 3 screens | Walks `DecoratedBox` and `PhysicalModel` only — **blind to every `CustomPainter`**, which is where all the new work lands. The screen list is hand-maintained. It pumps at 2400×4000, so **no test in the repo can go red on a 390×844 overflow.** |
| `.claude/hooks/verify-gate.sh` | `flutter analyze --fatal-infos`, `flutter test`, `npm run verify` on every commit and push | Nothing Dart-side proves the tests bite; there is no configured mutation harness (PROC-5 Tier 1b uses a falsification step instead). |
| `.github/workflows/ci.yml` | `changes`, `secrets`, `dart`, `ts`, `gate` | `gate` is **not registered on the `protect-main` ruleset**, so CI is advisory on `main` today. |

Three of those holes are closed by change `f0-invariant-tests` (§4.6), and none of them should be
closed later, because they are cheapest now and their surface area is about to grow by ~50 screens.

---

## 2 · The tree, and the convention

### 2.1 The convention, stated once

Ervin's rule is *structure by features; what is genuinely shared lives in `design/`*. PURE-1/PURE-2
generates exactly three subfolders inside a feature, and no more:

```
features/<feature>/
  policy/          PURE-1. Every decision. No Canvas, no widget, no clock, no randomness, no IO.
  data/            PURE-2 adapter — bytes.  Assets, storage, network, clock, connectivity.
  ui/              PURE-2 adapter — pixels. Screens, widgets, painters.
  <feature>.dart   Barrel. Created only when a second feature imports this one.
```

**A feature whose only content is UI stays flat; `ui/` appears when the feature earns a second
drawer.** `features/splash/` is one screen with no decision and no IO, so it stays the single file
it is today — and so do `character_sheet/`, and `shell/`, `onboarding/`, `home/` and `profile/`
until they gain a `policy/` or a `data/`. The earlier wording — *"a subfolder exists only when it
has content"* — read literally forces `features/splash/ui/splash_screen.dart`, because a screen
**is** content of `ui/`; that reading contradicts §2.6 and is not what is meant. A feature earns
`policy/` the moment it has something worth proving without a widget, and the day it does, its
screens move into `ui/` in the same change.

**Test paths mirror lib paths, drawer included.** `app/test/features/round/policy/answer_draft_test.dart`
for `app/lib/features/round/policy/answer_draft.dart`; a feature that is flat in `lib/` is flat in
`test/`, which is why `app/test/features/splash_screen_test.dart` is correct as it stands. Stated
here once because §4 names a test file in every scenario and two of them disagreed with each other
before this rule existed.

**There is no `model/` folder.** PURE-1 says verbatim that *"value types that carry no IO are
fine"* — inside the pure module, not beside it. `aki_spec.dart` already holds an enum, a record and
the geometry builders in one file and complies. Value types live in `policy/`.

**`data/` and `ui/` are separate because they are two different kinds of touching.** A pack reader
and a `CustomPainter` are both adapters, but a widget test cannot exercise the first and a fake
asset bundle cannot exercise the second.

### 2.2 The import ceiling for `policy/`

`policy/` inherits `design/brand/spec/`'s ceiling exactly, because that is the precedent already on
disk and enforced by reading.

| | Allowed in `policy/` | Forbidden in `policy/` |
|---|---|---|
| Dart SDK | `dart:ui show Offset, Radius, Rect, Size, Color`, `dart:math` (functions only) | anything under `package:flutter/`, `dart:io`, `dart:async` |
| Packages | `package:meta` | everything else |
| Repo | its own siblings, `tokens/brand_colors.dart`, `tokens/brand_shape.dart`, `content/model/` | **`tokens/tokens.dart` (the barrel)**, `tokens/brand_typography.dart`, `design/widgets/`, `design/brand/`, any `ui/`, any `data/` |
| Ambient | — | `DateTime.now()`, `Random()`, `Platform`, any environment read |

**The barrel is the trap.** `tokens/tokens.dart` re-exports `brand_typography.dart`, which imports
`package:flutter/painting.dart`. A `policy/` file writing the habitual
`import '../../design/tokens/tokens.dart';` pulls Flutter in transitively and breaks the ceiling
with no Flutter symbol visible at the call site.

**One hop does not catch it, and the gate must not be specified that way.** Verified against the
file: `tokens.dart` contains three `export` directives and **no import at all**, and
`package:flutter/painting.dart` sits one file further in, at `brand_typography.dart:1`. A resolver
that stops at one hop reports zero violations; a resolver that follows only `import` and never
`export` reports zero violations at *any* depth, because the edge `tokens.dart → brand_typography.dart`
is an export. So the requirement is: **transitive closure over the union of `import` and `export`
directives**, restricted to repo-local URIs (relative paths and `package:akimath_app/`), stopping at
`dart:` and third-party `package:` URIs, which are leaves. The prohibition on the barrel is
therefore double — **by name** for the direct import, and **by closure** for everything it drags in
— and the error message the scenario demands (naming the barrel *and* the
`package:flutter/painting.dart` it re-exports) is only expressible with the closure.

The same closure is what lets the gate see an **import cycle between two feature barrels**, which
Dart compiles without complaint and which §2.5's acyclicity rule otherwise has no enforcement for
at all.

**Clock and randomness are injected as values, not as interfaces.** `remainingCooldown(issuedAt,
now)` takes `now` as a parameter; the widget in `ui/` reads the clock and passes it down. No `Clock`
abstraction, no fake to write. Same for seeds. That is the concrete form of PURE-1's own decisive
test: *if proving the decision correct requires faking a canvas, a socket, a clock or a seed, the
decision is on the wrong side of the boundary.*

### 2.3 The three non-feature peers

Three things are genuinely shared and are not design. Two of them are already named in
`CLAUDE.md`'s own layout block, so this is a carve-out being written down rather than smuggled in.

```
app/lib/
  design/     how it looks         brand, tokens, primitives, icons, the math compositor.
                                   No domain vocabulary — no ratings, streaks, cages, misconceptions.
  content/    what it asks         the offline pack format and the item model.
  api/        where it comes from  already planned in CLAUDE.md's layout block.
  features/   everything else.
```

`content/` earns its place by `ARCHITECTURE.md` §6: *"the boundary is a directory of pinned,
versioned artifacts, not a handoff."* The pack format is a cross-stack contract emitted by F1.5 and
later by the server, and `round/`, `calibration/`, `home/` and `puzzles/` all read it. Putting it
inside any one of them would make three features depend on a fourth for a reason that has nothing
to do with the fourth. **Constraint: `content/model/` holds to the `policy/` import ceiling in
§2.2**, which is what makes it importable from `policy/` and what the boundary test covers.

### 2.4 The tree

```
app/lib/
├── main.dart
├── design/
│   ├── theme.dart
│   ├── tokens/                brand_colors · brand_shape · brand_typography · tokens (barrel)
│   ├── brand/
│   │   ├── spec/              aki_spec · brand_shapes                        [PURE]
│   │   ├── aki.dart · wordmark.dart · brand_lockup.dart · app_icon.dart
│   │   └── brand_drawing_painter.dart
│   ├── icons/
│   │   ├── spec/icon_paths.dart      ~20 stroke icons as path data           [PURE]
│   │   └── brand_icon.dart           the painter beside it
│   ├── painting/
│   │   ├── spec/dash_spec.dart       dash pattern → segment list             [PURE]
│   │   └── dashed_border.dart        the painter
│   ├── math/
│   │   ├── spec/              math_node · fraction_metrics · answer_draft?† ·
│   │   │                      es_mx_number                                    [PURE]
│   │   ├── math_view.dart · fraction_glyph.dart · expression_row.dart
│   │   └── answer_slot.dart          the generic dashed slot (no Spanish)
│   └── widgets/
│       ├── spec/              verdict · keypad_layout · resolve_button_skin ·
│       │                      resolve_field_visual · resolve_banner_visual ·
│       │                      meter_layout · mastery_level                    [PURE]
│       └── candy_surface · pressable_surface · brand_button · icon_button_tile ·
│         screen_header_bar · entity_row · keypad · speech_bubble · loading_dots ·
│         verdict_chip · baseline_meter · stat_tile · stat_pill · outlined_chip ·
│         segmented_indicator · brand_text_field · inline_banner · dimmed_layer ·
│         centered_state_view · app_bottom_nav
├── content/
│   ├── model/                 pack · item · stimulus payload · answer spec ·
│   │                          puzzle spec · distractor                        [PURE]
│   └── pack_reader.dart       the asset adapter
├── api/                       (F3)
└── features/
    ├── splash/                splash_screen.dart                              [built]
    ├── character_sheet/       character_sheet_screen.dart                     [built]
    ├── shell/
    │   ├── policy/            routes.dart (AppRoute ids) · visible_tabs.dart  [PURE]
    │   └── ui/                app_scaffold · router · skeleton_block · skeletons
    ├── onboarding/            0.2 · 0.3 · 0.7
    ├── round/
    │   ├── policy/            answer_draft† · series_state · stimulus (sealed) ·
    │   │                      figurate_figure_spec
    │   ├── data/              (F3) attempt outbox
    │   └── ui/                item_scaffold · item_term_tile · answer_card ·
    │                          item_progress_dots · stimulus/ ×6 · verdict/ · summary/
    ├── home/
    │   ├── policy/            streak_policy.dart                              [PURE]
    │   ├── data/              day_log_store.dart
    │   └── ui/
    ├── calibration/
    ├── skill_map/
    │   ├── policy/            skill_graph.dart — the 9-node / 9-edge lattice
    │   └── ui/
    ├── puzzles/
    │   ├── policy/            board_geometry · board_rules · cage_geometry · undo_stack
    │   ├── data/              session_store.dart
    │   └── ui/                puzzle_scaffold · grid_board · board_glyph_layer ·
    │                          reference_sheet · boards/ ×5
    ├── auth/
    │   ├── policy/            credential_rules.dart
    │   ├── data/              auth_client.dart
    │   └── ui/
    ├── profile/
    │   ├── policy/            profile_summary · history_entry (nullable delta)    [PURE]
    │   ├── data/              profile_client.dart — GET /v1/me, /v1/me/history (F3)
    │   └── ui/                4.1 — identity row, stat pair, history list
    └── settings/
        ├── policy/            preferences.dart — sound, haptics, reduced motion ·
        │                      reminder_schedule.dart — 4.4's three reminders     [PURE]
        ├── data/              preferences_store.dart · reminder_scheduler.dart
        └── ui/                brand_toggle · segmented_chooser · brand_bottom_sheet
```

† `AnswerDraft`'s home is settled in §3.4: it stays in `round/policy/`, and the recommendation to
move it into `design/math/spec/` is recorded there with the reason for declining.

### 2.5 Cross-feature edges

A feature may import `design/`, `content/` and `api/` freely. It may import **another feature's
barrel** only — never its internals — and only in a direction that keeps the graph acyclic.

Two kinds of edge, and the distinction is load-bearing for the build order:

```
compile-time (imports a barrel; the dependency must ship first)
  onboarding  → round        AnswerCard + ItemProgressDots      both exist at F2
  calibration → round        the item shell                     both exist by F4
  home        → puzzles      the PUZZLE DEL DÍA thumbnail        both exist by F6
  profile     → settings                                         both exist by F7
  round       → settings     sound and haptics at the key press  F7  (see below)

navigation only (an AppRoute id owned by shell/policy/; the destination may not exist yet)
  shell       → home, skill_map, profile      the tab roots
  onboarding  → calibration                    "Va, empecemos" — F4; unregistered at F2
  home        → round, puzzles, skill_map
  round       → skill_map                      "Cambiar a decimales" from 4.15
```

**`onboarding → round` is compile-time, not navigation.** `0.3 Primer reto` draws the same answer
card and the same keypad as the item screen (`primera-vez-cuenta.md`:96-105) and therefore imports
`round/round.dart` for `AnswerCard`. It does **not** use `ItemScaffold`: the digest draws no close
control and no progress dots on `0.3`. The keypad itself resolves against `design/`, not against
`round/`, once §3.3 owns it.

**Route ids live in `shell/policy/routes.dart`, and features import that file, never `shell`'s
barrel.** An `enum AppRoute` with its path holds to §2.2's ceiling and imports no feature; only
`shell/ui/router.dart` imports feature barrels. Without that split the natural implementation is a
cycle — `home` imports `shell` for a route name while `shell` imports `home` to build the router —
and **Dart compiles import cycles silently**, so neither `flutter analyze` nor any test today would
report it. The transitive closure in §2.2 is what makes the rule checkable.

**Device preferences are the one place the three drawers do not fit, and the carve-out is written
rather than discovered.** `settings/` owns sound, haptics and reduced motion (`4.6`), but the code
that must honour them is `PressableSurface` in `design/widgets/` and the key and verdict sounds in
`round/ui/` — and `design/` may not import a feature. So: the **value** is a pure type in
`settings/policy/preferences.dart`, the store is `settings/data/preferences_store.dart`,
`shell/ui/` reads it once and propagates it down the tree by `InheritedWidget`, and `design/`
receives `hapticsEnabled` / `reduceMotion` **as parameters**. That is the same discipline §2.2
already fixes for the clock and the seed: injected as values, not as interfaces. The
`round → settings` edge above exists only for the feature-level call sites that read the value
directly; if F7 lands the `InheritedWidget` everywhere, the edge disappears and this line is
deleted.

**`4.4 Notificaciones` sits in the same drawer under the same discipline.** `settings/` also owns
the three reminder toggles, the reminder hour and the preset chips — as a **pure** value,
`settings/policy/reminder_schedule.dart`, which turns preferences plus a local calendar day into a
list of `(when, kind)` pairs and reads no clock. The plugin that hands that list to
`UNUserNotificationCenter` / `NotificationManager` is the adapter beside it
(`settings/data/reminder_scheduler.dart`), and it is the only place a notification API is named —
see `f7-notifications` in §4 and **D21**, which decides the transport is local scheduling and never
a push token.

This settles a question two digests raised: **`PuzzleThumbnail` is rendered on Inicio and does not
move into `design/` for that reason.** It carries puzzle domain — cages, clue diagonals, capsules —
and `design/` holds no domain. Home imports `puzzles/puzzles.dart`.

**Promotion test, so this is not argued per widget:** a widget moves into `design/` when two
different features need it **and** it carries no domain vocabulary. `BrandToggle`, used nine times
across three settings screens, is one feature — it stays in `settings/` until something else needs
it. `PressableSurface` is needed by every feature and knows nothing — it starts shared.

### 2.6 What already exists stays where it is

`features/splash/` and `features/character_sheet/` are correctly placed; nothing moves.
`character_sheet/` is not a product screen — it is a live rendering of the brand document, the only
place the design system is inspected. It stays a feature and stays out of product navigation.

---

## 3 · Component inventory

Four columns: what exists, what gets extended, what is new and shared, what is new and feature-local.
For every new module the PURE side is named, because `openspec/config.yaml` requires each
`design.md` to say which side a module sits on.

**This section is `components.md`'s merged inventory, folded into those four columns.** That merge
reconciled three domain files — `components-surfaces.md` (24 entries), `components-displays.md`
(12) and `components-math.md` (30) — into **53 canonical rows**, on a folded basis of 51 product
screens. Thirteen entries named the same concept in two or three domains and collapsed. Names below
are the canon; where a digest used another name it is listed so a reader can trace it. Screen counts
are the merge's, and they are the argument for where a component lives — not decoration.

**The promotion test, restated because it decided most of this table** (§2.5, `features.md` §1.7):
*a widget moves into `design/` when two different features need it **and** it carries no domain
vocabulary.* Two features is **necessary, not sufficient**: `AnswerCard` is drawn by `round`,
`onboarding` and `calibration` and still stays in `round/ui/`, because it carries the literal
`TU RESPUESTA`. The mechanism for cross-feature use is a barrel, not a promotion.

**One constraint on every PURE row.** A pure module may import `brand_colors.dart` and
`brand_shape.dart` **directly** and must never import `tokens/tokens.dart` (§2.2). Honest caveat
from `components-surfaces.md` §12: `brand_shape.dart` itself opens with `import 'dart:ui' show
Offset`, so these modules are pure in the PURE-1 sense and run under `flutter test`, but are **not**
portable to a bare `dart test`. Do not describe them as "runs without Flutter".

Rows marked **★** are widened or newly-collapsed proposals — the component is drawn but was never
named by any digest, or was named for one feature and widened to many. They are **additions, not
reconciliations: approve them separately.**

### 3.1 Exists — reuse, do not duplicate

| Widget | Path | Verdict |
|---|---|---|
| `CandySurface` (+ `.card` / `.pill` / `.tile`) | `design/widgets/candy_surface.dart` | **The one primitive every outlined box in every document is** — 50 of 51 screens, all but `0.1`. Extended, never duplicated — see §3.2. |
| `SpeechBubble` | `design/widgets/speech_bubble.dart` | 4 screens (`01`, `03`, `04`, `3.2`). Extended — see §3.2. |
| `Aki`, `AkiFace`, `AkiPose` | `design/brand/aki.dart`, `spec/aki_spec.dart` | No change to the widget. `AkiSpec` gains one mark — see §3.2. Variant mapping in §5.3 D9. |
| `BrandDrawingPainter` + the `brand_shapes.dart` marks | `design/brand/` | **Reuse as-is for every painted figure and board.** `components-math.md` §1.3 verified mark by mark that this domain needs **no new `Canvas` class at all**: board hairlines are `InkStroke.line(1.5)`, Killer block rules `3`, Kakuro diagonals `1.6`, blocked cells and Sopa's found capsule are `InkRect`, figurate dots are `InkDot`. Two data extensions only — §3.2. |
| `AkiMathWordmark`, `BrandLockup`, `AkiAppIcon` | `design/brand/` | Splash and the character sheet only. No change. |
| `LoadingDots` | `design/widgets/loading_dots.dart` | **Referenced by no product screen in any document** — `0.1` only. `4.11 Cargando` is annotated *"esqueletos, sin ruedita"*. Leave it alone and **do not repurpose it**. Do not invent a spinner anywhere. |
| `BrandColors` / `BrandColorRole` | `design/tokens/brand_colors.dart` | Extended — 4 tokens, 1 role. |
| `BrandShape` | `design/tokens/brand_shape.dart` | Extended — 8 radii, 2 border widths, 2 shadows. |
| `BrandText` / `BrandFonts` | `design/tokens/brand_typography.dart` | Extended — parameters, not new styles. |

**The single worst outcome of this whole plan would be a second widget that draws a 3px ink outline
and a hard shadow.** Three digests and all three domain inventories say so independently. Every
card, chip, tile, key, board container, nav bar, banner and button is `CandySurface` with different
arguments.

**But the named constructors mostly do not fit the product screens, and they stay.** `.card` = r28 +
padding 32/30 + shadow (5,7); `.tile` forces a square size and a green fill; `.pill` = r18 + shadow
(3,4) + minHeight 32 and **has zero call sites today**. The documents run r22/r24/r26 with padding
14–18 and shadow (4,6). Deleting the constructors breaks committed code for nothing; using them on
product screens lands the wrong radius on every card. So: product screens go through the **base
constructor with explicit values**, and that restriction is a **doc-comment change, not an API
change** (`components.md` §3.1).

### 3.2 Extend what exists

| Target | Extension | Why it is not a new widget |
|---|---|---|
| `BrandColors` | `+quiet` (`#EAE6F0`), `+pinkFigure` (`#FF9EC1`), `+hairline` (ink @ 18%), `+BrandColorRole.focus → pink` | BRD-2b: no colour literal outside `tokens/`. Naming in §5.3 D3. `rule` stays at 16% for card dividers; `hairline` at 18% is the 100+ board hairlines — two roles, not one role with two alphas. |
| `BrandShape` | `+radiusSlot 12`, `+radiusChip 14`, `+radiusControl 16`, `+radiusButton 20`, `+radiusCardSmall 22`, `+radiusPanel 24`, `+radiusCardMedium 26`, `+radiusSheet 32`, `+borderWidthThin 2.5`, `+borderWidthField 2`, `+shadowButton (4,6)`, `+shadowDot (2,3)` | `brand_shape.dart`'s own header says "no widget invents its own stroke width or radius". `(4,6)` is the most common shadow in the app and has no name; `SpeechBubble` already writes it as a literal. `shadowDot (2,3)` has exactly **one** use — the current progress dot — and still earns a name, because the alternative is a literal on a screen. §5.3 D2. |
| `BrandText` | `numeral(size)` (Darumadrop at `height: 1`, 15–42), `eyebrow({size, letterSpacing})` (10/11/12 px at .06/.08/.1em), `cardTitle({size})`, `body({height})`, `caption({size, height})` | Every one is the same style with a different parameter. `numeral(size)` is the alias the digests keep reaching for via `sectionTitle(size:)`, whose name lies at a keypad key. |
| `CandySurface` | `+borderColor` (default `BrandColors.ink`); `+borderDash` (`DashSpec?`, null = solid); `shadowOffset` **widened to `Offset?`**, name unchanged | Three additions, no renames. **`borderColor` is the blocker `components-math.md` §3.3 says nobody had named** and it is what lets `AnswerSlot`, the locked map node, the error field, the focus field and `4.7`'s destructive ghost row route through `CandySurface` instead of forking into a bare `DecoratedBox`. `borderDash` carries BRD-1's shape clause and **must land in the same change as `req-no-blur-painters`** (§5.3 D22). The nullable shadow is **API honesty, not a rendering fix** — offset 0 / blur 0 / spread 0 already paints coincident under an opaque fill; it blocks nothing. |
| `SpeechBubble` | `+tailSide` (left / right), `+tailInset` (22/24/26/28), `+padding`, `+textStyle` (600 15/**1.35**, not `body()`'s 1.5) | Hard-codes `left: 22`, apex `11`, padding 16/14 and `Offset(4, 6)`. Max widths in use: 250 / 214 / 196 / 186 / 170 / 158 / 150 against a default of 180. **Correction to the first draft: no `tailApexX`.** The two apexes are an exact mirror — viewBox `0 0 26 18`, left `M3 2 L23 2 L11 16 Z`, right `…L15 16 Z`, and 26 − 11 = 15 — so apex is **derived** from `tailSide`. The `Offset(4, 6)` literal becomes `BrandShape.shadowButton` in the same edit. |
| `brand_shapes.dart` marks (PURE) | `InkRect.fill` becomes **nullable**; `InkRect.dash` and `InkStroke.dash` take a `DashSpec?` | Sopa's drag capsule is `fill: none`, and a transparent colour literal would violate BRD-2b. The dashes are the cages (`6 4`), Killer (`2 5`, round cap) and Sopa's capsule (`9 7`). These two data extensions are the **entire** delta this domain needs. |
| `aki_spec.dart` (PURE) | `+AkiSpec.tailCurl` — an 86×30 mark, `M43 30 C43 10 62 6 62 18 C62 26 51 26 51 15`, ink width 13 then `akiCoat` width 6 | The function machine on `Reactivo operación oculta` borrows Aki's tail curl **while she is not on screen**, drawn twice. Today the curl exists only as part of a whole pose. **The machine has no face and must not get one.** |
| `BrandFonts.display` doc comment | rewrite | It says *"Wordmark and section headers only"*. The design sets Darumadrop on every keypad digit, numeral, board digit, stat value and OTP digit. The comment is wrong and will be re-litigated by every implementer until it is corrected (PROC-6). |

### 3.3 New — shared, in `design/`

Ordered by build order: the three hard dependency rules first (nothing interactive before
`PressableSurface`, nothing dashed before `DashSpec`, nothing icon-bearing before `BrandIconSpec`),
then by screen count.

| Name | PURE side | What it is | Collapses | Screens |
|---|---|---|---|---|
| `DashSpec` | **PURE** `design/painting/spec/` | Dash pattern + path length → segment list. Zero mocks. | DashedOutline (data half) · DashPattern | cross-cutting |
| `DashedBorderPainter` | adapter | Paints a `DashSpec` around a rounded rect. Needed by the focused answer slot, locked map nodes and edges (`9 9`), `4.8`'s placeholders, `4.5`'s error chip, KenKen cages (`6 4`), Killer cages (`2 5`), Sopa's capsule. | DashedOutline (paint half) | cross-cutting |
| `BrandIconSpec` | **PURE** `design/icons/spec/` | ~21 stroke icons as path data + stroke width + viewBox, in the `aki_spec.dart` style. | BrandStrokeIcon · BackspaceGlyph · SubmitArrowGlyph · the matrix/analogy/series arrows · the 22-viewBox kenken mark | cross-cutting |
| `BrandIcon` | adapter | The painter beside it. | the same, painted | cross-cutting |
| `Verdict` + `SlotState` | **PURE** `design/widgets/spec/` | The type `ARCHITECTURE.md` §6 asks for, **with no `.color`**: `{ outline: solid \| dashed, glyph: check \| alert, role }`. `SlotState` is the progress-dot alphabet built on it. **Imports nothing.** | Verdict | 10 · 6 item, `03`, `04`, `2.5`, `4.5` |
| `PressableSurface` (+ `pressTravel`) | adapter + **PURE** press rule | `CandySurface` + the press: translate by the surface's own shadow offset, shadow to zero. ~50 call sites specify it identically. Nothing in `app/lib/` handles a gesture today. | PressableCandySurface | 49 · all but `0.1`, `4.11` |
| `BrandButton` (+ `resolveButtonSkin`) | adapter + **PURE** skin map | Variants `primary` / `secondary` / `raised` / `destructive` / `text`; sizes `standard` and `hero` (§5.3 D4). Built on `PressableSurface`. | CandyButton · PrimaryButton · SecondaryButton · TextLink · GhostTextAction | 30 |
| `IconButtonTile` | adapter | 48×48, r16, shadow (3,4), optional toggled fill (`#FFD447` for pencil-on). Covers close, back, pause, undo, hint, pencil, gear. | IconSquareButton · IconTileButton · SquareIconButton · SeriesCloseButton | 26 |
| `EsMxNumber` | **PURE** `design/math/spec/` | The whole surface: `integer` (U+202F per D8) · `decimal` · `seconds({places})` · `elapsed` · `clockTime` · `durationCoarse` · `percent` · `deltaParts` · `ratio` · `dimensions` · `noValue`. Preserves U+2212 (never hyphen-minus), U+00B2, U+00B7, U+2190, U+00D7 with spaces, decimal **comma**. | NumberFormat (the first draft's name) · "es-MX number formats" | 24+ · every screen printing a number |
| `ScreenHeaderBar` ★ | adapter | The identical band: `padding 4px 20px 0`, 48 px leading, optional Darumadrop title, optional trailing, `reserveTrailingSpace` for the 48 px spacer, fit-to-width titles (40/38/34/34/32/32 tracks title **length**, not screen identity). | DetailHeader · "header row" · "title bar" · "series header" · "probe header" | 24 · 5 features |
| `OutlinedChip` | adapter | Border 2.5 ink, no shadow, `800 12` ink, optional 12 px leading icon, `+width` for fixed-width targets. h28 / h34 / h36 / h38 / h40. Explicitly **not** `CandySurface.pill` (r18 / border 3 / shadow (3,4)). | CountChip · BannerActionChip · LegendChip | 15 |
| `Keypad` · `KeypadKey` · `KeypadLayout` | adapter + **PURE layout** (`design/widgets/spec/keypad_layout.dart`) | One key, three named layout constants: item 4×4 (keys h62, gap 10), puzzle 5×2 (h58, gap 9, no `0`, no enter), OTP 3×4 (h60). Geometry is identical in all three: border 3, radius 18, shadow (3,5), press `translate(3,5)`; the backspace glyph is byte-identical between documents. A key face is a sealed `KeyFace` — `TextFace` / `FractionFace` / `IconFace` — because the `a/b` key face is a 15 px `FractionGlyph`, not a character. One `KeypadKeyId` enum covers the union of the three layouts, so the U+2212 / U+00B2 / U+002C codepoint contract (R2) is typed **once**. | ItemKeypad · PuzzleKeypad · OtpKeypad · MathKeypad · KeyButton · TecladoReactivo · TecladoPuzzle | 13 · 6 item, 4 boards, `1.3`, `0.3`, `0.5` |
| `CenteredStateView` ★ | adapter | Optional Aki or illustration frame, Darumadrop headline with **designed line breaks** (`headlineLines` is a `List<String>`), optional body, optional content slot, footer of one or two buttons at `0 24 30`. | CenteredStateView ∪ OnboardingScaffold | 11 · `4.8`–`4.10`, `4.12`–`4.15`, `0.2`, `0.4`, `0.6`, `0.7` |
| `StatTile` + `StatValue` | adapter | Darumadrop value over a caps label. **Three** variants: `raised` (r20, shadow (3,5), value 26 — `03`, `0.7`), `compact` (r18, shadow (3,5), value 24 — `4.1`, `2.5`, `3.5`), `flat` (r16–18, no shadow, value 21–24 — `04`, `2.3`, `3.6`, `4.9`, `1.6`). `value` is a **`Widget`**, not a `num`, because `3.6 Pausa` puts a puzzle **name** where a number goes. The `−6` delta is `EsMxNumber.deltaParts` → `StatValue.delta` → `StatTile.value`: two runs, `−` in Plus Jakarta 800 15 + `6` in Darumadrop 22, baseline-aligned, gap 3. | ResultStatTile · MetricCell · MetricTrio · "mini stat tile" | 9 |
| `BaselineMeter` + `MeterLayout` + `MasteryLevel` | adapter + **PURE layout** | Track + fill + optional 6 px ink baseline marker that overhangs the track. Sizes h9 / h10 / h12 / h14 / h16; the marker overhang is a **function of track height**, not a second decision — `h14 → ±4`, `h16 → ±5`, no exceptions. **It takes a `MasteryLevel`, never a `Color`** — `pct >= 90 ? green : pink` inside `build()` passes the whole suite today while breaking a stated invariant (R6). | MasteryBar · ProgressMeter · BaselineProgressBar · SkillMiniBar | 7 |
| `EntityRow` ★ | adapter | The row grammar five features draw: leading badge / title + subtitle / polymorphic trailing. The badges (`4.1`'s 34×34 cream, `4.15`'s 44×44 yellow) are `CandySurface` + `BrandText.numeral` passed into `leading` — there is no `RowBadge` class. | SettingsRow | 7 · 6 features |
| `BrandTextField` (+ `resolveFieldVisual`) | adapter + **PURE** state map | States rest (2 px ink, no shadow) / focus (2.5 px pink + shadow (3,4)) / error (2.5 px coral, no shadow), with the label colour following the state. Custom caret 2.5×24 ink. `CAMPO DE TEXTO SIN RUIDO` is the normative spec. | ConfirmByTypingField | 6 |
| `SegmentedIndicator` ★ | adapter | N outlined segments, first k filled, `heights` **required** so `heights.length` *is* the count (a `total` parameter allows a state the widget then has to throw on). Uniform hosts pass `[10, 10, 10]` explicitly. | CalibrationProbeBar · PasswordStrengthMeter · TutorialStepBar · StepMeter · SegmentBar | 4 · `0.5`, `1.5`, `3.2`, `4.6` |
| `StatPill` | adapter | Two sizes (§7.0 C): **`header`** h48 / r24 / shadow (3,5) and **`hero`** r22 / shadow (4,6) with the height from the call site — h56 for `4.12`, h64 for `0.6`. `leadingLabel` / `trailingLabel` (rating reads `RATING 1 248`, streak reads flame + `13` + `días`), `background` for `4.12`'s `#FFD447`. | HomeStatPill · HeaderStatPill · StatChip · StreakPill · RatingChip · StreakBadge | 5 · `01`, `2.1`, `0.6`, `4.12`, ‡ |
| `AppBottomNav` | adapter (owned by `shell`) | h72, white, r26, shadow (4,6), `space-around`. Active slot 64×52 green r18; idle 60×52 muted icon. Identical geometry in three documents. Renders **only the tabs that have roots** (§5.3 D12), from `shell/policy/visible_tabs.dart`. | BottomNavBar | 3 · `01`, `05`, `4.1` |
| `InlineBanner` (+ `resolveBannerVisual`) | adapter + **PURE** variant map | Variants `error` (coral) / `notice` (yellow) — **not** `offline`; the hue encodes *whose fault it is*: *"Sin conexión no es un error del usuario: va en amarillo."* `BannerPlacement { inline, topBand }` absorbs the two skins (K7). The variant map returns a `Verdict` alongside the copy and the optional action chip, so the glyph is not optional. | OfflineBanner | 2 + the normative spec card · `4.9`, `1.7` |
| `DimmedLayer` ★ | adapter | The layer under a sheet: an opacity dim, **no scrim and no blur** — `BackdropFilter` is a `CLAUDE.md` NEVER and both documents rule it out in their own words (*"tablero tapado, no borroso"*). Opacity is K5. | — (no digest named it) | 2 · `4.3`, `3.3` |
| `VerdictChip` | adapter | Renders a `Verdict`. Drawn once (`4.5`) and applied app-wide as the encoding. | — | 1 drawn · app-wide |
| `MathNode` + `FractionMetrics` | **PURE** `design/math/spec/` | Expression layout with font metrics injected; x-height from `OS/2.sxHeight` (Darumadrop 435/1000, Jakarta 536/1000). `OperatorNode(face:, tone:)` carries D7's per-token operator styling. | math_layout · MathLayout · "the compositor" · Spike B | 11 |
| `MathView` | adapter | The painter. **`MathLayout` — a general box-layout engine with nesting — is deferred pending Spike B's exit criterion (`components.md` R6, which is that document's numbering and not §6's risk R6)**: no document draws a nested fraction, a radical or a real superscript, and `x²` is a character append. The names stay in the inventory; the capability is Spike B's exit criterion. | math_view | 11 |
| `FractionGlyph` | adapter, in `design/math/` | Stacked numerator / ink rule / denominator, driven by one size. Variants plain, **struck** (3 px ink bar, −16°, inset −5 each side) and **editable slot** (dashed pink, r12). Also the 15 px `a/b` key face — that one is the `plain` variant at a fixed size and it is built by `f0-keypad`, one phase earlier (§4.0). | StackedFraction · StruckTerm · "mini stacked fraction" | 11 (15 instances) |
| `AnswerSlot` | adapter, in `design/math/` | The generic half — the outlined box and the dashed focus outline. Carries **no Spanish**. `value: String` + `fontSize`; the fraction denominator slot is a `FractionGlyph` parameter, **not** a nested `AnswerSlot`. Whole-number slot: min-width 96 × h52, r14, Darumadrop 34. | "the dashed pink slot" · half of AnswerSlotCard | 8 · 6 item, `0.3`, `0.5` |
| `ExpressionRow` | adapter, in `design/math/` | Operands + operators + `=`. Operator style is **per token**, from the item's rendered prompt (§5.3 D7). | MathExpressionRow · ExpressionLine | 5 (8 instances; gaps 8/14/16/18/20) |

† `0.6`'s rating chip is **not** a `StatPill` — see the note under §3.5.

‡ **K8 is decided (§7.0 C, 2026-08-15): h56 and h64 are one component at two sizes.** `StatPill`
carries `StatPillSize.header` (h48 / r24 / shadow (3,5)) **and `StatPillSize.hero`**, so `0.6`'s
rating chip and `4.12`'s streak badge come back onto this row instead of living as local
compositions. `perfil-estados.md` §3.12 draws the badge at h56 / r22 / border 3 ink / `#FFD447` /
shadow (4,6) and `0.6`'s chip at h64 / r22 / shadow (4,6) / value Darumadrop 38: the two agree on
radius and shadow and differ only in height and fill, which is a size plus the `background` the row
already takes. `hero` therefore resolves r22 / shadow (4,6) and takes its height from the call site.

The scenario in `f0-stat-readouts` inverts with it: it asserted `header` and *no* `hero` member, and
now asserts **both sizes, with `hero` at r22 / shadow (4,6)**. Sites go 3 → 5. The earlier reasoning
is kept above rather than deleted because it is why the collapse needed deciding rather than
assuming — three of the four geometric differences were real, and only the fourth turned out to be a
parameter the row already had.

`design/math/` stays inside `app/lib/` rather than becoming `packages/math_layout`.
`ARCHITECTURE.md` §6's reason for a package — *"a package containing a `CustomPainter` cannot run
under `dart test`"* — is satisfied by the spec/painter split alone. **Exit criterion:** if the
compositor's suite gets slow enough that a Flutter-free `dart test` is worth it, the pure half lifts
out unchanged.

**Micro-geometry does not go in `BrandShape`.** Fraction bar radii (2, 3), dot ring radii, cage
corner radii (4, 7, 9, 10, 11), figurate dot radii and board hairline widths belong to the spec
module that draws them — `design/math/spec/`, `puzzles/policy/board_geometry.dart`. `BrandShape`
governs **widget surfaces**. That distinction is what turns twenty observed radii into a scale of
ten instead of a list of twenty (§5.3 D2).

### 3.4 New — feature-local

Each row names its PURE side. Everything marked **PURE** is testable with zero mocks and its test is
the first thing written.

**`round/`**

| Name | Side | Note |
|---|---|---|
| `AnswerDraft` + `apply(KeypadKeyId, AnswerDraft)` | **PURE** `policy/answer_draft.dart` | Transcribed from the `<script type="text/x-dc">` behaviour spec in `02 Reto activo`: field toggle on `a/b`, backspace pops one char, `neg` toggles a leading U+2212, `sq` appends U+00B2, hard 4-char cap per field, an empty field renders one space so the slot never collapses. Ids outside the item layout return `this`. **Recorded and declined:** `components.md` §4.2 · X4 recommends `design/math/spec/` because three features drive it and it holds no domain vocabulary, and records the counter itself — `AnswerCard` needs the `round` barrel regardless, so leaving the reducer here **costs no extra edge** while moving it churns six test paths, the §2.4 tree and the boundary-test roots. It stays. |
| `Stimulus` (sealed) | **PURE** `policy/stimulus.dart` | `Arithmetic \| NumberSeries \| Matrix \| Analogy \| HiddenOperation \| Figurate`. A sealed type means the seventh shape is a compile error away from being handled. |
| `SeriesState` | **PURE** `policy/series_state.dart` | Five slots, four dot states, advance/fail transitions. Feeds `SlotState`; the dots never read a hue. |
| `FigurateFigureSpec` | **PURE** `policy/` | The four authored figures (1/3/6/10 dots, radii 7 / 7 / 6.5 / 5.4 shrinking with the count so the figure always fits the 52 px box). Authored data with no canvas. Term 5 is undesigned — `components.md` R8. |
| `ItemScaffold` | adapter | The *armazón*: close · dots · `<stimulus slot>` · answer card · keypad. **One shell, six renderers, not six screens.** The renderer map is exhaustive over `Stimulus` and is asserted as data, not by hoping the analyzer is run. |
| `ItemProgressDots` | adapter | Five dots. Renders a `SlotState`, never a hue (§5.3 D6). Size is K10 — 22×22 everywhere except `2.5`'s 18×18. |
| `AnswerCard` | adapter, + barrel | `TU RESPUESTA` + an `AnswerSlot`. `AnswerCardVariant { label, hint }` — `hint` is required by, and only by, the hint variant, which is `02 Reto activo`'s *"Estás escribiendo el denominador"* (conflict K1). The eyebrow is fixed copy, not a `label` parameter. |
| `ItemTermTile` ★ | adapter | The term tile five stimuli share and the error screen replays: white, border 3, r14–16, shadow (3,4), Darumadrop 25–34, plus an `unknown` state that is `#FFD447` + 3 px **dashed** ink + `?`. No digest proposed it; it collapses five separately-stated geometries. **Its `wrong` state has no shape channel left** — see §5.2, design request DR-4. |
| `ArithmeticDiagnosis`, `SeriesDiagnosis` | adapter | The **body** of the error screen, one per stimulus family. Not one `DiagnosisCard`: `04 Error` diagnoses a fraction sum with a three-row step card and a rotated strike, `Error con diagnóstico` diagnoses a number series with a seven-cell replay, a delta row, a divider, an explanation and a check chip. Same frame, different body — see `f2-core-loop`. |
| six `*Stimulus` renderers | adapter | One file each under `ui/stimulus/`. |

**`puzzles/`**

| Name | Side | Note |
|---|---|---|
| `BoardGeometry` | **PURE** `policy/` | Pitch, hairline positions, the outer container. The measurement conflict K17 and its width rule are §5.3 D23. |
| `CageGeometry` | **PURE** `policy/` | Cage outlines: KenKen dash `6 4`, rx 10, inset 5; Killer `2 5` round-cap, rx 9, inset 6. |
| `BoardRules`, `UndoStack` | **PURE** `policy/` | Legality, cage sums, whether a pencil mark counts as an answer, undo. Also the **fillable-cell denominator**: Kakuro's `9 / 24` is 36 grid cells minus 12 blocked, which is content, not layout. |
| `GridBoard` | adapter | The board container plus `cages:`, `blockLines:`, `capsules:` — **parameters, not classes.** The digest models the board as one absolute SVG painting hairlines and decoration under a grid of cells; `CageOverlay`, `BlockRules` and `WordSearchOverlay` were five names for arguments to it. |
| `BoardGlyphLayer` | adapter | `clues:`, `candidates:`, `cageLabels:` — likewise. Absorbs `KakuroClueCell` and `PencilMarks`. |
| `MagicTargets` | adapter (composition) | Composes `OutlinedChip` with a fixed `width`; the 54×62 and 54×46 target chips are `OutlinedChip`'s contract exactly. |
| `PuzzleThumbnail` | adapter, + barrel | Rendered on Inicio and **stays here** — it carries puzzle domain, and `design/` holds no domain. Home imports `puzzles/puzzles.dart`. |
| `ReferenceSheet` | adapter | Deliberately **not** `BrandBottomSheet`: an inset sheet, `left/right/bottom 14, top 150`, full border, r30, shadow (5,7), no grabber, dim 0.45 — against a top-border-only sheet at r32/0 with no shadow and a grabber. Unifying them yields a `mode` parameter that changes every property. It composes `GridBoard(3×3 @ pitch 28)` for its three rule minis, which **must be wrapped in `IgnorePointer`** — as must `3.5`'s 41.6 px recap board. That is a test, not a comment. |
| `PuzzleScaffold`, `PuzzleToolbar` | adapter | Pencil is a per-puzzle **capability**, not four toolbars. The tool row is a `Row` of `IconButtonTile` + `OutlinedChip`. |
| `SessionStore` | adapter `data/` | Local autosave; needs a `sent_rev` and `DELETE … WHERE id=? AND rev=?` or the outbox loses the last save (`ARCHITECTURE.md` §6). |

`TutorialStepBar` and `LegendChip` are **gone as classes**: they are a `SegmentedIndicator` call site
and an `OutlinedChip` call site. `PuzzleKeypad` is a `KeypadLayout` constant.

**`skill_map/`**

| Name | Side | Note |
|---|---|---|
| `SkillGraph` | **PURE** `policy/skill_graph.dart` | The hand-authored 9-node / 9-edge lattice on a 358×576 space, plus `edgeStyle(target)` = solid+ink when reachable, dashed+muted when locked. **All nine SVG edge endpoints were verified arithmetically to land exactly on node centres.** Directly testable, no canvas. Node **states** come from the pack and `SkillGraph` does not derive them — that is the decision in §7.0 B, not a gap. The mastery threshold that turns `user_skills` into `mastered` / `started` / `locked` stays a server-side rule, so `f5-skill-map` ships before it exists and does not change when it is set. |
| `SkillMapNode` | adapter | Stays feature-local **because of an unresolved conflict, and that is recorded rather than hidden**: `05`'s 358×576 geometry (mastered/started 100×62 r20 shadow (3,5), current 132×78 border 4 r24 shadow (4,6), locked 100×62 dashed no shadow) and `0.6`'s 300×150 preview (96×52 r16 shadow (3,4), locked 96×34 r14 dashed) are two coordinate spaces (K4). The duplicate preview node in `calibration/` is a consequence of an open decision and goes away when it is taken. |
| `SkillGraphView`, `SkillNodeDetail` | adapter | Edges painted behind absolutely-placed nodes. Digest aliases: `SkillMapLayout`, `SkillMapGraph`, `SkillMapLegend`. The legend is a **composition** — a `Row` of 14×14 swatches — not a class; Sopa's legend is different geometry and belongs to `puzzles`. |

**`auth/`**

| Name | Side | Note |
|---|---|---|
| `EmailShape`, `PasswordStrength`, `PasswordFloor`, `ResendCooldown(issuedAt, now)`, `AuthErrorTaxonomy` | **PURE** `policy/credential_rules.dart` | Strength → (filled count, es-MX message); cooldown → (remaining, `0:42` formatting, enabled verdict); error tag → **(`Verdict`, banner variant, copy, optional action chip)**. The `Verdict` is not optional: without it two of the three coral banners are distinguished from the yellow one by hue alone, which is BRD-1 failing in the auth flow. The clock is the adapter's. |
| `OtpCodeField` | adapter | Built on `resolveFieldVisual`. |
| `AuthFooterPrompt` | adapter | |
| `AuthClient` | adapter `data/` | |

`OtpKeypad` is a `KeypadLayout` constant (3×4, `1 2 3 / 4 5 6 / 7 8 9 / ⌫ 0 ↵`, keys h60, backspace
`#EAE6F0`, enter `#5ED6A4`), not a widget. `PasswordStrengthMeter` is a `SegmentedIndicator` call
site. **`LabelledDivider` is deleted**: its only instance is the `O` divider on `1.1`, which §5.3 D13
removes along with the OAuth buttons — the first draft listed a component the same document had
already cut (K18). `BrandButtonKind.raised` **stays**: it loses its two OAuth call sites but `1.6`'s
`Ya tengo cuenta` still uses that skin (`100% × 56`, r18, white, shadow (3,5)).

**`calibration/`** — `SkillMapPreview` (adapter; a 300×150 space carrying **its own four preview
nodes as local data**, because K4 makes `SkillMapNode` unshareable and because a pure `SkillGraph`
does not exist until F5). The ten fixed probe-segment heights `[22,16,22,14,20,14,22,16,20,14]` are
**data** passed to `SegmentedIndicator` — the varying heights *are* the "sonda, no serie" signal.
`0.6`'s rating chip is **not** local here: §7.0 C settled K8, so it is
`StatPill(size: hero, height: 64)` with its Darumadrop 38 value, and `calibration/` holds no pill of
its own.

**`home/`** — `DailyChallengeCard`, `DailyPuzzleCard` (adapters); `StreakPolicy(attemptDays, today)`
(**PURE** `policy/`) and `DayLogStore` (`data/`), which are what make the F2 streak pill renderable
at all. **`SkillSummaryCard` is deleted**: D5 picks `Inicio actualizado`, which has no
`TUS HABILIDADES` row, and no change in §4 ever restores it.

**`profile/`** — the drawer §2.4 draws and no row here described, which is how `4.1` reached F7
with a screen, a feature folder and no components. `ProfileSummary` and `HistoryEntry` are
**PURE** `policy/`: the summary is rating, seven-day delta, streak, lifetime attempts, accuracy and
mean answer time; the entry is kind (series or puzzle), title, relative stamp (`Hoy`,
`Ayer · 11:24`), score (`4 de 5`) and a **nullable** delta — puzzle rows read `sin rating`, so the
nullability is drawn, not defensive. `relativeStamp(then, now)` takes both instants; nothing in
`policy/` reads a clock. `ProfileClient` is the adapter (`data/`) over `f3-profile-read`'s two
endpoints. Everything visible on `4.1` is a composition or a shared component — the avatar tile,
the two headline cards and the nav bar are already named — so this drawer builds two pure types, one
client and one screen.

**`settings/`** — `BrandToggle`, `SegmentedChooser<T>`, `BrandBottomSheet` (all adapters);
`Preferences` (**PURE** `policy/`) and `PreferencesStore` (`data/`) per §2.5's carve-out.
**`ReminderSchedule`** (**PURE** `policy/reminder_schedule.dart`) is the fourth: preferences plus a
local calendar day in, a list of `(when, kind)` pairs out, no clock and no plugin — `4.4`'s three
toggles, its hour and its preset chips are that function's input. `ReminderScheduler` (`data/`) is
the plugin-facing adapter, and it is the only file in the app that names a notification API (D21).
`BrandBottomSheet` **moves here from `design/`**: exactly one bottom sheet exists in 51 screens
(`4.3`). `SettingsRow` is an `EntityRow` call site, `DetailHeader` is a `ScreenHeaderBar` call site,
`StepMeter` is a `SegmentedIndicator` call site.

**`shell/`** — `AppRoute` and `visibleTabs(Set<TabRoot>)` (**PURE** `policy/`), `AppScaffold`, the
skeleton layouts, and **`SkeletonBlock`, which moves here from `design/`**: one screen (`4.11`)
draws it in 51, `height` is **required** (`4.11` uses 10/11/12/20/44/74, so there is no honest
default), and it is promoted the day a second feature ships a skeleton. The offline banner is an
`InlineBanner` call site, not a widget.

**`onboarding/`** — no widget of its own. `0.2`, `0.4`, `0.6` and `0.7` are `CenteredStateView`;
`0.3` composes `AnswerCard` + `Keypad` directly.

**`content/`** — the pack model is **PURE** and holds to the §2.2 ceiling; `PackReader` is the asset
adapter beside it.

### 3.5 Compositions — explicitly not components

Naming these as widgets is how a 53-row inventory becomes a 130-row one. Each is `CandySurface` (or
an existing mark) with arguments plus a column of text. The discriminator that survives all six
documents: **a component has a fixed internal structure that repeats; an arbitrary child in an
outlined box is a composition.**

`IllustrationFrame` (`4.10`, 150×150 r34 shadow (5,7)) · `PackCard` (`4.9`) · `ReassuranceCard`
(`4.13`) · `UnlockedCard` / `MasteryCard` (`4.14`) · `AvatarTile` (`4.1`, 78×78 r26 clipping a 66 px
Aki) · `CoverCard` (`3.6`) · **`RatingCard` / `RachaCard`** (`4.1`'s three-row headline pair — a
card, **not** a `StatPill`; K8) · **`4.12`'s streak badge** (h56 / r22 / `#FFD447` / border 3 /
shadow (4,6): flame 20 + `13` Darumadrop 30 + `días en juego` PJS 800 14 — **not** a `StatPill`
either, §3.3 ‡) · every settings card · the tool row · `AkiWithBubble` (a `Stack` of
`Aki` + a positioned `SpeechBubble`) · the **diagnosis step badge** (`04`, a 28 px `CandySurface` +
a check or a numeral) · the **before/after streak counters** (`4.13`, two 82×70 boxes + a 30×24
arrow — the muted-flat against raised contrast *is* the screen, and no `StatTile` emphasis expresses
it) · **`4.8`'s dashed placeholder row** (`CandySurface` h56 r20 + `DashedBorderPainter` 3 px muted —
**must not be merged with `SkeletonBlock`**) · **`SkillMapLegend`** · **`AkiSpec.tailCurl`** (one
`InkStroke`, not a widget).

---

## 4 · The changes, in build order

Each heading is an OpenSpec change: its **id** is the change name, its **phase** is from
`ARCHITECTURE.md` §9. Delta specs follow the format `openspec` requires, and **every scenario names
the test file that verifies it** — `openspec/config.yaml`: *"if you cannot name the test, the
scenario is not a requirement yet."*

Changes on the critical path to the first playable (F0 → F1b → F2) carry full requirement sets.
**F3 and later carry the requirement plus one or two anchor scenarios and expand at propose time** —
their screens will move before they are built, and a hundred scenarios written now against a design
that shifts is worse than an honest horizon.

**Per-change definition of done, in addition to its own tasks** — from `features.md` §3.3(h), and it
is the first thing that silently rots:

1. Every new screen is added to `no_blurred_shadow_test.dart`'s `screens` map.
2. Every new screen is added to the 390×844 overflow test (`f0-invariant-tests`).
3. Tier 1 evidence stated with counts; Tier 1b falsification when the change touches `policy/`.

Point 2 makes `f0-invariant-tests` a prerequisite of **every screen change in the document**, which
is why its own "Blocks" line is not "nothing".

**Test paths follow §2.1's mirror rule** — the test path mirrors the lib path of the file under
test, drawer included. `app/test/architecture/` does not exist on disk yet; `f0-invariant-tests`
creates it, and every scenario below that names a file under it inherits that ordering.

### 4.0 · Which change builds each shared component

§3.3 lists what is shared; this table says who builds it, because a shared widget with no owning
change is a widget the first feature that needs it will fork. Feature-local components are built by
the change that owns their screen.

| §3.3 component | Built by | First consumer |
|---|---|---|
| `DashSpec`, `DashedBorderPainter` | `f0-dashed-border` | the answer slot, F2 |
| `BrandIconSpec`, `BrandIcon` | `f0-brand-icons` | every screen |
| `Verdict`, `SlotState`, `VerdictChip` | `f0-verdict` | the progress dots, F2 |
| `PressableSurface`, `BrandButton`, **`IconButtonTile`** | `f0-pressable-surface` | the item shell's 48×48 close, F2 |
| `Keypad`, `KeypadKey`, `KeypadLayout` | **`f0-keypad`** (new below) | `0.3` and the item screen, F2 |
| `StatTile`, `StatPill`, `BaselineMeter` + `MeterLayout` + `MasteryLevel`, `OutlinedChip` | **`f0-stat-readouts`** (new below) | `03`, `04`, F2 |
| `EsMxNumber`, `MathNode`, `FractionMetrics`, `MathView`, `ExpressionRow`, `AnswerSlot` | `f1b-math-compositor` | the item screen, F2 |
| `FractionGlyph` · **`plain` variant only**, fixed geometry, no `FractionMetrics` | **`f0-keypad`** | the 15 px `a/b` key face, F0 |
| `FractionGlyph` · the **struck** and **editable-slot** variants and metrics-driven sizing | `f1b-math-compositor` | `04 Error`'s strike and the answer slot, F2 |
| `SkeletonBlock` (now `shell/ui/`), `InlineBanner` | `f2-app-shell` | `4.11`, the offline banner |
| `ScreenHeaderBar` | `f2-core-loop` | the six item screens |
| `CenteredStateView` | `f2-onboarding-first-run` | `0.2` — **not built; `0.2` is a bespoke column. `docs/decisions/OPEN.md` §6.** |
| `BrandTextField`, `SegmentedIndicator` | `f3-auth-screens` | `1.1`, `1.5` |
| `EntityRow` | `f5-skill-map` | `2.7 Detalle de nodo` |
| `AppBottomNav` | `f5-skill-map` | the second tab root |
| `DimmedLayer` | `f6-puzzles` | `3.3`'s reference sheet |

---

### F0 · Foundations

#### `f0-token-scale` — phase F0

**Capability:** `design-tokens`. **Screens:** none. **Depends on:** nothing. **Blocks:** every
screen change.

Hard-blocking. `grep -rn "Color(0x" app/lib` returns only `brand_colors.dart` today, and BRD-2b
plus `CLAUDE.md`'s NEVER keep it that way. `#EAE6F0` — the delete key and the skeleton fill —
genuinely blocks the first keypad key.

```
## ADDED Requirements

### Requirement: req-palette-coverage · The palette covers every hue the design uses
The system SHALL expose a named token for every colour the design documents use, and no colour
literal SHALL exist outside `app/lib/design/tokens/`.

#### Scenario: The quiet neutral has a name
- **WHEN** a widget needs the backspace-key fill or a skeleton block fill
- **THEN** `BrandColors.quiet` resolves to `#EAE6F0` and no other file in `app/lib/` contains that
  literal
  → `app/test/design/tokens/brand_colors_test.dart`, `app/test/architecture/no_color_literal_test.dart`

#### Scenario: The figure pink is distinct from the soft pink
- **WHEN** the hidden-operation machine body or a figurate dot is filled
- **THEN** `BrandColors.pinkFigure` resolves to `#FF9EC1` and is not equal to `BrandColors.pinkSoft`
  → `app/test/design/tokens/brand_colors_test.dart`

#### Scenario: Focus is an accent, not a verdict
- **WHEN** the role map is enumerated
- **THEN** `BrandColorRole.focus` resolves to `BrandColors.pink`, and pink still resolves to none of
  `error`, `success`, `action`
  → `app/test/design/tokens/brand_colors_test.dart`

### Requirement: req-shape-scale · The shape scale names the geometry the screens use
The system SHALL name the radii, border widths and shadow offsets that recur across the design
documents, so that no widget writes a geometry literal.

#### Scenario: The most common shadow in the app has a name
- **WHEN** a card, a primary button, the bottom nav or a speech bubble is built
- **THEN** it reads `BrandShape.shadowButton` and that constant equals `Offset(4, 6)`
  → `app/test/design/tokens/brand_shape_test.dart`

#### Scenario: SpeechBubble stops writing its shadow as a literal
- **WHEN** `speech_bubble.dart` is read
- **THEN** it contains no `Offset(` literal and reads `BrandShape.shadowButton`
  → `app/test/architecture/no_geometry_literal_test.dart`

#### Scenario: The radius the cards actually use has a name
- **WHEN** `0.6`'s map card, `1.6`'s card or `04`'s step card is built
- **THEN** it reads `BrandShape.radiusPanel` and that constant equals 24
  → `app/test/design/tokens/brand_shape_test.dart`

### Requirement: req-splash-measurements · The splash matches the measurements the design states
The system SHALL render `0.1 Splash` at the design's stated geometry, because the design is
authoritative on measurements (§5.3 D19) and `splash_screen.dart` predates it.

#### Scenario: The splash is re-measured
- **WHEN** `SplashScreen` is built
- **THEN** `Aki` measures 210 (not 222) and the three gaps are a uniform 26 (not 28/28/36)
  → `app/test/features/splash_screen_test.dart`

#### Scenario: The unexplained border width is settled
- **WHEN** the splash's `width: 4` border is read
- **THEN** it either carries a one-line reason naming what it is doing that
  `BrandShape.borderWidth` cannot, or it is 3
  → `app/test/features/splash_screen_test.dart`

### Requirement: req-type-parameters · Type styles take the parameters the documents need
The system SHALL let a caller vary size, letter spacing and line height on the existing styles
rather than adding new ones.

#### Scenario: An eyebrow at 10 px with 0.06em tracking
- **WHEN** `BrandText.eyebrow(size: 10, letterSpacing: 0.06)` is requested
- **THEN** it returns Plus Jakarta 800 at 10 px with 0.6 px tracking
  → `app/test/design/tokens/brand_typography_test.dart`

#### Scenario: A numeral style that does not lie about its name
- **WHEN** a keypad digit or a board digit is rendered
- **THEN** it reads `BrandText.numeral(29)` — Darumadrop 400 at `height: 1` — not
  `BrandText.sectionTitle(size: 29)`
  → `app/test/design/tokens/brand_typography_test.dart`
```

**Also in this change:** rewrite `BrandFonts.display`'s doc comment, which currently forbids the
usage every document depends on (PROC-6, same session). The splash correction lands here rather than
in its own change because `f0-token-scale` is already opening `speech_bubble.dart` for the same
reason — a measurement the design settled and the code predates. Without an owner, D19 is prose and
R5 erases it.

---

#### `f0-pressable-surface` — phase F0

**Capability:** `press-physics`. **Screens:** none. **Depends on:** `f0-token-scale`.
**Blocks:** every interactive screen.

Nothing in `app/lib/` handles a gesture. The press rule is specified identically on ~50 elements
across all six documents and is the app's entire interaction language. `theme.dart` already sets
`NoSplash.splashFactory`, so the substrate is right.

```
## ADDED Requirements

### Requirement: req-press-displacement · A pressed surface travels into its own shadow
The system SHALL render a press as a translation by exactly the surface's own shadow offset with
the shadow removed, and SHALL apply no opacity change, no scale and no ripple.

#### Scenario: A keypad key is pressed
- **WHEN** a `PressableSurface` with `shadow: BrandShape.shadowTile` is pressed
- **THEN** its child is offset by `Offset(3, 5)` and its decoration carries no `BoxShadow`
  → `app/test/design/widgets/pressable_surface_test.dart`

#### Scenario: A primary button is released
- **WHEN** the pointer is released
- **THEN** the offset returns to zero and the shadow returns to `Offset(4, 6)`, and `onPressed`
  fires exactly once
  → `app/test/design/widgets/pressable_surface_test.dart`

#### Scenario: A shadowless surface still reports a press
- **WHEN** a secondary button (`shadow: null`) is pressed
- **THEN** `onPressed` fires and the surface does not move
  → `app/test/design/widgets/brand_button_test.dart`

### Requirement: req-touch-target · Every interactive target clears 48 logical pixels
The system SHALL give every pressable a hit box of at least `BrandShape.minTouchTarget` in both
dimensions, independent of its painted size.

#### Scenario: A tertiary text action is smaller than its hit box
- **WHEN** `BrandButton.text` renders "Dejar la serie" at its drawn ~29 px height
- **THEN** its hit-test area measures at least 48×48
  → `app/test/design/widgets/brand_button_test.dart`

### Requirement: req-icon-button-tile · The icon tile is one widget, not seven
The system SHALL render close, back, pause, undo, hint, pencil and gear as one 48×48 tile — r16,
shadow (3,4), optional toggled fill — built on `PressableSurface`.

#### Scenario: The pencil tile toggles its fill and nothing else
- **WHEN** `IconButtonTile` is built toggled and untoggled
- **THEN** the fill is `#FFD447` and `BrandColors.surface` respectively, and the geometry, the press
  travel and the hit box are identical in both
  → `app/test/design/widgets/icon_button_tile_test.dart`
```

BRD-2d is a MUST and it fires at F2, not later: `Dejar la serie` is ~29 px and F2 ships it. Later
instances — the reference sheet's 44×44 close, the 60×34 toggle, `4.4`'s 40 px preset chips — get
the same treatment with the visual unchanged.

**`IconButtonTile` is here because it is `PressableSurface` plus fixed geometry and because this
change already has its first consumer**: the item shell's 48×48 close control. Six touch targets in
the corpus are drawn below 48 and each is a design decision rather than a bug to patch by growing a
box, so `req-touch-target` goes red on day one for reasons that are not defects — they are listed
in §5.2 as design request DR-6.

**Open and owned here:** no document specifies a **duration, a curve or a haptic** for the press,
and *"travel into your own shadow"* yields **zero displacement** on a shadowless control — the
secondary button, the ghost row, the pills, the map nodes and the nav items carry no active style
anywhere. `PressableSurface` must not silently ship a control that does nothing visible when
pressed. §5.2, DR-5.

---

#### `f0-dashed-border` — phase F0

**Capability:** `dashed-outline`. **Depends on:** `f0-token-scale`, `f0-invariant-tests` (it amends
that change's gate). **Blocks:** the answer slot, the verdict encoding, locked map nodes,
empty-state placeholders, every puzzle cage.

```
## ADDED Requirements

### Requirement: req-dash-spec · Dash patterns are computed as data
The system SHALL compute dash segmentation in a module that touches no `Canvas`.

#### Scenario: A pattern that does not divide the perimeter evenly
- **WHEN** `DashSpec(on: 9, off: 9).segments(pathLength: 100)` is requested
- **THEN** it returns segments covering the full length with the final segment truncated, never
  overrunning
  → `app/test/design/painting/spec/dash_spec_test.dart`

#### Scenario: The three patterns the documents use produce their stated segment counts
- **WHEN** the KenKen (`6 4`), Killer (`2 5`) and locked-edge (`9 9`) patterns are segmented over a
  100 px path
- **THEN** the counts are 10, 15 and 6 respectively, and the Killer pattern reports a round cap
  → `app/test/design/painting/spec/dash_spec_test.dart`

(Stated as counts on purpose. *"They produce different segment lists"* is true of any implementation
that reads its own arguments and can never go red.)

### Requirement: req-dashed-outline · A dashed outline paints around a rounded rectangle
The system SHALL draw a dashed border on a `CandySurface` with a caller-supplied colour, width and
pattern.

#### Scenario: The focused answer slot
- **WHEN** an answer slot is focused
- **THEN** its border is 3 px, `BrandColors.pink`, dashed, radius 12, and no solid border is painted
  → `app/test/design/painting/dashed_border_test.dart`

#### Scenario: A cage outline is inset inside the hairline it sits on — **RETRACTED 2026-08-29**
This scenario described a rounded rectangle drawn around a whole cage, and F6 does not draw one.
`fix-cage-outline-is-the-boards-weight` replaced that model with a path of **only the sides on the
boundary**, because a rounded rectangle per cell draws a line through the middle of every
multi-cell cage — so `radius` and `inset` were figures no painter could read, and they are gone
from `CageOutline` along with the assertion that used them. Its arithmetic was
`inset − strokeWidth / 2 > 0.75`; the per-edge painter insets by `strokeWidth / 2` exactly, which
makes it `0 > 0.75`, and **the cage does cover the hairline on the sides it is on** — correctly, it
being the heavier of the two lines. The rx/inset figures stay recoverable in
`openspec/changes/archive/2026-08-26-f0-dashed-border/` and are quoted in
`app/lib/design/puzzle/spec/cage_outline.dart`, which is where a cage's appearance now lives.

What replaces it is the scenario that was missing, and whose absence let a Killer board draw
KenKen's dash for weeks with a green suite:

#### Scenario: Each caged format is drawn in its own outline
- **WHEN** a KenKen board and a Killer board are pumped and their cage painters are read
- **THEN** the KenKen cage is `6 4` butt-capped and the Killer cage is `2 5` round-capped, both
  2.5 px pink, and the two are never the same outline
  → `app/test/features/puzzle/ui/puzzle_screen_test.dart`,
  `app/test/features/puzzle/policy/board_constraints_test.dart`

### Requirement: req-no-blur-painters · The no-blur gate covers painters, not only decorations
The system SHALL assert the absence of `BackdropFilter` and of any non-zero `MaskFilter` in the
pumped tree, in addition to the four assertions it makes today.

#### Scenario: A painter that blurs
- **WHEN** a screen paints with a blurred `MaskFilter`
- **THEN** `no_blurred_shadow_test.dart` fails
  → `app/test/design/no_blurred_shadow_test.dart`
```

**`req-no-blur-painters` lives in this change and not in `f0-invariant-tests`, deliberately**
(§5.3 D22). `no_blurred_shadow_test.dart` walks `DecoratedBox` / `PhysicalModel`, so the moment a
border moves into a `CustomPainter` the surface leaves the gate's reach — and `borderDash` is
exactly what moves it, on the answer slot, `4.8`'s placeholders, the locked map node, `VerdictChip`,
every cage and Sopa's capsule. Landing the two in one change is what stops the invariant from
silently ceasing to cover the components that carry BRD-1's shape encoding.

---

#### `f0-brand-icons` — phase F0

**Capability:** `icon-set`. **Depends on:** `f0-token-scale`. **Blocks:** almost every screen.

~21 stroke icons: chevron-left, chevron-right, gear, check, alert, wifi-off, flame, arrow-right,
arrow-down, **arrow-up** (the 11×11 glyph in `Reactivo serie`'s hint pill), backspace, submit arrow,
pause, undo, hint, pencil, X, padlock, kenken mark, the four
nav glyphs, the 60×60 server mark. Path data is transcribed verbatim from the digests. They follow
the `design/brand/spec/` precedent — geometry as pure data, painter as adapter — and no icon
package enters `pubspec.yaml` (DEP-1).

```
## ADDED Requirements

### Requirement: req-icon-spec · Icons are path data, painted by an adapter
The system SHALL hold every icon's geometry in a pure module and paint it from a separate adapter.

#### Scenario: The backspace glyph is one spec at two sizes
- **WHEN** the item keypad requests it at 24 px and the puzzle keypad at 23 px
- **THEN** both resolve to the same `BrandIconSpec` and differ only in rendered size
  → `app/test/design/icons/spec/icon_paths_test.dart`

#### Scenario: The spec carries its own stroke weight
- **WHEN** the submit arrow and the backspace glyph are compared
- **THEN** the submit arrow's stroke width is 3.2 and the backspace's is 2.6
  → `app/test/design/icons/spec/icon_paths_test.dart`

#### Scenario: No icon dependency is added
- **WHEN** `app/pubspec.yaml` is read
- **THEN** its runtime dependencies are exactly `flutter`, `cupertino_icons` and `meta`
  → `app/test/architecture/dependency_allowlist_test.dart`
```

The allowlist is a committed list, so **any change that adds a dependency amends this test and owes
the `CLAUDE.md`:9 phones-home check in the same change**. One is scheduled: `f8-motion`'s Rive.

---

#### `f0-verdict` — phase F0

**Capability:** `verdict-encoding`. **Depends on:** `f0-dashed-border`, `f0-brand-icons`.
**Blocks:** `f2-core-loop` (which contributes the progress-strip scenario), `f3-auth-screens`
(the banner taxonomy returns a `Verdict`) — the strip ships at F2, so this cannot wait for F7.

`ARCHITECTURE.md` §6 asks for a `Verdict` type without `.color`. BRD-1 requires success and error
to differ in **shape**, not hue alone. The design already solved this on `4.5 Accesibilidad` —
success is a **solid** ink outline with a check, error is a **dashed** ink outline with an alert
glyph — and then failed to propagate it. Every other screen distinguishes correct from wrong by hue
alone: two 22 px circles with an identical 3 px border, `#5ED6A4` versus `#FF8A5B`. Deuteranopia
collapses them. **The encoding is always on** (§5.3 D6); `4.5`'s "Modo daltonismo" toggle only adds
redundancy on top.

```
## ADDED Requirements

### Requirement: req-verdict-type · A verdict cannot be communicated by hue
The system SHALL expose a `Verdict` type that carries an outline style and a glyph, and SHALL NOT
expose a colour on it.

#### Scenario: The type has no colour accessor
- **WHEN** `Verdict`'s public surface is enumerated
- **THEN** it exposes `outline` and `glyph` and no member returns a `Color`
  → `app/test/design/widgets/spec/verdict_test.dart`

#### Scenario: Success and error differ in shape
- **WHEN** `Verdict.correct` and `Verdict.wrong` are compared
- **THEN** their outline styles differ (solid vs dashed) and their glyphs differ (check vs alert)
  → `app/test/design/widgets/spec/verdict_test.dart`

#### Scenario: The paint adapter differs in greyscale
- **WHEN** the ring adapter is asked to paint `Verdict.correct` and `Verdict.wrong` at the same size
  with colour stripped
- **THEN** the two outputs differ in stroke pattern and in glyph, and neither is distinguishable by
  fill alone
  → `app/test/design/widgets/spec/verdict_test.dart`

### Requirement: req-verdict-everywhere · Every state signal in the app renders a verdict, not a hue
The system SHALL render correct/wrong state through `Verdict` wherever it appears — the progress
dots, the verdict screens, the auth banners, the map nodes and `4.5`'s pair.

#### Scenario: The auth banners differ in greyscale
- **WHEN** `1.7`'s credential banner and the no-connection banner are rendered
- **THEN** the first carries the alert glyph and the second the wifi-off glyph, and the two are
  distinguishable with colour stripped
  → `app/test/features/auth/ui/auth_banner_test.dart`
```

**The glyph is the channel that can never be preempted; the outline is the one a widget may already
have spent.** `ItemTermTile`'s `unknown` state is *already* yellow + 3 px **dashed** ink + `?` on
five of the six stimulus screens, so on that widget `Verdict.wrong` cannot claim the dash without
colliding with "still to fill" — which would reintroduce exactly the failure BRD-1 names, on six
screens. `Verdict` keeps both channels; the glyph is mandatory at every call site and the outline is
honoured where it is free. Which channel `unknown` gives up is a **design request, not a code
decision** — §5.2, DR-4.

**The strip scenario moved.** The greyscale progress-dot scenario used to live here and named
`app/test/features/round/ui/item_progress_dots_test.dart` — a file under a feature that does not
exist until `f2-core-loop`, which itself depends on this change. Naming a test **is** an ordering
edge under `openspec/config.yaml`, so that was a cycle. The scenario now lives in `f2-core-loop`
verbatim, and this change verifies the type and its paint adapter, which is where it can actually
go red.

---

#### `f0-invariant-tests` — phase F0

**Capability:** `architecture-gates`. **Depends on:** nothing. **Blocks:** `f0-dashed-border`
(which amends the no-blur gate), `f1b-math-compositor` and every change that writes a `policy/`
(`pure_boundary_test.dart`), and **every screen change in the document** through §4's own definition
of done (`screen_overflow_test.dart`). It also creates `app/test/architecture/`, which several
F0 scenarios above already name. It is not "any time": it is first.

Three holes in §1.3, closed cheaply while the surface is small. R5 is precisely the observation that
prose invariants erode under agents.

```
## ADDED Requirements

### Requirement: req-pure-boundary · The pure boundary is enforced by a test, not by prose
The system SHALL fail the build when a file under `features/*/policy/`, `design/**/spec/` or
`content/model/` imports Flutter, reads a clock, or reads randomness — resolving repo-local
directives to their **transitive closure over `import` ∪ `export`**, stopping at `dart:` and
third-party `package:` URIs.

#### Scenario: The token barrel is caught transitively
- **WHEN** a `policy/` file imports `design/tokens/tokens.dart`
- **THEN** the test fails, naming the barrel and the `package:flutter/painting.dart` it re-exports
  → `app/test/architecture/pure_boundary_test.dart`

#### Scenario: The closure follows exports, not only imports
- **WHEN** the resolver walks `tokens.dart`, whose three directives are all `export` and whose own
  imports are none
- **THEN** it still reaches `brand_typography.dart` and reports the violation — a one-hop resolver,
  and any resolver that follows `import` alone, reports zero
  → `app/test/architecture/pure_boundary_test.dart`

#### Scenario: An ambient clock is caught
- **WHEN** a `policy/` file contains `DateTime.now()` or `Random(`
- **THEN** the test fails, naming the file and line
  → `app/test/architecture/pure_boundary_test.dart`

#### Scenario: The gate is not vacuously green
- **WHEN** the roots are enumerated
- **THEN** the test reports the count of files it scanned and fails if that count is zero for a root
  that exists on disk
  → `app/test/architecture/pure_boundary_test.dart`

### Requirement: req-acyclic-features · Feature barrels do not form a cycle
The system SHALL fail when the same closure finds a cycle among `features/*/<feature>.dart`, because
Dart compiles import cycles without complaint and §2.5's acyclicity rule has no other enforcement.

#### Scenario: Two features import each other's barrel
- **WHEN** `home` imports `shell/shell.dart` while `shell` imports `home/home.dart`
- **THEN** the test fails, printing the cycle
  → `app/test/architecture/pure_boundary_test.dart`

### Requirement: req-screen-overflow · Screens do not overflow at the design viewport
The system SHALL pump every screen at 390×844 and at 390×844 with `textScaler` 1.3, and SHALL fail
on any render overflow.

#### Scenario: A screen that fits at 1.0 and not at 1.3
- **WHEN** a screen whose content measures 803 px in 838 px is pumped at scale 1.3
- **THEN** the test fails with the overflowing widget named
  → `app/test/design/screen_overflow_test.dart`
```

`04 Error` already measures ~803 px of content in 838 px, and today **no test in the repo would go
red on that overflow**. This test is also the condition that makes deferring `4.5`'s text-size
toggle (§7 Q8) safe rather than merely postponed.

**Two limits of a directive-level scan, stated so they are not discovered as bugs:** comments must
be stripped before scanning or `// import 'package:flutter/…'` is a false positive; and the textual
clock check does not see `Random.secure()`, a `DateTime.now` tear-off, or a `now()` arriving as a
parameter — which is the shape §2.2 wants. Also note that banning `import 'dart:async'` in `policy/`
bans nothing useful: `Future` and `Stream` come from `dart:core`. If the intent is *policy does not
wait*, the check is for `async` / `await` / `Future<` in the body.

---

#### `f0-keypad` — phase F0

**Capability:** `keypad`. **Screens:** none directly. **Depends on:** `f0-pressable-surface`,
`f0-brand-icons`, `f0-token-scale`. **Blocks:** `f2-core-loop`, `f2-onboarding-first-run`,
`f3-auth-screens`, `f4-calibration`, `f6-puzzles`. **Also builds:** `FractionGlyph`'s `plain`
variant, for the `a/b` key face — see the phase-inversion note at the end of this change.

**This change exists because the first draft did not have one.** D14 states that the three layouts
*"share `KeypadKey`"*, and §3 then filed `ItemKeypad` under `round`, `PuzzleKeypad` under `puzzles`
and `OtpKeypad` under `auth` as three independent adapters, with no shared key, no owner and no
build slot. `components.md` calls that **the largest defect found in plan §3**. Written that way,
three keys get built and the U+2212 / U+00B2 / U+002C codepoint contract — risk R2 — is re-typed in
three features.

The geometry is identical across the documents: border 3, radius 18, shadow (3,5), press
`translate(3,5)`, and the backspace glyph is byte-identical between `TecladoReactivo` and
`TecladoPuzzle`, differing only in rendered size (24 px against 23 px).

```
## ADDED Requirements

### Requirement: req-keypad-layout-pure · A layout is data, not a widget
The system SHALL declare the three layouts as pure constants — key ids, faces and per-key fills —
in a module that touches no `Canvas` and no widget.

#### Scenario: The three layouts are the three the design draws
- **WHEN** `KeypadLayout.item`, `.puzzle` and `.otp` are enumerated
- **THEN** `item` is 4×4 in calculator order with `, 0 ⌫ ➜` last, `puzzle` is 5×2 in **reading**
  order with digits 1–9, no `0`, no submit, and `otp` is 3×4 with `⌫ 0 ↵` last
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

#### Scenario: The codepoint contract is typed once
- **WHEN** the union of key ids across the three layouts is enumerated
- **THEN** the negate key emits U+2212 (never U+002D), the square key U+00B2, the decimal key
  U+002C, and no layout declares an id outside that union
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

#### Scenario: A key face is not a nullable string
- **WHEN** the `a/b` key, the `7` key and the backspace key are read
- **THEN** their faces are `FractionFace`, `TextFace` and `IconFace` respectively, and no face is
  expressed as a `String?` that is null for the icons
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

### Requirement: req-keypad-widget · One key widget renders every layout
The system SHALL render any `KeypadLayout` through one `KeypadKey`, and SHALL hold no answer rule.

#### Scenario: Item and puzzle keys are the same widget at two sizes
- **WHEN** the item layout and the puzzle layout are built
- **THEN** the keys are h62 gap 10 and h58 gap 9, both border 3 / r18 / shadow (3,5), and both
  render the same backspace `BrandIconSpec` at 24 and 23
  → `app/test/design/widgets/keypad_test.dart`

#### Scenario: The keypad clears the touch minimum on a narrow device
- **WHEN** each layout is laid out at 320 logical pixels wide
- **THEN** every key measures at least 48×48
  → `app/test/design/widgets/keypad_test.dart`

#### Scenario: The system keyboard never appears
- **WHEN** a keypad is mounted
- **THEN** no `EditableText` and no `TextField` is in the tree
  → `app/test/design/widgets/keypad_test.dart`

#### Scenario: The `a/b` face is a stacked fraction and takes no metrics
- **WHEN** the item layout's `a/b` key is built
- **THEN** its face renders `a` over a 20×3 ink bar over `b` with a 2 px gap at 15 px, through
  `FractionGlyph`'s `plain` variant, whose constructor takes a size and **no** `FractionMetrics`
  → `app/test/design/widgets/keypad_test.dart`,
  `app/test/design/math/fraction_glyph_test.dart`
```

**Deliberately not unified:** the item pad is calculator order (7-8-9 on top) and the puzzle pad is
reading order (1-2-3 on top). The digest says so explicitly and says not to unify them without a
design decision. One widget, two orders, as data.

**A phase inversion had to be settled to make this change buildable, and it is settled here.** The
`a/b` key face is a 15 px `FractionGlyph` (§3.3), and §4.0 gave `FractionGlyph` to
`f1b-math-compositor` — so an F0 change could not go green without an F1b component, and its
`Depends on` line said nothing about it. Three options were on the table: **(a)** raise only the
`plain` variant of `FractionGlyph` into this change; **(b)** narrow the widget scenario here to
`puzzle` + `otp` and move the `item` layout into a `f1b-math-compositor` scenario; **(c)** move
`f0-keypad` whole into F1b, behind the compositor. **Decision: (a).** `teclados.md`:92-98 describes
the face as pure geometry — `a` over a 20×3 bar over `b`, gap 2 — with no `FractionMetrics` and no
metric injection, unlike the struck and editable-slot variants, so the separable half is genuinely
separable. (b) was rejected because `KeypadKey` renders `FractionFace` either way: scoping the
*scenario* leaves the *code* dependency in place and splits one widget across two changes with no
test naming the seam. (c) was rejected because it drags the OTP and puzzle pads behind the longest
pole in the plan (R1) for a fraction neither of them draws. So this change creates
`design/math/fraction_glyph.dart` with the `plain` variant only, and `f1b-math-compositor` extends
that file — F0 precedes F1b, so the split adds no edge across the two lanes. (This change *is* on the
critical path, but for the other reason: `f2-core-loop` depends on it, and §5.4 now says so.) The
invariant that keeps the split honest: **the `plain` variant takes a size and never a
`FractionMetrics`.** Reversible into (c) in one move if Spike B finds the two are one widget after
all.

---

#### `f0-stat-readouts` — phase F0

**Capability:** `stat-readouts`. **Screens:** none directly. **Depends on:** `f0-token-scale`,
`f0-pressable-surface`. **Blocks:** `f2-core-loop` (`03`, `04`), `f2-home-reduced`,
`f2-series-summary`, and every later screen that prints a measured number.

`StatTile`, `StatPill`, `BaselineMeter` and `OutlinedChip` appeared in the first draft's inventory
and in **no change at all**. All four are on F2 screens: `03 Acierto` draws three stat tiles and a
meter with a baseline marker, `04 Error` draws three flat tiles and an inline h14 meter, `2.5` draws
three tiles and two meters, and the counter chip (`5 retos`, `3 / 9`) is `OutlinedChip`.

**Those are the counts the documents draw, not the counts F2 builds.** Q3 and Q4, both decided
2026-08-15, take the rating-delta tile off `03` and `04`, which ship **two** — see `f2-core-loop`.
Nothing here changes, because this change ships **variants, not instances**: `req-stat-readouts`
below fixes the three `StatTile` variants — `raised`, `compact`, `flat` — and the one `StatPill`
size, and how many tiles a given screen mounts is that screen's change to decide. The distinction is
worth the sentence because
§4 is where an implementer builds from, and "draws three" one phase away from "ships two" is exactly
how a third tile gets written.

```
## ADDED Requirements

### Requirement: req-meter-takes-a-level · The meter is handed a mastery level, never a colour
The system SHALL type `BaselineMeter`'s fill as a `MasteryLevel` and SHALL NOT accept a `Color`.

#### Scenario: The signature refuses a colour
- **WHEN** `BaselineMeter`'s constructor is enumerated
- **THEN** it takes a `MasteryLevel` and no parameter of type `Color`
  → `app/test/design/widgets/baseline_meter_test.dart`

#### Scenario: No widget decides a hue by comparison
- **WHEN** `app/lib/` is scanned for a colour chosen by a numeric comparison — the
  `pct >= 90 ? green : pink` shape
- **THEN** none is found
  → `app/test/architecture/no_hue_by_comparison_test.dart`

#### Scenario: The marker overhang is a function of track height
- **WHEN** meters are laid out at h14 and h16 with a baseline marker
- **THEN** the 6 px ink marker overhangs by ±4 and ±5 respectively, for every instance
  → `app/test/design/widgets/spec/meter_layout_test.dart`

### Requirement: req-stat-readouts · Stat tiles and pills ship the geometries the documents draw
The system SHALL render `StatTile` in three variants and `StatPill` at the header size only.

#### Scenario: The three tile clusters
- **WHEN** `raised`, `compact` and `flat` are built
- **THEN** they are r20 / shadow (3,5) / value 26, r18 / shadow (3,5) / value 24 and r16–18 / no
  shadow / value 21–24
  → `app/test/design/widgets/stat_tile_test.dart`

#### Scenario: The rating delta is two runs, not one span
- **WHEN** a `−6` delta is rendered
- **THEN** the sign is Plus Jakarta 800 15 and the digits are Darumadrop 22, baseline-aligned with a
  3 px gap, and the value is produced by `EsMxNumber.deltaParts`
  → `app/test/design/widgets/stat_tile_test.dart`

#### Scenario: The pill ships both sizes
- **WHEN** `StatPill`'s sizes are enumerated
- **THEN** `header` resolves h48 / r24 / border 3 / shadow (3,5), and `hero` resolves r22 /
  shadow (4,6) taking its height from the call site
  → `app/test/design/widgets/stat_pill_test.dart`

#### Scenario: The hero size carries the two screens that forced K8
- **WHEN** `StatPill` is built at `hero` with height 56 and `background: BrandColors.yellow`, and
  again at height 64 with the default background
- **THEN** the first matches `4.12`'s streak badge and the second `0.6`'s rating chip, and neither
  screen holds a local pill composition
  → `app/test/design/widgets/stat_pill_test.dart`
```

**`StatPill` ships two sizes, and K8 is why it needed deciding rather than assuming.** The first
draft collapsed `0.6`'s rating chip into the header size and was wrong to: h64 / r22 / shadow (4,6)
with a Darumadrop 38 value, against h48 / r24 / shadow (3,5), is the same failure the plan warns
about with `CandySurface.pill` — forcing a screen through the wrong constructor and landing the
wrong radius and the wrong shadow. The second draft then removed `4.12`'s badge for the same reason
and left both screens holding local compositions.

**§7.0 C settles it: one component, two sizes.** Looked at across both screens rather than each
against `header`, `0.6` (h64 / r22 / shadow (4,6)) and `4.12` (h56 / r22 / shadow (4,6) on
`#FFD447`) **agree on radius and shadow** and differ only in height and fill — a size and a
`background`, both of which the row already carries. So `hero` resolves r22 / shadow (4,6), takes
its height from the call site, and the two screens stop being local compositions. `RatingChip` and
`StreakBadge` return to the alias list; `StatPill`'s site list is `01`, `2.1`, `0.6`, `4.12`.
The two `StatTile` variants merge cleanly as they always did.

What survives from the earlier reasoning is the method, not its conclusion: three of four measures
really did disagree with `header`, and comparing each screen to the *default* size rather than to
*each other* is what hid the shared geometry for two drafts.

---

#### `f0-dart-client-spike` — phase F0 (Spike A)

**Capability:** none — a spike whose output is a decision recorded in `docs/adr/`.
**Depends on:** nothing.

`CLAUDE.md`'s stated open decision: `swagger_dart_code_generator` versus ~250 hand-written lines.
`ARCHITECTURE.md` §2's exit criterion is already written: three representative Zod schemas → OpenAPI
→ Dart, **read the generated code**, run the generator twice and compare bytes. *If the generated
Dart is not better than what you would write by hand, write it by hand.* Half a day, and if it is
not deterministic the `git diff --exit-code` gate does not exist. Neither a JVM nor Docker is on
this machine, which already removes `dart-dio` and `openapi-generator-cli`.

---

#### `f0-pack-contract` — phase F0 · **the load-bearing change**

**Capability:** `offline-pack-format`. **Screens:** none. **Depends on:** the pre-F1 decisions in
§5.1. **Blocks:** `f1b-content-reader`, `f1-5-pack-builder`, and therefore both lanes.

This is what decouples the Dart track from the TypeScript track, which is the whole point of §9's
two parallel lanes: **freeze the pack shape at F0 as a versioned artifact and read a hand-written
fixture pack immediately.** The format is a cross-stack contract (`ARCHITECTURE.md` §1 lists it as
one of six), so it lives in `contract/` with golden fixtures.

**Q2 was due before this change, not before F1.5 — and it was answered on 2026-08-15** (per-distractor
`HMAC → {misconception, steps, explain}` plus a generic per-skill fallback), so what follows is why
the format survives an answer arriving late rather than a live risk. The first draft dated it three ways at once —
§5.1 put it in Gate B (*before F1*), §7 said *before F1.5*, and this change's own dependency line
says *the pre-F1 decisions in §5.1*, which for an F0 change means before F0. A format that freezes
at F0 cannot wait for an F1.5 decision about which fields it carries. The earliest date wins, and
the mechanism that makes it survivable is written into the format now: the diagnosis payload is a
**reserved, versioned, nullable field** (`diagnosis: DiagnosisPayload | null`), so answering Q2
later fills a slot instead of reopening a frozen artifact. Q4 and Q5 get the same treatment where
they touch the pack.

Two shapes the design forces and `ARCHITECTURE.md` §4 does not yet carry:

- **The prompt is not a token stream.** §4 types it `PromptToken[]` and §2 forbids response
  polymorphism. But a 3×3 matrix with pink margin arrows, a function machine with Aki's tail curl,
  seven elastic tiles, two pair-cards joined by a bridge pill and figurate SVGs whose dot radius
  shrinks with the count cannot be expressed as a flat list. **Decision:** the prompt is
  `{ kind, payload }` where `kind` is the closed six-member enum of §3.4's sealed `Stimulus` and
  `payload` is an opaque per-kind object with one Zod schema per kind. Variance lives inside an
  opaque payload, which is exactly what §2 permits. The mitigation for the six hand-written Dart
  parsers is `contract/fixtures/` carrying **one golden fixture per kind, including rejection
  rows** — that is R2's remedy moved from grading to layout.
- **The answer shape is a union too:** `(num, den)` for a fraction, an integer for series, matrix,
  analogy, hidden operation and figurate. `AnswerSpec` is a closed union with the same fixture
  discipline.
- **The pack carries puzzles, and the first draft's did not.** `f6-puzzles` promises *"plays fully
  offline"* while `CLAUDE.md`:175 forbids generating a board on the client — so the boards must
  arrive in the pack, and the pack format freezes here, three phases earlier. Nothing in the first
  draft modelled a cage, a blocked cell, a row or column sum, a solution, a tutorial step or the
  reference-sheet content. **Decision:** `PuzzleSpec` is a closed union keyed by
  `PuzzleKind { kenken, kakuro, killer, magicSquare, wordSearch }` with an opaque per-kind payload
  and one Zod schema per kind — the same shape as the prompt, for the same reason.

```
## ADDED Requirements

### Requirement: req-pack-artifact · The offline pack format is a versioned, committed artifact
The system SHALL define the pack format once, in `contract/`, and SHALL fail CI when the emitted
format and the committed artifact differ.

#### Scenario: The format is regenerated and unchanged
- **WHEN** the emitter runs twice
- **THEN** both runs produce byte-identical output and `git diff --exit-code` passes
  → `packages/contract/test/pack_format.test.ts`, CI job `contract`

### Requirement: req-pack-fixtures · A golden fixture exists for every kind the pack can carry
The system SHALL carry one golden fixture per stimulus kind and per puzzle kind, each with its
rejection rows, in `contract/fixtures/`.

#### Scenario: Eleven kinds are fixtured
- **WHEN** `contract/fixtures/` is enumerated
- **THEN** it holds a golden fixture for each of the six stimulus kinds and each of the five puzzle
  kinds, and the TypeScript parser accepts every one
  → `packages/contract/test/fixtures.test.ts`

#### Scenario: A rejection row is rejected
- **WHEN** a fixture containing `""`, `"1/0"`, `"x+1"`, U+0660, U+2212, ZWSP or a combining mark is
  parsed as an answer
- **THEN** the parser rejects it with a stable tag
  → `packages/contract/test/canon.test.ts`

#### Scenario: A malformed board is rejected
- **WHEN** a puzzle fixture declares a cage that does not cover its cells, an impossible sum, or a
  board with no unique solution
- **THEN** the parser rejects it with a stable tag
  → `packages/contract/test/fixtures.test.ts`

### Requirement: req-keypad-layouts · The keypad is one of three named layouts, not a per-template spec
The system SHALL declare `KeypadLayout` as a closed enum of `item`, `puzzle` and `otp`.

#### Scenario: A template cannot request a bespoke keypad
- **WHEN** a pack item declares its keypad
- **THEN** the value is one of the three layouts and no per-key list is accepted
  → `packages/contract/test/keypad_layout.test.ts`
```

**The Dart half of the parity claim moved to `f1b-content-reader`, and it had to.** The first draft
wrote two scenarios here naming `app/test/content/model/pack_test.dart` and
`…/canon_test.dart` — Dart files that require the pack parser, which is exactly what
`f1b-content-reader` produces, and `f1b-content-reader` declares `Depends on: f0-pack-contract`.
Under `openspec/config.yaml`'s rule that a named test is what makes a scenario a requirement, that
is a cycle on **the one change that must not slip**. This change now owns the TypeScript side and
the frozen fixture; `f1b-content-reader` owns `req-pack-parity`, written against that fixture. The
arrow points one way.

---

### F1b · Dart lane (parallel with F1)

#### `f1b-math-compositor` — phase F1b (Spike B first)

**Capability:** `math-composition`. **Screens:** none directly. **Depends on:** `f0-token-scale`.
**Blocks:** `round`, `home`, `onboarding`, `calibration`.

R1 names this **the only thing between F0 and playable** and says every estimate underrates it
roughly 2×: the week of visual iteration fitting a thick outline onto thin glyphs is in nobody's
plan. Spike B's exit criterion is already written — *the ugliest expression in v1, with the 3 px
outline applied, in two days.* Not a clean `1/2`.

The documents disagree on the largest numeral: 84 px (`0.3`), 76 px (`02`, `0.5`), 70 px
(`Reactivo aritmética`). **Decision:** 76 px. It is the size both *screen* documents that show a
real solve screen use; 84 is the teaching item `0.3` (which has more room because it has no dot
strip), and 70 is the later revision of the same screen. The compositor takes the size as a
parameter, so this decides a default, not a capability.

```
## ADDED Requirements

### Requirement: req-math-layout-pure · Expression layout is computed without a canvas
The system SHALL lay out an expression from injected font metrics, in a module that constructs no
`Path` and touches no `Canvas`.

#### Scenario: A nested fraction lays out from metrics alone
- **WHEN** `MathNode.layout(expression, metrics: darumadropMetrics)` is called for a fraction whose
  numerator is itself a fraction
- **THEN** it returns boxes whose baselines and bar positions are computed from the injected
  x-height, with no Flutter import in the module
  → `app/test/design/math/spec/math_node_test.dart`, `app/test/architecture/pure_boundary_test.dart`

#### Scenario: The bar geometry scales with the numeral
- **WHEN** a fraction is laid out at 76, 46 and 22 px
- **THEN** the bar thickness is 6, 4 and 3 and the bar minimum width is 58, 36 and 26
  → `app/test/design/math/spec/fraction_metrics_test.dart`

### Requirement: req-fraction-stacked · A fraction is never rendered inline
The system SHALL stack a fraction over a horizontal rule and SHALL NOT emit a solidus form.

#### Scenario: The compositor is asked for three quarters
- **WHEN** a fraction is rendered
- **THEN** the painted output contains a numerator box above a rule above a denominator box, and no
  `/` glyph
  → `app/test/design/math/math_view_test.dart`

### Requirement: req-number-format · Number formatting preserves es-MX conventions exactly
The system SHALL format numbers through one pure module, `EsMxNumber`, with a comma decimal
separator, a U+202F thousands separator, and U+2212 for a leading minus.

#### Scenario: A rating and a time are formatted
- **WHEN** `EsMxNumber.integer(1180)` and `EsMxNumber.seconds(4.2, places: 1)` are called
- **THEN** the results are `1 180` and `4,2 s`, and the thousands separator is not U+0020
  → `app/test/design/math/spec/es_mx_number_test.dart`

#### Scenario: A counter chip and a delta go through the same module
- **WHEN** `3 / 9` and a `−6` delta are formatted
- **THEN** `ratio` returns `3 / 9` with spaces around the slash and `deltaParts` returns a sign run
  and a digit run, so no caller composes a minus sign by hand
  → `app/test/design/math/spec/es_mx_number_test.dart`
```

**The name is `EsMxNumber`, not `NumberFormat`.** `NumberFormat` collides head-on with `intl`'s
class of the same name, and `intl` is a plausible future dependency in a Spanish-language app. Home
is `design/math/spec/`, this document's own first option. Recorded smell: `settings` will import
`design/math/spec/` to render `19:30`; if that grates the module moves without changing a caller's
semantics.

---

#### `f1b-content-reader` — phase F1b

**Capability:** `offline-content`. **Depends on:** `f0-pack-contract`. **Blocks:** `f2-core-loop`.

`app/lib/content/`: the pure pack model plus the asset reader. Reads a hand-written fixture pack
from `assets/` from day one; F1.5's builder replaces the fixture without changing a line of the
model.

```
## ADDED Requirements

### Requirement: req-offline-pack-play · The app plays from a JSON pack in assets, with no network
The system SHALL load items, prompts, keypad layout and grading data from a bundled pack and SHALL
make no network request to do so.

#### Scenario: A pack is read from the bundle
- **WHEN** the reader is given a fixture pack via a fake `AssetBundle`
- **THEN** it yields the declared item count with each item's stimulus kind, prompt payload, answer
  spec and `ladder_step`
  → `app/test/content/pack_reader_test.dart`

#### Scenario: Difficulty comes from the pack, never from the client
- **WHEN** an item is selected offline
- **THEN** its difficulty is the pack's `ladder_step` and no rating is computed in Dart
  → `app/test/content/model/pack_test.dart`

#### Scenario: An expired pack is refused
- **WHEN** a pack whose `expires_at` is in the past is read with an injected `now`
- **THEN** the reader reports it expired rather than serving its items
  → `app/test/content/pack_reader_test.dart`

#### Scenario: A puzzle is read from the same pack
- **WHEN** a puzzle fixture of each of the five kinds is read
- **THEN** the reader yields its board, its blocked cells, its cages or targets, its solution and
  its tutorial steps, and the client computes none of them
  → `app/test/content/pack_reader_test.dart`

### Requirement: req-pack-parity · The Dart parser agrees with the frozen fixture
The system SHALL parse `contract/fixtures/` in Dart to the same normalised structure the TypeScript
parser produces, including the rejection rows.

#### Scenario: Every golden fixture round-trips in Dart
- **WHEN** each fixture frozen by `f0-pack-contract` is parsed in Dart
- **THEN** the normalised structure equals the TypeScript parser's recorded output for that fixture
  → `app/test/content/model/pack_test.dart`

#### Scenario: A rejection row is rejected on the Dart side too, with the same tag
- **WHEN** `""`, `"1/0"`, `"x+1"`, U+0660, U+2212, ZWSP or a combining mark is parsed as an answer
- **THEN** the Dart parser rejects it with the tag the TypeScript parser used
  → `app/test/content/model/canon_test.dart`
```

`req-pack-parity` is the half of the first draft's `req-pack-fixtures` that needs a Dart parser. It
lives here, downstream of the frozen fixture, instead of inside the F0 change that the parser
depends on. This is R2's remedy: the drift the risk names is between these two parsers, and the
fixture is the only place it can be caught.

---

### F1 · TypeScript lane (parallel with F1b)

#### `f1-schema-freeze` — phase F1 · **the schema freezes here**

**Capability:** `data-schema`. **Screens:** none. **Depends on:** Gate A, Gate B.
**Blocks:** `f3-server-foundation`, `f3-attempt-sync`, `f3-profile-read`, `f3-deletion-web`,
`f3-store-artifacts`.

`ARCHITECTURE.md`:369 freezes the schema at F1 and §5.1's Gate B collects the five decisions that
change it — and the F1 lane holds three changes and no migration. This change is where Gate A and
Gate B land as SQL. Everything it creates is *forward-only*: after it merges, a column is added by a
new migration, never by editing this one.

**What it creates.** `players` (UUIDv7 minted by the client, **no name column** — decision #5 and Q5,
**`age_band` NOT NULL** — see below), `issued_items`, `attempts` (append-only), `user_skills`,
`template_stats` with `sum_expected` and `sum_user_rating` (`ARCHITECTURE.md`:233), `offline_packs`
(`ARCHITECTURE.md`:194-198) and `diag_events`.

**What it deliberately does not create: Better Auth's tables.** They are generated by that library's
CLI at the version `f3-server-foundation` pins (`>= 1.6.22`), and that change depends on this one —
committing SQL at F1 that a dependency installed at F3 produces is an ordering nobody can honour.
Nothing at F1 needs `user`, `account`, `session` or `verification` to exist, so they land at F3 under
the same runner and the same `protected-paths` rule, and `req-deletion-completeness` stays exactly
where it already is.

**`age_band` is NOT NULL, and that decides where the gate stands.** The obvious reading — collect the
band at `1.2 Crear cuenta` — does not survive contact with `ARCHITECTURE.md`:219-225: the client mints
`player_id` at first launch, Better Auth's `anonymous()` supplies a session, and a **guest** therefore
writes a `players` row at first sync, before any account exists. A band collected at `1.2` arrives
after the row. **Decision: the band is resolved before the device obtains any session — anonymous or
credentialed — so it is in hand before the first byte of player data leaves the phone, and `1.2` is
one of the two doors it stands in front of; guest sync is the other.** F2 is untouched: F2 has no
server, nothing leaves, and `f2-onboarding-first-run` gains no screen. The alternative — nullable
until link, with the request path refusing writes for an unresolved band — was rejected because it
makes a compliance invariant a runtime check instead of a column constraint.

**Migration mechanism.** Plain forward-only `.sql` files in `packages/server/migrations/NNNN_*.sql`,
applied by a ~40-line runner over the `pg` client the project already chose, recording applied
filenames in `schema_migrations`, on the **direct** connection string, not the pooler
(`ARCHITECTURE.md`:217). No ORM and no `drizzle-kit`: `ARCHITECTURE.md`:150 names `drizzle-orm` by
hand as the dependency an agent adds in a one-line diff, and a migration tool is exactly the kind of
thing that arrives with one. The committed snapshot is `packages/server/schema.sql`, regenerated by
`pg_dump --schema-only` and diffed in CI — the same discipline as the `contract` job. Pin the
`pg_dump` client version in CI or the dump churns on every runner image bump.

**Retention runs under `retention_job`, and the numbers live in one pure module.** Decision #3 sets
attempts at 400 days and `diag_events` at 30. `packages/server/src/retention.ts` is that module and
it is PURE — it takes `now` as a parameter and returns cutoffs, the same shape
`packages/server/src/routing.ts` already sets as this package's PURE precedent (`openspec/config.yaml`
cites it by name). The adapter runs the DELETE under the `retention_job` role. Deleting is safe
because calibration never reads raw rows: `template_stats` is maintained on write
(`ARCHITECTURE.md`:232).

**Scheduling: a GitHub Actions scheduled workflow** (`.github/workflows/retention.yml`) running
`pnpm --filter @akimath/server retention` with the `retention_job` credential in
`RETENTION_DATABASE_URL`. Recorded as a default: it is free, it is visible, and it needs no extension.
Whether Neon offers `pg_cron` on Free is **unverified** and is not assumed here.

**`diag_events` is defined here or its retention figure has no referent.** It is the only table the
project knows solely by a number. Default, recorded as such: one row per diagnosis resolved at sync —
`{player_id, attempt_id, misconception_id | null, created_at}` — where `misconception_id` is null for
the generic fallback Q2's answer adds to the pack. Thirty days.

```
## ADDED Requirements

### Requirement: req-initial-migration · The schema is one forward-only migration with a committed snapshot
The system SHALL define the database as ordered forward-only SQL migrations applied by a runner with
no ORM dependency, and SHALL fail CI when the applied schema and the committed snapshot differ.

#### Scenario: The migrations are applied to an empty database
- **WHEN** the runner is pointed at a fresh ephemeral Neon branch and runs twice
- **THEN** the first run applies every migration, the second applies none, and
  `pg_dump --schema-only` matches `packages/server/schema.sql` under `git diff --exit-code`
  → `packages/server/test/migration.test.ts`, CI job `integration`

#### Scenario: A migration is edited after it shipped
- **WHEN** a file already recorded in `schema_migrations` has its checksum changed
- **THEN** the runner refuses to start and names the file, rather than applying a partial schema
  → `packages/server/test/migration.test.ts`

### Requirement: req-player-shape · A player row carries an age band and never a name
The system SHALL store `age_band` as a NOT NULL column on `players`, SHALL store no name and no
birth date anywhere in the schema, and SHALL make an insert without a band impossible rather than
merely discouraged.

#### Scenario: A player row is inserted without a band
- **WHEN** an INSERT into `players` omits `age_band`
- **THEN** the database rejects it, and the same is true of every path that writes a player row
  → `packages/server/test/players.test.ts`, CI job `integration`

#### Scenario: The schema holds no name and no date of birth
- **WHEN** `information_schema.columns` is enumerated for every table this migration creates
- **THEN** no column stores a personal name and no column stores a day, month or year of birth —
  only the coarse band
  → `packages/server/test/players.test.ts`

### Requirement: req-erasure-grants · Only the erasure path and the retention job may delete an attempt
The system SHALL grant DELETE on `attempts` to `retention_job` alone, SHALL grant the request-path
role neither DELETE nor UPDATE on `attempts`, and SHALL express this as grants rather than as
discipline.

#### Scenario: The request-path role tries to delete an attempt
- **WHEN** the runtime role issues `DELETE FROM attempts` or `UPDATE attempts`
- **THEN** the database refuses, and `information_schema.role_table_grants` shows that role holding
  only SELECT and INSERT on `attempts`
  → `packages/server/test/grants.test.ts`, CI job `integration`

### Requirement: req-retention-job · Retention is a job with the figures in one pure module
The system SHALL delete `attempts` older than 400 days and `diag_events` older than 30 days, under
the `retention_job` role, from cutoffs computed by a module that reads no clock.

#### Scenario: The cutoffs are computed from an injected now
- **WHEN** `retentionCutoffs(now)` is called
- **THEN** it returns `now − 400 days` for `attempts` and `now − 30 days` for `diag_events`, from a
  module containing no `Date.now`, and those are the only two places the figures appear in the
  source
  → `packages/server/test/retention.test.ts`

#### Scenario: The job runs twice over the same data
- **WHEN** the retention job runs, then runs again with the same injected `now`
- **THEN** the second run deletes zero rows, reports the counts it deleted, and `template_stats`
  aggregates are unchanged by either run
  → `packages/server/test/retention.test.ts`, CI job `integration`
```

**Also in this change:** `.github/workflows/retention.yml`, and `packages/server/migrations/` plus
`packages/server/schema.sql` are added to the `protected-paths` job's list — `ARCHITECTURE.md`:275
names a migration as one of the four things an agent must not be able to edit unattended, and today
that job does not exist because there was nothing to protect.

#### `f1-core-rederivation` — phase F1

**Capability:** `domain-core`. **Depends on:** `f0-pack-contract`.

`packages/core` is the rederivation machine: `attempts` is append-only and the server must
reconstruct the exact problem years later from `(template_id, template_version, seed, ladder_step)`
— **four fields; `issued_items` stores the ladder step and no seed implies it**. Zero
`dependencies`, enforced by a CI check that reads `package.json` — not by pnpm strictness, because
an agent runs `pnpm add drizzle-orm --filter @akimath/core` and a resolution-based invariant dies in a
one-line diff. Rationals as `BigInt`; a vendored PRNG whose golden vector is **emitted from the
code**; Glicko-1 with the **session** as the rating period; `decay(prior, elapsedDays)` in days.

Anchor scenario:

```
### Requirement: req-core-determinism · The core performs no ambient IO
The system SHALL forbid `Math.random`, `Date`, `performance`, `crypto.randomUUID`, `Intl` and
`toLocaleString` inside `packages/core`.

#### Scenario: A generator reaches for the clock
- **WHEN** a file under `packages/core/**` references `Date`
- **THEN** the lint fails, because an import ban cannot catch `Math.random()`, and a test asserts
  that the ban lists every one of the six globals rather than trusting the config to stay complete
  → `packages/core/test/determinism.test.ts`, CI job `core`.
  **As built:** a TypeScript AST walk rather than ESLint — a flat ban cannot scope the permission
  Glicko needs — and the CI job is `core`; there is no `ts-unit` job in `.github/workflows/ci.yml`.
```

#### `f1-contract-emitter` — phase F1

**Capability:** `api-contract`. **Depends on:** `f0-pack-contract`, `f0-dart-client-spike`.

`packages/contract` exists so the spec can be emitted **without booting Hono or touching
`DATABASE_URL`** — if emitting the spec needs a database the CI gate goes flaky and gets disabled.
OpenAPI **3.0.3**, not 3.1. Zero response polymorphism. Correct `ARCHITECTURE.md`:179 while doing
this: it still types the response as `{itemId, prompt, keypad, options?}`, which contradicts
decision #4 at line 437 — **`options` comes out.**

#### `f1-5-pack-builder` — phase F1.5

**Capability:** `pack-builder`. **Depends on:** `f1-core-rederivation`, `f0-pack-contract`.

Emits the same format the server will later emit. What it carries for the error screen was
**Q2**, **decided 2026-08-15**: per labelled distractor an `HMAC(canonical answer) →
{misconception, steps, explain}`, plus one non-scolding generic fallback per skill for the answer no
distractor anticipated. The reserved `diagnosis` slot `f0-pack-contract` froze is what that answer
fills, so the format does not reopen.

---

### F2 · The first playable ★

Five items played on a plane. No account, no server, no Neon (decision #2), no rating in Dart, no
leaderboard (decision #5), free entry (decision #4).

#### `f2-app-shell` — phase F2

**Capability:** `app-shell`. **Screens:** `4.11 Cargando` (skeletons), the offline banner.
**Depends on:** `f0-*`. **Blocks:** every F2 screen.

Routing, the cream scaffold, the offline banner, and the skeleton layouts. **No bottom nav at F2** —
a nav bar needs a second root and the map is F5 (§5.3 D12). `main.dart` stops showing the character
sheet.

```
## ADDED Requirements

### Requirement: req-nav-staging · The app routes without a navigation bar until a second root exists
The system SHALL render no bottom navigation while exactly one tab root exists.

#### Scenario: F2 launches
- **WHEN** the app starts with only the home root registered
- **THEN** no `AppBottomNav` is in the tree
  → `app/test/features/shell/ui/app_shell_test.dart`

### Requirement: req-fullscreen-session · A full-screen session hides the app frame
The system SHALL present the item, the verdicts, calibration and a puzzle as full-screen routes
with no navigation affordance, per declared rule 1 of `REGLAS DECLARADAS`.

#### Scenario: A series is entered
- **WHEN** "Empezar la serie" is pressed
- **THEN** the pushed route carries no bottom navigation and the only exit is the close control
  → `app/test/features/shell/ui/app_shell_test.dart`

### Requirement: req-skeleton-loading · Loading is skeletal, never a spinner
The system SHALL show content-shaped placeholders whose geometry matches the loaded layout.

#### Scenario: The home screen loads
- **WHEN** the home route is entered before its data resolves
- **THEN** `SkeletonBlock`s occupy the same boxes the loaded content will occupy, and no
  `LoadingDots` and no `CircularProgressIndicator` is in the tree
  → `app/test/features/shell/ui/loading_skeleton_test.dart`
```

#### `f2-core-loop` — phase F2 · **the ★ change**

**Capability:** `round`. **Screens:** `02 Reto activo` / `Reactivo aritmética` (one shell),
`03 Acierto`, `04 Error` / `Error con diagnóstico`. **Depends on:** `f1b-math-compositor`,
`f1b-content-reader`, `f0-verdict`, `f0-pressable-surface`, **`f0-keypad`**, **`f0-stat-readouts`**.
The last two already declare that they block this change; the edge was written in one direction
only, and a one-way edge is how a build order lets F2 start without the shared keypad — which is
precisely the second keypad §3.3 exists to prevent.

`04 Error` and `Error con diagnóstico` are **the same screen in two documents at different
fidelity**; the reactivos version wins on precedence and detail. `2.5 Resumen de serie` and the
other five stimulus renderers are separate changes (below), because they are content work, not
shell work.

Order inside the change, and it matters: `policy/answer_draft.dart` **first**, TDD, zero mocks. It
is transcribed from a behaviour spec the document already wrote, so it goes red-green before a
single widget exists.

```
## ADDED Requirements

### Requirement: req-answer-draft · The answer draft is a pure reducer
The system SHALL apply every key press as a pure function of the current draft, with no widget, no
canvas and no clock.

#### Scenario: The fraction key toggles the focused field
- **WHEN** `apply(KeypadKeyId.fraction, draft(num: '23', den: '', focus: den))` is called
- **THEN** the focus becomes `num` and neither field's text changes
  → `app/test/features/round/policy/answer_draft_test.dart`

#### Scenario: Negation prepends and removes U+2212, never a hyphen
- **WHEN** `KeypadKeyId.negate` is applied twice to `'7'`
- **THEN** the field is `'−7'` and then `'7'`, and never contains U+002D
  → `app/test/features/round/policy/answer_draft_test.dart`

#### Scenario: The square key appends U+00B2
- **WHEN** `KeypadKeyId.square` is applied to `'4'`
- **THEN** the field is `'4²'`
  → `app/test/features/round/policy/answer_draft_test.dart`

#### Scenario: A field is capped at four characters
- **WHEN** a fifth digit is pressed into a field already holding four characters
- **THEN** the draft is unchanged
  → `app/test/features/round/policy/answer_draft_test.dart`

#### Scenario: Backspace pops one character from the focused field only
- **WHEN** `KeypadKeyId.backspace` is applied with focus on the denominator
- **THEN** the denominator loses its last character and the numerator is untouched
  → `app/test/features/round/policy/answer_draft_test.dart`

#### Scenario: An empty field renders as one space
- **WHEN** a field is empty
- **THEN** its rendered text is a single space so the slot does not collapse to zero width
  → `app/test/features/round/policy/answer_draft_test.dart`

#### Scenario: An id the item layout does not carry is a no-op
- **WHEN** `apply` is called with a `KeypadKeyId` the item layout never emits — `enter`, from the
  OTP layout — on any draft
- **THEN** it returns that draft unchanged. This is the scenario that makes **one** union enum safe
  (§3.4: *"Ids outside the item layout return `this`"*); without it, the reducer's exhaustive switch
  is the only thing standing between a shared enum and a silent no-op nobody notices
  → `app/test/features/round/policy/answer_draft_test.dart`

### Requirement: req-item-keypad-call-site · The item screen mounts the shared keypad and declares none of its own
The system SHALL build the item screen's pad as `Keypad(KeypadLayout.item)` from `design/widgets/`,
SHALL declare no keypad, key or layout under `features/round/`, and SHALL keep the platform keyboard
out of the assembled screen.

#### Scenario: The screen mounts the shared keypad
- **WHEN** `ItemScaffold` is pumped with any stimulus
- **THEN** the pad in the tree is `design/widgets/`'s `Keypad` at `KeypadLayout.item`, and no widget
  under `app/lib/features/round/` declares keys, a layout or a key face
  → `app/test/features/round/ui/item_scaffold_test.dart`

#### Scenario: The system keyboard never appears
- **WHEN** the answer slot is focused
- **THEN** no `EditableText` and no `TextField` is in the tree
  → `app/test/features/round/ui/item_scaffold_test.dart`

### Requirement: req-item-shell · One shell hosts every stimulus family
The system SHALL render the item as close · progress dots · stimulus slot · answer card · keypad,
and SHALL select the renderer by an exhaustive switch over a sealed type.

#### Scenario: A seventh stimulus kind fails to compile
- **WHEN** a member is added to the sealed `Stimulus` type without a renderer
- **THEN** `flutter analyze --fatal-infos` fails on a non-exhaustive switch
  → `app/test/features/round/policy/stimulus_test.dart` + `flutter analyze --fatal-infos`

### Requirement: req-aki-absent-solving · Aki never appears while the learner is solving
The system SHALL keep Aki out of the item screen.

#### Scenario: An item is on screen
- **WHEN** `ItemScaffold` is built with any stimulus
- **THEN** no `Aki` and no `SpeechBubble` is in the tree
  → `app/test/features/round/ui/item_scaffold_test.dart`

### Requirement: req-quiet-timing · Time is measured and never displayed during solving
The system SHALL record elapsed time per item and SHALL render no timer while an item is on screen.

#### Scenario: An item is being solved
- **WHEN** the item screen is pumped and time advances
- **THEN** no elapsed-time text is in the tree, and on the verdict screen the recorded time renders
  as `4,2 s`
  → `app/test/features/round/ui/item_scaffold_test.dart`,
    `app/test/features/round/ui/verdict/correct_screen_test.dart`

### Requirement: req-diagnosis-copy · The error screen names the reasoning, never the failure
The system SHALL render the learner's own wrong term, a named misconception, an explanation and the
correct step, and SHALL NOT render the words "incorrecto", "error", "fallaste" or "mal".

#### Scenario: A labelled distractor is matched
- **WHEN** the submitted answer matches a labelled distractor in the pack
- **THEN** the diagnosis card shows the misconception headline, the learner's value struck through
  with a rotated ink bar, the explanation sentence and the correct step
  → `app/test/features/round/ui/verdict/wrong_screen_test.dart`

#### Scenario: No distractor anticipated the answer
- **WHEN** the submitted answer matches no labelled distractor
- **THEN** the screen renders the skill's generic non-scolding fallback and still shows the correct
  step, and never the word "incorrecto"
  → `app/test/features/round/ui/verdict/wrong_screen_test.dart`

### Requirement: req-error-band-overflow · Aki's error band does not clip her art
The system SHALL let the error pose overflow its band upward rather than clipping it.

#### Scenario: The error verdict renders
- **WHEN** `04 Error` is pumped at 390×844
- **THEN** Aki's 182 px art renders whole inside the 156 px band and no overflow is reported
  → `app/test/design/screen_overflow_test.dart`
```

On `04 Error`, Aki's declared art height is 182 px inside a 156 px band — **26 px of deliberate
upward overflow.** In CSS it paints over; in Flutter a fixed-height `Column` child clips or throws.
That band is a `Stack` or an `OverflowBox`.

**Why this change no longer specifies a keypad.** An earlier draft carried `req-own-keypad` here,
with a layout scenario and a touch-minimum scenario pointing at
`app/test/features/round/ui/keypad/item_keypad_test.dart` — a directory §2.4's tree does not contain,
duplicating word for word the two scenarios `f0-keypad` already owns at
`app/test/design/widgets/keypad_test.dart`. §3.3 gave the keypad to `design/` and §2.5 says it
outright (*"the keypad itself resolves against `design/`, not against `round/`"*), but §4 is where an
implementer builds from, so the residue would have produced the second keypad the inventory exists to
prevent. The two duplicated scenarios are gone. What survives is the **call site**: `f0-keypad` proves
the pad in isolation; `req-item-keypad-call-site` proves the assembled screen mounts that pad and
declares none of its own, which is a different test on a different tree.

**`03` and `04` ship two stat tiles, not three, and no rating anywhere** — Q3 and Q4, both **decided
2026-08-15**. Q4 puts the rating delta on the series, not the item, so the `+18` / `−6` tile comes
off both verdict screens (`2.5 Resumen de serie` is where a delta is real). Q3 hides the rating
outright in F2 — no pill, no number, no placeholder — because F2 has no server and the rating is the
server's exclusive authority (D17). What the verdicts show is **time and streak**: the `4,2 s`
`req-quiet-timing` already asserts, and the local streak `StreakPolicy` computes. Both tiles come
back with `f3-attempt-sync`, which is also when the rating first exists; this is a subtraction with a
named return phase, not a redesign. The consequence to hold on to: a verdict screen in F2 carries no
number that sync can later contradict, which is exactly why Q6's provisional marker is not needed in
F2 either.

**`Ver paso` is not cut; it has no destination yet.** `04 Error` draws the affordance and no
document draws what it opens. An earlier draft of this plan removed it under *"cut until a screen
exists"*, and that criterion was retired on 2026-08-15 — so the affordance is **absent from this
change only until DR-11 is drawn**, which is a fact about the build order and not a decision about
scope. §5.2, DR-11; the delivery order and the interim are in §8.2, batch B5.

#### `f2-home-reduced` — phase F2

**Capability:** `home`. **Screens:** `Inicio actualizado`, reduced. **Depends on:**
`f1b-math-compositor`, `f2-app-shell`.

`Inicio actualizado` is the canonical home (§5.3 D5). F2 ships a **named subset** of it: the Aki
band at 150 with the bubble, the `RETO DEL DÍA` card with its composed expression preview, and one
green button. **Subtracted, with the phase each returns in:** the rating pill (F3 — rating is the
server's authority; Q3, decided), the `PUZZLE DEL DÍA` card (F6), the bottom nav (F5).

**The streak pill is not subtracted — it ships here, and it is the only pill on the F2 home.** The
streak is a local calendar fact (D17), computed on device by `StreakPolicy(attemptDays, today)` over
`DayLogStore` (§3.4), and its day boundary is settled by Q7, decided 2026-08-15: the device's local
calendar day, `America/Mexico_City` when the device offers no zone, and a wrong answer never
decrements it. It was listed among the subtractions with a return phase of "F2", which is this
change — the two statements were the same statement, written as though they disagreed.

The `TUS HABILIDADES` row is **not** deferred — it
is the structural difference between the two home documents, and picking `Inicio actualizado`
means dropping it.

```
### Requirement: req-home-subset · The home screen offers today's series and nothing it cannot source
The system SHALL render only the elements whose data exists in the current phase.

#### Scenario: F2 home with no server
- **WHEN** home is built against a local pack with no rating available
- **THEN** the Aki band, the bubble, the `RETO DEL DÍA` card, one primary button and the **streak**
  pill are present, and no rating pill, no skills row, no puzzle card and no bottom nav are in the
  tree
  → `app/test/features/home/ui/home_screen_test.dart`
```

#### `f2-onboarding-first-run` — phase F2

**Capability:** `onboarding`. **Screens:** `0.2 Bienvenida`, `0.3 Primer reto`. **Depends on:**
`f2-core-loop`.

The drawn first-run path is `0.2 → 0.3 → 0.4 → 0.5 ×10 → 0.6 → mapa`. Calibration is F4 and the map
is F5, so **F2 ships `0.2 → 0.3 → home` and nothing else** (§5.3 D11). `0.3` is correctly Aki-free
and teaches the answer format; its item is a fixed, unrated teaching item, not a pack fetch.

```
### Requirement: req-first-run · The first run reaches a playable item without an account
The system SHALL take a first-launch user from the welcome screen to a solved item with no
registration, no network call and no calibration.

#### Scenario: A fresh install
- **WHEN** "Resolver uno" is pressed on `0.2`
- **THEN** `0.3` is pushed, and on submit the app continues to home; the calibration route is not
  registered
  → `app/test/features/onboarding/onboarding_flow_test.dart`
```

#### `f2-stimulus-families` — phase F2+ (content-gated)

**Capability:** `round` (extends). **Screens:** `Reactivo serie`, `Reactivo matriz`,
`Reactivo analogía`, `Reactivo operación oculta`, `Reactivo figurativa`. **Depends on:**
`f2-core-loop`, `f1-5-pack-builder`.

Five renderers plugged into the existing shell — one file each, one golden fixture each, no shell
change. Sequenced by content availability (R3), not by code. Anchor scenario:

```
### Requirement: req-stimulus-renderers · Each stimulus family renders from its own payload
#### Scenario: The analogy family never renders a colon form
- **WHEN** an analogy item is rendered
- **THEN** it shows two pair cards joined by a `MISMA RELACIÓN` bridge pill and contains no
  `a : b :: c : d` text
  → `app/test/features/round/ui/stimulus/analogy_stimulus_test.dart`
```

#### `f2-series-summary` — phase F2+

**Capability:** `round` (extends). **Screens:** `2.5 Resumen de serie`. **Depends on:**
`f2-core-loop`, and on the rating existing at all — so it lands with or after `f3-attempt-sync`.
Q4 is **decided 2026-08-15: the delta is per series**, which makes this the one screen in the app
that prints one. What remains gating is the recommender copy, which is content (R3).

---

### F3 · Server, auth and sync

Requirement plus anchor scenarios only; these expand at propose time.

#### `f3-server-foundation` — phase F3
Hono 4.13.x · `pg` over TCP (**not** the Neon serverless driver — the sync batch computes Glicko in
TypeScript between the INSERT's `RETURNING` and the `user_skills` upsert, which is an interactive
transaction) · Better Auth `>= 1.6.22`, `basePath: "/v1/auth"`,
`advanced.ipAddress.disableIpTracking: true` (it persists IP and user-agent **of minors** by
default) · `pg_advisory_xact_lock` to serialize two devices · `DELETE /v1/me` **and the web deletion
page**, which Play requires and which is not optional — and which `f3-deletion-web`, below, turns
from a clause into a change with tests. **Depends on:** `f1-schema-freeze` (Better Auth's own tables
land here, under that change's runner; everything else is already frozen). `DELETE /v1/me` is the
**only** user-initiated erasure path in the system: Q1 is decided 2026-08-15 and `Borrar mi
historial` is cut, so the request-path role never needs a DELETE grant on `attempts`
(`req-erasure-grants`).

```
### Requirement: req-deletion-completeness · Deletion removes the data Better Auth keeps off the user row
#### Scenario: An account is deleted
- **WHEN** `DELETE /v1/me` completes
- **THEN** `account.password` and `verification.identifier` hold no row for that user — a test that
  scans only `user`'s text columns passes over data still sitting there
  → `packages/server/test/deletion.test.ts`
```

#### `f3-deletion-web` — phase F3

**Capability:** `web-deletion`. **Screens:** none in `app/` — the page is not an app screen, and its
own states are undrawn (§5.2, DR-8). **Depends on:** Gate A, `f1-schema-freeze`,
`f3-server-foundation`. **Blocks:** `f3-store-artifacts` (Data Safety declares the URL), and the
first internal-test build (R4).

`ARCHITECTURE.md`:378 and R4 both name the web deletion page, `gaps.md` §4.2 records that it is
*"designed nowhere"*, and `f3-server-foundation` mentions it in one clause with no requirement and no
test. Play requires it for any account-holding app and requires it **reachable without installing the
app**, which is the constraint that decides everything else in this change: it cannot live behind the
app, behind a login SDK, or behind a page the API's availability gates.

**Where it is hosted.** A new `packages/web/` — a static site with no framework, no analytics, no
remote font and no external request of any kind — published at the project's own domain. Default,
recorded as such: **static hosting rather than a route on the Hono server.** The API autosuspends on
Neon Free and the page must outlive API downtime; the legal documents behind `req-legal-reachable`
live in the same site for the same reason. The vendor is a default, not a fact: any static host that
adds no script to the page satisfies this.

**How deletion actually happens, and why it is one path and not two.** The page takes an email
address and always answers the same thing; if an account exists, a signed, single-use, short-lived
link is emailed; following it runs the **same** server erasure that `DELETE /v1/me` runs. That keeps
`CLAUDE.md`:159 true — the erasure path is one path — and it keeps the transactional email provider
question where it belongs, in Gate A, since this flow cannot exist without one.

**The page is also the only user-facing surface that carries the retention figures.** `gaps.md` §4.5
notes that decision #3's 400 days and 30 days *"appear in no user-facing surface"* although a written
retention policy is required. They appear here, read from the same module the retention job reads —
`packages/web/test/deletion_page.test.ts` fails the build if the two drift — so the promise and the
job cannot disagree. That is a build rule, not a second requirement.

```
### Requirement: req-web-deletion · Account deletion is reachable from the open web, without the app
The system SHALL publish a static page that requests account deletion with no app install, no login
SDK and no external network request, and the emailed confirmation SHALL perform the same erasure the
in-app path performs.

#### Scenario: The page is fetched by someone who has never installed the app
- **WHEN** the published page is loaded
- **THEN** it renders its form with no session, and the emitted HTML references no origin other than
  its own — no script, no font, no image, no analytics
  → `packages/web/test/deletion_page.test.ts`, CI job `compliance`

#### Scenario: The emailed link is followed
- **WHEN** the single-use link from the deletion email is followed
- **THEN** `account.password` and `verification.identifier` hold no row for that user and the
  player's attempts are gone — the same post-state `req-deletion-completeness` asserts for
  `DELETE /v1/me` — and following the link a second time changes nothing
  → `packages/server/test/deletion.test.ts`

#### Scenario: An address with no account is submitted
- **WHEN** the form is submitted with an address that has no account and with one that does
- **THEN** the response body, the status and the rendered page are identical in both cases
  → `packages/server/test/deletion_web.test.ts`
```

**Undrawn and therefore requested, not cut:** the page's own three states (requested · link expired ·
done), the deletion email's es-MX copy, and the tone rule — a child may read this page. §5.2, DR-8.
The copy is content work and belongs in R3's budget, not in this change's estimate.

#### `f3-guest-save-prompt` — phase F3

**Capability:** `onboarding` (extends). **Screens:** `0.7 Guardar progreso`. **Depends on:**
`f3-auth-screens`.

The account ask, placed *after* play. It lives in `onboarding/` by the tree in §2.4 but ships at F3,
because both its exits — `Crear cuenta` → `1.6`/`1.2` and `Después` → dismiss — need auth to exist.
At F2 the screen is simply never reached; nothing stubs it.

```
### Requirement: req-guest-save-optional · The account ask never blocks play
#### Scenario: A guest declines
- **WHEN** "Después" is pressed on `0.7`
- **THEN** the screen dismisses, local progress is untouched, and the prompt is not shown again in
  the same session
  → `app/test/features/onboarding/guest_save_prompt_test.dart`
```

Its three stat tiles (`RETOS`, `RATING`, `DÍA`) carry the Q3 problem in miniature: `0.7` prints
`1 180 RATING` for an account-less user. Q3 is **decided 2026-08-15** — the rating is hidden
entirely until F3 — so the tile is not shown and the screen ships with two tiles until this phase's
sync lands a real value. It is drawn with three; the third arrives with the number, not before it.

#### `f3-auth-screens` — phase F3
**Screens:** `1.1`–`1.7`. **Cut from `1.1`: the Google and Apple buttons and the `O` divider**
(§5.3 D13). **`1.2` loses the `CÓMO TE LLAMO` field** — Q5, **decided 2026-08-15**: a player has no
name, the schema has no column for one, and `4.1` greets the email. `1.6` is here rather than in
onboarding because its promise is the linking endpoint, not a welcome — an idempotent
`POST /v1/players/link` with an `Idempotency-Key`, **not** `onLinkAccount`, whose hook runs after
the `createUser` commit so its "no progress lost" promise does not hold.

**`1.2` is unreachable without an age band** (`req-age-gate`): `gaps.md` §4.1 calls this the item
most likely to stop a store submission, and `f1-schema-freeze` has already made `players.age_band`
NOT NULL, so the gate is in front of every door that reaches the server — `1.2` and guest sync
both. The age screen and the tutor-consent flow are drawn in no document; they are design requests
DR-7, not a cut.

```
### Requirement: req-age-gate · No account form is reachable without a resolved age band
The system SHALL resolve a coarse age band before any screen that submits personal data and before
any session is obtained, SHALL route a band below the consent threshold to the tutor-consent flow and
never to `1.2`, and SHALL persist and transmit the band alone.

#### Scenario: A band below the threshold reaches consent and never the form
- **WHEN** `AgeGate.next(band)` is evaluated for every band in the declared value set
- **THEN** every band below `AgeGate.consentAge` yields the tutor-consent route and no path — back,
  resubmit, relaunch — yields `1.2`; every band at or above it yields `1.2`; and the threshold is
  one constant, whose recorded default is 13
  → `app/test/features/auth/policy/age_gate_test.dart`

#### Scenario: The birth date never leaves the device
- **WHEN** the neutral date entry is completed and the band is computed
- **THEN** the persisted value and the first sync payload carry the band and contain no day, month
  or year
  → `app/test/features/auth/policy/age_gate_test.dart`,
  `app/test/features/auth/data/age_band_store_test.dart`

#### Scenario: The server is asked for a session with no band
- **WHEN** a device with no resolved band requests an anonymous or credentialed session
- **THEN** the request is refused with a stable tag rather than a constraint violation, and no
  `players` row is created
  → `packages/server/test/session.test.ts`

### Requirement: req-credential-rules · Credential rules are pure
#### Scenario: The resend cooldown is a function of two timestamps
- **WHEN** `remainingCooldown(issuedAt, now)` is called with `now` 18 seconds after issue
- **THEN** it returns 42 seconds, formats as `0:42`, and reports resend disabled — with no clock
  read inside the module
  → `app/test/features/auth/policy/credential_rules_test.dart`
```

> **AMENDED 2026-08-29 (ADR 0004 and its amendment).** The requirement above **routes**; the gate
> now **refuses**. A band below the eligibility line reaches no account form and no tutor-consent
> flow either, because the consent machinery is never built — the refusal happens at link time
> (Reading A), unlinked offline play is untouched, and the threshold constant moves from 13 to 18
> whenever the sibling change lands it. What survives word for word is the second scenario: the
> birth date never leaves the device, and the band alone is persisted and transmitted. The text is
> left as written because it is why `players.age_band` carries values the product will never issue
> again.

`req-age-gate`'s third scenario is deliberately the second of two layers. `f1-schema-freeze`'s
`req-player-shape` makes a band-less row *impossible* at the database; this scenario makes the
request path fail *legibly* instead of surfacing a 500 from a NOT NULL violation. Different test,
different file, and neither one alone is enough.

**Two numbers here are Gate A's, and the plan records defaults rather than deciding them.** The
threshold's default is 13 — the COPPA-equivalent floor — and the question the consult actually
settles is whether Mexican civil law's *minor* (under 18) makes 13 the wrong constant for LFPDPPP
consent. Keeping it as one named constant is what makes that a one-line change instead of a
redesign. The band value set is `{under_13, 13_17, adult}` — spelled `18_plus` here until
2026-08-29, which the frozen `CHECK` never said; the input is a neutral date
entry rather than a leading *"¿eres mayor de 13?"*, and the date is reduced to a band on device and
discarded. Below the threshold, what the tutor-consent flow *collects* and what it *records as
evidence* are also Gate A's, and they are schema shapes, so they land in `f1-schema-freeze` with
whatever Gate A returns. **[suggestion]** The maximally-minimizing alternative is worth putting in
front of the consult: below the threshold, offer no account at all and let the child keep playing as
a guest with sync off — nothing leaves the device, so there is nothing to consent to. It costs the
under-13 cohort their rating and their cross-session history, which is most of the product, so it is
a product decision and not the plan's.

#### `f3-attempt-sync` — phase F3
The attempt outbox with `sent_rev`; **transport failures must not consume the 8-attempt retry
counter**, or the airplane scenario dies in about four minutes. **The sync endpoint does not accept
an `ok` field** — that is what makes the answer-never-travels invariant true by construction rather
than by discipline. The rating pill returns here.

```
### Requirement: req-provisional-verdict · A verdict is provisional until sync
#### Scenario: An offline verdict is displayed before sync
- **WHEN** an item is graded against the local membership verifier
- **THEN** the verdict screen marks the rating unsettled, the settled value replaces it after sync,
  and when the two disagree the server's value wins **silently** — the attempt is re-scored, the
  screen is not re-shown, and no copy tells the child a second time that they were wrong
  → `app/test/features/round/ui/verdict/provisional_test.dart`
```

**Q6 is decided 2026-08-15, and this is the phase it lands in.** There is **no** provisional marker
in F2: Q3 hides the rating there, which removes the only number a later sync can contradict, so F2
has nothing to mark. The settled/unsettled axis arrives here with the sync, is drawn **once** and
reused everywhere a rating appears, and the disagreement rule is the scenario above — the server
wins in silence. The axis itself is undrawn in every document; it is design request DR-12, and
Ervin's criterion says that documents it rather than cutting it.

#### `f3-profile-read` — phase F3

**Capability:** `profile`. **Screens:** the data behind `4.1 Perfil`. **Depends on:**
`f1-schema-freeze`, `f3-server-foundation`. **Blocks:** `f7-profile-settings`, and the rating half of
`f7-system-states` (`4.13`'s `RATING · INTACTO`).

**`4.13 Racha perdida` is deliberately not this change's screen, and that is a decision, not an
omission.** Its before/after pair — two 82×70 boxes holding the streak that was and the streak that
is — is a **local** fact by D17: `StreakPolicy(attemptDays, today)` over `DayLogStore` already holds
both values, and asking the server for a number the device computed is how the two disagree. What
`4.13` does need from here is the rating it reassures the child about (`1 248`, `RATING · INTACTO`),
which is `GET /v1/me`'s summary field and nothing more.

**Two screens in the F7 block had no source of data in any change.** `perfil-estados.md` §8 lists
what `4.1` prints — rating `1 248`, a seven-day delta `+36`, streak `13`, `312` lifetime attempts,
`78%` accuracy, `6,8 s` mean time, a history feed whose puzzle rows carry a **null** delta
(`sin rating`), and per-topic mastery — and the plan named `DELETE /v1/me` and nothing else under
`/v1/me`. A screen scheduled at F7 whose endpoints are scheduled nowhere is not late, it is missing.

`GET /v1/me` returns the summary and the aggregates; `GET /v1/me/history` returns the feed, paged,
with a **nullable** delta per entry. Both are read-only, both are the shape `f3-attempt-sync` already
writes, and both are computed from `attempts` and `user_skills` — no new write path.

**The seven-day delta is the one open piece, and it is Gate B's.** `4.1`'s `+36 esta semana` is a
third granularity: Q4 settled that a delta is per **series**, which makes a weekly figure a
*window over history*, and `f1-schema-freeze` freezes no rating-history table. Two ways to get it,
and the choice is a schema choice: derive it from `attempts` (cheap, exact, and it dies with the
400-day retention window, which is far longer than seven days) or keep a small `rating_history`
row per settled series. **Default: derive it from `attempts`** — no new table, and the retention
window already outlives the question. If Gate B prefers the table it arrives as a new forward-only
migration, which `f1-schema-freeze` explicitly permits.

```
### Requirement: req-profile-read · The profile screen reads one endpoint and the history reads another
The system SHALL serve the profile summary and its aggregates from `GET /v1/me` and the history feed
from `GET /v1/me/history`, SHALL type the per-entry rating delta as nullable, and SHALL compute the
seven-day delta from a window whose boundary is a parameter, not a clock read.

#### Scenario: A puzzle entry carries no rating
- **WHEN** the history feed contains a puzzle entry and a series entry
- **THEN** the puzzle entry's delta is null and renders as `sin rating`, and the series entry's
  delta renders through `EsMxNumber.deltaParts`
  → `packages/server/test/profile.test.ts`,
  `app/test/features/profile/policy/history_entry_test.dart`

#### Scenario: The seven-day delta is computed from an injected boundary
- **WHEN** `weeklyDelta(attempts, since)` is called with a fixed `since`
- **THEN** it returns the same figure for the same input on every run, and the module reads no clock
  → `packages/server/test/profile.test.ts`
```

#### `f3-store-artifacts` — phase F3

**Capability:** `store-compliance`. **Screens:** none. **Depends on:** Gate A, `f1-schema-freeze`,
`f3-deletion-web`. **Blocks:** the first TestFlight or internal-test build — which is R4's early
signal, so this change is what turns that signal from prose into a red build.

Play's Data Safety declaration and Apple's `PrivacyInfo.xcprivacy` are the two places the project
tells a store what it collects. Both are hand-maintained everywhere else in the industry and both
drift the moment a column is added. `ARCHITECTURE.md` §8 already lists a `compliance` CI job that
checks `PrivacyInfo.xcprivacy` exists; `ci.yml`'s own header says the job is unimplemented *"because
the code they guard does not exist"*. It exists after `f1-schema-freeze`.

**One inventory, two artifacts, one direction.** `packages/compliance/src/inventory.ts` is a typed
TypeScript module — not YAML, so it is type-checked and needs no parser dependency — with one entry
per collected datum: what it is, which table and column hold it, why it is collected, whether it is
shared (nothing is), whether it is deletable (everything is), its retention window, and its Play Data
Safety category, plus the Apple required-reason entries for the APIs the shipped plugins actually
touch — **that list is populated by the plugins, so it is empty until one arrives**, and
`req-privacy-manifest`'s second scenario passes vacuously until then. The first arrivals are already
visible: the local-notification plugin D21 names and whatever holds the age band on device. Neither
has shipped, so the honest statement is that the list must be non-empty and reviewed before the first
submission, not that it is correct today. The inventory also holds the three published URLs — the
deletion page, the aviso de privacidad and the términos — because Data Safety declares the first and
`req-legal-reachable` opens the other two, and a URL written twice is a URL that goes stale once. The
emitters read it and write `app/ios/Runner/PrivacyInfo.xcprivacy` and
`compliance/play-data-safety.csv`. Apple's required-reason codes are **data in the inventory**, not
literals in a test, so a code that Apple revises is a one-line edit.

**What the gate can and cannot prove.** Play has no committed-artifact API — Data Safety is a console
form with a CSV import. CI proves the generated CSV matches the inventory and that the inventory
covers the real schema; it cannot prove what the console shows. Stated plainly here so the scenario
does not overclaim: the CSV is the thing a human imports, and importing it is a human step.

**This change also carries D21's teeth.** The three toggles on `4.4` are served by locally scheduled
notifications and nothing else, so no push token exists, so no identifier is collected, so a Data
Safety row stays empty by construction. The denylist that keeps it that way is a CI check and it
belongs in the same job as the rest of the SDK denylist.

```
### Requirement: req-data-inventory · Both store declarations are generated from one inventory that covers the real schema
The system SHALL generate the Play Data Safety CSV and `PrivacyInfo.xcprivacy` from a single
committed inventory, SHALL fail CI when regeneration produces a diff, and SHALL fail CI when a
column exists that the inventory does not classify.

#### Scenario: A column is added without being classified
- **WHEN** `information_schema.columns` is compared against the inventory on the ephemeral branch
- **THEN** every column is either classified with a Data Safety category and a retention window, or
  explicitly marked not-personal with a reason, and an unclassified column fails the job
  → `packages/compliance/test/inventory_coverage.test.ts`, CI jobs `integration`, `compliance`

#### Scenario: The artifacts are regenerated
- **WHEN** the emitters run twice
- **THEN** both runs produce byte-identical output, `git diff --exit-code` passes, and the CSV names
  the deletion URL `f3-deletion-web` publishes
  → `packages/compliance/test/emitters.test.ts`, CI job `compliance`

### Requirement: req-privacy-manifest · The iOS manifest declares no tracking and gives a reason for every accessed API
The system SHALL emit a `PrivacyInfo.xcprivacy` in which tracking is false, the tracking-domain list
is empty, and every accessed-API category present carries a declared reason.

#### Scenario: The manifest is validated
- **WHEN** the emitted manifest is parsed
- **THEN** `NSPrivacyTracking` is false, `NSPrivacyTrackingDomains` is empty, and every entry in
  `NSPrivacyAccessedAPITypes` carries a non-empty reason list drawn from the inventory
  → `packages/compliance/test/privacy_manifest.test.ts`, CI job `compliance`

### Requirement: req-no-remote-messaging · Notifications are local, and remote messaging cannot enter by accident
The system SHALL fail CI when a remote-messaging dependency appears in the Flutter app, directly or
transitively, or when the native projects declare remote-push capability.

#### Scenario: A messaging dependency is added
- **WHEN** `pubspec.yaml` or `pubspec.lock` names `firebase_messaging`, `firebase_core`,
  `onesignal_flutter` or any package on the messaging denylist
- **THEN** the job fails and names the package and whether it arrived directly or transitively
  → `packages/compliance/test/dependency_denylist.test.ts`, CI job `compliance`

#### Scenario: The native projects are inspected
- **WHEN** the iOS entitlements and the merged `AndroidManifest.xml` are read
- **THEN** no `aps-environment` entitlement exists, no `com.google.firebase.MESSAGING_EVENT` service
  is declared, and `AD_ID` is still absent — while `POST_NOTIFICATIONS`, which Android 13+ requires
  for local notifications, is present
  → `packages/compliance/test/native_manifests.test.ts`, CI job `compliance`
```

**Also in this change:** CI job 6 `compliance` is implemented for the first time — `ARCHITECTURE.md`
§8 specifies it and `ci.yml` defers it by name — and `compliance/`, `packages/compliance/` and
`app/ios/Runner/PrivacyInfo.xcprivacy` join the `protected-paths` list.

---

### F4 – F8

| Change | Phase | Screens | Depends on | Note |
|---|---|---|---|---|
| `f4-calibration` | F4 | `0.4`, `0.5`, `0.6` | `f3-server-foundation`, `f2-core-loop` | Its own feature, not part of onboarding: its own probe bar, its own skip paths, its own phase. Requires F3 — a starting rating cannot be computed in Dart. **`0.5` loses its 52 px Aki** (§5.3 D10). |
| `f5-skill-map` | F5 | `05 Mapa de habilidades`, `2.7 Detalle de nodo`, `4.8 Vacío`, `4.14 Habilidad dominada` | `f0-dashed-border` | Unlocks the second tab root, and therefore the nav bar. **Nine nodes, fixed: Q10 decided 2026-08-15** — the number the design draws and the layout encodes, not R3's 12–15 sizing estimate. `SkillGraph` is pure and its test is that 9-node/9-edge lattice with `edgeStyle` — zero mocks; a tenth node is a design change, not a content one. Legend gains a fourth entry, "Disponible". Side margin 13, not width 352. |
| `f6-puzzles` | F6 | `3.1`, `3.2`, `3.3`, `3.5`, `3.6`, five boards | `f0-dashed-border`, `f0-brand-icons` | One shell, five renderers. Boards are 6×6 max (§5.3 D15). Board side padding 18, not 20 — `390 − 2×18 = 354` outer, 348 inner, 58 px pitch. Plays fully offline; generation is server-side and batched. |
| `f6-home-puzzle-card` | F6 | `Inicio actualizado`, complete | `f6-puzzles` | Home imports `puzzles/puzzles.dart` for `PuzzleThumbnail`. |
| `f7-profile-settings` | F7 | `4.1`–`4.7` | `f3-*`, **`f3-profile-read`** (without it `4.1` has nothing to print), `f3-deletion-web` (a legal row needs a destination) | **`Borrar mi historial` is cut — Q1, decided 2026-08-15**; `DELETE /v1/me` stays the only user-initiated erasure. **`4.5` ships as one card in v1**: the `Acierto` / `Se torció` preview plus its legend, *"Contorno continuo para acierto, punteado para error"*. The shape-not-hue invariant is visible from **F2 by D6**, not by this screen — the earlier justification had that backwards, and of `4.5`'s four controls none has an effect at F7: `Modo daltonismo` changes nothing D6 has not already made unconditional, `Reducir movimiento` gates motion that arrives at F8, and the two type/contrast toggles are Q8's default (neither ships in v1). The three toggles are **DR-P2**, each with the phase it would acquire an effect in. `Ayuda` has no screen; the row waits on **DR-11** rather than being cut. **`Pedir mi archivo` is recorded, not cut:** it has no job, no email path and no endpoint anywhere in this plan, its default is to ship on the same transactional-email path `f3-deletion-web` already needs, and whether the ARCO *acceso* right makes it mandatory is Gate A's question — see §5.1. With the erasure card gone, `4.7` is two legal rows and an export card whose states nobody drew: **DR-P3**. `req-legal-reachable` is carried early — see the block after this table. |
| `f7-notifications` | F7 | `4.4 Notificaciones`, and `4.12`'s `Recuérdame a las 21:00` | `f7-profile-settings`, D21 | **The change `4.4` never had.** Three toggles, a reminder hour and preset chips were a whole screen with no plugin, no policy and no scenario in the plan, while `f7-profile-settings` promised `4.1`–`4.7` and could build six of seven. The schedule is **pure** — `settings/policy/reminder_schedule.dart` (§2.5) turns preferences plus a local calendar day into `(when, kind)` pairs and reads no clock — and `settings/data/reminder_scheduler.dart` is the only file that names a notification API. **The dependency decision is reasoned, not waved at, exactly as D13 was:** `flutter_local_notifications` wraps `UNUserNotificationCenter` and `NotificationManager` and makes no network call, so DEP-1 is satisfied by stating that audit; D21 settles that the transport is local scheduling and never a push token; `f3-store-artifacts`' `req-no-remote-messaging` is the CI check that keeps a messaging SDK from arriving later in a one-line diff. The runtime permission prompt Android 13+ and iOS both require has no drawn screen — **DR-9** — and the hour card with the reminder off is **DR-P4**. Q9's default holds: `4.12` keeps the screen and loses the ticking chip; whether `Racha en riesgo` should reach a child at all is a product question D21 does not answer. |
| `f7-system-states` | F7 | `4.9`, `4.10`, `4.12`, `4.13`, `4.15` | `f3-*`, `f3-profile-read`, `f0-pack-contract`, `f2-app-shell` | The dependency line used to read `f2-app-shell` alone and that was false in two directions: `4.13` prints `1 248` and `RATING · INTACTO`, which is the server's rating and therefore `f3-*`; `4.9` counts `40 RETOS / 2 PUZZLES`, which is the pack manifest and therefore `f0-pack-contract`. `4.13`'s before/after streak pair is **local** — `StreakPolicy` over `DayLogStore`, per D17 — and only its `RATING · INTACTO` figure comes from `f3-profile-read`. `4.15` sits in `round` (the trigger owns it); its two options arrive as navigation edges. `4.12`'s streak badge is a **local composition** here — h56 / r22 / shadow (4,6) on yellow — not a `StatPill` (§3.3 ‡). `4.10` keeps its timestamp and drops the numeric status (Q11, default taken). Plus the three offline states nobody drew (§5.2, DR-1–DR-3). |
| `f8-motion` | F8 | — | everything | Rive. Aki's tail regrowth, the dot transition 22→28, the meter animating off its ink marker, the rating count-up, the map reveal, the streak flip, the sheet slide, the toggle knob. Every one is promised by copy or by a component that makes no sense without it, and every one is drawn only as a still frame. The **reduce-motion preference** gates all of it — the value lives in `settings/policy/preferences.dart` and exists from F7, so the flag is honoured whether or not `4.5` ever draws its toggle (DR-P2). **No duration and no curve is specified anywhere in any document** — DR-5, and DR-K3 for the key press specifically. |

One F4–F8 row carries a requirement that cannot wait for propose time, because the phase that submits
to a store is F3 and this is a store review item. It is written here rather than as its own change
heading: `f7-profile-settings` is defined once, in the table above, and this is that row's delta.

**`f7-profile-settings` · `req-legal-reachable`, carried early** — phase F7.
**Capability:** `profile-settings`. **Screens:** `4.1`–`4.7`. **Depends on:** `f3-*`,
`f3-deletion-web` (the destinations must exist before a row can open one).

`gaps.md` §4.6: `1.2`'s legal line is *"plain unlinked prose"* and store review will ask for reachable
links; `4.7` has the rows and `1.2` does not link to them. Neither surface has a destination at all
until `f3-deletion-web` publishes the site that holds them.

**Opening a URL is a dependency decision, so it is recorded rather than assumed.** `url_launcher`
(flutter.dev) hands a URL to the platform browser and makes no network call of its own; that is the
DEP-1 audit, stated here as DEP-1 requires and not waved at. The rejected alternative is an in-app
`WebView`, which in a child-directed app is an unrestricted browser inside the app.
**[suggestion]** Whether leaving the app needs a parental gate under Play's Families policy is worth
putting to Gate A in the same session; if it does, the gate is one sheet and the requirement below
does not change.

```
### Requirement: req-legal-reachable · The legal documents are reachable from both places that name them
The system SHALL open a published document when `Aviso de privacidad` or `Términos` is pressed, SHALL
render `1.2`'s legal line as tappable links rather than prose, and SHALL give each link a hit box of
at least `BrandShape.minTouchTarget` in both dimensions with its painted text unchanged.

#### Scenario: A legal row is pressed
- **WHEN** `Aviso de privacidad` or `Términos` is pressed on `4.7`
- **THEN** the published URL for that document is opened, and that URL is the same string the store
  artifacts declare — one source, not two
  → `app/test/features/settings/ui/data_privacy_screen_test.dart`,
  `packages/compliance/test/legal_urls.test.ts`

#### Scenario: The create-account legal line is read
- **WHEN** `1.2` renders *"Al crearla aceptas los términos y el aviso de privacidad."*
- **THEN** the two runs are tappable, each hit box measures at least 48×48, the two boxes do not
  overlap each other, and the painted 12 px text is unchanged
  → `app/test/features/auth/ui/create_account_screen_test.dart`
```

**The second scenario ships at F3, not F7.** `1.2` is an `f3-auth-screens` screen and a store
submission happens in that era, so `f3-auth-screens` implements it against this requirement id and
this change owns the `4.7` scenarios. Written once, here, so the two halves cannot disagree.
`1.2`'s line has no vertical room for a 48 px hit box between the primary button and the footer —
the design gives it none — so the room is design request DR-10.

---

## 5 · The critical path, and what runs beside it

### 5.1 Gates before code

Two things are due before F1 and neither is a change with scenarios.

**Gate A — the legal consult.** `ARCHITECTURE.md`'s closing line and R4 both put it **before F1**,
because `players`, `age_band`, deletion semantics and the retention policy are schema decisions made
there. Concretely open: no age gate and no parental-consent path on `1.2` (Mexico's LFPDPPP requires
consent from a parent or guardian for a minor's data regardless of decision #1's no-US-launch
posture, and Google Play's Families policy applies in any market); the transactional email provider
that will receive minors' addresses, which is a processor decision, not an F3 implementation
detail; the retention figures from decision #3 (attempts 400 days, `diag_events` 30), which appear
in no user-facing surface although amended COPPA requires a written policy; and reachable links
behind `1.2`'s currently-unlinked legal line.

Two of those now have owners and therefore deadlines: the reachable links are `req-legal-reachable`
and the retention figures reach a person on the page `f3-deletion-web` publishes. What Gate A still
owes them is the *content* — an aviso de privacidad and términos written for this audience, in es-MX,
which is authored work in R3's budget and not a placeholder — plus the consent threshold, the age-band
value set, and what the tutor-consent flow records as evidence. **And one item Q1's answer promoted
into this list:** with `Borrar mi historial` cut, `Pedir mi archivo` is the only function `4.7` has
left, and whether the ARCO *acceso* right obliges an export at all — in what form, within what term —
is a legal question and not a product one. The plan records a default (the same transactional-email
path `f3-deletion-web` already needs) and does not decide it here.

**Gate B — the schema decisions the design forces.** Four of the five it used to hold were **answered
by Ervin on 2026-08-15** and are now inputs rather than questions: Q1 (history erasure — cut), Q5 (a
player has no name), Q2 (what the pack carries for the error screen), and Q4 (the rating delta is per
series). What Gate B still owes is: **the age band** — `req-age-gate` makes `players.age_band` NOT
NULL and the band must be resolved before the first session, not at `1.2`; **the retention policy** —
decision #3's 400 days and 30 days become a job, a role and a `diag_events` table; the baseline-marker
question in §5.2; and **how `4.1`'s seven-day delta is derived**, from `attempts` (the recorded
default) or from a rating-history table (`f3-profile-read`). All of them change the schema, the schema
freezes at F1, and the screens they serve are scheduled at F7. **A F7 screen with a pre-F1
prerequisite is the cleanest sequencing finding in the whole review.** Gate B's output has one
consumer and one only: **`f1-schema-freeze`**, which is where it lands as SQL. Before that change
existed, Gate B's answers had nowhere to go.

### 5.2 Design requests — what the design does not draw

**A feature is not cut for lacking a screen.** Ervin's instruction, 2026-08-15: *"si necesitamos más
pantallas, sólo documéntalas, hacemos una segunda iteración después"* — and suggestions are welcome,
marked as such. Everything below is a request for iteration 2, numbered so §4 can cite it. Where an
earlier draft of this plan wrote *"cut until a screen exists"*, it now writes *"DR-n"*.

**Numbering, so two readers do not mint the same id.** Plain numbers are the cross-cutting requests
and **DR-1 … DR-13 are assigned and frozen** — §4 and §5.3 cite several of them by number, so no id
here is ever reused or renumbered. A letter prefix groups an area: **DR-K** the keypads, **DR-P**
profile, settings and the system states (`4.1`–`4.15`). **A new request joins a letter group rather
than extending the numeric run** — that is what keeps two people editing this document from minting
the same number twice.

`ARCHITECTURE.md` §9 makes offline **the entire F2 experience**, and the design's only offline
artefact is `4.9 Sin conexión`, which assumes a pack is already downloaded (40 retos, 2 puzzles).
DR-1 to DR-3 are that hole.

1. **DR-1 · The pack download.** No progress, no failure, no retry.
2. **DR-2 · Pack expiry.** `expires_at` is a column in `ARCHITECTURE.md`:197 and no screen mentions it.
3. **DR-3 · Offline with no pack** — a fresh install on a plane. The one state where the app
   genuinely cannot proceed, and the one that will be hit first in a TestFlight build.
4. **DR-4 · `ItemTermTile`'s `wrong` state has no shape channel left.** The `unknown` state already
   owns dashed; success owns solid. Cited by §3.4 and by `f0-verdict`.
5. **DR-5 · The press has no duration, no curve and no haptic**, and *"travel into your own shadow"*
   yields zero displacement on a shadowless control — the secondary button, the ghost row, the
   pills, the map nodes and the nav items. Cited by `f0-pressable-surface`.
6. **DR-6 · Six touch targets are drawn below 48** — `Dejar la serie` at ~29, `3.3`'s 44×44 close,
   the 60×34 toggle, `4.4`'s 40 px preset chips. Each is a design decision, not a bug to patch by
   growing a box. Cited by `f0-pressable-surface`.
7. **DR-7 · The age screen and the tutor-consent flow.** `req-age-gate` stands in front of `1.2` and
   in front of guest sync, and neither surface is drawn anywhere: the neutral date entry, the
   consent screen, what a child sees when the flow routes them there, and how a tutor completes it.
8. **DR-8 · The deletion web page and its email.** Not an app screen, so no digest drew it: the
   form, the three states (requested · link expired · done), the email copy, and the tone rule — a
   child may read this page.
9. **DR-9 · The notification permission prompt.** `4.4` needs a runtime permission on Android 13+
   and on iOS, and no screen asks for it. `gaps.md` §4.7 flags it; D21 confirms the notifications
   are local, which does not remove the prompt.
10. **DR-10 · Vertical room for `1.2`'s legal line.** `req-legal-reachable` needs two 48 px hit
    boxes on a 12 px line that sits directly under the primary button. **[suggestion]** giving the
    line its own row with 24 px above and below is the smallest change that fits.
11. **DR-11 · The three affordances the earlier draft cut for having no destination** —
    `Ver paso` (`04 Error`), `Ayuda` (`4.2`), and the stats / *progreso* tab. Under the new criterion
    these are requests, not cuts. The stats tab carries a warning with it: decision #5 forbids a
    leaderboard and that tab is the one hole shaped exactly like the thing it forbids, so whatever
    gets drawn there should be own-progress only.
12. **DR-12 · The settled / unsettled axis** — the sync that §4 says makes a verdict final has no
    surface at all. Q6 puts it at F3, drawn once and reused; it is not needed in F2 because Q3 hides
    the only number a later sync could contradict.
13. **DR-13 · The reduced F2 home.** D5 picks `Inicio actualizado` and F2 ships a named subset of
    it — the subtraction is decided, the resulting screen is drawn nowhere. Cited by D5.

**DR-K · the keypads.** `teclados.md` §6 and §7 name these as holes in the source documents, and
D14's *"no disabled-key visual exists anywhere"* is where the plan noticed and stopped.

- **DR-K1 · The disabled key.** `teclados.md`:314-318 — *"no está presente en ninguno de los dos
  documentos … ese visual no existe todavía y debe diseñarse."* It is needed because the operator
  strip **is** context-dependent: `components.md` R8 records that five of the six reactivo families answer into a
  single slot, where `a/b` means nothing. Without a disabled treatment the choices are a key that
  silently does nothing or a strip whose shape changes per family — and neither is drawn.
- **DR-K2 · The submit arrow with an empty answer.** `teclados.md`:340 — *"si se deshabilita cuando
  la respuesta está vacía no se muestra."* Same hole, on the one key a child presses to commit.
- **DR-K3 · The press: duration, curve and haptic, for the keypad specifically.** The keypad half of
  DR-5. The HTML is an instant swap; the user is a nine-year-old pressing sixteen keys a minute.
- **DR-K4 · Illegal-digit feedback on the board.** `TecladoPuzzle` has no submit key, so *"illegal"*
  has no drawn affordance at all. `components.md` R8 states it; that half of R8 never crossed into
  this plan, and a grep for `ilegal` in it returns nothing.
- **DR-K5 · [suggestion] Press-and-hold backspace to repeat.** `teclados.md`:337 warns explicitly
  against assuming it. Children clear four-character fields constantly; it is worth drawing or
  ruling out on purpose.

**DR-P · profile, settings and the system states.** `perfil-estados.md` §6's *"implied but never
drawn"* list, plus the three holes Ervin's own answers opened.

- **DR-P1 · `4.1`'s identity row without a name.** Q5 removes the Darumadrop 34 greeting. Either the
  email moves up into that line or the row keeps a hole; both are design calls, neither is an
  implementation one.
- **DR-P2 · `4.5` reduced, and the three toggles that leave it.** v1 is one card — the
  `Acierto` / `Se torció` preview and its legend. `Reducir movimiento` acquires an effect at F8;
  `TAMAÑO DE TEXTO` and `Alto contraste` are undated (Q8); `Modo daltonismo` has no effect at all
  while D6 holds, so redrawing it means deciding what it would mean.
- **DR-P3 · `4.7` with neither the erasure card nor a drawn export state.** Q1 removes the first;
  the digest never drew the second (*"requested / in progress / rate-limited"* for `Pedir mi
  archivo`). What is left is two legal rows, which nobody has drawn as a screen.
- **DR-P4 · `4.4`'s hour card with the daily reminder off.** The digest draws it always enabled and
  §6 lists the disabled case as a hole.
- **DR-P5 · The rest of `perfil-estados.md` §6:** empty history on `4.1` (the profile exists, nothing
  is solved), deletion in progress and after deletion, and loading and error **inside** settings —
  an account row that fails to load has no state today.
- **DR-P6 · [suggestion] One disabled treatment, drawn once.** DR-K1, DR-K2 and DR-P4 are the same
  request in three places, and a design that answers them separately will produce three greys. One
  rule — what a control looks like when it is present and unavailable — closes all three.

These are design requests, not engineering unknowns. DR-1 to DR-3 are here because `f2-app-shell`
cannot ship a complete offline story without them and the plan should not pretend otherwise. DR-7 to
DR-12 are here because a compliance or correctness requirement with no drawn surface is the same
problem one phase later, and because cutting the requirement is not available: `req-age-gate` and
`req-legal-reachable` are store review items, not features.

**This list is the register; §8 is the delivery order.** §8 restates no request's body — it batches
these ids by the phase that first needs them and adds the column this list does not carry: **what
the build ships while each request is open.** Where the two sections disagree, this one wins.

### 5.3 Decisions taken here, where the sources disagreed

Each one names what it overrode and why. These are the reconciliations, not restatements.

| # | Decision | What it settles |
|---|---|---|
| **D1** | **The feature is `round/`, not `reactivos/` and not `game/`.** | `reactivos-puzzles.md` proposes `features/reactivos/`, which violates LANG-1 (identifiers are English). `pantallas-base.md` proposes `game/`, which fails NAM-1 — it is not self-descriptive. `deck.md` and `features.md` both converge on `round/`. |
| **D2** | **Micro-geometry lives in its spec module; `BrandShape` gains ten names (6 radii + 2 border widths + 2 shadows), not twenty-plus.** | Four digests list 14–20 observed radii and conclude the scale must grow. It must, but not by twenty: fraction bar radii, dot rings, cage corners and hairline widths belong to `design/math/spec/` and `puzzles/policy/cage_geometry.dart`. `BrandShape` governs widget surfaces. That is the difference between a scale and a list. |
| **D3** | **`#EAE6F0` is `BrandColors.quiet`, not `keyQuiet`. `#FFC9DC` snaps to `pinkSoft`. Ink @ 20% snaps to `rule`. Ink @ 18% gets `BrandColors.hairline`.** | `gaps.md` §3.5 proposes `keyQuiet`, which is wrong for a token with 17 skeleton uses; both uses mean "inert surface", so name the role. `#FFC9DC` is one avatar tile, 7/6/4 off `pinkSoft`, behind a clipped Aki at 78 px — a token for that is worse than a three-unit hue shift, and `gaps.md`'s "do not silently snap it" is honoured by snapping it *loudly*, here. Ink @ 18% is 100+ board hairlines against `rule`'s 16% on reference-sheet dividers; both are real and both are used in the same file. |
| **D4** | **`BrandButton` has two sizes: `standard` (h60 / 800 18) and `hero` (h62 / 800 19). `hero` is the primary action of a centred full-screen state — a `CenteredStateView` — whether or not a secondary sits underneath it. `standard` is the primary of every in-flow screen.** | `pantallas-base.md` says h60/18, `perfil-estados.md` says h62/19, `reactivos-puzzles.md` shows h58/17 in two-button footers. Not a three-way tie — but the first draft resolved it by **counting buttons** (*"the single action on a centred full-screen state"*) and then claimed 62/19 tracks the `4.8`–`4.15` states *exactly*, which is false for three of them: `perfil-estados.md` §3.10, §3.12 and §3.14 draw two-button footers on `4.10`, `4.12` and `4.14`, and that document's §2.4 gives the primary as h62 / r20 / shadow (4,6) / 800 19 **uniformly across all eight states**. `primera-vez-cuenta.md` says the same on the other side of the corpus: `0.2`, `0.4`, `0.6` and `0.7` are all h62/19, and two of the four carry a cream secondary under the primary. Keying the size to the **screen** instead of to the button count puts all of them on `hero` as drawn and makes the justification true. The rest stands: 60/18 tracks every in-flow screen, and 58 vs 60 is 2 px and does not earn a token. The secondary is unaffected — h52 / r18 / no shadow, everywhere it appears. |
| **D5** | **`Inicio actualizado` is the canonical home now; F2 ships a named subset of it.** | `gaps.md` Q7 default picks `Inicio actualizado`; `features.md` §3.4 says defer the pick because neither home can ship at F2. Both are right about different things, and they converge: picking the document settles the geometry (Aki 158, band 150, bubble 186) while F2 ships a subset with **named** subtractions. Subtraction is not merging — merging takes elements from both documents; a subset takes part of one. `features.md`'s real objection is that the reduced home is undesigned, which is true and is listed in §5.2 as a design request. |
| **D6** | **The solid/dashed + glyph verdict encoding is always on, at F2.** | `4.5 Accesibilidad` gates it behind a "Modo daltonismo" toggle. BRD-1 is not conditional; an invariant behind a setting is not an invariant. Both consolidations agree. The consequence is that `f0-verdict` and `f0-dashed-border` are F0 blockers, not F7 polish. |
| **D7** | **Operator styling is a per-token property of the rendered prompt, not a global rule. Default: operators in Darumadrop, `=` in Plus Jakarta 800.** | Deck slide 04 states operators are *always* Plus Jakarta; every phone mock breaks it, and the two screen documents disagree with each other on `=` (Darumadrop in `02 Reto activo`, PJS 800 42 in `Reactivo aritmética`). Precedence puts the deck last. Making it a per-token property defuses the conflict at the compositor's API and leaves a default. |
| **D8** | **The thousands separator is U+202F, not the source's U+0020.** | Verified: `1 230` uses a plain ASCII space, which can wrap to `1` / `230` inside a 48 px pill at a larger text scale. es-MX convention allows either; only the no-break form is safe. |
| **D9** | **The code's pose names win: `base` / `correct` / `slip`. The design's `base` / `fan` / `error` is an alias documented on `AkiPose`.** | Three digests derived the mapping independently, which is evidence it is not obvious and will produce a mapping bug. The code names are semantic and tested; renaming committed code for a visual alias is churn. Write it down once, in the enum's doc comment. |
| **D10** | **`0.5 Calibración reactivo` loses its 52 px Aki. `3.2 Tutorial` keeps hers, as a written carve-out.** | Both break *"she does not appear while you are solving"*. The tutorial frames itself as the exception in its own label (*"aquí Aki sí habla"*) and `REGLAS DECLARADAS` rule 5 names the tutorial explicitly as *"el único lugar donde habla de más"*. Calibration frames nothing. The carve-out goes into `CLAUDE.md` and the rulebook in the same session (PROC-6). |
| **D11** | **Onboarding ships twice, deliberately: `0.2 → 0.3 → home` at F2, then the calibration branch at F4.** | The drawn path crosses F4 and F5. The alternative is shipping `0.4`'s promise — *"unos rápidos para acomodar tu nivel"* — that the F2 build cannot keep. Two small builds beat one broken promise. |
| **D12** | **The nav bar renders only tabs that have roots; the stats tab has no root, so it does not render.** | Four tabs are drawn. At F2 there is one root and the bar should not exist; at F5 there are two; profile arrives at F7. **Tab 3 (stats) has an icon in every nav bar and no screen in any document, ever** — and it is the one hole shaped exactly like the leaderboard decision #5 forbids. A four-tab bar with two dead tabs is worse than a two-tab bar. Under the criterion in §5.2 the tab is not *cut*: the bar renders only tabs that have roots, which is a rendering rule, and the missing root is design request DR-11. |
| **D13** | **Google and Apple sign-in come off `1.1`, along with the `O` divider.** | The reasoning is Play's Families policy restricting SDKs in child-directed apps, plus the audience constraint that stood at `CLAUDE.md`:7 until ADR 0004 removed it on 2026-08-29 — **the conclusion is unchanged and the citation is not**; what carries it now is DEP-1 as a category refusal (supply-chain surface, ADR 0003's per-version audit cost, data minimisation), and the Families half is retired outright, per `docs/gates/gate-a-adult-data-consult.md` §5's assumption 10 — an adults-only app is not in that programme — **not** a straight DEP-1 citation, because a redirect-based OAuth flow through Better Auth is not necessarily an SDK that phones home, and a mis-cited NEVER is its own problem in a repo where reviewers cite rule IDs. |
| **D14** | **There are three keypad layouts, not two: item 4×4, puzzle 5×2, OTP 3×4.** | `gaps.md` §1.8 argues `KeypadSpec` is over-scoped for v1 and proposes two named layouts. It missed `1.3 Verificar correo`'s 3×4 numeric pad (`1 2 3 / 4 5 6 / 7 8 9 / ⌫ 0 ↵`, keys h60). All three share `KeypadKey`; none varies per template, and no disabled-key visual exists anywhere — which is not a shrug: it is design request **DR-K1**, with DR-K2 for the submit arrow on an empty answer and DR-K4 for illegal-digit feedback on a board that has no submit key at all. |
| **D15** | **6×6 is the board maximum and the 9×9 three-tab split is out of scope. This was never a conflict.** | `gaps.md` §3.4 lists deck slide 10 ("los tableros no pasan de 6 × 6") against reactivos' 9×9 tab split as a contradiction. Reactivos' own annotation B says 38 px *"queda fuera del móvil, no se ofrece"* — it agrees. The tab split is a stated contingency for a puzzle that does not exist in the five-puzzle catalogue. Reading it as a conflict would put dead scope in F6. |
| **D16** | **Sopa's "Arrastre en curso" is recoloured from coral to yellow.** | Coral means error and nothing else, enforced by `brand_colors_test.dart`. The design's own declared rule 3 supplies the replacement: *"Sin conexión no es un error del usuario: va en amarillo"* — yellow is the in-progress hue. The dashed-vs-solid capsule distinction is kept, so BRD-1 still holds without hue. |
| **D17** | **The streak is a local calendar fact; the rating is the server's exclusive authority.** | `features.md` 3.3(d) flags these as separable and says so; `gaps.md` Q1's default assumes the streak is available offline. Both are satisfied by stating it: the streak is computed on device from the local attempt log, so it survives F2; the rating is hidden until F3. The day boundary is Q7, **decided 2026-08-15**: the device's local calendar day, `America/Mexico_City` when it offers no zone, and a wrong answer never decrements it. |
| **D18** | **`BrandColorRole.focus → pink` is added, and the pink invariant's wording is narrowed to verdicts.** | `deck.md` §9.5 claims the test asserts "no role resolves to pink"; it does not — it asserts pink ≠ error/success/action. `primera-vez-cuenta.md` §7.2 is right that adding `focus` passes today. Focus is a transient input affordance, not a verdict, and every focused field in the design is pink. The `CLAUDE.md` wording is amended in the same session (PROC-6). |
| **D19** | **The splash keeps `SplashVariant`; the design wins on measurements.** | `splash_screen.dart` renders `Aki(width: 222)` with gaps 28/28/36; `0.1` says 210 and a uniform 26 — the design is authoritative on measurements. `SplashVariant.brandGreen` appears in no document but is quoted verbatim in `craftsmanship.md` FUN-2 as the rulebook's canonical example; deleting it makes the rulebook stale for no gain (PROC-6). The unjustified `width: 4` border BRD-2c names gets a one-line reason or reverts to 3. |
| **D20** | **`4.15 Tema agotado` lives in `round/`.** | The owner test strains here and it is placed by tiebreak, not cleanly: the trigger is round's (this skill has no items left today) but both options are owned elsewhere — "Cambiar a decimales" is skill_map data and "Puzzle del día" is puzzles data. Only the trigger can decide the screen should appear; both options arrive as navigation edges, not imports. |
| **D21** | **The three toggles on `4.4` are served by locally scheduled notifications only — no FCM, no APNs, no messaging SDK, no push token.** The daily reminder, `Racha en riesgo` and `Puzzle nuevo` are all scheduled on the device from data the device already holds. | The same reasoning as D13, and cited the same careful way. The reason is Play's Families policy on SDKs in child-directed apps plus the audience constraint that stood at `CLAUDE.md`:7 until ADR 0004 removed it on 2026-08-29 — **the conclusion is unchanged and the citation is not**; what carries it now is DEP-1 as a category refusal (supply-chain surface, ADR 0003's per-version audit cost, data minimisation), and the Families half is retired outright, per `docs/gates/gate-a-adult-data-consult.md` §5's assumption 10 — an adults-only app is not in that programme — **not** a straight DEP-1 citation, because `flutter_local_notifications` wraps `UNUserNotificationCenter` and `NotificationManager` and makes no network call, so DEP-1 is satisfied by stating that audit rather than by banning the plugin. What FCM would add is a push token, which is a device identifier, collected and shared with a processor, for three reminders the device can compute alone. The payoff is concrete: no token means no identifier, which keeps a Data Safety row empty by construction — see `f3-store-artifacts`, `req-no-remote-messaging`, which fails if `pubspec.yaml` or `pubspec.lock` gains a messaging dependency, if the iOS entitlements gain `aps-environment`, or if the merged manifest declares a Firebase messaging service. **This decides transport only.** Whether `Racha en riesgo` should be sent to a child at all is Q9's question and D21 does not answer it. The runtime permission prompt Android 13+ and iOS both require has no designed screen — §5.2, DR-9. |
| **D22** | **`req-no-blur-painters` lands in `f0-dashed-border`, not in `f0-invariant-tests`** — the dash and the widened no-blur gate ship in one change. | `no_blurred_shadow_test.dart` walks `DecoratedBox` and `PhysicalModel` only, so the moment a border moves into a `CustomPainter` the surface leaves the gate's reach — and `CandySurface.borderDash` (§3.2) is exactly what moves it, on the answer slot, `4.8`'s placeholders, the locked map node, `VerdictChip`, every cage and Sopa's capsule. Split across two merges, the invariant silently stops covering the components that carry BRD-1's shape encoding for as long as the gap lasts. So `f0-dashed-border` depends on `f0-invariant-tests` and amends its gate in the same change — which is also why that change is **first**, not "any time" (§5.4). |
| **D23** | **The board is 354 px outer at pitch 58, and the side padding is 18, not 20.** | `components.md` K17 — **one document contradicting itself.** Its SVG viewBox is `0 0 348 348` with hairlines at 58/116/174/232/290, so the pitch is 58, which the same file annotates *"el máximo del móvil"*; counting the 3 px border that is a **354 px** outer box. Its board zone then states `padding: 12px 20px`, which leaves **350 px** inside a 390 px frame. Four pixels decide whether the pitch survives. **The discriminator is the source's own, not this plan's:** `reactivos-puzzles.md`:415 rules that 58 px *"es el máximo del móvil"* is **stated intent and the 20 px padding is not**, so the padding yields. The resulting 18 px is `[inferred]`, and stays labelled that way — `390 − 2×18 = 354` outer, 348 inner, 58 px pitch. One implementation note travels with it, because the conflict is box-sizing dependent and Flutter resolves it the other way from CSS: `Border` paints **inside** the box, so the widget is a `SizedBox(354)` with a 3 px border → 348 inner → pitch 58. Lands in `BoardGeometry` (§3.4) and in the `f6-puzzles` row. |

### 5.4 The critical path

```
                    ┌─ f0-token-scale ─┬─ f0-pressable-surface ─┐
                    │                  ├─ f0-dashed-border ─────┼─ f0-verdict ─┐
   Gate A (legal) ──┤                  ├─ f0-brand-icons ───────┘              │
   Gate B (schema)  │                  ├─ f0-keypad ───────────────────────────┤
                    │                  └─ f0-stat-readouts ────────────────────┤
                    │                                                          │
                    ├─ f0-pack-contract ─┬─ f1b-content-reader ────────────────┤
                    │                    └─ f1-core-rederivation ─ f1-5-pack-builder
                    ├─ f1b-math-compositor (Spike B) ─────────────────────────┤
                    ├─ f0-dart-client-spike (Spike A)                          │
                    └─ f0-invariant-tests                                      │
                                                                               ▼
                                             f2-app-shell ─ f2-core-loop ★ ─ f2-home-reduced
                                                                     └─ f2-onboarding-first-run
```

**On the path:** `f0-token-scale` → `f0-dashed-border` + `f0-verdict` → `f1b-math-compositor` →
`f1b-content-reader` → `f2-core-loop`. That chain is what "playable" means, and
`f1b-math-compositor` is the long pole in it. **`f0-keypad` and `f0-stat-readouts` are on it too** —
both already declared that they block `f2-core-loop`, and that change now declares them back. Neither
is long, but neither is optional: the item screen has no answer path without the keypad and no
verdict without the tiles. The diagram above draws them inside the `f0-token-scale` fan.

**`f0-invariant-tests` is not beside the path either — it is first.** An earlier reading of this
section had it at "any time", and its own change block says the opposite in its own words. Three
edges make it first: `f0-dashed-border` amends its no-blur gate and therefore depends on it (D22),
it creates `app/test/architecture/` — which four F0 changes already name a test file under — and
`screen_overflow_test.dart` reaches every screen change in the document through §4's definition of
done. It has no upstream of its own, so "first" costs nothing; deferring it is what costs.

**Beside it, no dependency on the path:** `f0-brand-icons` (any time before the first screen),
`f0-dart-client-spike` (F0, decides `app/lib/api/` shape only),
the whole TypeScript lane `f1-core-rederivation` → `f1-contract-emitter` → `f1-5-pack-builder`
(joined to the Dart lane only at `f0-pack-contract`, upstream of both), and every design request in
§5.2.

`f1-schema-freeze` is also beside the path and not on it — F2 plays from a JSON pack and touches no
database — but it is the **only** F1-lane change with a hard upstream outside the repo: Gate A and
Gate B. It is first in the TypeScript lane because everything at F3 reads its output, and because a
schema that freezes at F1 with no owner does not freeze at all.

**The one thing that must not slip:** `f0-pack-contract`. It is upstream of both lanes; if it moves,
the parallelism in `ARCHITECTURE.md` §9 collapses into a serial chain and the first playable slides
by whatever the TypeScript lane costs.

---

## 6 · Risks, each with its early signal

The five from `ARCHITECTURE.md` §10 still hold; three of them now have a sharper signal, and three
more come out of the design review.

| Risk | Early signal |
|---|---|
| **R1 · Nothing playable in 8 weeks.** The concrete mechanism is the math compositor: it is the only thing between F0 and playable and every estimate underrates it ~2×. | Spike B passes two days without one legible nested fraction with the outline on. Second signal: week 8 with nothing playable on the phone. |
| **R2 · Silent drift between TypeScript and Dart grading.** The worst bug the system can have — a child sees "incorrecto" offline and "correcto" on sync, with no telemetry to catch it and no broken build to announce it. | `contract/fixtures/` does not exist, or exists **without rejection rows** (`""`, `"1/0"`, `"x+1"`, U+0660, U+2212, ZWSP, combining marks). Without those the fixture tests one direction only. |
| **R2b · The same drift, moved to layout.** Six stimulus payloads parsed by hand on both sides with no compiler help across the seam. | A stimulus kind lands in `f2-stimulus-families` with no golden fixture in `contract/fixtures/`. |
| **R3 · Content is the speed ceiling, not code.** It is the one body of work that does not parallelize with agents. | F1 ends with any map node under three templates; or the uniqueness rule library has under 20 rules. Sharper now: **the design multiplies the estimate** — six reactivo families each with a generator, per-distractor structured diagnostics, five puzzle types with cages/clues/targets/solutions/hints, per-puzzle tutorials and reference sheets, Aki's non-repeating dialogue pool per context, and the whole of 4.2–4.15's settings copy. |
| **R4 · Minors compliance arrives after the schema freezes.** | A TestFlight or internal-test build without `DELETE /v1/me`, without the web deletion page, and without a retention figure written down. Sharper now: **Gate A has not happened by the time `f1-core-rederivation` starts.** Sharper still: the three changes that carry it are `f1-schema-freeze`, `f3-deletion-web` and `f3-store-artifacts`, so the signal is now a build, not a worry — any of the three unstarted when `f3-server-foundation` merges. |
| **R5 · Agents erode invariants that live only in prose.** | A PR touching `pubspec.yaml`, `package.json`, `AndroidManifest.xml`, `PrivacyInfo.xcprivacy` or any migration **when the task did not ask for it**. Sharper now: a screen lands without being added to `no_blurred_shadow_test.dart`'s list — the moment coverage starts decaying silently. |
| **R6 · The design's own invariants are not enforced anywhere.** `REGLAS DECLARADAS` rules 2 and 4 are directly checkable and no test checks them; the enforced colour test cannot see a widget writing `pct >= 90 ? green : pink`. | A meter, chip or capsule ships whose fill colour is chosen by a comparison rather than by a role. |
| **R7 · The `(4,6)` shadow and the radius scale are decided per screen instead of once.** BRD-2c fires on every review and each screen invents its own literal. | The second screen change lands before `f0-token-scale` merges. |

---

## 7 · Open questions for Ervin

Ranked by how much they block. **Each has a default; if a question goes unanswered the plan takes
its default and records it.** Every one is answerable without re-reading the design.

**Status as of 2026-08-15: none of the thirteen is open.** Ervin answered eight — Q1, Q2, Q3, Q4,
Q5, Q6, Q7 and Q10 — and let the other five stand at their default. Each question keeps its text,
because the reasoning is *why* the answer is what it is, and gains one closing line: **DECIDIDO** with
the answer and the date, or **DEFAULT TOMADO** for the five that were not asked again. Both are
binding, and both are propagated: every closing line names the sections written against it, so a
decision recorded here and contradicted in §4 is a defect either this list or that section has to
own. The one instruction that reaches past this list is the criterion change of the same date — *"si
necesitamos más pantallas, sólo documéntalas"* — which retires *"cut until a screen exists"*
everywhere it appeared (§5.2 holds the requests it produced; §8 holds the order they are handed
over in, and what ships while each one is open).

### 7.0 · The four that outlived the thirteen — decided 2026-08-15

These were not on the list of thirteen. They surfaced during verification, the document could not
settle them alone, and Ervin closed all four on the same date. They are binding on the same terms.

| | Question | **Decided** | Propagated to |
|---|---|---|---|
| **A** | Where does `4.1`'s seven-day delta come from? | **Derive from `attempts`.** No `rating_history` table. The 400-day retention outlives a 7-day window by a wide margin, and the boundary stays an injected parameter rather than a clock read. **Gate B is now closed** — this was its last open item. | `f1-schema-freeze` (no history table in the freeze), `f3-profile-read`, §5.1 Gate B |
| **B** | What makes a skill-map node *mastered*? | **The pack declares node state.** `SkillGraph` does not derive it. This is what lets `f5-skill-map` ship before a mastery threshold exists; the day that threshold is set it is a server-side rule and this pure module does not change. The gap the closing pass reported as an unnumbered phantom is closed by deciding it, not by numbering it. | §3 `SkillGraph`, `f5-skill-map`, `f0-pack-contract` |
| **C** | Are the h56 chip and the h64 pill one component? | **One component, two sizes.** `StatPill` gains `StatPillSize.hero`. K8 resolves in favour of collapsing: `0.6`'s rating chip and `4.12`'s streak badge stop being local compositions. The F0 scenario that forbade a `hero` member is replaced by one that asserts both sizes. | §3 `StatPill` row and §3.5, `f0-stat-readouts`, `0.6`, `4.12` |
| **D** | When does Gate A — the children's-data consult — start? | **Now, before any F1 work.** It decides the age bands, the consent threshold, the retention figures the privacy notice states, and whether ARCO *access* obliges `Pedir mi archivo`. All four are schema decisions and the schema freezes in F1. | §5.1 Gate A, `f1-schema-freeze`, `f3-auth-screens`, `f3-deletion-web` |

**Consequence worth stating once:** with A and D settled, `f1-schema-freeze` has everything it needs
except Gate A's output, and Gate A is now the single thing standing between today and the F1 lane.
That is the whole critical path in one sentence.

**Q1 · Does "Borrar mi historial" (`4.7`) ship, and through which path?** — *due before F1*
The screen's copy — *"Se van las respuestas y los tiempos. Tu rating y tu racha se quedan."* —
requires deleting `attempts` while keeping the player alive. That is a **third erasure path the
schema forbids**, from the request path, which holds no DELETE grant. It also breaks the calibration
guarantee: `template_stats` is maintained on write, so a user-initiated wipe leaves the aggregate
silently outliving the data the user was told was gone. Options: cut it; a soft-hide flag that
deletes nothing; or an async job under the `retention_job` role.
**Default: cut the feature. `DELETE /v1/me` remains the only user-initiated erasure.**
**DECIDIDO 2026-08-15 — cortado.** `DELETE /v1/me` is the only erasure a user can start, the
request-path role keeps no DELETE grant on `attempts` (`f1-schema-freeze`, `req-erasure-grants`), and
the third erasure path never comes into existence. **Propagated to:** `f3-server-foundation` (the
clause that says so), the `f7-profile-settings` row, and §5.1 Gate A — because with the card gone,
`Pedir mi archivo` is all `4.7` has left and nobody had planned it. `4.7` reduced to two legal rows
and an undrawn export card is design request **DR-P3**.

**Q2 · Where does the offline diagnosis come from, and what happens when a child types something no
distractor anticipated?** — *due before F1.5*
Decision #4 says labelled distractors exist **server-side only**; §9's F1.5 says the pack emits them
**with `explain` copy in es-MX**. Both cannot hold. And even after one wins, free entry means an
unanticipated answer is reachable on **every** item, while `04 Error` renders the learner's own
wrong term struck through with an explanation keyed to that specific mistake. **No screen anywhere
designs the unmatched case**, and the copy explicitly refuses to degrade to "incorrecto". Note the
security cost of the pack-side answer: a readable `explain` blob per distractor weakens the
membership-verifier posture, because the correct answer becomes the one *not* in the list.
**Default: the pack carries `HMAC(canonical answer) → {misconception, steps, explain}` per labelled
distractor, plus one non-scolding generic fallback per skill for unanticipated input.**
**DECIDIDO 2026-08-15 — exactly that.** The pack carries `HMAC(canonical answer) →
{misconception, steps, explain}` per labelled distractor **and** one generic, non-scolding fallback
per skill for the answer no distractor anticipated. The fallback is not an error message: it names
the reasoning and shows the correct step, like every other path through `04`. **Propagated to:**
`f2-core-loop`'s `req-diagnosis-copy`, whose second scenario is that case and already asserts the
screen never says *"incorrecto"*; `f0-pack-contract`, which fixtures the shape; and
`f1-schema-freeze`, where `diag_events.misconception_id` is nullable **because** of this answer —
null is the fallback.

**Q3 · In F2 — offline, no account, a JSON pack in `assets/` — what do the rating pill and the
±18 / −6 tiles show?** — *due before F2*
Rating is the server's exclusive authority and F2 has no server, yet **ten screens print a rating**
and three print a delta. `4.9` makes it worse in copy: *"Tu rating se guarda aquí y se pone al día
cuando haya señal."* states the device holds it.
**Default: in F2 the rating pill and both delta tiles are hidden entirely; the verdict screens show
time and streak only, and the rating pill returns at F3.** (See D17: the streak is local and does
survive F2.)
**DECIDIDO 2026-08-15 — oculto por completo.** Not dimmed, not a placeholder, not a dash: in F2 no
screen prints a rating or a delta. The verdicts show **time and streak**; the pill returns at F3 with
`f3-attempt-sync`, which is when a rating first exists. The streak is local and does survive F2
(D17). **Propagated to:** `f2-core-loop` (`03` and `04` ship two tiles), `f2-home-reduced` (no pill),
`f3-guest-save-prompt` (`0.7` ships two of its three tiles until the sync lands), and Q6 — hiding the
rating is what removes the only number a later sync could contradict, which is why F2 needs no
provisional marker.

**Q4 · Is the rating delta per item or per series?** — *due before F1*
`ARCHITECTURE.md`:160 gives **one** Glicko update per session. `03` and `04` show +18 / −6 per item;
`2.5` shows +12 for a five-item series containing a failure. Those numbers cannot both be real.
`4.1`'s "+36 esta semana" is a third granularity needing rating history over a window, and §5 names
no rating-history table.
**Default: per series only. `2.5` is authoritative; the delta tile comes off `03` and `04`, leaving
the time and streak tiles already on those screens.** *(Consequence to accept: `03 Acierto` ships
with two stat tiles, not three.)*
**DECIDIDO 2026-08-15 — por serie.** `2.5 Resumen de serie` is authoritative and is the only screen
in the app that prints a delta; `03` and `04` lose that tile and ship with two. This matches
`ARCHITECTURE.md`:160's one Glicko update per session — the per-item numbers were never derivable.
**Propagated to:** `f2-core-loop` (two tiles on both verdicts), `f2-series-summary` (no longer gated
on this question), and `f3-profile-read` — `4.1`'s `+36 esta semana` is now explicitly a *window over
history*, not a third granularity, and how it is derived is the one open item left at Gate B.

**Q5 · Does a player have a name?** — *due before F1*
`1.2` asks `CÓMO TE LLAMO` and `4.1` greets `ANA` at Darumadrop 34 — and `ARCHITECTURE.md`:444 says
`players` gains **no name column**. The decision's *rationale* is about public display names, which a
local first name is not; but the decision as written says the column does not exist. **One earlier
citation on this question was false and is corrected here rather than quietly dropped:** `4.3`'s
deletion sheet was said to interpolate the name, and it does not. Its copy is *"Se borra tu correo,
tu rating de 1 248, tu racha de 13 días y las 312 respuestas que llevas."* — four interpolations,
which `perfil-estados.md` §5 enumerates as email, rating, streak-days and attempt-count. The evidence
is two screens, not three. Gate B treats this as a pre-F1 schema decision, and a phantom third
citation is exactly how a column gets added.
**Default: drop the field. `4.1` greets the email; the compliance rationale stands unchanged.**
**DECIDIDO 2026-08-15 — se elimina el campo.** No name is collected, stored or transmitted. `1.2`
loses `CÓMO TE LLAMO`; `players` has no name column, and `f1-schema-freeze`'s `req-player-shape`
enumerates `information_schema.columns` so the absence is tested rather than promised. **Propagated
to:** `f3-auth-screens` and `f1-schema-freeze`. **And the consequence nobody had written down:**
`4.1`'s identity row loses its Darumadrop 34 line. Whether the email rises into that slot or the row
keeps a hole is a drawing decision, not an implementation one — design request **DR-P1**.

**Q6 · Is there a settled/unsettled axis on verdicts and the rating pill?** — *due before F2*
§4 guarantees only a **provisional** verdict offline. `03 Acierto` says `¡EXACTO!` at 50 px and pays
out `+18`; not one screen carries a provisional marker or any visual difference between a verdict
the server confirmed and one an HMAC guessed. In F2, 100% of verdicts are provisional and 100% are
drawn as final. R2 says this is the worst bug the system can have, and the design has no surface on
which it can ever be seen or corrected.
**Default: no provisional marker in F2 (because Q3's default hides the rating, which removes the
only number that can be wrong); add the settled/unsettled axis at F3 with the sync, drawn once and
reused. Rule when sync disagrees: the server's verdict wins silently and the attempt is re-scored;
the child is never told they were wrong twice.**
**DECIDIDO 2026-08-15 — ninguno en F2.** No provisional axis exists in F2, because Q3 hides the only
number that can be wrong. The settled/unsettled axis arrives at F3 with the sync, is **drawn once**
and reused wherever a rating appears, and when the two disagree **the server wins in silence**: the
attempt is re-scored, the screen is not shown again, and no copy tells a child a second time that
they were wrong. **Propagated to:** `f3-attempt-sync`, whose `req-provisional-verdict` scenario now
states the disagreement rule instead of deferring it, and §5.2 — the axis is drawn in no document, so
it is design request **DR-12**.

**Q7 · When does a day roll over for the streak?** — *due before F2*
`12 días` / `13 DÍAS` / `DÍAS · SIGUE` with no timezone policy anywhere, and `4.12` needs a deadline
to render at all.
**Default: the device's local calendar day, `America/Mexico_City` if the device offers no zone. A
wrong answer never breaks the streak — `DÍAS · SIGUE` is the rule, and the drifting numbers across
mocks are mock inconsistency, not a decrement.**
**DECIDIDO 2026-08-15 — día calendario local del dispositivo, con `America/Mexico_City` de
respaldo.** A wrong answer never breaks the streak. **Propagated to:** `f2-home-reduced` and
`StreakPolicy(attemptDays, today)` in `home/policy/` — `today` is a parameter, so the rule is a pure
function of the day list and the day, and the zone fallback is the adapter's single decision.

**Q8 · Do the four text-size steps and "Alto contraste" (`4.5`) ship in v1?** — *cheap now,
expensive after fifty screens*
They cost very different things. Text size is a root-level
`MediaQuery(...copyWith(textScaler: TextScaler.linear(s)))` and `BrandText` does not change — but
the design is full of **fixed heights that do not scale with type** (settings rows 62, secondary
buttons 52, fields 56, the 82×74 time boxes, meter tracks 9–16, icon tiles 48), and `04 Error`
already sits at ~803 px in 838 px. "Alto contraste" needs a runtime palette, which
`BrandColors`' `static const` layer cannot do without touching every consumption site — and it has
**no specification anywhere**: no palette, no treatment, nothing. Both toggles also sit one phase
before the motion they gate (`4.5`'s copy asserts an Aki idle bounce that arrives at F8).
**Default: ship neither toggle in v1; honour the OS `textScaler`; and the 390×844 × 1.3 overflow
test in `f0-invariant-tests` is what makes the deferral safe rather than merely postponed.**
**DEFAULT TOMADO 2026-08-15.** Neither toggle ships in v1 — and note what this is *not*: it is not a
cut for lacking a screen, it is a cut for lacking a specification (`Alto contraste` has no palette
anywhere) and for a cost the fixed heights make real. The criterion change of the same date does not
reach it. **Propagated to:** the `f7-profile-settings` row — `4.5` ships as one card, the verdict
preview and its legend — and §5.2 **DR-P2**, which carries the three remaining controls with the
phase each would acquire an effect in: `Reducir movimiento` at F8, text size and contrast undated,
`Modo daltonismo` never while D6 holds.

**Q9 · Does `4.12 Racha en riesgo` keep its live countdown chip?** — *due before F7*
`TE QUEDAN 3 H 46 MIN` is not a solving timer, so the "no visible timer" invariant does not reach it
(that invariant should be scoped to solving in writing, or a reviewer will fire it at `1.3`'s
`0:42` resend cooldown too). The question is a product one, not a rules one: a ticking countdown
pointed at a child to protect a streak is a deliberate engagement-pressure mechanic, and the same
screen's `4.4` counterpart schedules a push notification *"Solo si no jugaste y ya va a ser tarde"*.
**Default: keep the screen, drop the ticking chip, and let the screen's own line — *"Con un reto de
cuatro minutos queda cerrado el día."* — carry the urgency. Reversible: it is one widget.**
**DEFAULT TOMADO 2026-08-15.** The screen ships without the ticking chip. **Propagated to:** the
`f7-system-states` and `f7-notifications` rows. D21 settles the *transport* of the `Racha en riesgo`
reminder — locally scheduled, never a push token — and deliberately does **not** answer this
question, which is whether that reminder should reach a child at all. Reversible in one widget, and
the streak deadline the chip needs is data `f3-profile-read` already returns.

**Q10 · How many skill-map nodes does v1 ship?** — *due before F1, it sizes R3*
R3 budgets "12–15 nodes × ≥3 templates". Deck slide 02 fixes it at **9 temas** and
`05 Mapa de habilidades` draws exactly 9 with a hand-authored layout whose nine edge endpoints were
verified arithmetically.
**Default: 9. It is what the design draws and what the layout encodes; R3's 12–15 was a sizing
estimate, not a spec. This cuts the R3 content budget by roughly 40%.**
**DECIDIDO 2026-08-15 — nueve.** The nine the design draws, on the hand-authored 358×576 lattice
whose nine edge endpoints were verified arithmetically. **Propagated to:** the `f5-skill-map` row,
`SkillGraph` in `skill_map/policy/` (whose test *is* the 9-node / 9-edge lattice), and R3's content
budget — nine nodes × ≥3 templates, not twelve to fifteen. A tenth node is a design change, not a
content one, because the layout is authored rather than computed.

**Q11 · What does `4.10 Error de servidor` show a child?** — *due before F7*
`error 503 · 18:42` puts a raw HTTP status in front of a nine-year-old.
**Default: keep the timestamp, drop the numeric status. The chip reads the local time and nothing
else; the status code goes to a copyable diagnostic that support can ask for.**
**DEFAULT TOMADO 2026-08-15.** `4.10`'s chip reads `18:42` and no status code; the code lives in a
copyable diagnostic. **Propagated to:** the `f7-system-states` row.

**Q12 · Are `Ver paso` (`04 Error`), `Ayuda` (`4.2`), and the stats tab in scope?** — *due before
their phase*
None has a destination screen in any document. Screens `2.6` and `3.4` are implied by the row
numbering and appear nowhere; `GET /v1/me/standing` (decision #5) has no surface either.
**DEFAULT TOMADO 2026-08-15 — pero el default mismo se reescribió**, because the criterion it rested
on was retired the same day. The old default read *"cut all three affordances until a screen
exists"*; Ervin's instruction is that nothing is cut for lacking a screen, so:
**None of the three is cut. `Ver paso`, `Ayuda` and the stats tab are documented as design request
DR-11 for iteration 2, and the affordance is absent from the build only until its screen exists —
which is a sequencing fact, not a scope decision. `2.6` and `3.4` remain a numbering gap, not missing
work.** **Propagated to:** §5.2 DR-11, §8.4 (which records the reversal in full, for a reader who
saw the draft that cut them), §8.2 batch B5 (the interim for each of the three), the `f2-core-loop`
block (`04` keeps the affordance's room rather than reflowing without it), the
`f7-profile-settings` row (`Ayuda` waits, it is not cut) and §5.3 D12 (the stats tab has no root,
which is a rendering rule — the missing root is the request). `GET /v1/me/standing` still has no surface and is not scheduled; that one is decision #5's
endpoint, not an affordance, and it stays out of v1.

**Q13 · What does a guest with local progress see when they sign into an *existing* account?** —
*due before F3*
`0.2` → "Ya tengo cuenta" → `1.1` is a drawn path. `1.6` designs only guest → **new** account, so
two ratings, two streaks and two attempt sets collide. `POST /v1/players/link` is idempotent against
double-submit, not against conflicting state.
**Default: the server keeps the account's state and discards the guest's, with a one-line warning
on `1.1` when the device holds progress.**
**DEFAULT TOMADO 2026-08-15.** The account's state wins; the guest's is discarded; `1.1` carries a
one-line warning when the device holds progress. **Propagated to:** `f3-auth-screens` (the warning is
copy on `1.1`) and `f3-guest-save-prompt`. The warning line is drawn nowhere — it is one line of copy
on an existing screen, so it is recorded here rather than as its own design request, and R3's copy
budget owns it.

---

## 8 · Design requests for iteration 2

**§5.2 is the register; this section is the delivery order.** Where the two disagree §5.2 wins — it
holds the evidence, the source citations and the frozen ids, and §3, §4, §5.3 and §7 all cite it by
number. Nothing here restates a request's body. Every row is a **DR id**, what a designer has to
produce for it, the surface it attaches to, the phase that first wants it, and **what the build does
while the request is open** — that last column is why the section exists. Ervin's instruction of
2026-08-15, *"si necesitamos más pantallas, sólo documéntalas, hacemos una segunda iteración
después"*, converts each of these from a cut into a dated hole, and a dated hole has to say what
ships through it in the meantime. A request with no interim answer is a cut wearing a new name.

**The ids are frozen and this section mints none.** DR-1 … DR-13, DR-K1 … DR-K5 and DR-P1 … DR-P6
are assigned in §5.2 and cited from four other sections. A request discovered after this draft joins
a letter group; nothing here becomes DR-14.

**A note on the interim column.** Where the plan already decided what ships through the hole, the
cell states it and the decision is binding. Where the plan did not, the cell is marked
**[suggestion]** — the plan's own proposal, offered so the hole is not shapeless, and not something
the design owes an answer to.

### 8.1 The order to hand them over in

Five batches, ordered by the phase that first needs them rather than by how much drawing each costs.
The ordering has one non-obvious consequence worth stating: **the two cheapest batches are the two
earliest**, because B1 and B2 are *rules* rather than screens, and every screen drawn after them
inherits the answer. Drawing them late means redrawing everything drawn before.

1. **B1 · The rules every later screen inherits** — DR-4, DR-5, DR-6, DR-K3. Phase **F0**. Four
   specifications, no new screen among them. They are first because `f0-pressable-surface` and
   `f0-verdict` are on the critical path (§5.4) and because a press spec decided in iteration 2 is
   applied once, while a press spec decided in iteration 3 is applied to every control that shipped
   in between.
2. **B2 · One disabled treatment, drawn once** — DR-K1, DR-K2, DR-K4, DR-P4, all closed by
   **DR-P6**. Phase **F0** for the keypad half, **F7** for `4.4`. One rule, four call sites; four
   separate answers produce four different greys, which is DR-P6's whole argument.
3. **B3 · The compliance surfaces** — DR-7, DR-8, DR-9, DR-10. **Gate A → F3**. This batch is the
   one that **cannot be deferred by deferring the feature**: `req-age-gate` and
   `req-legal-reachable` are store-review items, so the choice is drawing them or not submitting.
   DR-7 additionally waits on Gate A's *content*, so it is the one batch with a non-design
   dependency in front of it.
4. **B4 · The offline story** — DR-1, DR-2, DR-3. Phase **F2**. `ARCHITECTURE.md` §9 makes offline
   the entire F2 experience and the design's only offline artefact is `4.9 Sin conexión`, which
   assumes a downloaded pack. DR-3 is the one a TestFlight tester hits first, on the first fresh
   install with no network.
5. **B5 · The screens the plan names and no document draws** — DR-11, DR-12, DR-13, DR-P1, DR-P2,
   DR-P3, DR-P5. Phases **F2 → F7**, each dated in the roster. This batch is the largest and the
   least urgent per item, because every one of them has a stated interim that ships.

### 8.2 The roster

**B1 · The rules every later screen inherits.**

| DR | What the designer produces | Attaches to | First needed | What ships while it is open |
|---|---|---|---|---|
| **DR-4** | Which channel `unknown` gives up on `ItemTermTile`, or a third shape for `wrong` | `ItemTermTile`, on the five stimulus screens and the error replay | F0 · `f0-verdict` | Decided only on the code side: `Verdict` keeps both channels, **the glyph is mandatory at every call site** and the outline is honoured where it is free (§4, `f0-verdict`). Which channel `unknown` gives up stays open — that is the request, and this column does not answer it |
| **DR-5** | A press duration, a curve, a haptic, and an active style for the five controls that carry no shadow to travel into | `PressableSurface`: the secondary button, the ghost row, the pills, the map nodes, the nav items | F0 · `f0-pressable-surface` | Nothing. This is the one request with **no interim**: the change is forbidden from silently shipping a control with no visible press, so it is an unmet exit criterion rather than a default |
| **DR-6** | A decision per target for the six drawn below 48 — `Dejar la serie` ~29, `3.3`'s 44×44 close, the 60×34 toggle, `4.4`'s 40 px preset chips | six named controls across four screens | F0 · `f0-pressable-surface` | Decided: `req-touch-target` **goes red on day one and stays red**, and nobody grows a box to make it green. A red test naming six design decisions is the request's tracking mechanism |
| **DR-K3** | The same press spec, for the keypad specifically | `Keypad`, `KeypadKey` | F0 · `f0-keypad` | The source HTML's instant swap. The user is a nine-year-old pressing sixteen keys a minute, which is why the keypad gets its own row rather than inheriting DR-5's |

**B2 · One disabled treatment, drawn once.** DR-P6 is not a fifth request in this batch — it is the
observation that the other four are one request seen from four screens, and answering it answers
them. Hand the batch over as one brief: *what does a control look like when it is present and
unavailable?*

| DR | What the designer produces | Attaches to | First needed | What ships while it is open |
|---|---|---|---|---|
| **DR-K1** | The disabled key face | the item keypad's operator strip | F0 · `f0-keypad` | **[suggestion]** every key renders enabled and `a/b` is inert on the five single-slot families — the honest interim, and the one the strip's alternative (a shape that changes per family) is worse than. `components.md` R8 records why the strip is context-dependent at all |
| **DR-K2** | The submit arrow on an empty answer | the one key a child presses to commit | F0 · `f0-keypad` | **[suggestion]** the arrow renders enabled and a submit on an empty draft is a no-op — `teclados.md`:340 says the disabled visual *"no se muestra"*, so there is nothing to render |
| **DR-K4** | Illegal-digit feedback on a board with no submit key | `TecladoPuzzle`, the five boards | F6 · `f6-puzzles` | **[suggestion]** the illegal digit is refused silently. `components.md` R8 states the rule and no document draws its affordance; a grep for `ilegal` in this plan returns nothing, which is the gap |
| **DR-P4** | `4.4`'s hour card with the daily reminder off | `4.4 Notificaciones` | F7 · `f7-notifications` | **[suggestion]** the card is hidden rather than greyed, until DR-P6 says what grey means. `perfil-estados.md` §6 lists the disabled case as a hole; the digest draws the card always enabled |
| **DR-P6** | *The rule.* One treatment for present-and-unavailable, drawn once and reused by the four above | all four call sites | F0, with the rest of the batch | The four interims above, which is four different answers — exactly what the rule exists to prevent |

**B3 · The compliance surfaces.** Cutting the requirement is not available here; only drawing it or
not shipping is.

| DR | What the designer produces | Attaches to | First needed | What ships while it is open |
|---|---|---|---|---|
| **DR-7** | The neutral date entry, the consent screen, what a child sees when the flow routes them there, and how a tutor completes it | in front of `1.2` and in front of guest sync | Gate A → F1 · `req-age-gate`, `f1-schema-freeze` | Nothing user-facing: `players.age_band` is NOT NULL and the gate stands in front of every door that reaches the server, so **`1.2` is unreachable until this is drawn**. The band value set is `{under_13, 13_17, adult}` and the threshold is one named constant, so Gate A's answer is a one-line change (§4, `f3-auth-screens`). **AMENDED 2026-08-29 (ADR 0004):** there is no tutor-consent flow to draw and no tutor to complete it — the design request is now a **refusal** screen for an under-18, and it is one of the two questions ADR 0004 left open |
| **DR-8** | The deletion page's three states — requested · link expired · done — the email's es-MX copy, and the tone rule, because a child may read this page | `f3-deletion-web`'s published page, which is not an app screen and so no digest drew it | F3 · `f3-deletion-web` | The page's behaviour is already specified and tested — the enumeration-safe response is identical for an address with an account and one without. What is missing is its *appearance*. The copy is R3 content budget, not this change's estimate |
| **DR-9** | The runtime notification permission prompt | Android 13+ and iOS, in front of `4.4` | F7 · `f7-notifications` | The OS prompt, unframed. D21 makes the notifications locally scheduled with no push token, which removes the processor and the identifier but **not** the prompt |
| **DR-10** | Vertical room for `1.2`'s legal line — two 48 px hit boxes on a 12 px line sitting directly under the primary button | `1.2`, and the same rows on `4.7` | F3 · `req-legal-reachable`, carried early into F7's row | The line is reachable and cramped: `req-legal-reachable` ships, DR-6's red target test carries the geometry. **[suggestion]** giving the line its own row with 24 px above and below is the smallest change that fits |

**B4 · The offline story.** One coherent brief, not three: a pack that downloads, expires, and is
sometimes absent. `4.9 Sin conexión` is the only offline screen the corpus contains and it assumes
the pack already arrived.

| DR | What the designer produces | Attaches to | First needed | What ships while it is open |
|---|---|---|---|---|
| **DR-1** | The pack download: progress, failure, retry | `f2-app-shell`, ahead of `4.9` | F2 · `f2-app-shell` | The F2 pack is a JSON file in `assets/` and there is no download to draw. That is true for exactly as long as one pack ships — the request comes due with the second |
| **DR-2** | What a child sees when a pack expires | `expires_at`, `ARCHITECTURE.md`:197 | F2 · `f0-pack-contract` | The column exists and no surface reads it |
| **DR-3** | Offline with **no** pack — a fresh install on a plane | the one state where the app genuinely cannot proceed | F2 · `f2-app-shell` | Undefined, and this is the batch's real urgency: it is the first state a TestFlight build will hit and the only one with no fallback behind it |

**B5 · The screens the plan names and no document draws.**

| DR | What the designer produces | Attaches to | First needed | What ships while it is open |
|---|---|---|---|---|
| **DR-11** | Destinations for the three affordances: `Ver paso`, `Ayuda`, and the stats / *progreso* tab | `04 Error`, `4.2`, tab 3 of the nav bar | F2 · `f2-core-loop`; F7 · `f7-profile-settings`; F5 · `f5-skill-map` | Each affordance is **absent from the build until its destination exists, and is not cut** (Q12). The nav bar renders only tabs that have roots (D12), which is a rendering rule and not a scope decision. **Carries a warning into the drawing:** decision #5 forbids a leaderboard and the stats tab is the hole shaped exactly like one, so whatever is drawn there is own-progress only |
| **DR-12** | The settled / unsettled axis, drawn once and reused wherever a rating appears | every rating surface, from F3 | F3 · `f3-attempt-sync` | Nothing, and correctly: Q3 hides the rating in F2, which removes the only number a later sync could contradict, so F2 needs no marker. When sync disagrees **the server wins in silence** and the attempt is re-scored (Q6) |
| **DR-13** | The reduced F2 home | `Inicio actualizado`, minus the named subtractions | F2 · `f2-home-reduced` | A **named subset** of `Inicio actualizado` (D5), enumerated with a return phase per subtraction in §4, `f2-home-reduced` — which is the authority on the list. The subtraction is decided; the resulting screen is drawn nowhere |
| **DR-P1** | `4.1`'s identity row without a name — the email rises into the Darumadrop 34 slot, or the row keeps a hole | `4.1 Perfil` | F7 · `f3-profile-read`, `f7-profile-settings` | Q5 removed the greeting; **[suggestion]** the email takes the slot, which is what `4.1` greets with now. Either way it is a drawing call, not an implementation one |
| **DR-P2** | `4.5`'s three remaining controls redrawn, or removed on purpose | `4.5 Accesibilidad` | F7, and later — see the interim | v1 ships **one card**: the `Acierto` / `Se torció` preview and its legend. The three toggles leave with a phase each: `Reducir movimiento` acquires an effect at **F8**; `TAMAÑO DE TEXTO` and `Alto contraste` are **undated** (Q8 — a cut for lacking a *specification*, not a screen); `Modo daltonismo` has **no effect at all** while D6 holds, so redrawing it means first deciding what it would mean |
| **DR-P3** | `4.7` with neither the erasure card nor a drawn export state — and the export's own states, *requested / in progress / rate-limited* | `4.7 Datos y privacidad` | F7 · `f7-profile-settings` | Two legal rows. Q1 cut `Borrar mi historial`; `Pedir mi archivo` is recorded, not cut, and whether the ARCO *acceso* right obliges it at all is Gate A's, not this section's |
| **DR-P5** | The rest of `perfil-estados.md` §6: empty history on `4.1`, deletion in progress, after deletion, and loading and error **inside** settings | `4.1`–`4.7` | F7 · `f7-profile-settings`, `f3-profile-read` | Undefined. An account row that fails to load has no state today, which is the one in this row most likely to be reached by an ordinary user on an ordinary day |

### 8.3 Suggestions — the plan's own, and not what the design owes

These are separated deliberately. Everything in §8.2 is a hole the plan found in the design;
everything here is a proposal the plan is making. **A designer may decline any of them without
leaving a gap** — declining is itself a complete answer, which is not true of anything above.

| # | Suggestion | Where it came from | Why it is worth a decision rather than a shrug |
|---|---|---|---|
| **DR-K5** | Press-and-hold backspace to repeat | `teclados.md`:337, which warns explicitly against *assuming* it | Children clear four-character fields constantly. The cost of drawing it is small; the cost of assuming it and being wrong is a keypad that feels broken to the one user who holds the key down |
| **DR-P6** | One disabled treatment, drawn once — listed in B2 because it closes four requests, listed again here because **nobody asked for it** | the plan's own reading of DR-K1, DR-K2, DR-K4 and DR-P4 | Four separate answers produce four different greys, and greys are the kind of inconsistency nobody files a bug about |
| **DR-10 ·** *room* | Give `1.2`'s legal line its own row, 24 px above and below | `req-legal-reachable` needs two 48 px hit boxes on a 12 px line | It is the smallest change that satisfies a store-review item. The request (reachability) is real; the layout is the suggestion |
| **§5.1 ·** *the minimizing alternative* | Below the consent threshold, offer no account at all: the child keeps playing as a guest with sync off, so nothing leaves the device and there is nothing to consent to | put in front of Gate A alongside DR-7 | It is the cheapest possible compliance answer and it costs the under-13 cohort their rating and their cross-session history — **most of the product**. That makes it a product decision, not the plan's, which is exactly why it is written down rather than taken |
| **§4 ·** *the parental gate* | Ask Gate A, in the same session, whether leaving the app for a legal document needs a parental gate under Play's Families policy | `req-legal-reachable` opens a URL in the platform browser (`url_launcher`; the in-app `WebView` alternative was rejected as an unrestricted browser inside a child-directed app) | If it does, the gate is one sheet and the requirement does not change. Asking costs one line in a consult that is already scheduled |

### 8.4 The three affordances this section exists to keep

Recorded plainly, because an earlier draft of this plan **cut** them and a reader who saw that draft
needs to find the reversal without reconstructing it.

`Ver paso` (`04 Error`), `Ayuda` (`4.2`) and the stats / *progreso* tab were cut under the criterion
*"cut until a screen exists"*. That criterion was retired on 2026-08-15 by Ervin's instruction, and
**none of the three is cut.** All three are DR-11. Each is absent from the build only until its
destination is drawn, which is a **sequencing fact about the build order, not a decision about
scope** — and the difference matters, because a cut feature is one nobody plans for and a sequenced
one has a phase waiting for it. The three changes holding those phases are `f2-core-loop` (`04`
keeps room for the affordance), `f7-profile-settings` (the `Ayuda` row waits on DR-11 rather than
being removed) and `f5-skill-map` (D12's rule renders only tabs that have roots, so the tab appears
the moment one exists).

Two things travel with this and are **not** reversed by it. `2.6` and `3.4` remain a **numbering
gap** in the source documents — implied by row numbering, drawn nowhere, and not missing work.
`GET /v1/me/standing` (decision #5) still has no surface, is not scheduled, and stays out of v1: it
is an endpoint without an affordance, which is the opposite problem and not one a drawing solves.

And one thing that looks like this and is not: **Q8's two toggles are still cut**, and the criterion
change does not reach them. `Alto contraste` has no palette, no treatment and no specification
anywhere in the corpus — that is a cut for lacking a *specification*, which no amount of drawing
supplies, plus a real cost in the fixed heights that do not scale with type. The three controls
leaving `4.5` are DR-P2, each with the phase it would acquire an effect in.

---

*Nothing in §7 Q1, Q5 or Gate A is legal advice, and neither is anything in `f1-schema-freeze`,
`req-age-gate` or `f3-deletion-web` — the consent threshold, the age-band value set, the export
right and the retention figures are recorded there as **defaults in the plan's own idiom**, so that
Gate A's answer is a one-line change and not a redesign. The consult with someone specialized in
children's data protection belongs before F1, not before F2 — `players`, `age_band`, deletion
semantics and the retention policy are schema decisions made there.*
