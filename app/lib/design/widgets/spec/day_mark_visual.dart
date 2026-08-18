import 'dart:ui' show Color;

// The one token file, not the barrel: `tokens.dart` re-exports
// `brand_typography.dart`, which imports `package:flutter/painting.dart` — and
// a pure module that reaches for the barrel fails `pure_boundary_test`.
import '../../tokens/brand_colors.dart';

/// Whether a day in the week strip was played.
enum DayMark { played, missed }

/// How a day mark is drawn.
///
/// **Two differences, not one.** BRD-1: a state communicated by hue alone is
/// invisible to a reader with deuteranopia, so a played day is filled *and*
/// solid-outlined while a missed one is hollow. The same rule the verdict ring
/// and the stimulus hole already follow.
///
/// **PURE**, and here rather than inline in the widget, because
/// `no_hue_by_comparison_test` fails a widget that picks a colour with a
/// conditional — and rightly: the thresholds that give a hue its meaning should
/// not be scattered across the screens that draw them.
class DayMarkVisual {
  const DayMarkVisual({required this.fill, required this.border, required this.filled});

  final Color fill;
  final Color border;

  /// Whether the dot is solid. The half of the distinction that survives with
  /// the hue gone.
  final bool filled;
}

DayMarkVisual resolveDayMark(DayMark mark) => switch (mark) {
      DayMark.played => const DayMarkVisual(
          fill: BrandColors.green,
          border: BrandColors.ink,
          filled: true,
        ),
      DayMark.missed => const DayMarkVisual(
          fill: BrandColors.surface,
          border: BrandColors.muted,
          filled: false,
        ),
    };
