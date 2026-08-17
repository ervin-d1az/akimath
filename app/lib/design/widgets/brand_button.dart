import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'pressable_surface.dart';

/// The app's three button weights, all built on [PressableSurface].
///
/// They differ in fill, outline and shadow — never in how a press behaves. That
/// is the point of the primitive underneath: the interaction language is one
/// rule, and these are three costumes for it.
class BrandButton extends StatelessWidget {
  const BrandButton._({
    required this.label,
    required this.onPressed,
    required this.background,
    required this.shadow,
    required this.outlined,
    required this.pressEffect,
    required this.padding,
    required this.textColor,
  });

  /// Green fill, ink outline, the app's most common shadow. The action the
  /// screen wants you to take.
  factory BrandButton.primary({
    required String label,
    required VoidCallback onPressed,
  }) =>
      BrandButton._(
        label: label,
        onPressed: onPressed,
        background: BrandColorRole.action.color,
        shadow: BrandShape.shadowButton,
        outlined: true,
        pressEffect: null,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        textColor: BrandColors.ink,
      );

  /// Outlined, unfilled, and **shadowless** — so it names its press treatment.
  ///
  /// No document draws an active state for it. `PressEffect.none` records that
  /// rather than hiding it; DR-5 is where the visual will come from.
  factory BrandButton.secondary({
    required String label,
    required VoidCallback onPressed,
  }) =>
      BrandButton._(
        label: label,
        onPressed: onPressed,
        background: BrandColors.surface,
        shadow: null,
        outlined: true,
        pressEffect: PressEffect.none,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        textColor: BrandColors.ink,
      );

  /// No fill, no outline, no shadow. `Dejar la serie` is one of these, drawn at
  /// roughly 29 px, and its hit box still clears 48 (BRD-2d).
  factory BrandButton.text({
    required String label,
    required VoidCallback onPressed,
  }) =>
      BrandButton._(
        label: label,
        onPressed: onPressed,
        background: null,
        shadow: null,
        outlined: false,
        pressEffect: PressEffect.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textColor: BrandColors.muted,
      );

  final String label;
  final VoidCallback onPressed;
  final Color? background;
  final Offset? shadow;
  final bool outlined;
  final PressEffect? pressEffect;
  final EdgeInsetsGeometry padding;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onPressed: onPressed,
      background: background,
      shadow: shadow,
      outlined: outlined,
      pressEffect: pressEffect,
      padding: padding,
      child: Text(label, style: BrandText.action(color: textColor)),
    );
  }
}
