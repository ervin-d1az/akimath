## Purpose

How a player moves between the screens they can stand on, and the rule that
decides whether a bottom bar is drawn at all.

## ADDED Requirements

### Requirement: req-nav-bar-follows-roots · The bar exists only when there is somewhere to go

The system SHALL draw a bottom navigation bar only when two or more tab roots exist, and SHALL
decide this from the roots themselves rather than from a flag.

#### Scenario: A second root arrives

- **WHEN** preferences becomes a root beside the home
- **THEN** the bar appears with both, in the order the design draws them, without the rule changing
  → `app/test/features/shell/ui/app_shell_test.dart`

#### Scenario: Only one root

- **WHEN** the app is built with the home alone
- **THEN** no bar is drawn, because a bar with one tab has nothing to switch to
  → `app/test/features/shell/policy/visible_tabs_test.dart`

### Requirement: req-nav-shows-where-you-are · The bar says which root you are on

The bar SHALL mark the selected tab distinguishably **without relying on hue**, and SHALL give every
destination a target no smaller than the minimum touch size.

#### Scenario: A tab is selected

- **WHEN** the player is on a root
- **THEN** that tab is marked by more than colour, so the mark survives deuteranopia
  → `app/test/features/shell/ui/nav_bar_test.dart`

#### Scenario: Every destination is reachable by thumb

- **WHEN** the bar is measured
- **THEN** each tab's tappable area is at least `BrandShape.minTouchTarget`
  → `app/test/features/shell/ui/nav_bar_test.dart`

#### Scenario: Switching roots

- **WHEN** a tab other than the current one is tapped
- **THEN** the app shows that root, and tapping the current one does nothing
  → `app/test/features/shell/ui/nav_bar_test.dart`

### Requirement: req-nav-splash-is-reachable · The splash is shown, not merely built

The system SHALL display the splash while startup work is outstanding, and SHALL leave it once that
work completes.

#### Scenario: A cold start

- **WHEN** the app launches
- **THEN** the splash is on screen while the stored state is read, and is replaced when it resolves
  → `app/test/main_startup_test.dart`

#### Scenario: The splash never becomes the app

- **WHEN** startup completes
- **THEN** no splash remains in the tree, so a failure to advance is a visible defect rather than a
  screen that looks deliberate
  → `app/test/main_startup_test.dart`
