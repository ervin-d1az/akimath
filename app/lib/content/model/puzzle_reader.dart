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
    'killer' => _killer(payload, tutorial, reference, puzzleId),
    'magicSquare' => _magicSquare(payload, tutorial, reference, puzzleId),
    // A kind the contract froze but this build has no renderer for lands here.
    // Refused where the pack is read: the alternative is a player opening a
    // card and meeting a blank board.
    final Object? kind => throw FormatException(
        'puzzle "$puzzleId" is of a kind this build cannot draw: "$kind"',
      ),
  };
}

Puzzle _killer(
  Map<String, dynamic> payload,
  List<String> tutorial,
  List<String> reference,
  String id,
) {
  final (PuzzleBoard board, List<Cage> cages) = _cagedBoard(payload, id, _sumCage);
  return KillerPuzzle(
    board: board,
    cages: cages,
    tutorialSteps: tutorial,
    referenceSheet: reference,
  );
}

Puzzle _kenken(
  Map<String, dynamic> payload,
  List<String> tutorial,
  List<String> reference,
  String id,
) {
  final (PuzzleBoard board, List<Cage> cages) = _cagedBoard(payload, id, _cage);
  return KenKenPuzzle(
    board: board,
    cages: cages,
    tutorialSteps: tutorial,
    referenceSheet: reference,
  );
}

/// The most values the frozen pad can express.
///
/// `KeypadLayout.puzzle` is 5×2: nine digits and a backspace. A board needing
/// more than nine distinct values has values a player simply cannot type, which
/// is not difficulty — it is an unplayable board, and the honest place to say so
/// is where the pack is read (design D2).
///
/// Expressed as a property of the *input surface* rather than as "magic squares
/// must be 3×3", so the rule keeps working if the pad ever grows.
const int padHighestDigit = 9;

Puzzle _magicSquare(
  Map<String, dynamic> payload,
  List<String> tutorial,
  List<String> reference,
  String id,
) {
  final PuzzleBoard square = _board(payload['board'], id);
  // A magic square is made of 1 to size², each once.
  final int highest = square.size * square.size;
  if (highest > padHighestDigit) {
    throw FormatException(
      'puzzle "$id" is a ${square.size}×${square.size} magic square needing '
      '$highest values, and the pad offers $padHighestDigit — a player could '
      'not enter ${highest - padHighestDigit} of them',
    );
  }

  final List<int> rows = _targets(payload['row_targets'], square.size, id, 'row');
  final List<int> columns =
      _targets(payload['column_targets'], square.size, id, 'column');

  return MagicSquarePuzzle(
    board: PuzzleBoard(
      size: square.size,
      blocked: square.blocked,
      given: square.given,
      solution: square.solution,
      highestValue: highest,
    ),
    rowTargets: rows,
    columnTargets: columns,
    tutorialSteps: tutorial,
    referenceSheet: reference,
  );
}

List<int> _targets(Object? raw, int size, String id, String what) {
  if (raw is! List || raw.length != size) {
    throw FormatException(
      'puzzle "$id" has ${raw is List ? raw.length : 'no'} $what targets for a '
      '$size square',
    );
  }
  return <int>[
    for (final Object? target in raw)
      if (target is int && target > 0)
        target
      else
        throw FormatException('puzzle "$id" has a $what target of $target'),
  ];
}

/// The board and cages both caged formats share.
///
/// Killer is KenKen with the operation removed, so everything except how a cage
/// is parsed is the same — and duplicating this was the alternative that would
/// have let the two drift on coverage, bounds or which cell is outside a board.
(PuzzleBoard, List<Cage>) _cagedBoard(
  Map<String, dynamic> payload,
  String id,
  Cage Function(Object?, String) parseCage,
) {
  final PuzzleBoard board = _board(payload['board'], id);
  final Object? rawCages = payload['cages'];
  if (rawCages is! List || rawCages.isEmpty) {
    throw FormatException('puzzle "$id" has no cages');
  }

  final List<Cage> cages = <Cage>[
    for (final Object? cage in rawCages) parseCage(cage, id),
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

  for (final Cage cage in cages) {
    _boundTarget(cage, board.size, id);
  }

  return (board, cages);
}

/// Refuses a target no arrangement of digits could reach.
///
/// **A bound, not a reachability proof.** Every cell holds 1 to `size`, so a
/// summing cage of `n` cells lies between `n` and `n × size` — arithmetic, in
/// constant time, with nothing searched. Whether a *particular* target is
/// actually achievable given the Latin constraint is `checkCagedBoard`'s, where
/// the pack is built, and re-deriving it here is the device-side solving that
/// `no_puzzle_generation_test` exists to prevent.
///
/// It earns its place on the cheapest possible case: the frozen Killer
/// rejection row is a two-cell cage targeting 12 on a board whose cells top out
/// at 3. That is not a subtle content bug, and a reader that drew it would hand
/// a player a board with no answer.
void _boundTarget(Cage cage, int size, String id) {
  // Only for sums. `−` and `÷` cages are two cells and their targets are
  // differences and ratios, which this bound says nothing about.
  final bool sums = cage.operation == null || cage.operation == '+';
  if (!sums) {
    return;
  }
  final int cells = cage.cells.length;
  if (cage.target < cells || cage.target > cells * size) {
    throw FormatException(
      'puzzle "$id" has a $cells-cell cage targeting ${cage.target}, outside '
      'the $cells to ${cells * size} any arrangement could reach',
    );
  }
}

/// A cage whose operation the format names.
Cage _cage(Object? raw, String id) {
  final Map<String, dynamic> map = _cageMap(raw, id);
  final String operation = map['operation'] as String? ?? '';
  if (!cageOperations.contains(operation)) {
    throw FormatException('puzzle "$id" has a cage with operation "$operation"');
  }
  return _cageOf(map, id, operation);
}

/// A cage that asks for a sum and names no operation.
///
/// **An operation here is refused rather than ignored.** `KillerPayloadSchema`
/// has no such field, so one arriving means the two readers disagree about what
/// a Killer is — and ignoring it would draw a board that says less than its
/// content claims.
Cage _sumCage(Object? raw, String id) {
  final Map<String, dynamic> map = _cageMap(raw, id);
  if (map.containsKey('operation')) {
    throw FormatException(
      'puzzle "$id" has a killer cage naming an operation; killer cages sum',
    );
  }
  return _cageOf(map, id, null);
}

Map<String, dynamic> _cageMap(Object? raw, String id) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('puzzle "$id" has a malformed cage');
  }
  return raw;
}

Cage _cageOf(Map<String, dynamic> raw, String id, String? operation) {
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

  return PuzzleBoard.caged(size: size, blocked: blocked, given: given, solution: grid);
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
