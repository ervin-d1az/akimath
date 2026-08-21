import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';

/// The small annotation a state screen hangs under its copy.
///
/// **Extracted at its second caller, which is what its first one asked for.**
/// `StreakAtRiskScreen._runway` carried this shape with a note saying *"`4.10`
/// wants the same chip and `4.10` is not built. A widget with one caller is a
/// name nobody needs yet, and the second caller is where the shape gets
/// settled."* `4.10` is built, so it is settled here.
///
/// It lives in `features/states/` rather than in `design/widgets/` because both
/// callers are state screens and neither the round nor the boards want it; a
/// shared widget with two neighbouring callers is not yet a design primitive.
///
/// **Two tones, because the design sets the two differently and means it.**
/// The surface is identical — white, a thin outline, radius 14, no shadow — and
/// only the lettering moves: `4.12`'s runway is the figure the screen is
/// protecting and is set heavy and tracked, while `4.10`'s error code is an
/// annotation nobody is meant to read first.
class StateChip extends StatelessWidget {
  /// `4.12`'s runway: the quantity the screen is about.
  const StateChip.emphasis({super.key, required this.label})
      : _tracked = true;

  /// `4.10`'s error code: an annotation under the copy.
  const StateChip.note({super.key, required this.label}) : _tracked = false;

  final String label;

  final bool _tracked;

  @override
  Widget build(BuildContext context) => CandySurface(
    borderWidth: BrandShape.borderWidthSmallSurface,
    borderRadius: BrandShape.radiusChip,
    shadowOffset: Offset.zero,
    padding: const EdgeInsets.symmetric(
      horizontal: BrandShape.space4,
      vertical: BrandShape.space2,
    ),
    alignment: Alignment.center,
    child: Text(
      label,
      style: _tracked
          ? BrandText.eyebrow(size: 12, letterSpacing: 0.06)
          : BrandText.caption(size: 12),
    ),
  );
}
