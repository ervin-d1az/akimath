## Purpose

A pressed surface travels into its own shadow. That single rule is the app's interaction language,
specified identically on roughly fifty elements across the design corpus, and it is enforced here
once so that no screen restates it. Everything a finger can reach clears 48 logical pixels whatever
its paint says.

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

#### Scenario: A press applies no effect the rule does not name
- **WHEN** any pressable is pressed
- **THEN** its opacity, its scale and its splash factory are unchanged from the unpressed build
  → `app/test/design/widgets/pressable_surface_test.dart`

### Requirement: req-press-visible · A pressable with no shadow declares how it answers a press

The system SHALL require a surface built without a shadow to name a press treatment explicitly, so
that a control which cannot travel cannot silently ship with no response at all.

#### Scenario: A shadowless surface is built without naming a treatment
- **WHEN** a `PressableSurface` is constructed with `shadow: null` and no press treatment
- **THEN** construction fails rather than producing a control that does nothing visible when pressed
  → `app/test/design/widgets/pressable_surface_test.dart`

### Requirement: req-touch-target · Every interactive target clears 48 logical pixels

The system SHALL give every pressable a hit box of at least `BrandShape.minTouchTarget` in both
dimensions, independent of its painted size.

#### Scenario: A tertiary text action is smaller than its hit box
- **WHEN** `BrandButton.text` renders "Dejar la serie" at its drawn ~29 px height
- **THEN** its hit-test area measures at least 48×48
  → `app/test/design/widgets/brand_button_test.dart`

#### Scenario: Growing the hit box does not grow the paint
- **WHEN** the same tertiary action is measured for painted height and for hit-test height
- **THEN** the painted height is unchanged from its drawn size while the hit box clears 48
  → `app/test/design/widgets/brand_button_test.dart`

### Requirement: req-icon-button-tile · The icon tile is one widget, not seven

The system SHALL render close, back, pause, undo, hint, pencil and gear as one 48×48 tile — r16,
shadow (3,4), optional toggled fill — built on `PressableSurface`.

#### Scenario: The pencil tile toggles its fill and nothing else
- **WHEN** `IconButtonTile` is built toggled and untoggled
- **THEN** the fill is `#FFD447` and `BrandColors.surface` respectively, and the geometry, the press
  travel and the hit box are identical in both
  → `app/test/design/widgets/icon_button_tile_test.dart`
