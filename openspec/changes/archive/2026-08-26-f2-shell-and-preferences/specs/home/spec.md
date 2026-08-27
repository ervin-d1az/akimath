## ADDED Requirements

### Requirement: req-home-shows-the-week · The streak is legible, not a bare number

The home SHALL label the streak and SHALL show the last seven days as marks, so a player can see
which days they played rather than being told a total they must trust.

#### Scenario: A streak of several days

- **WHEN** the player has played some of the last seven days
- **THEN** the strip marks exactly those days, ends on today, and the played and unplayed marks
  differ by **shape** and not only by hue
  → `app/test/features/home/ui/home_screen_test.dart`

#### Scenario: A player who has never played

- **WHEN** no day has been recorded
- **THEN** the strip draws seven unplayed marks and the label reads zero, rather than the band
  disappearing and the layout moving
  → `app/test/features/home/ui/home_screen_test.dart`

#### Scenario: The strip is a week, whatever the streak

- **WHEN** the streak is longer than seven days
- **THEN** seven marks are drawn and the number carries the rest, because a strip that grew would
  reflow the screen every day
  → `app/test/features/home/ui/home_screen_test.dart`

### Requirement: req-home-shows-the-mix · The home says what today holds

The home SHALL name the stimulus families the next series will draw, taken from the same plan that
serves it.

#### Scenario: Today's families are listed

- **WHEN** the home is drawn for a pack whose next series mixes families
- **THEN** each family in that series is named once, in the order it will be met
  → `app/test/features/home/ui/home_screen_test.dart`

#### Scenario: The list comes from the plan, not from a guess

- **WHEN** the series plan changes what it would serve
- **THEN** the row changes with it, because both read `seriesPlan` rather than the row describing
  the pack in general
  → `app/test/features/home/ui/home_screen_test.dart`

#### Scenario: The row survives a narrow screen and large text

- **WHEN** the home is drawn at the design viewport with text scaled to 1.3
- **THEN** the row reflows rather than overflowing
  → `app/test/design/screen_overflow_test.dart`

### Requirement: req-home-preview-draws-any-family · The preview never crashes on the day's item

The home's preview SHALL render whichever family the day's item belongs to.

#### Scenario: The day's item is not an expression

- **WHEN** the previewed item is a series, a grid, an analogy, a machine or a figurate
- **THEN** the home draws it, rather than throwing because only expressions were anticipated
  → `app/test/features/home/ui/home_screen_test.dart`
