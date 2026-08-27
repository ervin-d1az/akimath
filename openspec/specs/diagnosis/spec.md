# diagnosis Specification

## Purpose
What a player is told when their answer is wrong, with no server.

## Requirements

### Requirement: req-a-wrong-answer-gets-steps · The screen always has something to say

A wrong answer SHALL produce steps to show, whether or not a distractor anticipated it.

#### Scenario: An anticipated wrong answer

- **WHEN** the answer matches a distractor the item carries
- **THEN** that misconception's steps are shown, because a player who subtracted in the wrong
  order and one who mistyped should not get the same screen
  → `app/test/features/round/policy/diagnose_test.dart`

#### Scenario: An answer nothing anticipated

- **WHEN** no distractor matches
- **THEN** the pack's fallback steps are shown, because this is the common case — the shipped
  pack carries distractors for a handful of items — and an empty diagnosis would leave the
  screen exactly as bare as it is today
  → `app/test/features/round/policy/diagnose_test.dart`

#### Scenario: An item carrying no distractors at all

- **WHEN** the item has no distractor table
- **THEN** the fallback is used rather than nothing
  → `app/test/features/round/policy/diagnose_test.dart`

### Requirement: req-the-match-is-canonical · How it was typed does not matter

The typed answer SHALL be canonicalised before it is compared, and the distractor's key SHALL be
required to be storage-canonical at load.

#### Scenario: The keypad's minus and the author's

- **WHEN** a player types `−9` with the keypad's U+2212 and the pack keys the distractor by the
  ASCII `-9` an author typed
- **THEN** it matches, because learner mode folds the one to the other — without it every
  distractor on a negative answer is dead
  → `app/test/features/round/policy/diagnose_test.dart`

#### Scenario: A key that is not storage-canonical

- **WHEN** the pack keys a distractor by a form storage mode refuses
- **THEN** the pack is refused at load, naming the item — rather than the lookup quietly
  canonicalising it, which would be an identity nothing can observe for every key that *is*
  canonical
  → `app/test/content/pack_reader_test.dart`

### Requirement: req-the-right-answer-is-never-diagnosed · Nothing to explain

A correct answer SHALL produce no diagnosis.

#### Scenario: The answer is right

- **WHEN** the answer is correct
- **THEN** no steps are produced, and `03 Acierto` is unchanged
  → `app/test/features/round/policy/diagnose_test.dart`

#### Scenario: A distractor keyed by the item's own answer

- **WHEN** a pack keys a distractor by the correct answer
- **THEN** the pack is refused where it is read, because a distractor explaining the right
  answer away is the leak the frozen format's D3 exists to prevent
  → `app/test/content/pack_reader_test.dart`

### Requirement: req-the-copy-is-carried-once · A map, not seventy copies

The pack SHALL carry each misconception's copy once, referenced by id.

#### Scenario: Two items sharing a misconception

- **WHEN** two items name the same misconception
- **THEN** the copy appears once in the pack
  → `app/test/content/pack_reader_test.dart`

#### Scenario: An id with no copy behind it

- **WHEN** an item names a misconception the pack does not define
- **THEN** the pack is refused where it is read, rather than showing an empty screen later
  → `app/test/content/pack_reader_test.dart`

### Requirement: req-the-error-screen-shows-them · The steps reach the player

`04 Error` SHALL show the steps, and SHALL fit at `textScaler` 1.3 with the most the format
admits.

#### Scenario: The steps are drawn

- **WHEN** the error screen is shown with a diagnosis
- **THEN** its steps appear
  → `app/test/features/round/ui/verdict/verdict_screen_test.dart`

#### Scenario: The most steps a diagnosis may carry

- **WHEN** the screen is registered with the longest copy the schema admits
- **THEN** it fits 390×844 at 1.0 and 1.3, because a registry entry built without a diagnosis
  would keep the gate green while the shipped screen overflowed
  → `app/test/design/screen_overflow_test.dart`

#### Scenario: The copy still does not scold

- **WHEN** any diagnosis is shown
- **THEN** none of the forbidden words appears, the same scan `04 Error` already passes
  → `app/test/features/round/ui/verdict/verdict_screen_test.dart`
