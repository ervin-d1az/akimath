## Purpose

What the answer keypad may offer, once the item pad stops drawing two keys no answer can contain.

## ADDED Requirements

### Requirement: req-a-cell-need-not-be-a-key · A grid can hold a hole

A layout SHALL be able to declare a cell that holds no key, and SHALL express it as a type rather
than as a null.

#### Scenario: An empty cell is not a nullable key

- **WHEN** the item layout's cells are enumerated
- **THEN** each is either a key or an empty cell, as a sealed type — the same construction the
  file already uses for `KeyFace`, so "no key here" and "a key with nothing set" are not two
  representations of one thing
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

#### Scenario: The row keeps its tracks

- **WHEN** a pad with an empty cell is laid out
- **THEN** the row still has as many tracks as the layout has columns, and every remaining key
  keeps the width and position a four-column grid gives it — the pad does not reflow around the
  hole
  → `app/test/design/widgets/keypad_test.dart`

#### Scenario: There is nothing to press in an empty cell

- **WHEN** an empty cell is tapped
- **THEN** nothing is reported to the caller, nothing travels, and no pressable surface is in the
  tree at that position — an empty cell is not a disabled key
  → `app/test/design/widgets/keypad_test.dart`

## MODIFIED Requirements

### Requirement: req-keypad-layout-pure · A layout is data, not a widget

The system SHALL declare the three layouts as pure constants — the cells, their key ids, faces, and
the text each key emits — in a module that touches no `Canvas` and no widget.

#### Scenario: The three layouts are the three the design draws
- **WHEN** `KeypadLayout.item`, `.puzzle` and `.otp` are enumerated
- **THEN** `item` is a four-column grid of fourteen keys and two empty cells in calculator order
  ending `0 ⌫ ➜`, `puzzle` is 5×2 in **reading** order with digits 1–9, no `0` and no submit, and
  `otp` is 3×4 ending `⌫ 0 ↵`
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

#### Scenario: The codepoint contract is typed once
- **WHEN** the union of key ids across the three layouts is enumerated
- **THEN** the negate key emits U+2212 (never U+002D), no layout declares an id outside that union,
  and the union names no id no layout declares — while U+00B2 and U+002C stay transcribed on the
  record of the keys the pad does not offer, so the codepoints survive the keys leaving the grid
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

#### Scenario: A key face is not a nullable string
- **WHEN** the `a/b` key, the `7` key and the backspace key are read
- **THEN** their faces are a fraction face, a text face and an icon face respectively, and no face
  is expressed as a `String?` that is null for the icons
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

### Requirement: req-every-live-key-can-be-graded · No key is a trap

Every key the pad offers SHALL be able to appear in some answer the grader accepts.

#### Scenario: A key whose output is never gradable

- **WHEN** a pad declares a key emitting text no accepted answer can contain
- **THEN** the gate fails, and the remedy is that the key is not on the pad — not that it is drawn
  disabled, because a disabled key says *not on this item* and no item can ever enable this one
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

#### Scenario: Position is part of the question

- **WHEN** a key is checked
- **THEN** it counts as gradable if it can appear anywhere in an accepted answer — unary minus
  goes in front and the fraction slash goes between, and a check that only tried one position
  would call the fraction key a trap
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

#### Scenario: The excluded keys are named, and re-checked

- **WHEN** the record of keys the pad does not offer is compared against the canonicaliser
- **THEN** a key on it that the grader has *started* accepting fails the gate, so growing an answer
  shape cannot leave a usable key off the pad forever — which is why the record keeps each key
  whole rather than emptying when the key leaves the grid
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

#### Scenario: The gate cannot pass without checking anything

- **WHEN** the gate runs
- **THEN** it reports how many keys it swept and how many it refused, and fails at zero swept —
  the same shape as the colour-literal and touch-target sweeps, because a loop over an empty list
  passes without asserting anything
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

### Requirement: req-an-operator-does-not-look-like-a-number · A face says what it does

No operator key SHALL draw a face a player would read as a digit.

#### Scenario: The negate key

- **WHEN** the negate key is drawn
- **THEN** its face is `−x`, as `TecladoReactivo` labels it
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

#### Scenario: The square key

- **WHEN** the square key is looked for
- **THEN** it is on no pad — the face `x²` was the fix while it was drawn, and the requirement it
  earned is checked against every operator key that remains, none of whose text faces is a digit
  or a lone superscript
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

### Requirement: req-the-grid-is-the-designed-one · The strip is in the design's order

The item pad SHALL lay its cells out in the order the design document draws them.

#### Scenario: The transcribed grid

- **WHEN** the pad's cells are listed
- **THEN** they are `7 8 9 a/b`, `4 5 6 −x`, `1 2 3 ·`, `· 0 backspace submit`, where `·` is an
  empty cell — every key keeps the position the design draws it in
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`

#### Scenario: The usable operator is not buried

- **WHEN** the fourth column is read top to bottom
- **THEN** it is `a/b`, `−x` and an empty cell, in that order — the two a player can use sit above
  the hole rather than beneath it, which is the same reading that put the strip in the design's
  order while a disabled key was still drawn there
  → `app/test/design/widgets/spec/keypad_gradable_test.dart`
