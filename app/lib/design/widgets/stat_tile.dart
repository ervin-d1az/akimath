import 'package:flutter/widgets.dart';

import '../math/spec/es_mx_number.dart';
import '../tokens/tokens.dart';

/// How prominent a stat tile is.
///
/// Three variants, not three widgets: they differ in radius, shadow and value
/// size and in nothing else.
enum StatTileVariant {
  /// `03 Acierto`'s tiles.
  raised(
      radius: BrandShape.radiusStatTileRaised,
      valueSize: 26,
      shadow: BrandShape.shadowTile,
  ),

  /// `2.5`'s tiles.
  compact(
      radius: BrandShape.radiusStatTileCompact,
      valueSize: 24,
      shadow: BrandShape.shadowTile,
  ),

  /// `04 Error`'s flat tiles. No shadow.
  flat(
      radius: BrandShape.radiusStatTileFlat,
      valueSize: 22,
      shadow: null,
  );

  const StatTileVariant({
    required this.radius,
    required this.valueSize,
    required this.shadow,
  });

  final double radius;
  final double valueSize;
  final Offset? shadow;
}

/// A measured number with a label under it.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.variant = StatTileVariant.raised,
  });

  /// A tile showing a signed change.
  ///
  /// **The sign and the digits are two runs, not one span.** They are set in
  /// different faces and sizes, and `EsMxNumber.deltaParts` returns them
  /// separately precisely so no tile concatenates a minus by hand and lands a
  /// hyphen where the brand requires U+2212.
  factory StatTile.delta({
    required String label,
    required int delta,
    StatTileVariant variant = StatTileVariant.raised,
  }) {
    final DeltaParts parts = EsMxNumber.deltaParts(delta);
    return StatTile(
      label: label,
      variant: variant,
      value: _DeltaValue(parts: parts, digitSize: variant.valueSize),
    );
  }

  final String label;

  /// The tile's figure. A widget rather than a string, because a delta is two
  /// differently-set runs.
  final Widget value;

  final StatTileVariant variant;

  @override
  Widget build(BuildContext context) {
    final Offset? shadow = variant.shadow;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space3,
        vertical: BrandShape.space2,
      ),
      decoration: BoxDecoration(
        color: BrandColors.surface,
        borderRadius: BorderRadius.circular(variant.radius),
        border: Border.all(
          color: BrandColors.ink,
          width: BrandShape.borderWidth,
        ),
        boxShadow: <BoxShadow>[
          if (shadow != null)
            BoxShadow(
              color: BrandColors.ink,
              offset: shadow,
              blurRadius: 0,
              spreadRadius: 0,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          value,
          const SizedBox(height: BrandShape.space1),
          Text(label, style: BrandText.eyebrow()),
        ],
      ),
    );
  }
}

/// A plain figure.
class StatValue extends StatelessWidget {
  const StatValue(this.text, {super.key, this.size = 26});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: BrandText.numeral(size));
}

/// A signed change, set as two runs sharing a baseline.
class _DeltaValue extends StatelessWidget {
  const _DeltaValue({required this.parts, required this.digitSize});

  final DeltaParts parts;
  final double digitSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        if (parts.sign.isNotEmpty) ...<Widget>[
          // 15 against the digits' 22, and a 3px gap: the sign is a modifier
          // on the number, not a second number beside it.
          Text(parts.sign, style: BrandText.action(size: 15)),
          const SizedBox(width: 3),
        ],
        Text(parts.digits, style: BrandText.numeral(digitSize)),
      ],
    );
  }
}
