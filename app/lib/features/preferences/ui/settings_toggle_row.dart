import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/pressable_surface.dart';
import 'brand_switch.dart';

/// One switchable setting: a label, an optional note, and the switch.
///
/// **The whole card is the press.** The switch is paint (see [BrandSwitch]) and
/// the row is the target, so the finger has 48 px whatever the switch measures
/// and nobody has to aim at a 34 px slot. It is the same argument
/// `SettingsRow` makes for its chevron: one press per row.
///
/// **No chevron.** `SettingsRow`'s doc comment states the rule — the mark
/// promises *there is more through here* — and a row that acts in place makes
/// no such promise.
///
/// [minHeight] rather than a fixed height, for the reason `PressableSurface`
/// records: the design's 62 clips its own label the moment a player raises the
/// text size, and this app is gated at 1.3.
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.label,
    required this.isOn,
    required this.onChanged,
    this.note,
  });

  final String label;

  /// The second line, where the design writes one. Absent rather than blank
  /// where it does not.
  final String? note;

  final bool isOn;

  /// Called with what the setting would become, never with what it is.
  final ValueChanged<bool> onChanged;

  /// The design's card height, as a floor.
  static const double minHeight = 62;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onPressed: () => onChanged(!isOn),
      minHeight: minHeight,
      borderRadius: BrandShape.radiusCardSmall,
      shadow: BrandShape.shadowTile,
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _labelling()),
          const SizedBox(width: BrandShape.space3),
          BrandSwitch(isOn: isOn),
        ],
      ),
    );
  }

  Widget _labelling() {
    final String? second = note;
    final Text title = Text(label, style: BrandText.cardTitle(size: 16));

    if (second == null) {
      return title;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        title,
        const SizedBox(height: BrandShape.space1),
        Text(second, style: BrandText.caption()),
      ],
    );
  }
}
