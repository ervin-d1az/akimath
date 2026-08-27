## ADDED Requirements

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
