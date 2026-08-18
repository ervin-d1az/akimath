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
  });

  final KenKenPuzzle puzzle;

  /// Leaves the puzzle. Defaults to popping, so a pushed board always has an
  /// exit even if a caller forgets to wire one — the same rule the round
  /// follows, and for the same reason: a full-screen session has no system
  /// back on iOS.
  final VoidCallback? onClose;

  /// Called once, when the last cell makes the board correct.
  final VoidCallback? onSolved;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  late PuzzleEntry _entry = PuzzleEntry.of(widget.puzzle.board);
  bool _reported = false;
  bool _rulesOpen = false;

  void _apply(PuzzleEntry next) {
    setState(() => _entry = next);
    // Once, and only on the transition. A callback that fired on every keystroke
    // after completion would push a verdict screen per digit.
    if (!_reported && next.isSolved) {
      _reported = true;
      widget.onSolved?.call();
    }
  }

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
                    cages: widget.puzzle.cages,
                    onTapCell: (Cell cell) => _apply(_entry.select(cell)),
                  ),
                ),
              ),
              const SizedBox(height: BrandShape.space3),
              Keypad(layout: KeypadLayout.puzzle, onKeyPressed: _onKey),
            ],
          ),
        ),
      ),
    );
  }

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
        Text('KENKEN', style: BrandText.eyebrow()),
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
