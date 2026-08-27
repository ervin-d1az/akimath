# verdict-encoding Specification

## Purpose
Right and wrong are told apart by shape before they are told apart by colour. The type that carries
a verdict exposes an outline and a glyph and no colour at all, so a call site physically cannot
communicate a result by hue alone.

## Requirements

### Requirement: req-verdict-type · A verdict cannot be communicated by hue

The system SHALL expose a `Verdict` type that carries an outline style and a glyph, and SHALL NOT
expose a colour on it.

#### Scenario: The type has no colour accessor
- **WHEN** `Verdict`'s public surface is enumerated
- **THEN** it exposes `outline` and `glyph` and no member returns a `Color`
  → `app/test/design/widgets/spec/verdict_test.dart`

#### Scenario: Success and error differ in shape
- **WHEN** `Verdict.correct` and `Verdict.wrong` are compared
- **THEN** their outline styles differ (solid vs dashed) and their glyphs differ (check vs alert)
  → `app/test/design/widgets/spec/verdict_test.dart`

#### Scenario: The paint adapter differs in greyscale
- **WHEN** the ring adapter is asked to paint `Verdict.correct` and `Verdict.wrong` at the same size
  with colour stripped
- **THEN** the two outputs differ in stroke pattern and in glyph, and neither is distinguishable by
  fill alone
  → `app/test/design/widgets/spec/verdict_test.dart`

#### Scenario: The glyph is never optional
- **WHEN** a verdict is rendered
- **THEN** a glyph is present, because the outline is a channel a widget may already have spent and
  the glyph is the one that cannot be preempted
  → `app/test/design/widgets/spec/verdict_test.dart`
