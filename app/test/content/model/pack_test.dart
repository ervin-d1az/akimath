import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/model/pack.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _packJson({
  String expiresAt = '2027-01-01T00:00:00Z',
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'pack_version': 1,
    'pack_id': 'starter',
    'issued_at': '2026-08-01T00:00:00Z',
    'expires_at': expiresAt,
    'items': items ??
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'a1',
            'ladder_step': 3,
            'answer': '5/4',
            'prompt': <Map<String, dynamic>>[
              <String, dynamic>{
                'kind': 'fraction',
                'numerator': '3',
                'denominator': '4',
              },
              <String, dynamic>{'kind': 'operator', 'glyph': '+'},
              <String, dynamic>{'kind': 'text', 'value': '1'},
              <String, dynamic>{'kind': 'operator', 'glyph': '='},
            ],
          },
        ],
  };
}

/// One number-series item, with everything overridable so each rejection can
/// break exactly one thing and leave the rest valid.
Map<String, dynamic> _seriesItem({
  Object? terms = const <int>[2, 4, 6],
  Object? unknownIndex = 2,
  String answer = '6',
  String kind = 'numberSeries',
  Object? alsoPrompt,
}) {
  return <String, dynamic>{
    'id': 'ser',
    'ladder_step': 1,
    'answer': answer,
    // `{kind, payload}`, which is the frozen shape — see `stimulus_reader.dart`
    // and the fixtures it is checked against.
    'stimulus': <String, dynamic>{
      'kind': kind,
      'payload': <String, dynamic>{
        'terms': terms,
        'unknown_index': unknownIndex,
      },
    },
    'prompt': ?alsoPrompt,
  };
}

void main() {
  group('a pack is read from its declared shape', () {
    test('it yields the declared item count and each item s payload', () {
      final Pack pack = Pack.fromJson(_packJson());

      expect(pack.id, 'starter');
      expect(pack.items, hasLength(1));

      final Item item = pack.items.single;
      expect(item.id, 'a1');
      expect(item.expected, '5/4');
      expect((item.stimulus as ArithmeticStimulus).prompt, hasLength(4));
      expect((item.stimulus as ArithmeticStimulus).prompt.first, isA<FractionToken>());
      expect((item.stimulus as ArithmeticStimulus).prompt[1], isA<OperatorToken>());
      expect((item.stimulus as ArithmeticStimulus).prompt[2], isA<TextToken>());
    });

    test('difficulty comes from the pack and is never computed here', () {
      final Pack pack = Pack.fromJson(_packJson());
      expect(pack.items.single.ladderStep, 3);
    });
  });

  group('an expired pack is refused', () {
    test('a pack past its expiry is expired against an injected now', () {
      final Pack pack =
          Pack.fromJson(_packJson(expiresAt: '2026-08-10T00:00:00Z'));

      expect(
        pack.isExpiredAt(DateTime.utc(2026, 8, 16)),
        isTrue,
      );
      expect(
        pack.isExpiredAt(DateTime.utc(2026, 8, 1)),
        isFalse,
      );
    });

    test('expiry reads an injected clock, never the ambient one', () {
      // Two calls with two different `now` values must disagree. A module
      // reaching for DateTime.now() would return the same answer for both.
      final Pack pack =
          Pack.fromJson(_packJson(expiresAt: '2026-08-10T00:00:00Z'));

      expect(
        pack.isExpiredAt(DateTime.utc(2026, 1, 1)),
        isNot(pack.isExpiredAt(DateTime.utc(2027, 1, 1))),
      );
    });
  });

  group('a malformed pack is rejected rather than half-read', () {
    test('a missing items list throws', () {
      final Map<String, dynamic> broken = _packJson()..remove('items');
      expect(() => Pack.fromJson(broken), throwsA(isA<FormatException>()));
    });

    test('an unknown prompt token kind throws', () {
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'bad',
                'ladder_step': 1,
                'answer': '1',
                'prompt': <Map<String, dynamic>>[
                  <String, dynamic>{'kind': 'hologram'},
                ],
              },
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('an item whose answer is not storage-canonical throws', () {
      // The pack is content, and broken content should fail where it is read
      // rather than show a player a wrong verdict for a right answer.
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'bad',
                'ladder_step': 1,
                'answer': ' 007 ',
                'prompt': <Map<String, dynamic>>[
                  <String, dynamic>{'kind': 'text', 'value': '7'},
                ],
              },
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('an empty pack throws', () {
      expect(
        () => Pack.fromJson(_packJson(items: <Map<String, dynamic>>[])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('a number-series item is read as its own stimulus', () {
    test('its terms arrive in order, hole and all', () {
      final Pack pack = Pack.fromJson(
        _packJson(items: <Map<String, dynamic>>[_seriesItem()]),
      );

      final Stimulus stimulus = pack.items.single.stimulus;
      expect(stimulus, isA<NumberSeriesStimulus>());
      expect((stimulus as NumberSeriesStimulus).terms, <int>[2, 4, 6]);
      expect(stimulus.unknownIndex, 2);
    });

    test('an item declaring both a prompt and a stimulus throws', () {
      // Not a preference. Whichever the reader picked, the other would be a
      // question the author wrote and nobody ever sees.
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              _seriesItem(
                alsoPrompt: <Map<String, dynamic>>[
                  <String, dynamic>{'kind': 'text', 'value': '8'},
                ],
              ),
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('an item declaring neither throws', () {
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              <String, dynamic>{'id': 'ser', 'ladder_step': 1, 'answer': '8'},
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('an unknown stimulus kind throws rather than drawing something else', () {
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[_seriesItem(kind: 'hologram')],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('two terms are refused and three are accepted', () {
      // Both sides of the boundary, so the rule cannot be widened *or*
      // tightened in silence. Two terms fit infinitely many rules, so a series
      // of two has no wrong answer — and therefore no right one.
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              // Index 1, so the refusal can only be the term count — index 2
              // would be out of range for two terms and would pass this test
              // for the wrong reason.
              _seriesItem(terms: const <int>[2, 4], unknownIndex: 1),
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
        reason: 'two terms imply no third',
      );
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              _seriesItem(terms: const <int>[2, 4, 6]),
            ],
          ),
        ),
        returnsNormally,
        reason: 'three terms are the shortest series that means anything',
      );
    });

    test('the hidden index must name one of the terms', () {
      // Out of range would be a RangeError thrown in `build`, mid-round, when
      // the item's turn came — past the point where "content is validated
      // where it is read" is true, and shown to a player as a red screen.
      for (final Object? index in <Object?>[null, -1, 3, 99, '2', 1.5]) {
        expect(
          () => Pack.fromJson(
            _packJson(
              items: <Map<String, dynamic>>[_seriesItem(unknownIndex: index)],
            ),
          ),
          throwsA(isA<FormatException>()),
          reason: 'unknown_index $index was accepted for three terms',
        );
      }
      for (final int index in <int>[0, 1, 2]) {
        expect(
          () => Pack.fromJson(
            _packJson(
              items: <Map<String, dynamic>>[
                // The answer is the hidden term, so it moves with the hole.
                _seriesItem(
                  unknownIndex: index,
                  answer: <String>['2', '4', '6'][index],
                ),
              ],
            ),
          ),
          returnsNormally,
          reason: 'unknown_index $index was refused for three terms',
        );
      }
    });

    test('the hidden term travels, and is the answer', () {
      // The payload carries the true value on purpose — offline grading and
      // the error screen's replay both need it — so the reader must keep it
      // rather than strip it, and the renderer is what refuses to draw it.
      final Pack pack = Pack.fromJson(
        _packJson(
          items: <Map<String, dynamic>>[
            _seriesItem(unknownIndex: 1, answer: '4'),
          ],
        ),
      );

      final NumberSeriesStimulus stimulus =
          pack.items.single.stimulus as NumberSeriesStimulus;
      expect(stimulus.terms, hasLength(3));
      expect(stimulus.unknownIndex, 1);
      // `toString`, because the terms are integers and the answer is the
      // canonical *string* the grader compares against. Making them one type
      // would mean either formatting in the content or grading against an int,
      // and both are worse than one conversion in a test.
      expect(
        stimulus.terms[stimulus.unknownIndex].toString(),
        pack.items.single.expected,
      );
    });

    test('terms that are not a list, or not integers, throw', () {
      for (final Object? terms in <Object?>[
        null,
        'onetwothree',
        const <Object>[2, '4', 6],
      ]) {
        expect(
          () => Pack.fromJson(
            _packJson(items: <Map<String, dynamic>>[_seriesItem(terms: terms)]),
          ),
          throwsA(isA<FormatException>()),
          reason: 'terms $terms was accepted',
        );
      }
    });
  });

  group('a pack cannot smuggle in a mark the vocabulary does not name', () {
    test('a solidus is refused at parse, not mid-round', () {
      // Refused now because it is outside `arithmeticGlyphs`; it used to be
      // refused because `OperatorNode.of` threw on it, an inline fraction
      // being something the compositor cannot express rather than something
      // it declines. Either way the throw belongs here and not in `build`,
      // mid-round, when the item's turn came — past the point where "content
      // is validated where it is read" is true.
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'bad',
                'ladder_step': 1,
                'answer': '1',
                'prompt': <Map<String, dynamic>>[
                  <String, dynamic>{'kind': 'operator', 'glyph': '/'},
                ],
              },
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('the operators the pack actually uses all parse', () {
      for (final String glyph in <String>['+', '−', '×', '÷', '=']) {
        expect(
          () => Pack.fromJson(
            _packJson(
              items: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'ok',
                  'ladder_step': 1,
                  'answer': '1',
                  'prompt': <Map<String, dynamic>>[
                    <String, dynamic>{'kind': 'operator', 'glyph': glyph},
                  ],
                },
              ],
            ),
          ),
          returnsNormally,
          reason: '"$glyph" was refused',
        );
      }
    });

    test('an ASCII hyphen is refused where a minus sign was meant', () {
      // `ARITHMETIC_OPERATORS` froze U+002D as the *name* of subtraction, and
      // `stimulus_reader` translates that name to U+2212 before anything is
      // drawn. An authored prompt carries no name — it carries the glyph — so
      // the hyphen arriving here is a mark outside the drawn vocabulary, and
      // the same item would draw U+2212 if it came back from the server.
      expect(
        () => Pack.fromJson(
          _packJson(
            items: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'hyphen',
                'ladder_step': 1,
                'answer': '1',
                'prompt': <Map<String, dynamic>>[
                  <String, dynamic>{'kind': 'text', 'value': '5'},
                  <String, dynamic>{'kind': 'operator', 'glyph': '-'},
                  <String, dynamic>{'kind': 'text', 'value': '4'},
                  <String, dynamic>{'kind': 'operator', 'glyph': '='},
                ],
              },
            ],
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a mark the vocabulary does not name is refused, drawable or not', () {
      // The compositor draws whatever it is handed, so asking it was asking
      // the wrong question. U+22C5 is the sharp case: Darumadrop has no glyph
      // for it, so it falls back to another font while `GlyphMeasure` still
      // measures a Darumadrop box — the mismatch `math_node.dart` records for
      // `=`. U+00B1 and `%` are the blunt case: the font draws them happily
      // and they are still not arithmetic this app poses.
      for (final String glyph in <String>['\u22C5', '\u00B1', '%', 'x']) {
        expect(
          () => Pack.fromJson(
            _packJson(
              items: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'bad',
                  'ladder_step': 1,
                  'answer': '1',
                  'prompt': <Map<String, dynamic>>[
                    <String, dynamic>{'kind': 'operator', 'glyph': glyph},
                  ],
                },
              ],
            ),
          ),
          throwsA(isA<FormatException>()),
          reason: '"$glyph" was accepted',
        );
      }
    });
  });
}
