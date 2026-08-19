## Purpose

What the answer keypad may offer.

## ADDED Requirements

### Requirement: req-every-live-key-can-be-graded · No key is a trap

Every key the pad offers SHALL be able to appear in some answer the grader accepts.

#### Scenario: A key whose output is never gradable

- **WHEN** a key emits text no accepted answer can contain
- **THEN** it is drawn unavailable, because pressing it loses the item whatever was asked and
  nothing on the screen says so
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

#### Scenario: Position is part of the question

- **WHEN** a key is checked
- **THEN** it counts as gradable if it can appear anywhere in an accepted answer — unary minus
  goes in front and the fraction slash goes between, and a check that only tried one position
  would call the fraction key a trap
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

#### Scenario: The excluded keys are named, and re-checked

- **WHEN** the excluded set is compared against the canonicaliser
- **THEN** a key on the list that the grader has *started* accepting fails the gate, so growing
  an answer shape cannot leave a usable key disabled forever
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

### Requirement: req-an-operator-does-not-look-like-a-number · A face says what it does

No operator key SHALL draw a face a player would read as a digit.

#### Scenario: The square key

- **WHEN** the square key is drawn
- **THEN** its face is `x²` and not a bare `²`, which in the brand's numeral face reads as
  another digit 2 one row above the real one
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

#### Scenario: The negate key

- **WHEN** the negate key is drawn
- **THEN** its face is `−x`, as `TecladoReactivo` labels it
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

### Requirement: req-the-grid-is-the-designed-one · The strip is in the design's order

The item pad SHALL lay its sixteen keys out in the order the design document draws them.

#### Scenario: The transcribed grid

- **WHEN** the pad's keys are listed
- **THEN** they are `7 8 9 a/b`, `4 5 6 −x`, `1 2 3 x²`, `, 0 backspace submit`
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

#### Scenario: The usable operator is not buried

- **WHEN** operators are disabled
- **THEN** the strip's live key sits above them rather than beneath both
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`
