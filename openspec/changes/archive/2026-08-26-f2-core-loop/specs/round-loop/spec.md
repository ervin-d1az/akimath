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

### Requirement: req-quiet-timing · Time is measured and never displayed while solving

The system SHALL record elapsed time per item from an injected clock, SHALL render no timer while an
item is on screen, and SHALL show the recorded time on the verdict screen as a measurement.

#### Scenario: No clock is visible at any point
- **WHEN** the item screen and either verdict screen are rendered
- **THEN** no text matching a running clock appears, and the verdict's figure reads `4,2 s`
  → `app/test/features/round/ui/round_screen_test.dart`,
    `app/test/features/round/ui/verdict/verdict_screen_test.dart`

### Requirement: req-verdict-copy · A verdict names the reasoning, never the failure

The system SHALL NOT render the words *incorrecto*, *error*, *fallaste* or *mal* on either verdict
screen, and SHALL show Aki stooping rather than disappointed.

#### Scenario: Neither mood scolds
- **WHEN** each verdict screen is rendered
- **THEN** none of the four words appears, and the wrong screen still renders copy of its own
  → `app/test/features/round/ui/verdict/verdict_screen_test.dart`

#### Scenario: The wrong answer costs only the tail curl
- **WHEN** the wrong verdict is rendered
- **THEN** Aki is in the `slip` pose, whose curl is already growing back
  → `app/test/features/round/ui/verdict/verdict_screen_test.dart`

### Requirement: req-verdict-two-tiles · A verdict shows time and streak, and no rating

The system SHALL render exactly two stat tiles on a verdict screen — elapsed time and the local
streak — and SHALL render no rating and no placeholder for one while no server exists.

#### Scenario: Two tiles, and nothing sync can contradict
- **WHEN** either verdict screen is rendered
- **THEN** exactly two tiles appear, labelled TIEMPO and RACHA, and no rating figure is present
  → `app/test/features/round/ui/verdict/verdict_screen_test.dart`

### Requirement: req-error-band-overflow · Aki's error band does not clip her art

The system SHALL let the error pose overflow its band upward rather than clipping it.

#### Scenario: The error verdict renders whole
- **WHEN** the error verdict is pumped at 390×844
- **THEN** Aki's art renders at full width and no overflow is reported
  → `app/test/features/round/ui/verdict/verdict_screen_test.dart`,
    `app/test/design/screen_overflow_test.dart`

### Requirement: req-streak-local · The streak is a local calendar fact

The system SHALL compute the streak on the device from the days it recorded, taking today as an
argument, and a wrong answer SHALL NOT decrement it.

#### Scenario: Yesterday still counts
- **WHEN** the player practised yesterday but has not yet practised today
- **THEN** the streak is unbroken
  → `app/test/features/round/policy/streak_policy_test.dart`

#### Scenario: The policy reads no clock of its own
- **WHEN** the same attempts are counted against two different todays
- **THEN** the two results differ
  → `app/test/features/round/policy/streak_policy_test.dart`
