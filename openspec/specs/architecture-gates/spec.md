# architecture-gates Specification

## Purpose
The executable form of this repository's structural invariants: the import ceiling that keeps pure
policy free of Flutter, clocks and randomness; the acyclicity of the feature graph, which Dart
itself never reports; and the design-viewport budget every screen has to fit inside. Prose
invariants erode; these are the ones that fail the build instead.

## Requirements

### Requirement: req-pure-boundary · The pure boundary is enforced by a test, not by prose

The system SHALL fail the build when a file under `features/*/policy/`, `design/**/spec/` or
`content/model/` imports Flutter, reads a clock, or reads randomness — resolving repo-local
directives to their **transitive closure over `import` ∪ `export`**, stopping at `dart:` and
third-party `package:` URIs.

#### Scenario: The token barrel is caught transitively
- **WHEN** a `policy/` file imports `design/tokens/tokens.dart`
- **THEN** the test fails, naming the barrel and the `package:flutter/painting.dart` it re-exports
  → `app/test/architecture/pure_boundary_test.dart`

#### Scenario: The closure follows exports, not only imports
- **WHEN** the resolver walks `tokens.dart`, whose three directives are all `export` and whose own
  imports are none
- **THEN** it still reaches `brand_typography.dart` and reports the violation — a one-hop resolver,
  and any resolver that follows `import` alone, reports zero
  → `app/test/architecture/pure_boundary_test.dart`

#### Scenario: An ambient clock is caught
- **WHEN** a `policy/` file contains `DateTime.now()` or `Random(`
- **THEN** the test fails, naming the file and line
  → `app/test/architecture/pure_boundary_test.dart`

#### Scenario: A commented-out import is not a violation
- **WHEN** a `policy/` file's only mention of `package:flutter/material.dart` is inside a `//` line
  comment or a `/* */` block comment
- **THEN** the test reports no violation, because comments are stripped before directives are read
  → `app/test/architecture/pure_boundary_test.dart`

#### Scenario: The gate is not vacuously green
- **WHEN** the roots are enumerated
- **THEN** the test reports the count of files it scanned and fails if that count is zero for a root
  that exists on disk
  → `app/test/architecture/pure_boundary_test.dart`

### Requirement: req-acyclic-features · Feature barrels do not form a cycle

The system SHALL fail when the same closure finds a cycle among `features/*/<feature>.dart`, because
Dart compiles import cycles without complaint and §2.5's acyclicity rule has no other enforcement.

#### Scenario: Two features import each other's barrel
- **WHEN** `home` imports `shell/shell.dart` while `shell` imports `home/home.dart`
- **THEN** the test fails, printing the cycle
  → `app/test/architecture/pure_boundary_test.dart`

### Requirement: req-screen-overflow · Screens do not overflow at the design viewport

The system SHALL pump every screen at 390×844 and at 390×844 with `textScaler` 1.3, and SHALL fail
on any render overflow.

#### Scenario: A screen that fits at 1.0 and not at 1.3
- **WHEN** a screen whose content measures 803 px in 838 px is pumped at scale 1.3
- **THEN** the test fails with the overflowing widget named
  → `app/test/design/screen_overflow_test.dart`
