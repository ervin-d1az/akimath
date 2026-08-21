import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/pressable_surface.dart';

/// One chip in a [SettingsChoiceRow].
@immutable
class SettingsChoiceOption {
  const SettingsChoiceOption({required this.label, this.labelSize});

  /// What the chip reads. `07:00` on `4.4`, a single `A` on `4.5`.
  final String label;

  /// The size that label is drawn at, where the option's own size is the point.
  ///
  /// `4.5` draws four A's at climbing sizes: the chip is a **preview** of what
  /// it selects, so the size is content rather than styling. Null everywhere
  /// else, and the row uses its own.
  final double? labelSize;
}

/// Pick one of a fixed few — `4.4`'s three hours, `4.5`'s four text sizes.
///
/// **A closed row rather than a picker.** Both settings behind it are closed
/// sets in `policy/`, so there is never an option the row cannot draw.
///
/// **One press per option and 48 px each**, which the design's own geometry
/// does not give: its hour chips are 40 px tall. `PressableSurface` keeps the
/// hit box at the floor while the paint stays as drawn, which is the answer
/// DR-6 names for a control deliberately drawn small.
///
/// The chips carry no shadow, which is why each names [PressEffect.none] — the
/// design draws none, so there is nothing for the press to travel into.
class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.unselectedBackground = BrandColors.cream,
  });

  final List<SettingsChoiceOption> options;

  /// Which option is set, by its index in [options].
  final int selected;

  final ValueChanged<int> onSelected;

  /// `4.5` draws its unselected chips on cream, `4.4` on white. Neither carries
  /// state — the selected one does, and it is the highlight.
  final Color unselectedBackground;

  /// The design's chip, as a floor.
  static const double minChipHeight = 40;

  /// What a chip's label is drawn at when the option does not say.
  static const double _labelSize = 12;

  @override
  Widget build(BuildContext context) {
    // **`IntrinsicHeight`, because the chips must match and the column above
    // them is unbounded.** The design draws one row of equal boxes, which is
    // `CrossAxisAlignment.stretch` — and a stretched `Row` inside a `ListView`
    // has no height to stretch to and fails its own layout. Measured: the four
    // A's of `4.5` and the three hours of `4.4` both crashed on `hasSize`
    // until this wrapped them, while the same row inside a `Center` passed,
    // which is why the test below pumps one inside a list.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int index = 0; index < options.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: BrandShape.space2),
            Expanded(child: _chip(index)),
          ],
        ],
      ),
    );
  }

  Widget _chip(int index) {
    final SettingsChoiceOption option = options[index];
    final bool isSelected = index == selected;

    return PressableSurface(
      onPressed: () => onSelected(index),
      pressEffect: PressEffect.none,
      minHeight: minChipHeight,
      borderRadius: BrandShape.radiusChip,
      borderWidth: BrandShape.borderWidthSmallSurface,
      background: isSelected
          ? BrandColorRole.highlight.color
          : unselectedBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space3,
        vertical: BrandShape.space2,
      ),
      child: Center(
        child: Text(
          option.label,
          maxLines: 1,
          style: BrandText.cardTitle(
            size: option.labelSize ?? _labelSize,
            // Ink for the one that is set, muted for the rest — the same
            // hierarchy the design draws, and it is a second channel behind the
            // fill rather than a decoration.
            color: isSelected
                ? BrandColors.ink
                : BrandColorRole.secondaryText.color,
          ),
        ),
      ),
    );
  }
}
