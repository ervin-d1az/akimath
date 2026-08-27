# app-shell Specification

## Purpose
One frame for every screen: cream, a place for a banner, and a single rule about when navigation
exists. Loading is skeletal. A session takes the whole screen.

## Requirements

### Requirement: req-nav-staging · The app routes without a navigation bar until a second root exists

The system SHALL render no bottom navigation while fewer than two tab roots exist.

#### Scenario: One root draws no bar
- **WHEN** the shell is built with only the home root
- **THEN** no bar is built, and the builder that would build one is not called
  → `app/test/features/shell/ui/app_shell_test.dart`

#### Scenario: Two roots draw one
- **WHEN** a second root is registered
- **THEN** the bar is built with both tabs, in declaration order
  → `app/test/features/shell/ui/app_shell_test.dart`,
    `app/test/features/shell/policy/visible_tabs_test.dart`

### Requirement: req-fullscreen-session · A full-screen session hides the app frame

The system SHALL present a session as a route carrying no navigation affordance.

#### Scenario: A series is entered
- **WHEN** a session is pushed from a shell that is drawing a bar
- **THEN** the pushed route covers it and the bar is no longer visible
  → `app/test/features/shell/ui/app_shell_test.dart`

### Requirement: req-banner-glyph · A banner is never distinguished by hue alone

The system SHALL resolve every banner kind to a glyph as well as a tone, and SHALL carry no `Color`
on the resolved visual.

#### Scenario: The two kinds differ in greyscale
- **WHEN** an error banner and a notice banner are resolved
- **THEN** their glyphs differ, the notice carries wifi-off, and neither visual exposes a colour
  → `app/test/features/shell/policy/banner_visual_test.dart`

#### Scenario: A lost connection is nobody's fault
- **WHEN** the banner kinds are enumerated
- **THEN** there is no `offline` kind, because *sin conexión no es un error del usuario*
  → `app/test/features/shell/policy/banner_visual_test.dart`

### Requirement: req-skeleton-loading · Loading is skeletal, never a spinner

The system SHALL show content-shaped placeholders whose geometry matches the loaded layout, and
SHALL show no spinner.

#### Scenario: A placeholder occupies the box its content will occupy
- **WHEN** a skeleton stands in for a 220×52 box
- **THEN** it measures 220×52
  → `app/test/features/shell/ui/loading_skeleton_test.dart`

#### Scenario: No spinner reaches a loading state
- **WHEN** a loading layout is rendered
- **THEN** no `CircularProgressIndicator`, no `LinearProgressIndicator` and no `LoadingDots` is in
  the tree
  → `app/test/features/shell/ui/loading_skeleton_test.dart`

#### Scenario: A skeleton does not animate
- **WHEN** a frame is pumped
- **THEN** nothing has changed and no further frame is scheduled
  → `app/test/features/shell/ui/loading_skeleton_test.dart`

### Requirement: req-shell-draws-the-bar · The shell renders the bar it has always accepted

The shell SHALL render a bottom bar when `visibleTabs` returns more than one tab, and SHALL keep the
decision in the policy rather than in the widget.

#### Scenario: The shell is given roots and a bar builder

- **WHEN** two roots exist
- **THEN** the shell asks the policy, is handed two tabs, and draws the bar with them
  → `app/test/features/shell/ui/app_shell_test.dart`

#### Scenario: The shell is given one root

- **WHEN** one root exists
- **THEN** the shell draws no bar, and the builder is never called
  → `app/test/features/shell/ui/app_shell_test.dart`

#### Scenario: Content is not hidden behind the bar

- **WHEN** a root's content is as tall as the viewport allows
- **THEN** it ends above the bar rather than beneath it
  → `app/test/design/screen_overflow_test.dart`
