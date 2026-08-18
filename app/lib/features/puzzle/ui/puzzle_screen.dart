import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';

import '../../../content/model/puzzle.dart';
import '../../../design/icons/brand_icon.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/icon_button_tile.dart';
import '../../../design/widgets/keypad.dart';
import '../../../design/widgets/spec/keypad_layout.dart';
import '../policy/puzzle_entry.dart';
import 'puzzle_board_view.dart';

/// A KenKen, played.
///
/// The board, the 5×2 pad that has existed since F0 and been wired to nothing,
/// and one way out. It holds the entry and nothing else — what a tap or a digit
/// means is `PuzzleEntry`'s, which is why all of that is tested without pumping
/// a screen.
///
/// **The reference sheet travels with the puzzle** and is shown on demand
/// rather than on arrival: the rules of a KenKen are three lines, and three
/// lines in front of a board is a wall between a player and the thing they came
/// for.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({
    super.key,
    required this.puzzle,
    this.onClose,
    this.onSolved,
    this.onPractised,
  });

  /// Any puzzle played on the shared square. A word search is not one, and the
  /// type says so rather than a getter throwing.
  final BoardPuzzle puzzle;

  /// Leaves the puzzle. Defaults to popping, so a pushed board always has an
  /// exit even if a caller forgets to wire one — the same rule the round
  /// follows, and for the same reason: a full-screen session has no system
  /// back on iOS.
  final VoidCallback? onClose;

  /// Called once, when the last cell makes the board correct.
  final VoidCallback? onSolved;

  /// Called once, the first time a value lands on the board.
  ///
  /// **Not on solve** (design D1): a puzzle is a longer commitment than an item,
  /// and a player who works on one for half an hour and leaves it unfinished has
  /// practised. It is the board's analogue of a round submitting an answer —
  /// which records the day right or wrong.
  ///
  /// The screen reports; the route records. It holds no store, because the two
  /// puzzle formats commit differently and the same IO decision written twice
  /// is free to diverge.
  final VoidCallback? onPractised;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  late PuzzleEntry _entry = PuzzleEntry.of(widget.puzzle.board);
  bool _reported = false;
  bool _practised = false;
  bool _rulesOpen = false;

  void _apply(PuzzleEntry next) {
    // **What landed on the board**, not what was pressed. Selecting a cell, and
    // a digit the board cannot hold, both leave `filled` alone — and neither
    // asserts anything about the puzzle.
    final bool committed = !mapEquals(next.filled, _entry.filled);
    setState(() => _entry = next);
    if (!_practised && committed) {
      _practised = true;
      widget.onPractised?.call();
    }
    // Once, and only on the transition. A callback that fired on every keystroke
    // after completion would push a verdict screen per digit.
    if (!_reported && next.isSolved) {
      _reported = true;
      widget.onSolved?.call();
    }
  }

  /// The digits this board cannot hold.
  ///
  /// A 3×3 KenKen admits 1 to 3, so 4 to 9 are shown unavailable rather than quietly
  /// doing nothing. `PuzzleEntry` refuses them either way — this changes what a
  /// player is invited to press, not what happens if they do.
  Set<String> get _tooLarge => <String>{
        for (int digit = widget.puzzle.board.highestValue + 1; digit <= 9; digit++)
          '$digit',
      };

  void _onKey(KeypadKey key) {
    if (key.id == 'backspace') {
      _apply(_entry.clear());
      return;
    }
    final int? value = int.tryParse(key.emits ?? '');
    if (value != null) {
      _apply(_entry.type(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BrandShape.space4,
            vertical: BrandShape.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _header(),
              const SizedBox(height: BrandShape.space3),
              if (_rulesOpen) _rules() else const SizedBox.shrink(),
              Expanded(
                child: Center(
                  child: PuzzleBoardView(
                    entry: _entry,
                    cages: switch (widget.puzzle) {
                      final CagedPuzzle caged => caged.cages,
                      _ => const <Cage>[],
                    },
                    rowTargets: switch (widget.puzzle) {
                      MagicSquarePuzzle(:final List<int> rowTargets) => rowTargets,
                      _ => const <int>[],
                    },
                    columnTargets: switch (widget.puzzle) {
                      MagicSquarePuzzle(:final List<int> columnTargets) =>
                        columnTargets,
                      _ => const <int>[],
                    },
                    runs: switch (widget.puzzle) {
                      KakuroPuzzle(:final List<Run> runs) => runs,
                      _ => const <Run>[],
                    },
                    onTapCell: (Cell cell) => _apply(_entry.select(cell)),
                  ),
                ),
              ),
              const SizedBox(height: BrandShape.space3),
              Keypad(
                layout: KeypadLayout.puzzle,
                onKeyPressed: _onKey,
                unavailable: _tooLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The kind, named for the player. Switched over the sealed type so a third
  /// caged format is a compile error here rather than a board labelled KENKEN.
  String get _title => switch (widget.puzzle) {
        KenKenPuzzle() => 'KENKEN',
        KillerPuzzle() => 'SUMAS',
        MagicSquarePuzzle() => 'CUADRO MÁGICO',
        KakuroPuzzle() => 'KAKURO',
      };

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // **Labelled**, because a glyph-only control says nothing to a screen
        // reader — and this one is the only way out of a full-screen session.
        Semantics(
          label: 'Salir',
          button: true,
          child: IconButtonTile(
            onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
            child: const BrandIcon(BrandGlyph.close, size: 22),
          ),
        ),
        Text(_title, style: BrandText.eyebrow()),
        Semantics(
          label: 'Cómo se juega',
          button: true,
          child: IconButtonTile(
            toggled: _rulesOpen,
            onPressed: () => setState(() => _rulesOpen = !_rulesOpen),
            child: const BrandIcon(BrandGlyph.hint, size: 22),
          ),
        ),
      ],
    );
  }

  /// The rules the pack carried, in es-MX. Never invented here — a board whose
  /// rules were hard-coded could not have a second kind.
  Widget _rules() {
    return Padding(
      padding: const EdgeInsets.only(bottom: BrandShape.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final String line in widget.puzzle.referenceSheet)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('· $line', style: BrandText.caption()),
            ),
        ],
      ),
    );
  }
}
