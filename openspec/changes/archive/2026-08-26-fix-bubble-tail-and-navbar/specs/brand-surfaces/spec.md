## Purpose

Two shared surfaces: what Aki says, and where you are.

## ADDED Requirements

### Requirement: req-the-tail-opens-into-the-bubble · One shape, not two

A speech bubble's tail SHALL share its interior with the bubble.

#### Scenario: The seam is erased first

- **WHEN** the tail is painted
- **THEN** the patch that removes the bubble's border across the mouth is the first thing drawn,
  because anything drawn before it would be erased too
  → `app/test/design/widgets/speech_bubble_test.dart`

#### Scenario: The patch clears the whole border

- **WHEN** the patch is measured
- **THEN** it reaches at least a full border-width above the mouth — a patch that removes most
  of a line leaves the hairline that made the tail look detached
  → `app/test/design/widgets/speech_bubble_test.dart`

#### Scenario: The sides survive it

- **WHEN** the patch is measured across
- **THEN** it stops short of both slanted sides, or the outline stops meeting the bubble's
  → `app/test/design/widgets/speech_bubble_test.dart`

#### Scenario: The top edge is not stroked

- **WHEN** the tail is painted
- **THEN** exactly one stroke is drawn and it is the last thing painted — stroking the mouth
  shut is what drew the line the patch then had to hide
  → `app/test/design/widgets/speech_bubble_test.dart`

### Requirement: req-the-nav-is-a-card · It floats, like everything else

The bottom navigation SHALL be a floating card, not a full-bleed strip.

#### Scenario: The app's own surface

- **WHEN** the bar is drawn
- **THEN** it carries the shared card radius and the app's most common hard shadow
  → `app/test/features/shell/ui/nav_bar_test.dart`

#### Scenario: Inset from three edges

- **WHEN** the bar is measured
- **THEN** the card sits inside its slot on the left, right and bottom
  → `app/test/features/shell/ui/nav_bar_test.dart`

### Requirement: req-the-current-tab-is-a-chip · Where you are, by shape

The current destination SHALL be marked by a chip, present or absent.

#### Scenario: Exactly one chip

- **WHEN** the bar is drawn
- **THEN** one tab carries a chip and the others do not — presence is the shape half of the
  distinction BRD-1 asks for, and ink against muted is only the hue half
  → `app/test/features/shell/ui/nav_bar_test.dart`

#### Scenario: It moves with the selection

- **WHEN** a different tab is current
- **THEN** the chip is over that tab's label, because a mark that never moved would satisfy the
  count above forever
  → `app/test/features/shell/ui/nav_bar_test.dart`

#### Scenario: It is the design's chip

- **WHEN** the chip is drawn
- **THEN** it is green with the shared 3 px border
  → `app/test/features/shell/ui/nav_bar_test.dart`
