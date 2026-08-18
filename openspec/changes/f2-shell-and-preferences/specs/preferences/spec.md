## Purpose

What a player can see and change about their own use of the app with no account,
and — as importantly — what this screen may not claim while there is no server
to compute it.

## ADDED Requirements

### Requirement: req-prefs-local-facts-only · Nothing here waits on a server

The preferences root SHALL show only facts the device computes, and SHALL show no rating, accuracy,
mean time or attempt history while those have no source.

#### Scenario: The screen is inspected for figures it cannot source

- **WHEN** every number on the screen is read
- **THEN** each one comes from `StreakPolicy` or `DayLogStore`, and no rating appears
  → `app/test/features/preferences/ui/preferences_screen_test.dart`

#### Scenario: A player who has never played

- **WHEN** no day has been recorded
- **THEN** the screen still renders, showing zero rather than an empty space or a dash
  → `app/test/features/preferences/ui/preferences_screen_test.dart`

### Requirement: req-prefs-verdict-legend · The verdict legend is the one card v1 ships

The preferences root SHALL show the `Acierto` and `Se torció` marks together with what each means, so
a player can learn the pair somewhere other than mid-round.

#### Scenario: Both verdicts are shown side by side

- **WHEN** the legend is drawn
- **THEN** both marks appear with their labels, and they differ by **shape** and not only by hue
  → `app/test/features/preferences/ui/preferences_screen_test.dart`

#### Scenario: The copy does not scold

- **WHEN** the legend's copy is read
- **THEN** it names neither failure nor blame, the same rule the verdict screens are held to
  → `app/test/features/preferences/ui/preferences_screen_test.dart`

### Requirement: req-prefs-deferred-controls-are-absent · A control with no effect is not drawn

The system SHALL NOT draw a setting it cannot honour.

#### Scenario: The deferred toggles

- **WHEN** the screen is inspected
- **THEN** no reduce-motion, text-size, high-contrast or colour-blind toggle appears, because each
  either has no effect yet or no specification, and a switch that changes nothing is worse than an
  absent one
  → `app/test/features/preferences/ui/preferences_screen_test.dart`
