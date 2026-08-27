## Purpose

What the app shows when the answer is not the happy one.

## ADDED Requirements

### Requirement: req-every-answer-has-a-state · No case falls through

Every result a profile lookup can produce SHALL map to exactly one state.

#### Scenario: The five results

- **WHEN** each `MeResult` is mapped
- **THEN** it yields a distinct state — the switch is over a sealed union, so a
  sixth result is a compile error rather than a screen that renders nothing
  → `app/test/features/states/policy/account_state_test.dart`

#### Scenario: The state that is not a result

- **WHEN** there is no result yet
- **THEN** the state is `loading` — which is why this is a function and not a
  `switch` written inline on a screen, since the absent case is the one nobody
  writes
  → `app/test/features/states/policy/account_state_test.dart`

### Requirement: req-the-hue-says-whose-fault · Losing signal is nobody's mistake

The banner's variant SHALL follow whether the failure is ours.

#### Scenario: Offline

- **WHEN** nothing answered
- **THEN** it is a `notice`, not an `error` — *"Sin conexión no es un error del
  usuario: va en amarillo"*
  → `app/test/features/states/policy/account_state_test.dart`

#### Scenario: A broken answer or a refused session

- **WHEN** the server answered something unusable, or refused the token
- **THEN** it is an `error`
  → `app/test/features/states/policy/account_state_test.dart`

#### Scenario: Nothing ordinary is anybody's fault

- **WHEN** the state is none, loading, linked or noPlayer
- **THEN** no fault is assigned, and no banner is drawn — a banner on every
  state is a banner nobody reads
  → `app/test/features/states/policy/account_state_test.dart`

### Requirement: req-waiting-is-skeletal · No spinner, anywhere

Waiting SHALL be drawn as the shape of what is coming.

#### Scenario: The sweep

- **WHEN** every source file is scanned
- **THEN** none constructs a progress indicator, and `LoadingDots` is used only
  by the splash it was drawn for
  → `app/test/design/no_spinner_test.dart`

#### Scenario: Comments are not code

- **WHEN** a file explains in prose why not to use a spinner
- **THEN** the gate does not fire — its first version reported three files, two
  of them doc comments and one its own rule
  → `app/test/design/no_spinner_test.dart`
