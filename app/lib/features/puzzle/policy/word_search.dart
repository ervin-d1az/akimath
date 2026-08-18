/// Claiming words in a grid, as a player works through one.
///
/// The reading itself is `content/model/word_grid.dart`, shared with the reader
/// so the two cannot disagree about which directions count.
library;

import '../../../content/model/puzzle.dart';
import '../../../content/model/word_grid.dart';

/// A word search mid-solve.
class WordSearchProgress {
  const WordSearchProgress({required this.puzzle, this.found = const <String>{}});

  final WordSearchPuzzle puzzle;

  /// The words already claimed.
  final Set<String> found;

  /// Claims whatever [trace] spells, if it spells a word still to be found.
  ///
  /// A word traced backwards is the same word: the line is read both ways,
  /// because which end a player started from is not part of the puzzle.
  WordSearchProgress claim(List<Cell> trace) {
    final String? forwards = lineReads(puzzle.grid, trace);
    if (forwards == null) {
      return this;
    }
    final String backwards = String.fromCharCodes(forwards.runes.toList().reversed);

    for (final String word in <String>[forwards, backwards]) {
      if (puzzle.words.contains(word) && !found.contains(word)) {
        return WordSearchProgress(
          puzzle: puzzle,
          found: <String>{...found, word},
        );
      }
    }
    return this;
  }

  bool get isSolved => puzzle.words.every(found.contains);
}
