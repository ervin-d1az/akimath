import 'dart:convert';
import 'dart:io';

import 'package:akimath_app/content/model/arithmetic_glyphs.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frozen schema, read from the artifact rather than restated here.
const String _stimulusSchema = '../contract/stimulus.schema.json';

List<String> _frozenOperators() {
  final File file = File(_stimulusSchema);
  final Map<String, dynamic> schema =
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final Map<String, dynamic> arithmetic =
      schema['arithmetic'] as Map<String, dynamic>;
  final Map<String, dynamic> properties =
      arithmetic['properties'] as Map<String, dynamic>;
  final Map<String, dynamic> operator =
      properties['operator'] as Map<String, dynamic>;
  return (operator['enum'] as List<dynamic>).cast<String>();
}

/// **One vocabulary for a drawn operator.**
///
/// Two readers turn content into the marks a prompt draws — `stimulus_reader`
/// for the frozen `{left, operator, right}` payload and `Pack.fromJson` for
/// the authored token list — and they used to answer *which marks may be
/// drawn* differently, because the authored one asked the compositor instead
/// of asking the content. These pin the relationship the fix rests on, not the
/// spelling of either constant.
void main() {
  group('the frozen names and the drawn marks are one statement', () {
    test('every operator the contract froze has a glyph, and no other does',
        () {
      final List<String> frozen = _frozenOperators();

      expect(
        operatorGlyphs.keys.toSet(),
        frozen.toSet(),
        reason: 'the schema froze $frozen; the map names '
            '${operatorGlyphs.keys.toList()}',
      );
      expect(frozen, isNotEmpty, reason: 'the schema was read but held no '
          'operator enum, so this test asserted nothing');
    });

    test('the drawn vocabulary is the glyphs plus the equals sign', () {
      // Derived rather than restated: this is the assertion that fails if
      // someone re-lists the set by hand and lets the two drift apart again.
      expect(
        arithmeticGlyphs,
        <String>{...operatorGlyphs.values, '='},
      );
      expect(arithmeticGlyphs, hasLength(operatorGlyphs.length + 1));
    });

    test('subtraction is named with a hyphen and drawn with a minus sign', () {
      // The one place the two halves deliberately disagree. U+002D is the
      // contract's name for the operation; U+2212 is the mark. A screen reader
      // says the first as "hyphen" and the second as "minus", which is the
      // same argument `math_node.dart` makes for not writing `×` as `x`.
      expect(glyphForOperator('-'), '−');
      expect(glyphForOperator('-'), isNot('-'));
      expect(operatorGlyphs.keys, contains('-'));
    });

    test('the hyphen is a name only, and is never a mark that may be drawn',
        () {
      // The defect this file exists to close: the authored reader accepted
      // U+002D, so the same subtraction drew a hyphen from the bundled pack
      // and a minus sign after a round trip through the server.
      expect(arithmeticGlyphs, isNot(contains('-')));
      expect(arithmeticGlyphs, contains('−'));
    });

    test('the vocabulary cannot be widened by whoever imports it', () {
      // A top-level `final` hands out the live set, and four features import
      // content/. A closed vocabulary an importer can `add` to is not closed.
      expect(
        () => arithmeticGlyphs.add('%'),
        throwsUnsupportedError,
      );
      expect(arithmeticGlyphs, isNot(contains('%')));
    });

    test('a mark the compositor happily draws is still not in the vocabulary',
        () {
      // `OperatorNode.of` declines only a solidus, which is why asking it was
      // asking the wrong question. Darumadrop draws `±` and `%` perfectly
      // well; neither is arithmetic this app poses.
      for (final String mark in <String>['±', '%', '*', 'x', '⋅']) {
        expect(
          arithmeticGlyphs,
          isNot(contains(mark)),
          reason: '"$mark" is in the drawn vocabulary',
        );
      }
    });
  });
}
