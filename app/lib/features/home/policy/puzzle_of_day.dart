import '../../../content/model/puzzle.dart';

/// The day the epoch counts from. Arbitrary, and fixed forever: moving it
/// would shuffle every player's rotation for no reason a player could see.
final DateTime _epoch = DateTime.utc(2026, 1, 1);

/// How many days have passed, counted in calendar days.
///
/// **PURE**, and **UTC arithmetic over local components** (design D2). The
/// components are the player's, so "today" is their today; the subtraction is
/// in UTC, so it contains no daylight-saving transition. A 23-hour local day is
/// still one day — `Duration` arithmetic over local `DateTime`s loses exactly
/// that, which is the bug `streak_policy_test` guards against under
/// `TZ=America/Tijuana`.
int dayNumber(DateTime moment) =>
    DateTime.utc(moment.year, moment.month, moment.day).difference(_epoch).inDays;

/// One board of each kind the pack carries: the day's.
///
/// **PURE.** No clock — the caller says which day — and no storage.
///
/// A cursor advanced on each visit would need a store, would drift between the
/// home and the card, and would hand a player a different board every time they
/// tapped in and out. A day number needs none of that: it is the same all day,
/// so leaving a puzzle and coming back continues it (design D1).
///
/// Kinds come in the order their first board appears in the pack, and boards
/// within a kind keep their pack order — both content decisions, and the pack
/// is where content decisions are made.
List<Puzzle> puzzlesOfDay(List<Puzzle> puzzles, {required DateTime today}) {
  final Map<String, List<Puzzle>> byKind = <String, List<Puzzle>>{};
  for (final Puzzle puzzle in puzzles) {
    // Insertion order is first-appearance order, which is what `Map` preserves.
    byKind.putIfAbsent(puzzleKindOf(puzzle), () => <Puzzle>[]).add(puzzle);
  }

  final int day = dayNumber(today);
  return <Puzzle>[
    for (final List<Puzzle> boards in byKind.values)
      // **A negative day needs no folding.** A device's clock can be set before
      // the epoch, and in C or JavaScript `-9862 % 2` is negative and this
      // would be a crash. Dart's `%` is Euclidean: for a positive divisor the
      // result is always in range. Written as one modulo rather than three,
      // with the before-the-epoch case asserted so the claim is checked and
      // not merely believed.
      boards[day % boards.length],
  ];
}

/// The frozen kind name, from the sealed type.
///
/// Exhaustive, so a sixth format cannot be added without deciding which kind it
/// groups under — the same discipline `puzzleName` applies to what it is called.
String puzzleKindOf(Puzzle puzzle) => switch (puzzle) {
      KenKenPuzzle() => 'kenken',
      KillerPuzzle() => 'killer',
      MagicSquarePuzzle() => 'magicSquare',
      KakuroPuzzle() => 'kakuro',
      WordSearchPuzzle() => 'wordSearch',
    };
