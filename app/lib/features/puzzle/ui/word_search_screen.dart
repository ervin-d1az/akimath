import 'package:flutter/material.dart';

import '../../../content/model/puzzle.dart';
import '../../../design/icons/brand_icon.dart';
import '../../../design/puzzle/spec/board_geometry.dart' show GridCell;
import '../../../design/puzzle/spec/letter_grid_geometry.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/icon_button_tile.dart';
import '../policy/word_search.dart';

/// A grid of letters and the words hidden in it.
///
/// **Its own screen** (design D1). `PuzzleScreen` composes a board and a
/// keypad, and this format has neither — bending it to draw letters with no pad
/// would make every future change to either one a change to a single widget.
///
/// A word is claimed by dragging across a line of cells. What that line spells,
/// and whether it counts, is `WordSearchProgress`'s — so all of it is tested
/// without a gesture and this widget only has to produce the list of cells.
class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({
    super.key,
    required this.puzzle,
    this.onClose,
    this.onSolved,
  });

  final WordSearchPuzzle puzzle;
  final VoidCallback? onClose;
  final VoidCallback? onSolved;

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  late WordSearchProgress _progress =
      WordSearchProgress(puzzle: widget.puzzle);
  List<Cell> _trace = <Cell>[];
  bool _reported = false;
  bool _rulesOpen = false;

  int get _columns => widget.puzzle.grid.first.length;

  void _extendTo(Cell cell) {
    if (_trace.isNotEmpty && _trace.last == cell) {
      return;
    }
    setState(() => _trace = <Cell>[..._trace, cell]);
  }

  void _release() {
    final WordSearchProgress next = _progress.claim(_trace);
    setState(() {
      _progress = next;
      _trace = <Cell>[];
    });
    if (!_reported && next.isSolved) {
      _reported = true;
      widget.onSolved?.call();
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
              if (_rulesOpen) _rules(),
              Expanded(child: Center(child: _grid())),
              const SizedBox(height: BrandShape.space3),
              _wordList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Semantics(
            label: 'Salir',
            button: true,
            child: IconButtonTile(
              onPressed:
                  widget.onClose ?? () => Navigator.of(context).maybePop(),
              child: const BrandIcon(BrandGlyph.close, size: 22),
            ),
          ),
          Text('SOPA DE LETRAS', style: BrandText.eyebrow()),
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

  Widget _rules() => Padding(
        padding: const EdgeInsets.only(bottom: BrandShape.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String line in widget.puzzle.referenceSheet)
              Text('· $line', style: BrandText.caption()),
          ],
        ),
      );

  /// **One gesture for the whole grid**, not one per cell.
  ///
  /// A pan is delivered to the widget the pointer went down on and to nothing
  /// else, so per-cell detectors can see the first letter of a word and never
  /// the rest. `letterAt` turns the pointer's position into a cell instead.
  Widget _grid() {
    return AspectRatio(
      aspectRatio: _columns / widget.puzzle.grid.length,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size box = constraints.biggest;
          void reach(Offset local) {
            final GridCell? at = letterAt(
              local,
              box: box,
              rows: widget.puzzle.grid.length,
              columns: _columns,
            );
            if (at != null) {
              _extendTo(Cell(row: at.row, col: at.col));
            }
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (DragStartDetails d) => reach(d.localPosition),
            onPanUpdate: (DragUpdateDetails d) => reach(d.localPosition),
            onPanEnd: (_) => _release(),
            // A pan that never moved is cancelled rather than ended, and a
            // trace left standing would join the next one into a line that
            // spells something neither of them did.
            onPanCancel: _release,
            child: Column(
              children: <Widget>[
                for (int row = 0; row < widget.puzzle.grid.length; row++)
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        for (int col = 0; col < _columns; col++)
                          Expanded(child: _letter(Cell(row: row, col: col))),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _letter(Cell cell) {
    final bool tracing = _trace.contains(cell);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The neutral highlight, the same yellow the stimulus hole uses for
          // "this is the thing you are working on".
          color: tracing ? BrandColors.yellow : BrandColors.surface,
          border: Border.all(
            color: BrandColors.muted,
            width: BrandShape.borderWidthField,
          ),
        ),
        child: Center(
          child: Text(
            widget.puzzle.grid[cell.row][cell.col],
            style: BrandText.numeral(18),
          ),
        ),
      ),
    );
  }

  /// **A found word is struck through, not merely dimmed** (design D4, BRD-1).
  /// Dimming is a hue difference; a line through the word survives with the hue
  /// gone.
  Widget _wordList() {
    return CandySurface(
      borderRadius: BrandShape.radiusChip,
      padding: const EdgeInsets.all(BrandShape.space3),
      child: Wrap(
        spacing: BrandShape.space3,
        runSpacing: BrandShape.space2,
        children: <Widget>[
          for (final String word in widget.puzzle.words)
            Text(
              word,
              style: BrandText.caption().copyWith(
                decoration: _progress.found.contains(word)
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: _progress.found.contains(word)
                    ? BrandColors.muted
                    : BrandColors.ink,
              ),
            ),
        ],
      ),
    );
  }
}
