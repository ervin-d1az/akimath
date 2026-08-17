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
  Object? terms = const <String>['2', '4', '6'],
  String kind = 'numberSeries',
  Object? alsoPrompt,
}) {
  return <String, dynamic>{
    'id': 'ser',
    'ladder_step': 1,
    'answer': '8',
    'stimulus': <String, dynamic>{'kind': kind, 'terms': terms},
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
    test('its terms arrive in order and the answer is not among them', () {
      final Pack pack = Pack.fromJson(
        _packJson(items: <Map<String, dynamic>>[_seriesItem()]),
      );

      final Stimulus stimulus = pack.items.single.stimulus;
      expect(stimulus, isA<NumberSeriesStimulus>());
      expect((stimulus as NumberSeriesStimulus).terms, <String>['2', '4', '6']);
      // The hole is drawn by the view, so the answer must not be a term. A pack
      // that shipped it would show the player what to type.
      expect(stimulus.terms, isNot(contains(pack.items.single.expected)));
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
              _seriesItem(terms: const <String>['2', '4']),
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
              _seriesItem(terms: const <String>['2', '4', '6']),
            ],
          ),
        ),
        returnsNormally,
        reason: 'three terms are the shortest series that means anything',
      );
    });

    test('terms that are not a list, or not strings, throw', () {
      for (final Object? terms in <Object?>[
        null,
        'onetwothree',
        const <Object>['2', 4, '6'],
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

  group('a pack cannot smuggle in a token the compositor refuses', () {
    test('an operator the compositor cannot draw is refused at parse', () {
      // OperatorNode.of throws on a solidus. Without validation here that throw
      // happened in build, mid-round, when the item's turn came — past the
      // point where "content is validated where it is read" is true, and shown
      // to a child as a red screen.
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
  });
}
