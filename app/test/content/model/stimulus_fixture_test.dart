import 'dart:convert';
import 'dart:io';

import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/model/stimulus_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frozen layout oracle, read rather than copied.
///
/// `docs/IMPLEMENTATION-PLAN.md` names the cost of the `{kind, payload}` prompt
/// format — six hand-written Dart parsers no generator checks — and names the
/// mitigation in the same breath: one golden fixture and one rejection row per
/// kind in `contract/`, which is *"R2's remedy moved from grading to layout"*.
/// This is that gate. It is the reason a new family is a small change instead
/// of a careful one.
const String _fixtureDir = '../contract/fixtures/stimulus';

/// The kinds this build can actually draw.
///
/// A kind moves from [_pending] to here in the commit that adds its renderer,
/// and never before — the whole point is that the list cannot drift from what
/// the app really does, because the gate below runs the reader for real.
const Set<String> _readable = <String>{
  'arithmetic',
  'numberSeries',
  'matrix',
  'analogy',
  'hiddenOperation',
};

/// Frozen in the contract, not yet built here.
///
/// These are not skipped. Each is asserted to be *refused*, with a message that
/// says so, because a family the app cannot draw must fail where the pack is
/// read and not halfway through a round.
const Set<String> _pending = <String>{
  'figurate',
};

Map<String, dynamic> _read(String name) {
  final File file = File('$_fixtureDir/$name');
  if (!file.existsSync()) {
    // Thrown, not asserted: this runs while the file is loading, before any
    // test body, where `expect` has nowhere to report. A silently skipped
    // parity test is worse than none.
    throw StateError(
      'the frozen stimulus fixture $name is missing at ${file.path} — layout '
      'parity cannot be checked',
    );
  }
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// The `stimulus` object of a fixture's first item.
Map<String, dynamic> _stimulusOf(Map<String, dynamic> pack) {
  final List<dynamic> items = pack['items'] as List<dynamic>;
  final Map<String, dynamic> first = items.first as Map<String, dynamic>;
  return first['stimulus'] as Map<String, dynamic>;
}

void main() {
  test('every frozen kind has a fixture, and none is unaccounted for', () {
    // PROC-10: the gate reports what it covered and fails at zero. Without
    // this, deleting the fixture directory would make every group below
    // vacuous rather than red.
    final Set<String> declared = <String>{..._readable, ..._pending};
    expect(
      declared,
      frozenStimulusKinds.toSet(),
      reason: 'a kind is frozen in the contract but neither readable nor '
          'declared pending here',
    );
    expect(_readable, isNotEmpty);
    for (final String kind in frozenStimulusKinds) {
      expect(File('$_fixtureDir/$kind.json').existsSync(), isTrue,
          reason: 'no golden fixture for "$kind"');
      expect(File('$_fixtureDir/$kind.rejected.json').existsSync(), isTrue,
          reason: 'no rejection fixture for "$kind"');
    }
    // ignore: avoid_print
    print('  stimulus parity · ${frozenStimulusKinds.length} frozen kinds → '
        '${_readable.length} readable, ${_pending.length} pending');
  });

  group('the Dart reader accepts every golden it claims to read', () {
    for (final String kind in _readable) {
      test('$kind parses', () {
        final Map<String, dynamic> stimulus = _stimulusOf(_read('$kind.json'));

        expect(
          () => readStimulus(stimulus, itemId: kind),
          returnsNormally,
          reason: 'the frozen golden for "$kind" must parse — if it does not, '
              'the Dart parser and the TypeScript schema have drifted',
        );
      });
    }

    test('numberSeries yields the terms and the hole the fixture declares', () {
      // Parsing without throwing is not the same as parsing correctly, so one
      // kind is read all the way through to its values. PROC-11: an assertion
      // that holds for any input is not a test.
      final Map<String, dynamic> stimulus =
          _stimulusOf(_read('numberSeries.json'));
      final Map<String, dynamic> payload =
          stimulus['payload'] as Map<String, dynamic>;

      final NumberSeriesStimulus parsed =
          readStimulus(stimulus, itemId: 'ser') as NumberSeriesStimulus;

      expect(parsed.terms, payload['terms']);
      expect(parsed.unknownIndex, payload['unknown_index']);
    });

    test('matrix yields the grid the fixture declares', () {
      final Map<String, dynamic> stimulus = _stimulusOf(_read('matrix.json'));
      final Map<String, dynamic> payload =
          stimulus['payload'] as Map<String, dynamic>;

      final MatrixStimulus parsed =
          readStimulus(stimulus, itemId: 'mat') as MatrixStimulus;

      expect(parsed.cells, payload['cells']);
      expect(parsed.size, payload['size']);
      expect(parsed.unknownIndex, payload['unknown_index']);
      // The invariant every consumer relies on and none re-checks.
      expect(parsed.cells, hasLength(parsed.size * parsed.size));
    });

    test('a grid must be square, and 2×2 or 3×3', () {
      // `matrix_cell_count` is a rejection tag in the frozen validator, and
      // `size` is declared rather than inferred exactly so a truncated pack
      // cannot become a silently smaller grid.
      Object? read({required int size, required int cells}) => readStimulus(
            <String, dynamic>{
              'kind': 'matrix',
              'payload': <String, dynamic>{
                'size': size,
                'cells': List<int>.generate(cells, (int i) => i + 1),
                'unknown_index': 0,
              },
            },
            itemId: 'grid',
          );

      expect(() => read(size: 2, cells: 4), returnsNormally);
      expect(() => read(size: 3, cells: 9), returnsNormally);
      expect(() => read(size: 3, cells: 8), throwsA(isA<FormatException>()),
          reason: 'a truncated 3×3 must not become a 2×2 with a spare');
      expect(() => read(size: 2, cells: 9), throwsA(isA<FormatException>()));
      expect(() => read(size: 1, cells: 1), throwsA(isA<FormatException>()));
      expect(() => read(size: 4, cells: 16), throwsA(isA<FormatException>()));
    });

    test('analogy flattens two nested pairs into four indexed terms', () {
      // The frozen payload nests; `unknown_index` does not. `checkAnalogy`
      // bounds it against `pairs.length * 2`, so the index is already an offset
      // into a flat reading order — and the model has to count the same way or
      // the index means one thing in the pack and another in the widget.
      final Map<String, dynamic> stimulus = _stimulusOf(_read('analogy.json'));
      final Map<String, dynamic> payload =
          stimulus['payload'] as Map<String, dynamic>;
      final List<dynamic> pairs = payload['pairs'] as List<dynamic>;

      final AnalogyStimulus parsed =
          readStimulus(stimulus, itemId: 'ana') as AnalogyStimulus;

      expect(parsed.terms, <int>[
        (pairs[0] as Map<String, dynamic>)['left'] as int,
        (pairs[0] as Map<String, dynamic>)['right'] as int,
        (pairs[1] as Map<String, dynamic>)['left'] as int,
        (pairs[1] as Map<String, dynamic>)['right'] as int,
      ]);
      expect(parsed.unknownIndex, payload['unknown_index']);
    });

    test('an analogy compares exactly two pairs', () {
      // `z.array(...).length(2)`. One pair states a relation but gives nothing
      // to apply it to; three is a shape no screen draws. Both sides, because
      // a rule tested from one side can be moved from the other in silence.
      Object? read(int pairs) => readStimulus(
            <String, dynamic>{
              'kind': 'analogy',
              'payload': <String, dynamic>{
                'pairs': <Map<String, dynamic>>[
                  for (int i = 0; i < pairs; i++)
                    <String, dynamic>{'left': i + 1, 'right': (i + 1) * 2},
                ],
                'unknown_index': 0,
              },
            },
            itemId: 'ana$pairs',
          );

      expect(() => read(1), throwsA(isA<FormatException>()));
      expect(() => read(2), returnsNormally);
      expect(() => read(3), throwsA(isA<FormatException>()));
    });

    test('hiddenOperation yields the examples and the query', () {
      final Map<String, dynamic> stimulus =
          _stimulusOf(_read('hiddenOperation.json'));
      final Map<String, dynamic> payload =
          stimulus['payload'] as Map<String, dynamic>;
      final List<dynamic> examples = payload['examples'] as List<dynamic>;

      final HiddenOperationStimulus parsed =
          readStimulus(stimulus, itemId: 'fn') as HiddenOperationStimulus;

      expect(parsed.examples, hasLength(examples.length));
      expect(parsed.examples.first.input,
          (examples.first as Map<String, dynamic>)['input']);
      expect(parsed.examples.first.output,
          (examples.first as Map<String, dynamic>)['output']);
      expect(parsed.queryInput, payload['query_input']);
    });

    test('a machine needs two or three examples, and a fresh query', () {
      Object? read({int count = 2, int query = 99}) => readStimulus(
            <String, dynamic>{
              'kind': 'hiddenOperation',
              'payload': <String, dynamic>{
                'examples': <Map<String, dynamic>>[
                  for (int i = 1; i <= count; i++)
                    <String, dynamic>{'input': i, 'output': i * 3},
                ],
                'query_input': query,
              },
            },
            itemId: 'fn',
          );

      // One example fixes no operation — `2 › 7` is `+5` and `×3+1` at once.
      expect(() => read(count: 1), throwsA(isA<FormatException>()));
      expect(() => read(count: 2), returnsNormally);
      expect(() => read(count: 3), returnsNormally);
      expect(() => read(count: 4), throwsA(isA<FormatException>()));

      // `query_repeats_example`: the answer would already be on the screen.
      expect(() => read(query: 1), throwsA(isA<FormatException>()));
      expect(() => read(query: 2), throwsA(isA<FormatException>()));
    });

    test('two examples sharing an output is ordinary, not a rejection', () {
      // The repeat rule is about *inputs*. `x²` maps 2 and -2 to the same
      // output, and refusing that would rule out a whole class of rules the
      // family exists to teach.
      expect(
        () => readStimulus(
          <String, dynamic>{
            'kind': 'hiddenOperation',
            'payload': <String, dynamic>{
              'examples': <Map<String, dynamic>>[
                <String, dynamic>{'input': 2, 'output': 4},
                <String, dynamic>{'input': -2, 'output': 4},
              ],
              'query_input': 3,
            },
          },
          itemId: 'sq',
        ),
        returnsNormally,
      );
    });

    test('arithmetic flattens the frozen term pair into drawable tokens', () {
      // `{num: 1, den: 2} + {num: 1, den: 3}` is the golden. The compositor
      // draws tokens, so the parser's job is the translation — and a `den` of
      // 1 must come out as a plain numeral rather than a bar over a one.
      final ArithmeticStimulus parsed = readStimulus(
        _stimulusOf(_read('arithmetic.json')),
        itemId: 'ari',
      ) as ArithmeticStimulus;

      expect(parsed.prompt, hasLength(4));
      expect(parsed.prompt[0], isA<FractionToken>());
      expect(parsed.prompt[1], isA<OperatorToken>());
      expect(parsed.prompt[2], isA<FractionToken>());
      expect((parsed.prompt[3] as OperatorToken).glyph, '=');
    });

    test('a series honours both ends of the frozen three-to-seven range', () {
      // `z.array(z.int()).min(3).max(7)`. Seven is not arbitrary: it is the
      // tile count `02 Reto activo` and the error screen's replay are drawn
      // for, so an eight-term series is a row neither screen has room for.
      // Both ends, because a bound tested from one side can be moved from the
      // other in silence.
      Object? read(int count) => readStimulus(
            <String, dynamic>{
              'kind': 'numberSeries',
              'payload': <String, dynamic>{
                'terms': List<int>.generate(count, (int i) => i * 2),
                'unknown_index': 0,
              },
            },
            itemId: 'len$count',
          );

      expect(() => read(2), throwsA(isA<FormatException>()));
      expect(() => read(3), returnsNormally);
      expect(() => read(7), returnsNormally);
      expect(() => read(8), throwsA(isA<FormatException>()));
    });

    test('the frozen ASCII hyphen is drawn as a minus sign', () {
      // The one place the two halves deliberately disagree, so it is the one
      // that most needs pinning. `ARITHMETIC_OPERATORS` froze `-`; the
      // compositor draws U+2212, which is the correct mark and the one every
      // other operator in the pack already uses. No fixture exercises
      // subtraction, so without this the translation could be deleted and
      // every gate would stay green.
      final ArithmeticStimulus parsed = readStimulus(
        <String, dynamic>{
          'kind': 'arithmetic',
          'payload': <String, dynamic>{
            'operator': '-',
            'left': <String, dynamic>{'num': 9, 'den': 1},
            'right': <String, dynamic>{'num': 4, 'den': 1},
          },
        },
        itemId: 'sub',
      ) as ArithmeticStimulus;

      expect((parsed.prompt[1] as OperatorToken).glyph, '−');
      expect((parsed.prompt[1] as OperatorToken).glyph, isNot('-'));
    });

    test('an operator outside the frozen four is refused', () {
      for (final String operator in <String>['/', '^', '=', '−']) {
        expect(
          () => readStimulus(
            <String, dynamic>{
              'kind': 'arithmetic',
              'payload': <String, dynamic>{
                'operator': operator,
                'left': <String, dynamic>{'num': 1, 'den': 1},
                'right': <String, dynamic>{'num': 1, 'den': 1},
              },
            },
            itemId: 'op',
          ),
          throwsA(isA<FormatException>()),
          reason: '"$operator" is not one of the four the contract froze',
        );
      }
    });

    test('a whole term is a numeral, not a bar over a one', () {
      final ArithmeticStimulus parsed = readStimulus(
        <String, dynamic>{
          'kind': 'arithmetic',
          'payload': <String, dynamic>{
            'operator': '+',
            'left': <String, dynamic>{'num': 3, 'den': 1},
            'right': <String, dynamic>{'num': 4, 'den': 1},
          },
        },
        itemId: 'whole',
      ) as ArithmeticStimulus;

      expect((parsed.prompt[0] as TextToken).value, '3');
      expect((parsed.prompt[2] as TextToken).value, '4');
    });
  });

  group('the Dart reader refuses every rejection row', () {
    for (final String kind in _readable) {
      test('$kind is refused for the reason the fixture names', () {
        final Map<String, dynamic> fixture = _read('$kind.rejected.json');
        final Map<String, dynamic> stimulus =
            _stimulusOf(fixture['pack'] as Map<String, dynamic>);

        expect(
          () => readStimulus(stimulus, itemId: kind),
          throwsA(isA<FormatException>()),
          reason: 'the frozen rejection row for "$kind" '
              '(${fixture['expected_tag']}) was accepted by the Dart reader, '
              'so the two halves disagree about what is valid',
        );
      });
    }
  });

  group('a kind this build cannot draw is refused, not half-drawn', () {
    for (final String kind in _pending) {
      test('$kind is refused where the pack is read', () {
        // Not skipped. A family frozen in the contract but unbuilt here must
        // fail at parse — the alternative is a round that reaches an item it
        // has no renderer for and shows a player a blank screen.
        expect(
          () => readStimulus(_stimulusOf(_read('$kind.json')), itemId: kind),
          throwsA(
            isA<FormatException>().having(
              (FormatException e) => e.message,
              'message',
              contains('cannot draw'),
            ),
          ),
        );
      });
    }
  });
}
