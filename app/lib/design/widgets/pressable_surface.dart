import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// What a surface with no shadow does when pressed.
///
/// It exists so that the absence of a treatment has to be *said* rather than
/// happening by default. No document in the corpus specifies a duration, a
/// curve, a haptic or an alternative visual for the shadowless controls — the
/// secondary button, the ghost row, the pills, the map nodes, the nav items —
/// and that gap is design request DR-5.
///
/// This type does not fill the gap. It makes it a decision at the call site
/// instead of a silence, and it gains members when DR-5 is drawn.
enum PressEffect {
  /// Deliberately nothing visible. The press still registers.
  none,
}

/// The one primitive every pressable in the app is built from.
///
/// **A pressed surface travels into its own shadow.** The rule is specified
/// identically on roughly fifty elements across all six design documents, which
/// makes it the app's interaction language rather than one widget's behaviour.
/// It is written once here so no screen restates it.
///
/// The travel is read from the surface's own [shadow] rather than looked up:
/// a surface shadowed (4, 6) travels (4, 6), one at (3, 5) travels (3, 5), and
/// nobody maintains that correspondence. It is also what
/// `no_geometry_literal_test` requires — that gate scans `design/widgets/` for
/// `Offset(` and fails on a match, so the distance cannot be typed here even if
/// someone wanted to.
///
/// No opacity change, no scale, no ripple. `theme.dart` already sets
/// `NoSplash.splashFactory`, so the substrate is right and this widget does not
/// have to suppress anything per instance.
class PressableSurface extends StatefulWidget {
  const PressableSurface({
    super.key,
    required this.child,
    required this.onPressed,
    this.shadow,
    this.pressEffect,
    this.background = BrandColors.surface,
    this.borderRadius = BrandShape.radiusButton,
    this.borderWidth = BrandShape.borderWidth,
    this.outlined = true,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.minHeight,
  }) : assert(
          shadow != null || pressEffect != null,
          'A surface with no shadow cannot travel into it, so it would ship '
          'pressable and visually inert. Name a PressEffect, or give it a '
          'shadow. See DR-5.',
        );

  final Widget child;

  /// Fires once per completed press.
  final VoidCallback onPressed;

  /// The hard shadow this surface rests on, and therefore how far it travels.
  final Offset? shadow;

  /// Required when [shadow] is null.
  final PressEffect? pressEffect;

  /// Null paints no fill — a text action sits on whatever is behind it.
  final Color? background;

  /// Whether the ink outline is drawn. A text action has none.
  final bool outlined;
  final double borderRadius;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  /// A floor rather than a fixed size.
  ///
  /// The design states a settings row as `height:62`, and a fixed 62 clips the
  /// label the moment the player raises the text setting — which this app is
  /// gated at 1.3 for. `CandySurface` already carries the same field for the
  /// same reason.
  final double? minHeight;

  @override
  State<PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends State<PressableSurface> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) {
      setState(() => _down = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Offset? shadow = widget.shadow;
    final bool travelling = _down && shadow != null;

    final double? floor = widget.minHeight;
    final Widget surface = Container(
      width: widget.width,
      height: widget.height,
      constraints: floor == null ? null : BoxConstraints(minHeight: floor),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.background,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.outlined
            ? Border.all(
                color: BrandColors.ink,
                width: widget.borderWidth,
              )
            : null,
        boxShadow: <BoxShadow>[
          if (shadow != null && !_down)
            BoxShadow(
              color: BrandColors.ink,
              offset: shadow,
              blurRadius: 0,
              spreadRadius: 0,
            ),
        ],
      ),
      child: widget.child,
    );

    return GestureDetector(
      // Opaque, so the whole target answers a tap and not only the painted
      // pixels — which is what makes the 48px box below mean anything.
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onPressed,
      child: ConstrainedBox(
        // The hit box clears 48 in both directions whatever the paint measures.
        // Six controls in the corpus are drawn smaller on purpose (DR-6); the
        // answer for them is a larger target behind unchanged paint, never a
        // larger drawing.
        constraints: const BoxConstraints(
          minWidth: BrandShape.minTouchTarget,
          minHeight: BrandShape.minTouchTarget,
        ),
        child: Center(
          child: Padding(
            // The shadow's space is reserved on both axes at all times and the
            // surface moves *within* it. Padding only the leading side would
            // let the centring absorb half the travel, and it would also let
            // the shadow overlap whatever sits next to this control.
            padding: EdgeInsets.fromLTRB(
              travelling ? shadow.dx : 0,
              travelling ? shadow.dy : 0,
              travelling ? 0 : shadow?.dx ?? 0,
              travelling ? 0 : shadow?.dy ?? 0,
            ),
            child: surface,
          ),
        ),
      ),
    );
  }
}
