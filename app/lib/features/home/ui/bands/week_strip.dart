import 'package:flutter/widgets.dart';

import '../../../../design/tokens/tokens.dart';
import '../../../../design/widgets/spec/day_mark_visual.dart';

/// `RACHA · 7 DÍAS` over seven day marks.
///
/// The bare `7` this replaces told a player a total they had to trust. Seven
/// marks ending on today say *which* days were played, which is the fact a
/// total cannot carry — and a gap is visible rather than merely subtracted.
///
/// The marks come from `weekMarks`, which computes them beside `streakLength`
/// so both walk the same calendar arithmetic.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.marks, required this.streakDays});

  /// Seven days, oldest first, ending today.
  final List<bool> marks;

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('RACHA', style: BrandText.eyebrow()),
            Text(
              streakDays == 1 ? '1 DÍA' : '$streakDays DÍAS',
              style: BrandText.eyebrow(color: BrandColors.ink),
            ),
          ],
        ),
        const SizedBox(height: BrandShape.space2),
        // **Grouped, not spread.** `spaceBetween` across the full width put
        // 40 px between neighbouring days, which reads as seven unrelated dots
        // rather than one week.
        Row(
          children: <Widget>[
            for (int i = 0; i < marks.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: BrandShape.space2),
              _Dot(mark: marks[i] ? DayMark.played : DayMark.missed),
            ],
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.mark});

  final DayMark mark;

  /// Comfortably visible at a glance, and small enough that seven fit a phone
  /// with room between them at large text.
  static const double _size = 18;

  @override
  Widget build(BuildContext context) {
    final DayMarkVisual visual = resolveDayMark(mark);
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: visual.fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: visual.border,
          width: BrandShape.borderWidthSmallSurface,
        ),
      ),
    );
  }
}
