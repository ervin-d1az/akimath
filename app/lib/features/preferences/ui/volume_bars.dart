import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/pressable_surface.dart';

/// One bar of the volume row.
///
/// Public rather than private so its own test can read [height] and [filled]
/// instead of digging a colour out of a decoration — a test that reads the
/// widget says what it means.
class VolumeBar extends StatelessWidget {
  const VolumeBar({super.key, required this.height, required this.filled});

  /// The drawn height. It is the bar's whole content: the row reads as a scale
  /// because the bars climb, not because they are coloured.
  final double height;

  /// Whether this step is inside the chosen level.
  final bool filled;

  /// The design's bar corner — smaller than every named radius, because it is
  /// the smallest rounded rect the app draws and a 20 would turn an 18 px bar
  /// into a lozenge. (BRD-2c: a deliberate departure, with its reason.)
  static const double _radius = 6;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: filled ? BrandColorRole.highlight.color : BrandColors.cream,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: BrandColors.ink,
          width: BrandShape.borderWidthSmallSurface,
        ),
      ),
    );
  }
}

/// `4.6`'s volume: five bars of climbing height, filled up to the chosen one.
///
/// **A row of presses, not a slider.** The design draws five discrete bars and
/// the policy behind it is a closed set of five steps, so a drag would produce
/// values the row cannot show. It is the same argument [SettingsChoiceRow]
/// makes, with the bar's own height as its label.
///
/// **The short bars still clear 48 px.** The first is drawn 18 px tall; the
/// press wrapping it is the full row height, so the target is the slot rather
/// than the paint — DR-6's answer, and the reason the bars are bottom-aligned
/// inside it rather than centred.
class VolumeBars extends StatelessWidget {
  const VolumeBars({super.key, required this.level, required this.onSelected});

  /// How many bars are filled, counting from one.
  final int level;

  /// Called with the level pressed, counting from one.
  final ValueChanged<int> onSelected;

  /// The design's five bars.
  static const int steps = 5;

  /// Their drawn heights, which is the row's content.
  static const List<double> _heights = <double>[18, 26, 34, 44, 52];

  /// The slot each bar sits at the bottom of. The tallest bar, and the floor
  /// `PressableSurface` would impose anyway.
  static const double _slotHeight = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _slotHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int step = 1; step <= steps; step++) ...<Widget>[
            if (step > 1) const SizedBox(width: BrandShape.space2),
            Expanded(child: _slot(step)),
          ],
        ],
      ),
    );
  }

  Widget _slot(int step) {
    return PressableSurface(
      onPressed: () => onSelected(step),
      pressEffect: PressEffect.none,
      // No fill and no outline: the slot is the target, the bar is the drawing.
      background: null,
      outlined: false,
      height: _slotHeight,
      width: double.infinity,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: VolumeBar(
          height: _heights[step - 1],
          filled: step <= level,
        ),
      ),
    );
  }
}
