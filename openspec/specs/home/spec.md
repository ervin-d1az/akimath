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
