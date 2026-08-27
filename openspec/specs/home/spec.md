# home Specification

## Purpose
Somewhere to stand before a series: what today offers, how long the player has kept it up, and one
way in.

## Requirements

### Requirement: req-home-subset · The home offers today's series and nothing it cannot source

The system SHALL render only elements whose data exists in the current phase.

#### Scenario: F2 home with no server
- **WHEN** home is built against a local pack with no rating available
- **THEN** the Aki band, the bubble, the `RETO DEL DÍA` card, one primary button and the **streak**
  pill are present, and no rating pill, no skills row, no puzzle card and no bottom nav are in the
  tree
  → `app/test/features/home/ui/home_screen_test.dart`

#### Scenario: No placeholder stands in for the rating
- **WHEN** the home is rendered
- **THEN** no rating figure and no word naming one appears — an empty pill would be a figure sync
  could later contradict
  → `app/test/features/home/ui/home_screen_test.dart`

### Requirement: req-home-preview-composed · The card composes the item it previews

The system SHALL render the preview through the same compositor the round uses, not as text.

#### Scenario: The preview cannot drift from the item
- **WHEN** the `RETO DEL DÍA` card is rendered
- **THEN** it contains a composed expression and no solidus
  → `app/test/features/home/ui/home_screen_test.dart`

### Requirement: req-home-starts-a-session · A series is entered as a full-screen route

The system SHALL push the series as a route with no navigation affordance, leaving the home mounted
beneath it.

#### Scenario: The series covers the home
- **WHEN** the primary button is pressed
- **THEN** the round is shown, the home is no longer visible, and popping returns to it
  → `app/test/features/home/ui/home_route_test.dart`

### Requirement: req-home-loading-skeletal · The home's wait is skeletal

The system SHALL render skeletons shaped like the home while its pack loads, and no spinner.

#### Scenario: The pack has not resolved
- **WHEN** the home is entered before its data arrives
- **THEN** skeletons occupy the boxes the content will occupy, and no spinner and no `LoadingDots`
  is in the tree
  → `app/test/features/home/ui/home_route_test.dart`

### Requirement: req-pill-hugs · A pill is as wide as its content

The system SHALL size a stat pill to its content rather than to the width it is offered.

#### Scenario: A pill in a stretching column
- **WHEN** a pill is placed in a column that stretches its children
- **THEN** it stays narrow
  → `app/test/design/widgets/stat_pill_test.dart`

### Requirement: req-home-offers-the-puzzle · `PUZZLE DEL DÍA` returns

The home SHALL offer the day's puzzle when the pack carries one, and SHALL show nothing in its place
when the pack carries none.

#### Scenario: The pack carries a puzzle

- **WHEN** the home is drawn for a pack with at least one puzzle
- **THEN** a `PUZZLE DEL DÍA` card offers it, naming the kind rather than only the word "puzzle"
  → `app/test/features/home/ui/home_screen_test.dart`

#### Scenario: The pack carries none

- **WHEN** no puzzle is available
- **THEN** the card is absent rather than disabled, because a card that cannot be opened is a
  promise the screen cannot keep
  → `app/test/features/home/ui/home_screen_test.dart`

#### Scenario: The home still fits

- **WHEN** the home carries the puzzle card at text scale 1.3
- **THEN** nothing overflows
  → `app/test/design/screen_overflow_test.dart`

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
