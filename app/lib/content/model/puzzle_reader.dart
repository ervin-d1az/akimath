/// The hand-written Dart parsers for the frozen puzzle formats.
///
/// **PURE.** A decoded envelope in, a [Puzzle] out, a [FormatException] on
/// anything else — so `puzzle_fixture_test` drives it straight from
/// `contract/fixtures/puzzle/` without a pack around it.
///
/// The same arrangement, and the same justification, as
/// `stimulus_reader.dart`: the frozen format is `{kind, payload}` with one Zod
/// schema per kind, no generator checks the Dart side, and the mitigation is a
/// golden and a rejection row per kind. The TypeScript half is
/// `packages/contract/src/puzzle/`. When the two disagree the fixtures are
/// right and both are wrong.
library;

import 'puzzle.dart';

/// Every kind the frozen format declares, in the order `puzzle/index.ts` lists
/// them. Exported so the gate can assert a fixture exists for each — a kind
/// added to the contract and forgotten here would be a puzzle the app silently
/// cannot read.
const List<String> frozenPuzzleKinds = <String>[
  'kenken',
  'kakuro',
  'killer',
  'magicSquare',
  'wordSearch',
];

/// The four operations a cage may name.
const List<String> cageOperations = <String>['+', '-', '×', '÷'];

Puzzle readPuzzle(Object? raw, {required String puzzleId}) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('puzzle "$puzzleId" is malformed');
  }
  final Object? payload = raw['payload'];
  if (payload is! Map<String, dynamic>) {
    throw FormatException('puzzle "$puzzleId" has no payload');
  }

  final List<String> tutorial = _requireCopy(raw, 'tutorial_steps', puzzleId, 5);
  final List<String> reference = _requireCopy(raw, 'reference_sheet', puzzleId, 6);

  return switch (raw['kind']) {
    'kenken' => _kenken(payload, tutorial, reference, puzzleId),
    // A kind the contract froze but this build has no renderer for lands here.
    // Refused where the pack is read: the alternative is a player opening a
    // card and meeting a blank board.
    final Object? kind => throw FormatException(
        'puzzle "$puzzleId" is of a kind this build cannot draw: "$kind"',
      ),
  };
}

Puzzle _kenken(
  Map<String, dynamic> payload,
  List<String> tutorial,
  List<String> reference,
  String id,
) {
  final PuzzleBoard board = _board(payload['board'], id);
  final Object? rawCages = payload['cages'];
  if (rawCages is! List || rawCages.isEmpty) {
    throw FormatException('puzzle "$id" has no cages');
  }

  final List<Cage> cages = <Cage>[
    for (final Object? cage in rawCages) _cage(cage, id),
  ];

  // **Every cell in exactly one cage.** `checkCageCoverage` enforces it where
  // the pack is built; re-checking here is not distrust of the builder, it is
  // the reader refusing to hand the renderer a board with a hole in it — the
  // cage outline is derived from these sets and a gap would draw as a border
  // around nothing.
  final List<Cell> covered = cages.expand((Cage c) => c.cells).toList();
  final int fillable = board.size * board.size - board.blocked.length;
  if (covered.length != fillable || covered.toSet().length != fillable) {
    throw FormatException(
      'puzzle "$id" has cages covering ${covered.toSet().length} of $fillable '
      'cells, with ${covered.length - covered.toSet().length} overlapping',
    );
  }

  return KenKenPuzzle(
    board: board,
    cages: cages,
    tutorialSteps: tutorial,
    referenceSheet: reference,
  );
}

Cage _cage(Object? raw, String id) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('puzzle "$id" has a malformed cage');
  }
  final String operation = raw['operation'] as String? ?? '';
  if (!cageOperations.contains(operation)) {
    throw FormatException('puzzle "$id" has a cage with operation "$operation"');
  }
  final Object? target = raw['target'];
  if (target is! int || target < 1) {
    throw FormatException('puzzle "$id" has a cage targeting $target');
  }
  final Object? cells = raw['cells'];
  if (cells is! List || cells.isEmpty) {
    throw FormatException('puzzle "$id" has an empty cage');
  }
  return Cage(
    cells: <Cell>[for (final Object? cell in cells) _cell(cell, id)],
    operation: operation,
    target: target,
  );
}

Cell _cell(Object? raw, String id) {
  if (raw is! Map<String, dynamic> ||
      raw['row'] is! int ||
      raw['col'] is! int) {
    throw FormatException('puzzle "$id" has a malformed cell');
  }
  return Cell(row: raw['row'] as int, col: raw['col'] as int);
}

PuzzleBoard _board(Object? raw, String id) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('puzzle "$id" has no board');
  }
  final Object? size = raw['size'];
  if (size is! int || size < 3 || size > 6) {
    throw FormatException('puzzle "$id" is $size squares wide; the format admits 3 to 6');
  }

  final Object? solution = raw['solution'];
  if (solution is! List || solution.length != size) {
    throw FormatException('puzzle "$id" has a solution of the wrong height');
  }
  final List<List<int>> grid = <List<int>>[
    for (final Object? row in solution)
      if (row is List && row.length == size)
        <int>[
          for (final Object? value in row)
            if (value is int) value else throw FormatException('puzzle "$id" has a non-integer cell'),
        ]
      else
        throw FormatException('puzzle "$id" has a solution row of the wrong width'),
  ];

  final Set<Cell> blocked = _cellSet(raw['blocked'], id);
  final Set<Cell> given = _cellSet(raw['given'], id);
  for (final Cell cell in <Cell>{...blocked, ...given}) {
    if (cell.row >= size || cell.col >= size) {
      throw FormatException('puzzle "$id" names cell $cell outside a $size square');
    }
  }

  return PuzzleBoard(size: size, blocked: blocked, given: given, solution: grid);
}

Set<Cell> _cellSet(Object? raw, String id) {
  if (raw == null) {
    return const <Cell>{};
  }
  if (raw is! List) {
    throw FormatException('puzzle "$id" has a malformed cell list');
  }
  return <Cell>{for (final Object? cell in raw) _cell(cell, id)};
}

List<String> _requireCopy(
  Map<String, dynamic> raw,
  String field,
  String id,
  int most,
) {
  final Object? value = raw[field];
  if (value is! List || value.isEmpty || value.length > most) {
    throw FormatException('puzzle "$id" needs one to $most $field');
  }
  return <String>[
    for (final Object? line in value)
      if (line is String && line.trim().isNotEmpty)
        line
      else
        throw FormatException('puzzle "$id" has an empty line in $field'),
  ];
}
