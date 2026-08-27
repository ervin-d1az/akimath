## Purpose

A dashed outline is the shape half of BRD-1 — the encoding that survives deuteranopia when green and
coral collapse into each other. Its segmentation is arithmetic in a module that touches no canvas;
the painter beside it strokes what that module returns. And because moving a border into a painter
would otherwise carry it outside the no-blur gate's reach, the gate is widened in the same change.

## ADDED Requirements

### Requirement: req-dash-spec · Dash patterns are computed as data

The system SHALL compute dash segmentation in a module that touches no `Canvas`.

#### Scenario: A pattern that does not divide the perimeter evenly
- **WHEN** `DashSpec(on: 9, off: 9).segments(pathLength: 100)` is requested
- **THEN** it returns segments covering the full length with the final segment truncated, never
  overrunning
  → `app/test/design/painting/spec/dash_spec_test.dart`

#### Scenario: The three patterns the documents use produce their stated segment counts
- **WHEN** the KenKen (`6 4`), Killer (`2 5`) and locked-edge (`9 9`) patterns are segmented over a
  100 px path
- **THEN** the counts are 10, 15 and 6 respectively, and the Killer pattern reports a round cap
  → `app/test/design/painting/spec/dash_spec_test.dart`

#### Scenario: The segmentation module imports no Flutter library
- **WHEN** `pure_boundary_test.dart` walks the import graph from `design/painting/spec/`
- **THEN** the root reports a non-zero file count and no transitive import of `dart:ui`,
  `package:flutter/**` or any other Flutter library
  → `app/test/architecture/pure_boundary_test.dart`

### Requirement: req-dashed-outline · A dashed outline paints around a rounded rectangle

The system SHALL draw a dashed border on a `CandySurface` with a caller-supplied colour, width and
pattern.

#### Scenario: The focused answer slot
- **WHEN** an answer slot is focused
- **THEN** its border is 3 px, `BrandColors.pink`, dashed, radius 12, and no solid border is painted
  → `app/test/design/painting/dashed_border_test.dart`

#### Scenario: A cage outline is inset inside the hairline it sits on
- **WHEN** a KenKen cage and a Killer cage are painted over the same cell block
- **THEN** the KenKen outline is 2.5 px pink, rx 10, inset 5 px, and the Killer outline is rx 9,
  inset 6 px, and neither overlaps the 1.5 px hairline beneath it
  → `app/test/design/painting/dashed_border_test.dart`

### Requirement: req-no-blur-painters · The no-blur gate covers painters, not only decorations

The system SHALL assert the absence of `BackdropFilter` and of any non-zero `MaskFilter` in the
pumped tree, in addition to the four assertions it makes today.

#### Scenario: A painter that blurs
- **WHEN** a screen paints with a blurred `MaskFilter`
- **THEN** `no_blurred_shadow_test.dart` fails
  → `app/test/design/no_blurred_shadow_test.dart`

#### Scenario: The widened gate still covers every registered screen
- **WHEN** the gate runs
- **THEN** it reports the number of screens it walked, and fails at zero
  → `app/test/design/no_blurred_shadow_test.dart`, `app/test/design/screen_registry.dart`
