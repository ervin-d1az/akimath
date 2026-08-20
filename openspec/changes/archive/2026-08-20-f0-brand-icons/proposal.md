## Why

Almost every screen in the corpus carries at least one stroke icon, and the app has none. About
**21 glyphs** are needed — chevron-left, chevron-right, gear, check, alert, wifi-off, flame,
arrow-right, arrow-down, arrow-up, backspace, submit arrow, pause, undo, hint, pencil, X, padlock,
the KenKen mark, four nav glyphs and the 60×60 server mark.

The obvious move is an icon package, and it is the wrong one here. The audience includes children
under 13, so `CLAUDE.md`'s first constraint applies to every dependency; and the design's glyphs carry
their own stroke weights — the submit arrow at 3.2, the backspace at 2.6 — which no general icon set
reproduces. Transcribing 21 paths costs less than fighting a package that draws them almost right.

**Phase: F0** (`ARCHITECTURE.md` §9). It blocks almost every screen.

## What Changes

- **`app/lib/design/icons/spec/icon_paths.dart`** — every glyph's geometry as pure data, following
  the `design/brand/spec/` precedent already on disk. Path data is transcribed **verbatim** from the
  design digests, not redrawn by eye.
- **`app/lib/design/icons/brand_icon.dart`** — the adapter that paints it. One widget, any glyph, any
  size.
- **Each spec carries its own stroke weight**, because the design assigns them per glyph rather than
  globally.
- **`app/test/architecture/dependency_allowlist_test.dart`** — a committed allowlist of runtime
  dependencies. It is not really about icons: it is the gate that makes DEP-1 a red build.

## Capabilities

### New Capabilities
- `icon-set`: the app's stroke icons, their geometry, their per-glyph stroke weights, and the rule
  that no icon package is added to obtain them.

### Modified Capabilities

None.

## Impact

- **New:** `app/lib/design/icons/spec/icon_paths.dart`, `app/lib/design/icons/brand_icon.dart`.
- **New tests:** `app/test/design/icons/spec/icon_paths_test.dart`,
  `app/test/architecture/dependency_allowlist_test.dart`.
- **`app/lib/design/icons/spec/` becomes a declared pure root** in `pure_boundary_test.dart`.
- **No dependency is added** — that is the point of one of the three scenarios. Runtime dependencies
  stay exactly `flutter`, `cupertino_icons` and `meta`.
- **The allowlist test constrains every future change**: any change that adds a dependency must amend
  this test *and* carry the `CLAUDE.md`:9 phones-home audit in the same change. One such change is
  already scheduled — `f8-motion`'s Rive.

## Non-goals

- **Aki herself and the wordmark.** They already exist under `design/brand/spec/` and are not touched.
- **Icon colour.** `BrandIcon` takes a colour from the caller; it holds no palette. Colours come from
  `BrandColors` at the call site, per the no-colour-literal gate.
- **Animated or state-carrying icons.** A glyph is geometry. Toggled *backgrounds* belong to
  `IconButtonTile` in `f0-pressable-surface`.
- **Redrawing anything.** Where a digest gives path data, it is transcribed. Where it does not, the
  glyph waits rather than being invented.

## What this builds on

- **`app/lib/design/brand/spec/`** versus the painter beside it — the exact precedent this change
  copies, and the one `CLAUDE.md`'s architecture rule names.
- **`app/lib/design/tokens/`** — landed in `f0-token-scale`; sizes and colours are read from it.
- **`app/test/architecture/pure_boundary_test.dart`** — landed in `f0-invariant-tests`; adding the
  new spec root makes the split a red build rather than a habit.
- **`app/pubspec.yaml`** — today's runtime dependency list is already exactly the three the allowlist
  will freeze, so the gate starts green and stays honest.
