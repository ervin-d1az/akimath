# onboarding Specification

## Purpose
A first launch explains what the app is and teaches how an answer is typed, then gets out of the way
permanently.

## Requirements

### Requirement: req-first-run · The first run reaches a playable item without an account

The system SHALL take a first-launch user from the welcome screen to a solved item with no
registration, no network call and no calibration.

#### Scenario: A fresh install
- **WHEN** the primary action on `0.2` is pressed
- **THEN** `0.3` is shown, and on submit the app continues to the home
  → `app/test/features/onboarding/onboarding_flow_test.dart`

#### Scenario: No account is asked for and no calibration is offered
- **WHEN** the first-run path is walked end to end
- **THEN** no field asks for an email or a password, and no calibration screen is reachable
  → `app/test/features/onboarding/onboarding_flow_test.dart`

### Requirement: req-first-run-once · The first run happens once

The system SHALL show the onboarding only when it has not been completed, and SHALL record its
completion so a later launch goes straight to the home.

#### Scenario: The second launch
- **WHEN** the app launches after the onboarding has been completed
- **THEN** the home is shown and no welcome screen appears
  → `app/test/features/onboarding/data/onboarding_store_test.dart`,
    `app/test/features/onboarding/onboarding_flow_test.dart`

#### Scenario: Storage that cannot be read
- **WHEN** the completion flag cannot be read
- **THEN** the onboarding is shown rather than the launch failing
  → `app/test/features/onboarding/data/onboarding_store_test.dart`

### Requirement: req-teaching-item-unrated · The teaching item measures nothing

The system SHALL use a fixed item on `0.3`, drawn from no pack and contributing to no rating or
streak.

#### Scenario: The teaching item is not a pack fetch
- **WHEN** `0.3` is shown
- **THEN** its item is the fixed teaching item and no pack is read
  → `app/test/features/onboarding/ui/first_item_screen_test.dart`

### Requirement: req-aki-absent-teaching · Aki does not appear on the teaching item

The system SHALL keep Aki off `0.3`, as it keeps her off every screen where the learner is solving.

#### Scenario: The teaching item is on screen
- **WHEN** `0.3` is rendered
- **THEN** no `Aki` and no `SpeechBubble` is in the tree
  → `app/test/features/onboarding/ui/first_item_screen_test.dart`
