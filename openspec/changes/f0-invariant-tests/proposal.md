## Why

Three of the four gates in `docs/IMPLEMENTATION-PLAN.md` §1.3 stop short of the work that is
about to land. `app/test/design/no_blurred_shadow_test.dart` pumps at **2400×4000**, so **no test
in this repository can go red on a 390×844 overflow** — and `04 Error` already measures ~803 px of
content in 838 px. The `policy/` import ceiling in §2.2 exists only as prose, and its worst trap —
`design/tokens/tokens.dart` re-exporting `brand_typography.dart`, which imports
`package:flutter/painting.dart` — is invisible at the call site and invisible to a one-hop scan.
Dart compiles import cycles without complaint, so §2.5's acyclicity rule has no enforcement at all.

Now, because the surface is 18 Dart files and ~50 screens are coming. Risk R5 in the plan is
precisely the observation that prose invariants erode under agents; PROC-6 says a lesson that lives
only in prose gets relearned the hard way.

This change belongs to **phase F0** of `ARCHITECTURE.md` §9 (scaffolding). Per §5.4 of the plan it
is **first** in the wave, not "any time": it creates `app/test/architecture/`, which four other F0
changes already name a test file under; `f0-dashed-border` amends its no-blur gate (D22); and the
overflow gate reaches every screen change in the document through §4's per-change definition of
done. It has no upstream of its own, so being first costs nothing.

## What Changes

- **New `app/test/architecture/`** — the directory the plan's later F0 changes already reference.
- **A pure import-graph resolver** (`app/test/architecture/import_graph.dart`): directive parsing
  over comment-stripped source, transitive closure over the union of `import` **and** `export`
  directives restricted to repo-local URIs, cycle detection, and a textual ambient-access scan. It
  takes a `Map<uri, source>` and returns violations; it opens no file. PURE-1.
- **A thin filesystem adapter** (`app/test/architecture/source_tree.dart`) that enumerates the roots
  under `app/lib/` and hands the resolver a map. PURE-2 — it translates and decides nothing.
- **`app/test/architecture/pure_boundary_test.dart`** — the gate. It fails when a file under
  `features/*/policy/`, `design/**/spec/` or `content/model/` reaches Flutter, `dart:io`,
  `dart:async` or a non-`package:meta` third-party package through that closure; when it reads an
  ambient clock, randomness or `Platform`; and when two feature barrels form a cycle. It reports the
  count of files scanned per root and fails if a root that exists on disk contributed zero.
- **`app/test/design/screen_overflow_test.dart`** — every registered screen pumped at 390×844 at
  `textScaler` 1.0 and 1.3, failing on any render overflow.
- **`app/test/design/screen_registry.dart`** — one list of the screens under test, shared by the
  overflow gate and by `no_blurred_shadow_test.dart`, so a new screen is registered once instead of
  twice. This collapses points 1 and 2 of §4's definition of done into one step; the deviation and
  its alternative are recorded in `design.md`.
- **`app/test/design/no_blurred_shadow_test.dart` is edited** to read that registry. Its assertions
  and its 2400×4000 pump are unchanged — **BREAKING for nothing**; it is a mechanical substitution
  of the hand-written `screens` map.
- Possibly **one product-code edit**: if `SplashScreen` overflows at `textScaler` 1.3, this change
  fixes the screen. That is the first real defect the gate catches and it is not exempted away. See
  `design.md` D-6 and the task list.

## Non-goals

- **`req-no-blur-painters` is not here.** Extending the no-blur gate to `CustomPainter` lands in
  `f0-dashed-border`, in the same merge as `CandySurface.borderDash` — plan D22. Splitting them
  would leave the invariant silently uncovering the components that carry BRD-1's shape encoding.
- **No `policy/`, `content/model/` or feature barrel is created.** The gate tolerates a root that
  does not exist yet; the scenarios that need one feed a synthetic graph to the resolver. Creating
  `features/home/home.dart` and `features/shell/shell.dart` importing each other would be an
  intentionally broken build and an ordering edge into F2.
- **No body-level `async` / `await` / `Future<` check.** `dart:async` stays on the forbidden-import
  list because §2.2 puts it there and it is free, but it bans nothing useful — `Future` and `Stream`
  come from `dart:core`. Building an untested body scan is worse than naming the gap.
- **No screen beyond what exists** enters the registry. The item screens, onboarding and the rest
  register themselves in their own changes, which is what §4's definition of done is for.
- **No analyzer plugin, no new dependency.** DEP-1, and the alternative is recorded in `design.md`.
- **No Dart mutation harness.** PROC-5 Tier 1b on the Dart side stays a falsification step.
- **No new CI job.** `.github/workflows/ci.yml`'s `dart` job already runs `flutter test`; these are
  tests, so they are already gated by the hook and by CI.
- **No golden or screenshot testing.** The overflow gate asserts the absence of a render overflow,
  not pixels.

## What this builds on

Brownfield, with the precedents on disk:

- `app/test/design/no_blurred_shadow_test.dart` — the existing screen walk, its hand-maintained
  `screens` map (lines 13-17) and its `_pumpLarge` helper (lines 65-74).
- `app/lib/design/tokens/tokens.dart` — three `export` directives, **no import at all**; the export
  edge to `app/lib/design/tokens/brand_typography.dart:1` is the real closure case scenario 2 walks.
- `app/lib/design/brand/spec/aki_spec.dart` and `brand_shapes.dart` — the only files under an
  existing pure root today, and the ones that must stay green.
- `app/lib/features/splash/splash_screen.dart` and
  `app/lib/features/character_sheet/character_sheet_screen.dart` — the three registered screens.
- `.claude/hooks/verify-gate.sh` and `.github/workflows/ci.yml` — both already run `flutter test`,
  so nothing has to be wired for these gates to block a commit.

## Capabilities

### New Capabilities

- `architecture-gates`: the executable form of the plan's structural invariants — the `policy/`
  import ceiling, feature-barrel acyclicity, and the design-viewport overflow budget. Behaviour of
  the build, not of the app: what the repository refuses to compile past.

### Modified Capabilities

None. `openspec/specs/` is empty; this is the first capability.

## Impact

- **Affected code:** `app/test/architecture/` (new, three files), `app/test/design/` (one new gate,
  one new registry, one edited test). `app/lib/features/splash/splash_screen.dart` only if the
  overflow gate goes red on it.
- **Affected process:** §4's per-change definition of done becomes enforceable — a new screen that
  is not registered is a screen with no overflow coverage, and the registry is the one place to add
  it. Every later change that writes a `policy/` inherits `pure_boundary_test.dart`.
- **Dependencies:** none added. `flutter_test` and `dart:io` are already available in the test
  environment (DEP-1 does not apply — nothing ships to a device).
- **Blocks:** `f0-dashed-border` (D22), `f1b-math-compositor` and every change that writes a
  `policy/`, and every screen change in the document.
- **Evidence expected:** Tier 1 (`flutter analyze --fatal-infos`, `flutter test` with counts).
  Tier 1b by falsification per PROC-5, because the resolver is pure logic — a green closure walk
  that would stay green with the closure disabled is exactly the vacuity this change exists to
  prevent.
