# math-composition Specification

## Purpose
An arithmetic expression is laid out from injected font metrics by a module that touches no canvas,
and painted by an adapter beside it. Every number the app displays passes through one formatter that
holds the es-MX conventions, so a comma decimal separator and a real minus sign are properties of the
system rather than of whoever wrote the call site.

## Requirements

### Requirement: req-math-layout-pure · Expression layout is computed without a canvas

The system SHALL lay out an expression from injected font metrics, in a module that constructs no
`Path` and touches no `Canvas`.

#### Scenario: A nested fraction lays out from metrics alone
- **WHEN** `MathNode.layout(expression, metrics: MathMetrics.brand, size:, measure:)` is called for a
  fraction whose numerator is itself a fraction
- **THEN** it returns boxes whose baselines and bar positions are computed from the injected
  x-height, with no Flutter import in the module
  → `app/test/design/math/spec/math_node_test.dart`, `app/test/architecture/pure_boundary_test.dart`

#### Scenario: A token is laid out in the face it is painted in
- **WHEN** an expression mixes a numeral and an `=` set in a different face
- **THEN** each token's axis is computed from **that face's** x-height, and both land on the shared
  row axis
  → `app/test/design/math/spec/math_node_test.dart`

#### Scenario: The painted glyph lands on the computed baseline
- **WHEN** the adapter renders a laid-out numeral
- **THEN** the painted line box is the font's own ascent plus descent, so the baseline falls where
  the layout placed it rather than where a tightened line box would put it
  → `app/test/design/math/math_view_test.dart`

#### Scenario: The bar geometry scales with the numeral
- **WHEN** a fraction is laid out at 76, 46 and 22 px
- **THEN** the bar thickness is 6, 4 and 3 and the bar minimum width is 58, 36 and 26
  → `app/test/design/math/spec/fraction_metrics_test.dart`

#### Scenario: The layout module is a declared pure root
- **WHEN** `pure_boundary_test.dart` walks the import graph from `design/math/spec/`
- **THEN** the root reports a non-zero file count and no transitive import of `dart:ui`,
  `package:flutter/**` or any other Flutter library
  → `app/test/architecture/pure_boundary_test.dart`

### Requirement: req-fraction-stacked · A fraction is never rendered inline

The system SHALL stack a fraction over a horizontal rule and SHALL NOT emit a solidus form.

#### Scenario: The compositor is asked for three quarters
- **WHEN** a fraction is rendered
- **THEN** the painted output contains a numerator box above a rule above a denominator box, and no
  `/` glyph
  → `app/test/design/math/math_view_test.dart`

#### Scenario: The API offers no inline form to call
- **WHEN** the fraction node's public surface is enumerated
- **THEN** it exposes no variant, flag or parameter that renders numerator and denominator on one
  line
  → `app/test/design/math/spec/math_node_test.dart`

### Requirement: req-operator-token-styling · Operator styling is a property of the token

The system SHALL carry the typeface and tone of each operator on the token itself rather than
applying one global rule, and SHALL default to Darumadrop for operators and Plus Jakarta Sans 800
for `=`.

#### Scenario: An expression mixes operator faces
- **WHEN** an expression carrying `OperatorNode(face: MathFace.display)` and
  `OperatorNode(face: MathFace.textHeavy)` is laid out
- **THEN** each operator resolves its own face and tone, and neither is overridden by a document-wide
  setting
  → `app/test/design/math/spec/math_node_test.dart`

#### Scenario: The default is applied when a token names no face
- **WHEN** `OperatorNode.of('+')` and `OperatorNode.of('=')` are built without an explicit face
- **THEN** the operator resolves to `MathFace.display` (Darumadrop) and the `=` to
  `MathFace.textHeavy` (Plus Jakarta Sans 800)
  → `app/test/design/math/spec/math_node_test.dart`

#### Scenario: Tone is a role and carries no colour
- **WHEN** the tone type's members are enumerated
- **THEN** none of them exposes a `Color`, and the adapter is what resolves a role to a palette
  entry — the precedent `Verdict` set by carrying no `.color`
  → `app/test/design/math/spec/math_node_test.dart`

### Requirement: req-number-format · Number formatting preserves es-MX conventions exactly

The system SHALL format numbers through one pure module, `EsMxNumber`, with a comma decimal
separator, U+2212 for a leading minus, and **U+202F for every space it emits** — the thousands
separator, the space before a unit, and the spaces around a ratio slash or a dimensions cross alike.
A breaking space anywhere in a formatted value lets it wrap inside the pill or tile that holds it.

#### Scenario: A rating and a time are formatted
- **WHEN** `EsMxNumber.integer(1180)` and `EsMxNumber.seconds(4.2, places: 1)` are called
- **THEN** the results are `1 180` and `4,2 s`, and the thousands separator is not U+0020
  → `app/test/design/math/spec/es_mx_number_test.dart`

#### Scenario: A counter chip and a delta go through the same module
- **WHEN** `3 / 9` and a `−6` delta are formatted
- **THEN** `ratio` returns `3 / 9` with spaces around the slash and `deltaParts` returns a sign run
  and a digit run, so no caller composes a minus sign by hand
  → `app/test/design/math/spec/es_mx_number_test.dart`

#### Scenario: The minus sign is never a hyphen
- **WHEN** any negative value is formatted through any entry point on the module
- **THEN** the leading character is U+2212 and never U+002D
  → `app/test/design/math/spec/es_mx_number_test.dart`

#### Scenario: No formatted value can wrap mid-value
- **WHEN** every formatter on the module is called
- **THEN** none of their outputs contains U+0020
  → `app/test/design/math/spec/es_mx_number_test.dart`

### Requirement: req-row-spacing · Tokens on a row are separated

The system SHALL place a gap between adjacent tokens on a row, defaulting to a size-relative value
and overridable per row. Edge-to-edge placement makes the rules of two adjacent fractions read as
one continuous line through the operator between them.

#### Scenario: Two fractions either side of an operator
- **WHEN** a row of fraction, operator, fraction is rendered
- **THEN** the two rules are separated rather than touching
  → `app/test/design/math/math_view_test.dart`
