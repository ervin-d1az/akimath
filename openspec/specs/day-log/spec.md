# day-log Specification

## Purpose
The app remembers which days the player practised, keeps only as many as a streak needs, and stores
a date rather than a moment.

## Requirements

### Requirement: req-day-log-days-not-moments · The log records days, never times of day

The system SHALL record the calendar day an attempt falls on and SHALL NOT store a time of day.

#### Scenario: Two attempts on one day
- **WHEN** two attempts on the same day are recorded
- **THEN** the log holds one entry
  → `app/test/features/home/policy/day_log_test.dart`

#### Scenario: The stored form carries no time
- **WHEN** a log holding an evening attempt is encoded
- **THEN** the encoded text is a date and contains no `:`
  → `app/test/features/home/policy/day_log_test.dart`

### Requirement: req-day-log-bounded · The log does not grow without limit

The system SHALL retain a bounded number of days, keeping the most recent.

#### Scenario: More days than the window
- **WHEN** more days are recorded than the log retains
- **THEN** the count stops at the window and the newest day is still present
  → `app/test/features/home/policy/day_log_test.dart`

### Requirement: req-day-log-survives-corruption · Unreadable storage costs the streak, never the launch

The system SHALL decode an unreadable log to an empty one and SHALL keep the entries it can read
from a partially unreadable one.

#### Scenario: The stored text is junk
- **WHEN** the log is decoded from text that is not a log
- **THEN** the result is an empty log and nothing throws
  → `app/test/features/home/policy/day_log_test.dart`

#### Scenario: A date that never existed
- **WHEN** an entry names an impossible date
- **THEN** it is skipped rather than rolled over into a real one
  → `app/test/features/home/policy/day_log_test.dart`

### Requirement: req-streak-earned · Playing raises the streak without a relaunch

The system SHALL record the day when an answer is submitted, whatever the verdict, and the home
SHALL re-read the log when a series ends.

#### Scenario: A series is played
- **WHEN** a player with yesterday recorded finishes a series and returns to the home
- **THEN** the streak reads two
  → `app/test/features/home/ui/home_route_test.dart`

#### Scenario: A wrong answer still counts the day
- **WHEN** the submitted answer is wrong
- **THEN** the day is recorded all the same
  → `app/test/features/home/ui/home_route_test.dart`

### Requirement: req-day-log-persists · The log survives the process that wrote it

The system SHALL keep the day log on the device, under a single key, so a streak earned in one launch
is still there in the next.

#### Scenario: A new store over the same storage
- **WHEN** one store records a day and a second store reads it
- **THEN** the day is there
  → `app/test/features/home/data/prefs_day_log_store_test.dart`

#### Scenario: A build that cannot write still reads what was written
- **WHEN** a build containing no write path launches after one that recorded a day
- **THEN** the streak reflects the recorded day
  → `openspec/changes/f2-day-log/evidence/launch-2-persisted.png`, and the two-launch record in
    `tasks.md` §3.5

#### Scenario: Storage that fails outright
- **WHEN** the underlying store throws on read or on write
- **THEN** neither call throws, the read reports an empty log, and the write still returns the
  session's own log
  → `app/test/features/home/data/prefs_day_log_store_test.dart`
