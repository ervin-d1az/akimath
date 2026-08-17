## Purpose

The loop a player actually performs: read a challenge, type an answer, learn whether it was right.
Every decision inside it is pure — what the keys become, and what the answer means — so the screen
holds an index and a draft and nothing else.

## ADDED Requirements

### Requirement: req-round-playable · A player can answer an item and see a verdict

The system SHALL render an item's prompt, accept an answer from the keypad, and return a verdict on
submission.

#### Scenario: A right answer is judged correct
- **WHEN** the answer matching the item is typed and submitted
- **THEN** the correct verdict is shown
  → `app/test/features/round/ui/round_screen_test.dart`

#### Scenario: A wrong answer is judged wrong
- **WHEN** any other answer is submitted
- **THEN** the wrong verdict is shown
  → `app/test/features/round/ui/round_screen_test.dart`

#### Scenario: An empty answer cannot be submitted
- **WHEN** submit is pressed with nothing typed
- **THEN** no verdict appears
  → `app/test/features/round/ui/round_screen_test.dart`

#### Scenario: The press that dismisses a verdict is not typed
- **WHEN** a key is pressed while a verdict is showing
- **THEN** the round advances and the next answer starts empty
  → `app/test/features/round/ui/round_screen_test.dart`

### Requirement: req-answer-draft-pure · What is typed becomes an answer by a pure rule

The system SHALL decide what a keypress does to the answer in a module that touches no widget, and
SHALL store a minus as U+2212.

#### Scenario: A draft is a value
- **WHEN** a character is typed onto a draft
- **THEN** a new draft is returned and the original is unchanged
  → `app/test/features/round/policy/answer_draft_test.dart`

#### Scenario: A malformed answer is refused
- **WHEN** a second decimal separator, or a minus after the first character, is typed
- **THEN** the draft is unchanged
  → `app/test/features/round/policy/answer_draft_test.dart`

#### Scenario: A draft has a ceiling
- **WHEN** more characters are typed than the maximum
- **THEN** the draft stops growing
  → `app/test/features/round/policy/answer_draft_test.dart`

### Requirement: req-grading-pure · A verdict is a function of the item and the answer

The system SHALL decide correctness in a pure module comparing canonical forms, reading no clock and
no network.

#### Scenario: Canonical forms are compared, not raw text
- **WHEN** an answer differs from the expected one only by surrounding whitespace or by U+002D
  against U+2212
- **THEN** it is judged correct
  → `app/test/features/round/policy/grading_test.dart`

### Requirement: req-no-debug-text-style · No screen ships Flutter's debug underline

The system SHALL fail the build when a registered screen renders text that inherits the
missing-`Material` fallback style, which paints a yellow double underline under every run.

#### Scenario: A screen with no Material ancestor
- **WHEN** a registered screen is pumped
- **THEN** no text inherits a decorated fallback style
  → `app/test/design/screen_text_style_test.dart`
