## Purpose

What a series is: how long it runs, which items it draws, and what a player is shown when it is over
rather than being handed another item forever.

## ADDED Requirements

### Requirement: req-series-length · A series is five items and then it ends

The system SHALL play a fixed number of items and SHALL end rather than continuing, and the number
SHALL be five — `ARCHITECTURE.md` §9's own definition of the first playable build.

#### Scenario: The fifth item is answered

- **WHEN** the last item of a series is solved and its verdict acknowledged
- **THEN** the summary is shown, and no sixth item is offered
  → `app/test/features/round/ui/series_flow_test.dart`

#### Scenario: A series does not wrap

- **WHEN** a series runs to its end
- **THEN** the first item is not shown a second time, which is what the round did before this change
  → `app/test/features/round/ui/series_flow_test.dart`

### Requirement: req-series-plan · Which items a series draws is decided without a screen

The system SHALL choose a series' items with a pure function of the pack and SHALL choose the same
items for the same input.

#### Scenario: A pack larger than a series

- **WHEN** a plan is drawn from a pack of twenty items
- **THEN** it contains exactly five of them, all distinct, and every one comes from that pack
  → `app/test/features/round/policy/series_plan_test.dart`

#### Scenario: A pack smaller than a series

- **WHEN** a plan is drawn from a pack of three items
- **THEN** it contains those three and does not repeat one to reach five, because an item a player
  has just answered is not a new challenge
  → `app/test/features/round/policy/series_plan_test.dart`

#### Scenario: The same pack twice

- **WHEN** a plan is drawn twice from the same pack
- **THEN** it is the same plan, so what a player is about to be asked does not depend on when they
  were asked
  → `app/test/features/round/policy/series_plan_test.dart`

### Requirement: req-series-summary · The ending says how it went, and claims nothing it cannot

The system SHALL show, at the end of a series, how many of its items were answered correctly, the
time taken and the current streak, and SHALL show no rating and no rating change.

#### Scenario: A completed series

- **WHEN** the summary is shown after a series
- **THEN** it states how many of the five were right, the total time and the streak, and offers one
  way back to the home
  → `app/test/features/round/ui/series_summary_screen_test.dart`

#### Scenario: Nothing a later sync could contradict

- **WHEN** the summary is rendered
- **THEN** no rating, no rating change and no placeholder for either appears — F2 has no server, and
  a figure the server would later disagree with is worse than an absent one
  → `app/test/features/round/ui/series_summary_screen_test.dart`

#### Scenario: Every score from none to all

- **WHEN** a series ends with none, some or all of its items correct
- **THEN** each is stated plainly and none of them scolds
  → `app/test/features/round/ui/series_summary_screen_test.dart`
