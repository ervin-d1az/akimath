## Purpose

Numeric entry is the app's own, never the platform's. Three layouts exist as data, one key widget
renders all three, and the codepoints they emit are declared once so a minus sign cannot become a
hyphen in one feature and not another.

## ADDED Requirements

### Requirement: req-keypad-layout-pure · A layout is data, not a widget

The system SHALL declare the three layouts as pure constants — key ids, faces, and the text each key
emits — in a module that touches no `Canvas` and no widget.

#### Scenario: The three layouts are the three the design draws
- **WHEN** `KeypadLayout.item`, `.puzzle` and `.otp` are enumerated
- **THEN** `item` is 4×4 in calculator order ending `, 0 ⌫ ➜`, `puzzle` is 5×2 in **reading** order
  with digits 1–9, no `0` and no submit, and `otp` is 3×4 ending `⌫ 0 ↵`
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

#### Scenario: The codepoint contract is typed once
- **WHEN** the union of key ids across the three layouts is enumerated
- **THEN** the negate key emits U+2212 (never U+002D), the square key U+00B2, the decimal key
  U+002C, and no layout declares an id outside that union
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

#### Scenario: A key face is not a nullable string
- **WHEN** the `a/b` key, the `7` key and the backspace key are read
- **THEN** their faces are a fraction face, a text face and an icon face respectively, and no face
  is expressed as a `String?` that is null for the icons
  → `app/test/design/widgets/spec/keypad_layout_test.dart`

### Requirement: req-keypad-widget · One key widget renders every layout

The system SHALL render any layout through one key widget, and SHALL hold no answer rule.

#### Scenario: Item and puzzle keys are the same widget at two sizes
- **WHEN** the item layout and the puzzle layout are built
- **THEN** the keys are h62 gap 10 and h58 gap 9, both border 3 / radius 18 / shadow (3,5), and both
  render the same backspace glyph at 24 and 23
  → `app/test/design/widgets/keypad_test.dart`

#### Scenario: The keypad clears the touch minimum on a narrow device
- **WHEN** each layout is laid out at 320 logical pixels wide
- **THEN** every key measures at least 48×48
  → `app/test/design/widgets/keypad_test.dart`

#### Scenario: The system keyboard never appears
- **WHEN** a keypad is mounted
- **THEN** no `EditableText` and no `TextField` is in the tree
  → `app/test/design/widgets/keypad_test.dart`

#### Scenario: A press reports the key and nothing more
- **WHEN** a digit key is pressed
- **THEN** the keypad reports that key's id to its caller and forms no answer of its own
  → `app/test/design/widgets/keypad_test.dart`
