## Why

**Nothing in `app/lib/` handles a gesture today.** The app has a brand layer, a character sheet and a
splash screen, and not one thing a finger can press.

The press rule is specified identically on roughly **50 elements across all six design documents** —
a pressed surface travels into its own shadow — which makes it the app's entire interaction language
rather than one widget's behaviour. Written once, it is right everywhere; written per screen, it
drifts by the third screen.

`theme.dart` already sets `NoSplash.splashFactory`, so the substrate is correct and this change is
not fighting Material.

**Phase: F0** (`ARCHITECTURE.md` §9). It blocks every interactive screen in the project.

## What Changes

- **`PressableSurface`** — the one primitive. A press translates the child by exactly the surface's
  own shadow offset and removes the shadow, so the surface appears to sink into the space the shadow
  occupied. No opacity change, no scale, no ripple.
- **`BrandButton`** — primary, secondary and text variants over that primitive.
- **`IconButtonTile`** — one 48×48 tile serving close, back, pause, undo, hint, pencil and gear.
  Seven controls, one widget.
- **A 48-pixel hit box on every pressable**, independent of what is painted. `BrandShape.minTouchTarget`
  stops being a constant nobody reads and becomes a constraint a test enforces.

## Capabilities

### New Capabilities
- `press-physics`: how a surface responds to being pressed, and the minimum size of anything that can
  be pressed.

### Modified Capabilities

None.

## Impact

- **New:** `app/lib/design/widgets/{pressable_surface,brand_button,icon_button_tile}.dart`.
- **New tests:** three files under `app/test/design/widgets/`.
- **`req-touch-target` goes red on day one for six controls**, and that is intended, not a defect to
  patch. Six targets in the corpus are drawn below 48 px — the reference sheet's 44×44 close, the
  60×34 toggle, `4.4`'s 40 px preset chips among them — and each is a design decision. They are
  logged as design request **DR-6**; the fix is a larger hit box behind unchanged paint, never a
  larger drawing.
- **No new dependency.** Gesture handling is `flutter/gestures`, already present.
- **Screens must register** in `app/test/design/screen_registry.dart` as they arrive; this change adds
  no screen.

## Non-goals

- **Motion.** No duration, no curve, no spring. The press is a discrete state change here; animation
  is F8.
- **Haptics.** Not specified in any document, and guessing one is worse than shipping none — see
  design D3.
- **Disabled states.** No disabled-key visual exists anywhere in the corpus; that is design request
  **DR-K1**, not a gap this change fills by invention.
- **The keypad.** `f0-keypad` consumes this primitive; it does not live here.

## What this builds on

- **`app/lib/design/tokens/brand_shape.dart`** — landed in `f0-token-scale`, and already carries
  `minTouchTarget`, `shadowTile` and the radii this change reads. Nothing new is named.
- **`app/lib/design/theme.dart`** — `NoSplash.splashFactory` is already set, so no ripple has to be
  suppressed per widget.
- **`app/test/architecture/no_geometry_literal_test.dart`** — landed in `f0-invariant-tests`; it
  scans `design/widgets/` for `Offset(`, so every offset this change uses must come from a token.
  That gate is why the press offsets are read and not typed.
