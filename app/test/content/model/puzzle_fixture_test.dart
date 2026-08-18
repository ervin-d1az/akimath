import 'dart:convert';
import 'dart:io';

import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/content/model/puzzle_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frozen puzzle oracle, read rather than copied.
///
/// The same gate `stimulus_fixture_test` is for the six item families, for the
/// same reason: these parsers are hand-written and no generator checks them.
/// One golden and one rejection row per kind, and a kind this build cannot draw
/// is asserted to be *refused* rather than skipped.
const String _dir = '../contract/fixtures/puzzle';

const Set<String> _readable = <String>{'kenken', 'killer', 'magicSquare'};

const Set<String> _pending = <String>{
  'kakuro',
  'wordSearch',
};

Map<String, dynamic> _read(String name) {
  final File file = File('$_dir/$name');
  if (!file.existsSync()) {
    throw StateError('the frozen puzzle fixture $name is missing at ${file.path}');
  }
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _envelope(Map<String, dynamic> pack) =>
    (pack['puzzles'] as List<dynamic>).first as Map<String, dynamic>;

void main() {
  test('every frozen kind has a fixture, and none is unaccounted for', () {
    final Set<String> declared = <String>{..._readable, ..._pending};
    expect(declared, frozenPuzzleKinds.toSet());
    expect(_readable, isNotEmpty);
    for (final String kind in frozenPuzzleKinds) {
      expect(File('$_dir/$kind.json').existsSync(), isTrue, reason: kind);
      expect(File('$_dir/$kind.rejected.json').existsSync(), isTrue, reason: kind);
    }
    // ignore: avoid_print
    print('  puzzle parity · ${frozenPuzzleKinds.length} frozen kinds → '
        '${_readable.length} readable, ${_pending.length} pending');
  });

  group('the reader accepts the golden it claims to read', () {
    test('kenken yields the board the fixture declares', () {
      final Map<String, dynamic> envelope = _envelope(_read('kenken.json'));
      final KenKenPuzzle puzzle =
          readPuzzle(envelope, puzzleId: 'k1') as KenKenPuzzle;

      expect(puzzle.board.size, 3);
      expect(puzzle.board.solution, <List<int>>[
        <int>[1, 2, 3],
        <int>[2, 3, 1],
        <int>[3, 1, 2],
      ]);
      expect(puzzle.board.blocked, isEmpty);
      expect(puzzle.board.given, isEmpty);
      // Every cell is open on this board, so the count is the whole square.
      expect(puzzle.board.openCells, hasLength(9));
    });

    test('its cages carry cells, an operation and a target', () {
      final KenKenPuzzle puzzle =
          readPuzzle(_envelope(_read('kenken.json')), puzzleId: 'k1')
              as KenKenPuzzle;

      expect(puzzle.cages, hasLength(5));
      expect(puzzle.cages.first.cells,
          <Cell>[const Cell(row: 0, col: 0), const Cell(row: 1, col: 0)]);
      expect(puzzle.cages.first.operation, '+');
      expect(puzzle.cages.first.target, 3);
    });

    test('the cages cover every cell exactly once', () {
      // The frozen validator checks this at build time; asserting it here is
      // how the *reader* proves it did not drop or duplicate a cell.
      final KenKenPuzzle puzzle =
          readPuzzle(_envelope(_read('kenken.json')), puzzleId: 'k1')
              as KenKenPuzzle;

      final List<Cell> covered =
          puzzle.cages.expand((Cage c) => c.cells).toList();
      expect(covered, hasLength(9));
      expect(covered.toSet(), hasLength(9));
    });

    test('the tutorial and the reference sheet come through in es-MX', () {
      // They are content, and they travel in the pack precisely so the copy can
      // change without an app release.
      final Puzzle puzzle =
          readPuzzle(_envelope(_read('kenken.json')), puzzleId: 'k1');

      expect(puzzle.tutorialSteps, isNotEmpty);
      expect(puzzle.referenceSheet, isNotEmpty);
      expect(puzzle.tutorialSteps.first, contains('fila'));
    });
  });

  group('a killer is cages and sums', () {
    test('its cages carry a target and no operation', () {
      final KillerPuzzle puzzle =
          readPuzzle(_envelope(_read('killer.json')), puzzleId: 'k1')
              as KillerPuzzle;

      expect(puzzle.cages, isNotEmpty);
      for (final Cage cage in puzzle.cages) {
        expect(cage.operation, isNull,
            reason: 'a killer cage asks for a sum by naming nothing');
        expect(cage.target, greaterThan(0));
      }
    });

    test('its cages cover the board exactly once', () {
      final KillerPuzzle puzzle =
          readPuzzle(_envelope(_read('killer.json')), puzzleId: 'k1')
              as KillerPuzzle;
      final List<Cell> covered =
          puzzle.cages.expand((Cage c) => c.cells).toList();
      final int fillable =
          puzzle.board.size * puzzle.board.size - puzzle.board.blocked.length;

      expect(covered, hasLength(fillable));
      expect(covered.toSet(), hasLength(fillable));
    });

    test('a killer cage naming an operation is refused', () {
      // `KillerPayloadSchema` has no such field. Ignoring one would draw a
      // board that says less than its content claims, and would let the two
      // readers disagree about what a killer is.
      expect(
        () => readPuzzle(<String, dynamic>{
          'kind': 'killer',
          'payload': <String, dynamic>{
            'board': <String, dynamic>{
              'size': 3,
              'blocked': <Object>[],
              'given': <Object>[],
              'solution': <List<int>>[
                <int>[1, 2, 3],
                <int>[2, 3, 1],
                <int>[3, 1, 2],
              ],
            },
            'cages': <Map<String, dynamic>>[
              <String, dynamic>{
                'cells': <Map<String, int>>[
                  for (int row = 0; row < 3; row++)
                    for (int col = 0; col < 3; col++)
                      <String, int>{'row': row, 'col': col},
                ],
                'target': 18,
                'operation': '+',
              },
            ],
          },
          'tutorial_steps': <String>['x'],
          'reference_sheet': <String>['y'],
        }, puzzleId: 'op'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a kenken cage without an operation is still refused', () {
      // The other half of D1: the model is permissive and the readers are
      // strict, so making `operation` optional must not let KenKen lose one.
      expect(
        () => readPuzzle(<String, dynamic>{
          'kind': 'kenken',
          'payload': <String, dynamic>{
            'board': <String, dynamic>{
              'size': 3,
              'blocked': <Object>[],
              'given': <Object>[],
              'solution': <List<int>>[
                <int>[1, 2, 3],
                <int>[2, 3, 1],
                <int>[3, 1, 2],
              ],
            },
            'cages': <Map<String, dynamic>>[
              <String, dynamic>{
                'cells': <Map<String, int>>[
                  for (int row = 0; row < 3; row++)
                    for (int col = 0; col < 3; col++)
                      <String, int>{'row': row, 'col': col},
                ],
                'target': 18,
              },
            ],
          },
          'tutorial_steps': <String>['x'],
          'reference_sheet': <String>['y'],
        }, puzzleId: 'noop'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('a magic square is lines and totals', () {
    test('it holds one to size squared, not one to size', () {
      // The assumption the two caged formats hid. Deriving the domain from the
      // board's size would refuse every digit above 3 here — which is every
      // digit a 3×3 magic square is made of.
      final MagicSquarePuzzle puzzle =
          readPuzzle(_envelope(_read('magicSquare.json')), puzzleId: 'm1')
              as MagicSquarePuzzle;

      expect(puzzle.board.size, 3);
      expect(puzzle.board.highestValue, 9);
    });

    test('a caged board still holds one to its size', () {
      final KenKenPuzzle kenken =
          readPuzzle(_envelope(_read('kenken.json')), puzzleId: 'k1')
              as KenKenPuzzle;
      expect(kenken.board.highestValue, 3);
    });

    test('its targets come through, one per line', () {
      final MagicSquarePuzzle puzzle =
          readPuzzle(_envelope(_read('magicSquare.json')), puzzleId: 'm1')
              as MagicSquarePuzzle;

      expect(puzzle.rowTargets, <int>[15, 15, 15]);
      expect(puzzle.columnTargets, <int>[15, 15, 15]);
    });

    test('a board the pad cannot express is refused', () {
      // A 4×4 needs sixteen values and the pad offers nine — seven of them
      // could never be typed. Not a hard board: an unplayable one.
      Object? read(int size) => readPuzzle(<String, dynamic>{
            'kind': 'magicSquare',
            'payload': <String, dynamic>{
              'board': <String, dynamic>{
                'size': size,
                'blocked': <Object>[],
                'given': <Object>[],
                'solution': <List<int>>[
                  for (int row = 0; row < size; row++)
                    <int>[for (int col = 0; col < size; col++) row * size + col + 1],
                ],
              },
              'row_targets': <int>[for (int i = 0; i < size; i++) 15],
              'column_targets': <int>[for (int i = 0; i < size; i++) 15],
            },
            'tutorial_steps': <String>['x'],
            'reference_sheet': <String>['y'],
          }, puzzleId: 'big');

      expect(() => read(3), returnsNormally, reason: 'nine is what the pad has');
      for (final int size in <int>[4, 5, 6]) {
        expect(() => read(size), throwsA(isA<FormatException>()),
            reason: 'a $size square needs ${size * size} values');
      }
    });

    test('a six-square KenKen is still fine — the limit is the domain', () {
      // The rule is about what a player can type, not how big a board is.
      expect(
        () => readPuzzle(<String, dynamic>{
          'kind': 'kenken',
          'payload': <String, dynamic>{
            'board': <String, dynamic>{
              'size': 6,
              'blocked': <Object>[],
              'given': <Object>[],
              'solution': <List<int>>[
                for (int row = 0; row < 6; row++)
                  <int>[for (int col = 0; col < 6; col++) (row + col) % 6 + 1],
              ],
            },
            'cages': <Map<String, dynamic>>[
              <String, dynamic>{
                'cells': <Map<String, int>>[
                  for (int row = 0; row < 6; row++)
                    for (int col = 0; col < 6; col++)
                      <String, int>{'row': row, 'col': col},
                ],
                'operation': '+',
                'target': 126,
              },
            ],
          },
          'tutorial_steps': <String>['x'],
          'reference_sheet': <String>['y'],
        }, puzzleId: 'big6'),
        returnsNormally,
      );
    });

    test('a targets list of the wrong length is refused', () {
      // The frozen rejection row is exactly this — `solution_shape` with four
      // column targets on a three square.
      final Map<String, dynamic> fixture = _read('magicSquare.rejected.json');
      expect(
        () => readPuzzle(_envelope(fixture['pack'] as Map<String, dynamic>),
            puzzleId: 'm1'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('the reader refuses the rejection row', () {
    for (final String kind in _readable) {
    test('$kind is refused', () {
      final Map<String, dynamic> fixture = _read('$kind.rejected.json');
      final Map<String, dynamic> envelope =
          _envelope(fixture['pack'] as Map<String, dynamic>);

      expect(
        () => readPuzzle(envelope, puzzleId: 'k1'),
        throwsA(isA<FormatException>()),
        reason: 'the frozen rejection row (${fixture['expected_tag']}) was '
            'accepted, so the two stacks disagree about a valid board',
      );
    });
    }
  });

  group('a malformed board is refused where it is read', () {
    Map<String, dynamic> envelope(Map<String, dynamic> payload) =>
        <String, dynamic>{
          'kind': 'kenken',
          'payload': payload,
          'tutorial_steps': <String>['x'],
          'reference_sheet': <String>['y'],
        };

    // The smallest board the format admits, with one cage over all of it — so
    // each case below breaks exactly one thing and leaves the rest valid.
    Map<String, dynamic> board() => <String, dynamic>{
          'size': 3,
          'blocked': <Object>[],
          'given': <Object>[],
          'solution': <List<int>>[
            <int>[1, 2, 3],
            <int>[2, 3, 1],
            <int>[3, 1, 2],
          ],
        };

    Map<String, dynamic> cage(String operation) => <String, dynamic>{
          'cells': <Map<String, int>>[
            for (int row = 0; row < 3; row++)
              for (int col = 0; col < 3; col++)
                <String, int>{'row': row, 'col': col},
          ],
          'operation': operation,
          'target': 18,
        };

    test('a cage operation outside the frozen four', () {
      // `CAGE_OPERATIONS` froze `+ - × ÷`. Nothing fed anything else until the
      // falsification pass, so removing the check changed nothing.
      for (final String operation in <String>['^', '%', '', 'plus', '*']) {
        expect(
          () => readPuzzle(envelope(<String, dynamic>{
            'board': board(),
            'cages': <Object>[cage(operation)],
          }), puzzleId: 'op'),
          throwsA(isA<FormatException>()),
          reason: '"$operation" was accepted',
        );
      }
    });

    test('each of the frozen four is accepted', () {
      // The other side of the same boundary: a check that refused everything
      // would satisfy the test above perfectly.
      for (final String operation in <String>['+', '-', '×', '÷']) {
        expect(
          () => readPuzzle(envelope(<String, dynamic>{
            'board': board(),
            'cages': <Object>[cage(operation)],
          }), puzzleId: 'op'),
          returnsNormally,
          reason: '"$operation" was refused',
        );
      }
    });

    test('a board narrower or wider than the format admits', () {
      for (final int size in <int>[0, 1, 2, 7, 9]) {
        // Only `size` changes; the solution stays 3×3, which is itself a
        // mismatch the reader must catch either way.
        final Map<String, dynamic> b = board()..['size'] = size;
        expect(
          () => readPuzzle(
              envelope(<String, dynamic>{'board': b, 'cages': <Object>[cage('+')]}),
              puzzleId: 'size'),
          throwsA(isA<FormatException>()),
          reason: 'a $size square was accepted',
        );
      }
    });

    test('cages that leave a cell uncovered', () {
      final Map<String, dynamic> short = cage('+')
        ..['cells'] = <Map<String, int>>[
          <String, int>{'row': 0, 'col': 0},
        ];
      expect(
        () => readPuzzle(
            envelope(<String, dynamic>{'board': board(), 'cages': <Object>[short]}),
            puzzleId: 'gap'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('a kind this build cannot draw is refused, not half-drawn', () {
    for (final String kind in _pending) {
      test('$kind is refused where the pack is read', () {
        expect(
          () => readPuzzle(_envelope(_read('$kind.json')), puzzleId: kind),
          throwsA(isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('cannot draw'),
          )),
        );
      });
    }
  });
}
