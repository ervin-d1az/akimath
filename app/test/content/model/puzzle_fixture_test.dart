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

const Set<String> _readable = <String>{
  'kenken',
  'killer',
  'magicSquare',
  'kakuro',
};

const Set<String> _pending = <String>{'wordSearch'};

/// Kinds whose frozen rejection row carries a fault **no reader can see**.
///
/// The gate asserted that the reader refuses every rejection row, and that held
/// for three formats by luck of which faults their fixtures carry. Kakuro's is
/// `solution_not_unique`, which cannot be detected without solving the board —
/// and `no_puzzle_generation_test` exists precisely to keep solving off the
/// device.
///
/// So the exception is named with its reason rather than the kind being quietly
/// dropped from the loop, which is the same code with the justification lost.
/// Every kind **not** named here is still required to refuse, so excusing a
/// second one is a visible edit (design D1).
const Map<String, String> _rejectionNeedsASearch = <String, String>{
  'kakuro': 'solution_not_unique — only a solver can see it, and the builder is '
      'where the solver lives',
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
      final String? excused = _rejectionNeedsASearch[kind];
      if (excused != null) {
        // ignore: avoid_print
        print('  puzzle parity · $kind\'s rejection row is the builder\'s: $excused');
        return;
      }
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

  group('a kakuro is runs and sums', () {
    test('its cells hold one to nine, whatever the board\'s size', () {
      // A third domain rule, after `size` and `size²`. A 3×3 Kakuro accepts a
      // 9 where a 3×3 KenKen stops at 3.
      final KakuroPuzzle puzzle =
          readPuzzle(_envelope(_read('kakuro.json')), puzzleId: 'k1')
              as KakuroPuzzle;

      expect(puzzle.board.size, 3);
      expect(puzzle.board.highestValue, 9);
    });

    test('its runs carry cells and a sum, across and down', () {
      final KakuroPuzzle puzzle =
          readPuzzle(_envelope(_read('kakuro.json')), puzzleId: 'k1')
              as KakuroPuzzle;

      expect(puzzle.runs, isNotEmpty);
      expect(puzzle.runs.any((Run r) => r.isAcross), isTrue);
      expect(puzzle.runs.any((Run r) => !r.isAcross), isTrue);
      for (final Run run in puzzle.runs) {
        expect(run.cells.length, greaterThanOrEqualTo(2));
        expect(run.sum, greaterThan(0));
      }
    });

    test('every fillable cell is in at least one run', () {
      // A cell no clue constrains is solvable only by guessing.
      final KakuroPuzzle puzzle =
          readPuzzle(_envelope(_read('kakuro.json')), puzzleId: 'k1')
              as KakuroPuzzle;
      final Set<Cell> covered = <Cell>{
        for (final Run run in puzzle.runs) ...run.cells,
      };
      for (final Cell cell in puzzle.board.openCells) {
        expect(covered, contains(cell), reason: '$cell is in no run');
      }
    });

    /// A valid 3×3 Kakuro, with the runs overridable so each case breaks one
    /// thing and leaves the rest sound.
    Object? readKakuro(List<Map<String, dynamic>> runs) => readPuzzle(
          <String, dynamic>{
            'kind': 'kakuro',
            'payload': <String, dynamic>{
              'board': <String, dynamic>{
                'size': 3,
                'blocked': <Map<String, int>>[
                  <String, int>{'row': 0, 'col': 0},
                ],
                'given': <Object>[],
                'solution': <List<int>>[
                  <int>[0, 1, 3],
                  <int>[4, 2, 9],
                  <int>[6, 8, 5],
                ],
              },
              'runs': runs,
            },
            'tutorial_steps': <String>['x'],
            'reference_sheet': <String>['y'],
          },
          puzzleId: 'runs',
        );

    List<Map<String, dynamic>> soundRuns() => <Map<String, dynamic>>[
          <String, dynamic>{
            'cells': <Map<String, int>>[
              <String, int>{'row': 0, 'col': 1},
              <String, int>{'row': 0, 'col': 2},
            ],
            'sum': 4,
          },
          for (int row = 1; row < 3; row++)
            <String, dynamic>{
              'cells': <Map<String, int>>[
                for (int col = 0; col < 3; col++)
                  <String, int>{'row': row, 'col': col},
              ],
              'sum': 15,
            },
        ];

    test('a fillable cell in no run is refused', () {
      // A cell no clue constrains is solvable only by guessing, which is not
      // the game. Nothing fed this until the falsification pass.
      final List<Map<String, dynamic>> short = soundRuns()..removeLast();
      expect(() => readKakuro(short), throwsA(isA<FormatException>()));
      expect(() => readKakuro(soundRuns()), returnsNormally);
    });

    test('a run of one cell is refused', () {
      // `z.array(CellSchema).min(2)`. A run of one is a given, not a run, and
      // it has no direction — so the clue renderer could not place it either.
      //
      // **Added to the sound runs, not substituted for one.** Replacing a
      // two-cell run left a cell in no run, so the coverage check fired and
      // the test passed without the length rule being involved at all — it was
      // green with that rule deleted.
      final List<Map<String, dynamic>> extra = soundRuns()
        ..add(<String, dynamic>{
          'cells': <Map<String, int>>[
            <String, int>{'row': 0, 'col': 1},
          ],
          'sum': 4,
        });
      expect(() => readKakuro(extra), throwsA(isA<FormatException>()));
    });

    test('a sum no distinct digits could reach is refused', () {
      // Two distinct digits from 1..9 sum to between 3 and 17. Constant time —
      // whether a *particular* sum works given the crossing runs is the
      // builder's, and deciding that here would be solving.
      Object? read(int sum) => readPuzzle(<String, dynamic>{
            'kind': 'kakuro',
            'payload': <String, dynamic>{
              'board': <String, dynamic>{
                'size': 3,
                'blocked': <Map<String, int>>[
                  <String, int>{'row': 0, 'col': 0},
                ],
                'given': <Object>[],
                'solution': <List<int>>[
                  <int>[0, 1, 3],
                  <int>[4, 2, 9],
                  <int>[6, 8, 5],
                ],
              },
              'runs': <Map<String, dynamic>>[
                <String, dynamic>{
                  'cells': <Map<String, int>>[
                    <String, int>{'row': 0, 'col': 1},
                    <String, int>{'row': 0, 'col': 2},
                  ],
                  'sum': sum,
                },
                for (int row = 1; row < 3; row++)
                  <String, dynamic>{
                    'cells': <Map<String, int>>[
                      for (int col = 0; col < 3; col++)
                        <String, int>{'row': row, 'col': col},
                    ],
                    'sum': 15,
                  },
              ],
            },
            'tutorial_steps': <String>['x'],
            'reference_sheet': <String>['y'],
          }, puzzleId: 'sum');

      expect(() => read(2), throwsA(isA<FormatException>()), reason: 'below 1+2');
      expect(() => read(18), throwsA(isA<FormatException>()), reason: 'above 9+8');
      expect(() => read(3), returnsNormally);
      expect(() => read(17), returnsNormally);
    });
  });

  group('the excuse cannot spread quietly', () {
    test('only kinds named as needing a search are excused', () {
      // A kind excused without being listed is a kind that stopped being
      // checked and nobody noticed.
      expect(_rejectionNeedsASearch.keys, everyElement(isIn(_readable)));
      expect(_rejectionNeedsASearch, hasLength(1),
          reason: 'a second exception should be a deliberate edit, not a habit');
    });

    test('every excuse carries a reason', () {
      for (final MapEntry<String, String> excuse
          in _rejectionNeedsASearch.entries) {
        expect(excuse.value, isNotEmpty, reason: excuse.key);
        expect(excuse.value.length, greaterThan(20),
            reason: '"${excuse.key}" needs a reason, not a word');
      }
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
