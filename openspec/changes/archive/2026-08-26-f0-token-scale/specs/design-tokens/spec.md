## Purpose

The named palette, shape scale and type scale that every AkiMath screen reads from, together with
the gates that keep colour and shadow literals out of the rest of `app/lib/`. A widget asks this
capability for a role, a radius or a style; it never writes a hue, an offset or a font size of its
own.

## ADDED Requirements

### Requirement: req-palette-coverage · The palette covers every hue the design uses

The system SHALL expose a named token for every colour the design documents use, and no colour
literal SHALL exist outside `app/lib/design/tokens/`. The single carve-out is `Colors.transparent`,
used to switch Material's surface tinting off in `app/lib/design/theme.dart` (BRD-2b, verbatim in
`CLAUDE.md`).

#### Scenario: The quiet neutral has a name

- **WHEN** a widget needs the backspace-key fill or a skeleton block fill
- **THEN** `BrandColors.quiet` resolves to `#EAE6F0` and no other file in `app/lib/` contains that
  literal
  → `app/test/design/tokens/brand_colors_test.dart`, `app/test/architecture/no_color_literal_test.dart`

#### Scenario: The figure pink is distinct from the soft pink

- **WHEN** the hidden-operation machine body or a figurate dot is filled
- **THEN** `BrandColors.pinkFigure` resolves to `#FF9EC1` and is not equal to `BrandColors.pinkSoft`
  → `app/test/design/tokens/brand_colors_test.dart`

#### Scenario: The board hairline and the card rule are two tokens, not one alpha

- **WHEN** a board hairline and a card divider are drawn in the same file
- **THEN** `BrandColors.hairline` is ink at 18% and `BrandColors.rule` stays ink at 16%, the two are
  not equal, and both carry the ink RGB
  → `app/test/design/tokens/brand_colors_test.dart`

#### Scenario: Focus is an accent, not a verdict

- **WHEN** the role map is enumerated
- **THEN** `BrandColorRole.focus` resolves to `BrandColors.pink`, and pink still resolves to none of
  `error`, `success`, `action`
  → `app/test/design/tokens/brand_colors_test.dart`

### Requirement: req-shape-scale · The shape scale names the geometry the screens use

The system SHALL name the radii, border widths and shadow offsets that recur across the design
documents, so that no widget writes a geometry literal. The gate that enforces this scans for
`Offset(` under `app/lib/design/widgets/` and `app/lib/features/`, with comments stripped before
scanning. `app/lib/design/brand/` is out of scope: its `spec/` modules are geometry, and
micro-geometry belongs to the spec module that draws it rather than to the shape scale, which
governs widget surfaces.

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
authoritative on measurements (plan §5.3 D19) and `splash_screen.dart` predates it.

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
rather than adding new ones. Letter spacing SHALL be requested in em and resolved to logical pixels
against the style's own size, which is the convention `descriptor` already uses.

#### Scenario: An eyebrow at 10 px with 0.06em tracking

- **WHEN** `BrandText.eyebrow(size: 10, letterSpacing: 0.06)` is requested
- **THEN** it returns Plus Jakarta 800 at 10 px with 0.6 px tracking
  → `app/test/design/tokens/brand_typography_test.dart`

#### Scenario: A numeral style that does not lie about its name

- **WHEN** a keypad digit or a board digit is rendered
- **THEN** it reads `BrandText.numeral(29)` — Darumadrop 400 at `height: 1` — not
  `BrandText.sectionTitle(size: 29)`
  → `app/test/design/tokens/brand_typography_test.dart`
