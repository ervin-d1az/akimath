## Purpose

An arithmetic expression is laid out from injected font metrics by a module that touches no canvas,
and painted by an adapter beside it. Every number the app displays passes through one formatter that
holds the es-MX conventions, so a comma decimal separator and a real minus sign are properties of the
system rather than of whoever wrote the call site.

## ADDED Requirements

### Requirement: req-math-layout-pure · Expression layout is computed without a canvas

The system SHALL lay out an expression from injected font metrics, in a module that constructs no
`Path` and touches no `Canvas`.

#### Scenario: A nested fraction lays out from metrics alone
- **WHEN** `MathNode.layout(expression, metrics: darumadropMetrics)` is called for a fraction whose
  numerator is itself a fraction
- **THEN** it returns boxes whose baselines and bar positions are computed from the injected
  x-height, with no Flutter import in the module
  → `app/test/design/math/spec/math_node_test.dart`, `app/test/architecture/pure_boundary_test.dart`

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
- **WHEN** an expression carrying `OperatorNode(face: darumadrop)` and `OperatorNode(face: jakarta800)`
  is laid out
- **THEN** each operator resolves its own face and tone, and neither is overridden by a document-wide
  setting
  → `app/test/design/math/spec/math_node_test.dart`

#### Scenario: The default is applied when a token names no face
- **WHEN** an operator token and an `=` token are built without an explicit face
- **THEN** the operator resolves to Darumadrop and the `=` to Plus Jakarta Sans 800
  → `app/test/design/math/spec/math_node_test.dart`

### Requirement: req-number-format · Number formatting preserves es-MX conventions exactly

The system SHALL format numbers through one pure module, `EsMxNumber`, with a comma decimal
separator, a U+202F thousands separator, and U+2212 for a leading minus.

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
