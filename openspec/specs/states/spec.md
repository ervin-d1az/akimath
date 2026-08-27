# states Specification

## Purpose
TBD - created by archiving change f7-estados-de-racha. Update Purpose after archive.

## Requirements

### Requirement: The streak has a closed set of states, decided purely

The app SHALL derive what the streak is doing from the recorded days and one
moment, with no clock read, no storage access and no widget.

#### Scenario: A live run with today already recorded is steady

- **WHEN** the log holds today and the days before it
- **THEN** the state is `steady` and neither screen is shown

#### Scenario: A live run with nothing today, late enough, is at risk

- **WHEN** the log holds yesterday but not today, and the moment is at or after
  the hour the policy names
- **THEN** the state is `atRisk`

#### Scenario: A live run with nothing today, early in the day, is not yet at risk

- **WHEN** the log holds yesterday but not today, and the moment is before that
  hour
- **THEN** the state is `steady` — the day is not gone, and saying so before it
  is would be nagging rather than help

#### Scenario: A run that ended before yesterday is broken

- **WHEN** the most recent recorded day is older than yesterday
- **THEN** the state is `broken`

#### Scenario: A player who has never recorded a day is in neither state

- **WHEN** the log is empty
- **THEN** the state is `none`, and no streak screen is reachable — there is no
  run to be at risk and none to have lost

#### Scenario: A day recorded after the moment does not mint a run

- **WHEN** the log holds a day later than the moment given
- **THEN** that day is ignored, the same normalisation `streakLength` applies —
  a device clock that jumped forward and back must not create a streak

### Requirement: The countdown is a duration to local midnight

The app SHALL compute the time left in the day by calendar arithmetic on the
local day, never by subtracting a fixed twenty-four hours.

#### Scenario: Mid-evening leaves the rest of the day

- **WHEN** the moment is 20:14 local
- **THEN** the duration is 3 hours 46 minutes

#### Scenario: The boundary is the next local midnight

- **WHEN** the moment is one minute before local midnight
- **THEN** the duration is one minute, and never a negative value or a full day

#### Scenario: A short local day is still measured to its own midnight

- **WHEN** the day is 23 hours long because of a daylight-saving transition
- **THEN** the duration still ends at that day's own midnight, because the day
  after is constructed from its calendar components and not from a `Duration`

### Requirement: The run that ended is read from the same log

The app SHALL report the length of the most recent completed run, so `4.13`
prints a fact rather than a remembered number.

#### Scenario: A thirteen-day run that ended two days ago reads thirteen

- **WHEN** the log holds thirteen consecutive days ending three days before the
  moment
- **THEN** the broken run's length is 13

#### Scenario: The new run's day number is one and is not the streak

- **WHEN** the streak is broken and the player has not solved today
- **THEN** `streakLength` is 0 and the value the screen draws for today is 1,
  because they are different quantities: one counts days earned, the other names
  the day the new run is on

### Requirement: Both states are reachable from the app's entry

The app SHALL route to the streak screens before the home, and a test SHALL walk
to each from a seeded log — a state with no route into it is decoration.

#### Scenario: A late launch with a live run and nothing solved opens the risk screen

- **WHEN** the app opens, the log holds yesterday, and the hour is late
- **THEN** `4.12 Racha en riesgo` is shown, carrying the run's length and the
  time left

#### Scenario: The risk screen leads back into a challenge

- **WHEN** the player takes its primary action
- **THEN** the round opens, and solving it records the day, which is what makes
  the state `steady` on the next read

#### Scenario: The risk screen can be left without solving

- **WHEN** the player takes its secondary action
- **THEN** the home is shown, and the state is not recorded as handled — the day
  is still at risk, because nothing about it changed

#### Scenario: A launch after a broken run opens the lost screen once

- **WHEN** the app opens and the run ended before yesterday
- **THEN** `4.13 Racha perdida` is shown, carrying the broken run's length
  against today's `1`

#### Scenario: The lost screen is not shown twice in one day

- **WHEN** the player has already seen it today
- **THEN** the home opens directly — it is annotated *"se pasa la página"*, and
  a page turned twice is a page that was not turned

### Requirement: Neither screen prints a figure the device cannot compute

Every number on both screens SHALL come from the recorded days and the moment.
Where the design draws one the device cannot produce, the app SHALL say the true
half rather than approximate the whole.

#### Scenario: No rating appears on the lost screen

- **WHEN** `4.13` is drawn
- **THEN** its reassurance names what survived without a number, because rating
  is F4 and `GET /me/standing` answers 501 — the same reading that keeps a
  rating off the verdict screens

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
