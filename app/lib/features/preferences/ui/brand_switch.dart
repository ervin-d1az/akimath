import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';

/// The two-state switch `4.4`, `4.5` and `4.6` draw beside a label.
///
/// **It is paint, not a control.** There is no gesture here on purpose: a
/// 60×34 switch with its own detector is 14 pixels short of
/// `BrandShape.minTouchTarget` in one dimension and is the classic way a
/// settings list fails `touch_target_test`. [SettingsToggleRow] owns the press,
/// so the whole row is the target and this only says which way it is set.
///
/// **The knob's side is the second channel.** The track's fill is the obvious
/// one and it is the one a reader with deuteranopia loses, so the knob moves —
/// the same reasoning BRD-1 applies to a verdict, applied to a control.
///
/// No shadow: the design draws none on a switch, which is why the surface's
/// offset is [Offset.zero] rather than a token.
class BrandSwitch extends StatelessWidget {
  const BrandSwitch({super.key, required this.isOn});

  /// Which way it is set. The row above it decides what that means.
  final bool isOn;

  /// The knob, so a test can read which side it is on.
  static const Key knobKey = Key('brand-switch-knob');

  /// The design's track.
  static const double trackWidth = 60;
  static const double trackHeight = 34;

  /// The design's knob, and the gap it sits in.
  static const double _knobSize = 24;
  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    return CandySurface(
      width: trackWidth,
      height: trackHeight,
      borderRadius: BrandShape.radiusPill,
      shadowOffset: Offset.zero,
      background: isOn ? BrandColorRole.action.color : BrandColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: _inset),
      alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
      child: CandySurface(
        key: knobKey,
        width: _knobSize,
        height: _knobSize,
        // Half the box, because the knob is a circle. Derived rather than
        // typed, so the two cannot drift apart.
        borderRadius: _knobSize / 2,
        borderWidth: BrandShape.borderWidthSmallSurface,
        shadowOffset: Offset.zero,
        // Cream against the green track and white against the white one, so
        // the knob is visible either way. Neither reads as state: the track
        // carries that.
        background: isOn ? BrandColors.surface : BrandColors.cream,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
