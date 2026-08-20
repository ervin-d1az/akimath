## Purpose

Every icon in the app is path data in a pure module, painted by an adapter beside it, at whatever
size the caller asks for. No icon package enters the dependency list to supply them — and that is
enforced by a committed allowlist rather than by anyone remembering.

## ADDED Requirements

### Requirement: req-icon-spec · Icons are path data, painted by an adapter

The system SHALL hold every icon's geometry in a pure module and paint it from a separate adapter.

#### Scenario: The backspace glyph is one spec at two sizes
- **WHEN** the item keypad requests it at 24 px and the puzzle keypad at 23 px
- **THEN** both resolve to the same `BrandIconSpec` and differ only in rendered size
  → `app/test/design/icons/spec/icon_paths_test.dart`

#### Scenario: The spec carries its own stroke weight
- **WHEN** the submit arrow and the backspace glyph are compared
- **THEN** the submit arrow's stroke width is 3.2 and the backspace's is 2.6
  → `app/test/design/icons/spec/icon_paths_test.dart`

#### Scenario: The geometry module imports no Flutter library
- **WHEN** `pure_boundary_test.dart` walks the import graph from `design/icons/spec/`
- **THEN** the root reports a non-zero file count and no transitive import of `dart:ui`,
  `package:flutter/**` or any other Flutter library
  → `app/test/architecture/pure_boundary_test.dart`

### Requirement: req-icon-allowlist · The runtime dependency list is a committed allowlist

The system SHALL assert its runtime dependencies against a committed list, so that adding one is a
deliberate amendment to a test rather than a line in a manifest nobody reads.

#### Scenario: No icon dependency is added
- **WHEN** `app/pubspec.yaml` is read
- **THEN** its runtime dependencies are exactly `flutter`, `cupertino_icons` and `meta`
  → `app/test/architecture/dependency_allowlist_test.dart`

#### Scenario: An added dependency fails the build until the list is amended
- **WHEN** a package is added to `dependencies` without amending the allowlist
- **THEN** the test fails and names the package that was added
  → `app/test/architecture/dependency_allowlist_test.dart`
