import '../../../content/model/puzzle.dart';

/// What a player calls each puzzle.
///
/// **PURE** — a sealed switch, no widget and no context. The names are
/// es-MX because they are the only thing here a player reads; everything
/// around them stays English.
///
/// Exhaustive over `Puzzle`, which is the point: a sixth format cannot be
/// added without deciding what the home should call it, because the switch
/// stops compiling until it is named.
String puzzleName(Puzzle puzzle) => switch (puzzle) {
      KenKenPuzzle() => 'KenKen',
      // Not "Killer sudoku": the pack is Mexican Spanish and the English name
      // is both untranslated and, for a general audience, alarming.
      KillerPuzzle() => 'Suma con jaulas',
      MagicSquarePuzzle() => 'Cuadro mágico',
      KakuroPuzzle() => 'Kakuro',
      WordSearchPuzzle() => 'Sopa de letras',
    };

/// The names of everything the pack carries, in pack order.
///
/// **The pack's order, not the frozen list's.** Which puzzle a player meets
/// first is a content decision, and the pack is where content decisions are
/// made — the same reason `seriesPlan` takes items in pack order.
///
/// A repeated kind is named twice rather than folded away: a pack may carry
/// two word searches, and dropping the second would hide a puzzle.
List<String> puzzleMenu(List<Puzzle> puzzles) =>
    <String>[for (final Puzzle puzzle in puzzles) puzzleName(puzzle)];
