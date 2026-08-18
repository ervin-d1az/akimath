## Why

Everything built so far is a component. **Nothing could be played.**

This is the first slice that joins them: an item is shown, an answer is typed, a verdict comes back.
It is the point at which `f1b-math-compositor`, `f0-keypad`, `f0-verdict`, `f0-pressable-surface`
and `f0-dashed-border` stop being a library and start being an app.

**Phase: F2.** Scoped deliberately below the plan's full `f2-core-loop` — see Non-goals.

## What Changes

- **`app/lib/content/model/`** — `Item` and its rendered `PromptToken`s as pure data, plus a
  hand-written `demoPack`. The prompt travels rendered (`ARCHITECTURE.md` §4); difficulty is the
  item's `ladderStep` and is never computed in Dart.
- **`app/lib/features/round/policy/`** — two pure modules. `AnswerDraft` decides what typed
  characters become; `grade` decides whether an answer is right.
- **`app/lib/features/round/ui/round_screen.dart`** — the screen.
- **`app/lib/main.dart`** — the home becomes the round instead of the character sheet.
- **`app/test/design/screen_text_style_test.dart`** — a new registry-driven gate, added because the
  first real screen shipped with Flutter's yellow debug underline under every run of text and
  nothing in the suite noticed.

## Capabilities

### New Capabilities
- `round-loop`: showing an item, accepting an answer, and returning a verdict.

## Impact

- **`features/*/policy/` and `content/model/` stop being absent.** Both were declared pure roots
  reporting *absent* since `f0-invariant-tests`; the boundary gate now covers 2 files in each. The
  expectation in `pure_boundary_test.dart` that asserted their absence flips to a presence check —
  which that test's own reason string predicted in as many words.
- **`screen_registry.dart`** gains the round, so it inherits the no-blur, overflow and text-style
  gates from one registration.
- **No new dependency.**

## Non-goals

- **The full `f2-core-loop`.** The plan's version covers `02 Reto activo`, `03 Acierto` and
  `04 Error` with stat tiles, a progress strip, streaks and a series. This slice is the loop's
  spine; those are screens it will grow into, and `f0-stat-readouts` is not built.
- **A real content pipeline.** `demoPack` is a fixture. `f1b-content-reader` reads the same `Item`
  type out of a bundled pack and `f1-5-pack-builder` generates it — when they land the *source*
  changes and the screen does not.
- **Navigation.** `f2-app-shell` owns it. The round is the home because it is the only thing to be.
- **Rating, streaks, sync.** No server exists.

## What this builds on

Everything F0 and F1b built: `MathView` renders the prompt, `Keypad` takes the input,
`CandySurface.borderDash` draws the focused slot, `VerdictRing` shows the result, `PressableSurface`
gives every key its travel and its 48 px target.
