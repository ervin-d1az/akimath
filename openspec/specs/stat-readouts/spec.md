# stat-readouts Specification

## Purpose
Every measured number the player reads, and every bar that shows progress, comes from one small set
of components — and none of them is ever handed a colour to decide meaning with.

## Requirements

### Requirement: req-meter-takes-a-level · The meter is handed a mastery level, never a colour

The system SHALL type `BaselineMeter`'s fill as a `MasteryLevel` and SHALL NOT accept a `Color`.

#### Scenario: The signature refuses a colour
- **WHEN** `BaselineMeter`'s constructor is enumerated
- **THEN** it takes a `MasteryLevel` and no parameter of type `Color`
  → `app/test/design/widgets/baseline_meter_test.dart`

#### Scenario: No widget decides a hue by comparison
- **WHEN** `app/lib/` is scanned for a colour chosen by a numeric comparison — the
  `pct >= 90 ? green : pink` shape
- **THEN** none is found
  → `app/test/architecture/no_hue_by_comparison_test.dart`

#### Scenario: The marker overhang is a function of track height
- **WHEN** meters are laid out at h14 and h16 with a baseline marker
- **THEN** the 6 px ink marker overhangs by ±4 and ±5 respectively, for every instance
  → `app/test/design/widgets/spec/meter_layout_test.dart`

### Requirement: req-stat-readouts · Stat tiles and pills ship the geometries the documents draw

The system SHALL render `StatTile` in three variants and `StatPill` in two sizes.

#### Scenario: The three tile clusters
- **WHEN** `raised`, `compact` and `flat` are built
- **THEN** they are r20 / shadow (3,5) / value 26, r18 / shadow (3,5) / value 24 and r16–18 / no
  shadow / value 21–24
  → `app/test/design/widgets/stat_tile_test.dart`

#### Scenario: The rating delta is two runs, not one span
- **WHEN** a `−6` delta is rendered
- **THEN** the sign is Plus Jakarta 800 15 and the digits are Darumadrop 22, baseline-aligned with a
  3 px gap, and the value is produced by `EsMxNumber.deltaParts`
  → `app/test/design/widgets/stat_tile_test.dart`

#### Scenario: The pill ships both sizes
- **WHEN** `StatPill`'s sizes are enumerated
- **THEN** `header` resolves h48 / r24 / border 3 / shadow (3,5), and `hero` resolves r22 /
  shadow (4,6) taking its height from the call site
  → `app/test/design/widgets/stat_pill_test.dart`

#### Scenario: The hero size carries the two screens that forced K8
- **WHEN** `StatPill` is built at `hero` with height 56 and a yellow background, and again at height
  64 with the default background
- **THEN** the first matches `4.12`'s streak badge and the second `0.6`'s rating chip, and neither
  screen holds a local pill composition
  → `app/test/design/widgets/stat_pill_test.dart`
