import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// The two sizes a stat pill ships at.
///
/// **K8, decided 2026-08-15, and it needed deciding rather than assuming.** The
/// first draft collapsed `0.6`'s rating chip into [header] and landed the wrong
/// radius and the wrong shadow — the same failure the plan warns about with
/// `CandySurface.pill`. The second removed `4.12`'s badge for that reason and
/// left both screens holding local compositions.
///
/// Compared to **each other** rather than each to the default, `0.6` (h64, r22,
/// shadow (4,6)) and `4.12` (h56, r22, shadow (4,6) on yellow) agree on radius
/// and shadow and differ only in height and fill — a size and a `background`,
/// both of which this widget already carries. Comparing each screen to the
/// default instead of to its sibling is what hid the shared geometry for two
/// drafts.
enum StatPillSize {
  /// `01` and `2.1`. A fixed height.
  header(radius: 24, shadow: BrandShape.shadowTile, height: 48),

  /// `0.6`'s rating chip and `4.12`'s streak badge. Height from the call site.
  hero(radius: 22, shadow: BrandShape.shadowButton, height: null);

  const StatPillSize({
    required this.radius,
    required this.shadow,
    required this.height,
  });

  final double radius;
  final Offset shadow;

  /// Null means the call site decides.
  final double? height;
}

/// A rounded, outlined figure — a rating, a streak, a count.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.child,
    this.size = StatPillSize.header,
    this.background = BrandColors.surface,
    this.height,
  });

  final Widget child;
  final StatPillSize size;
  final Color background;

  /// Overrides the size's own height. Required by [StatPillSize.hero], which
  /// declares none.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? size.height,
      padding: const EdgeInsets.symmetric(horizontal: BrandShape.space4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size.radius),
        border: Border.all(
          color: BrandColors.ink,
          width: BrandShape.borderWidth,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: BrandColors.ink,
            offset: size.shadow,
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The counter chip: `5 retos`, `3 / 9`.
///
/// Outlined, unfilled, no shadow — it counts rather than announces.
class OutlinedChip extends StatelessWidget {
  const OutlinedChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space3,
        vertical: BrandShape.space1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BrandShape.radiusChip),
        border: Border.all(
          color: BrandColors.ink,
          width: BrandShape.borderWidthField,
        ),
      ),
      child: Text(label, style: BrandText.eyebrow(color: BrandColors.ink)),
    );
  }
}
