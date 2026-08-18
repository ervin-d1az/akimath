import 'package:flutter/widgets.dart';

import '../icons/brand_icon.dart';
import '../math/fraction_glyph.dart';
import '../tokens/tokens.dart';
import 'pressable_surface.dart';
import 'spec/keypad_layout.dart';

/// One key, rendering any [KeyFace].
///
/// It is [PressableSurface] plus fixed geometry, so the press rule is inherited
/// rather than restated — a key travels into its own shadow like everything
/// else, and the 48 px hit box comes free even when the drawn key is smaller on
/// a narrow device.
class KeypadKeyView extends StatelessWidget {
  const KeypadKeyView({
    super.key,
    required this.data,
    required this.onPressed,
    required this.height,
    required this.iconSize,
  });

  final KeypadKey data;
  final ValueChanged<KeypadKey> onPressed;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onPressed: () => onPressed(data),
      height: height,
      borderRadius: BrandShape.radiusPill,
      shadow: BrandShape.shadowTile,
      child: Center(child: _face()),
    );
  }

  Widget _face() {
    return switch (data.face) {
      TextFace(:final String text) => Text(
          text,
          textScaler: TextScaler.noScaling,
          style: BrandText.numeral(iconSize * 1.2),
        ),
      IconFace(:final BrandGlyph glyph) => BrandIcon(glyph, size: iconSize),
      // 15px, per the digest: `a` over a 20x3 bar over `b`. The plain variant
      // takes a size and never a FractionMetrics — the invariant that keeps the
      // F0/F1b split honest (design D5).
      FractionFace(:final String numerator, :final String denominator) =>
        FractionGlyph(
          numerator: numerator,
          denominator: denominator,
          size: 15,
        ),
    };
  }
}

/// A numeric pad, laid out from a [KeypadLayout].
///
/// **It holds no answer rule.** It reports which key was pressed and nothing
/// else: it does not accumulate an answer, validate one, or know what a valid
/// answer looks like. `ARCHITECTURE.md` §4 keeps the answer off the wire and
/// `packages/contract` already froze what a canonical answer is — a keypad that
/// assembled one would be a second place that knows the rule, on the client
/// (design D4).
///
/// The system keyboard never appears. `CLAUDE.md` forbids it for numeric entry,
/// and `keypad_test.dart` asserts no `EditableText` reaches the tree.
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.layout,
    required this.onKeyPressed,
  });

  final KeypadLayout layout;
  final ValueChanged<KeypadKey> onKeyPressed;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];

    for (int i = 0; i < layout.keys.length; i += layout.columns) {
      final List<KeypadKey> rowKeys =
          layout.keys.skip(i).take(layout.columns).toList();

      rows.add(
        Row(
          children: <Widget>[
            for (int c = 0; c < rowKeys.length; c++) ...<Widget>[
              if (c > 0) SizedBox(width: layout.gap),
              Expanded(
                child: KeypadKeyView(
                  data: rowKeys[c],
                  onPressed: onKeyPressed,
                  height: layout.keyHeight,
                  iconSize: layout.iconSize,
                ),
              ),
            ],
          ],
        ),
      );
      if (i + layout.columns < layout.keys.length) {
        rows.add(SizedBox(height: layout.gap));
      }
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}
