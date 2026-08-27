# verdict-copy Specification

## Purpose
The words a verdict is announced with.

## Requirements

### Requirement: req-one-home-for-the-headlines · A key cannot teach a word no screen shows

The headline for each verdict SHALL come from one place, read by every screen that names it.

#### Scenario: The legend and the verdict screen agree

- **WHEN** `4.5`'s legend and `04 Error` both name the wrong verdict
- **THEN** they say the same word, because a key to a term the app never shows is worse than no
  key
  → `app/test/features/preferences/ui/preferences_screen_test.dart`

#### Scenario: Neither headline scolds

- **WHEN** either headline is read
- **THEN** it contains none of "incorrecto", "error", "fallaste" or "mal"
  → `app/test/design/widgets/spec/verdict_copy_test.dart`

### Requirement: req-the-legend-describes-the-shape · The key explains the mark

The legend's caption for each mark SHALL describe its outline, not its colour.

#### Scenario: Continuous and dashed

- **WHEN** the two captions are read
- **THEN** the solid mark is called *línea continua* and the dashed one *línea punteada*, and
  each matches the outline its verdict actually draws
  → `app/test/design/widgets/spec/verdict_copy_test.dart`

#### Scenario: No colour word

- **WHEN** either caption is read
- **THEN** it names no hue, because a reader who cannot separate green from coral still has to
  be able to use this legend — a caption reading "el aro verde" would be the one sentence on the
  screen that undoes the invariant the marks were designed around
  → `app/test/design/widgets/spec/verdict_copy_test.dart`

#### Scenario: No metaphor

- **WHEN** either caption is read
- **THEN** it uses neither *aro*, *cortado* nor *torció* — a dashed circle is not a cut one, and
  the ring is not a thing a player has been introduced to by name
  → `app/test/design/widgets/spec/verdict_copy_test.dart`
