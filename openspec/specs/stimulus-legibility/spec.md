# stimulus-legibility Specification

## Purpose
What a stimulus may draw between two numbers, and what it may not: a glyph that sits
between them reads as a relation whether or not one was meant, so a mark that states something
false about the pair is a defect in the item rather than a detail of its typography.

## Requirements

### Requirement: req-nothing-between-numbers-reads-as-a-relation · A glyph must not state something false

A glyph drawn between two numerals SHALL NOT be a character a reader would take as an arithmetic
relation.

#### Scenario: The mapping glyph

- **WHEN** the glyph meaning "becomes" is drawn
- **THEN** it is not `›`, `‹`, `>`, `<`, `=`, `≥` or `≤`, because between two numerals each of
  those states something, and `2 › 4` states something false
  → `app/test/design/icons/brand_icon_test.dart`

#### Scenario: The function machine

- **WHEN** a worked pair is drawn
- **THEN** an arrow joins them, not a chevron
  → `app/test/features/round/ui/stimulus/hidden_operation_view_test.dart`

#### Scenario: The analogy

- **WHEN** a pair is drawn either side of `como`
- **THEN** an arrow joins them, not a chevron
  → `app/test/features/round/ui/stimulus/analogy_view_test.dart`

#### Scenario: A chevron is still a chevron where it means one

- **WHEN** the home draws the affordance on a puzzle card
- **THEN** it is still `›`, because there it means "this opens something" and sits beside no
  number at all
  → `app/test/design/icons/brand_icon_test.dart`
