import 'package:flutter/widgets.dart';

import '../painting/dashed_border_painter.dart';
import '../painting/spec/dash_spec.dart';
import '../tokens/tokens.dart';

/// The one primitive every surface in the app is built from.
///
/// Thick ink outline, hard shadow, no blur. `BoxShadow.blurRadius` is fixed at
/// zero here on purpose: a blurred shadow anywhere in the app is a defect, and
/// routing every surface through this widget is what makes that checkable.
class CandySurface extends StatelessWidget {
  const CandySurface({
    super.key,
    required this.child,
    this.background = BrandColors.surface,
    this.borderRadius = BrandShape.radiusCard,
    this.borderWidth = BrandShape.borderWidth,
    this.shadowOffset = BrandShape.shadowCard,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.minHeight,
    this.alignment,
    this.clip = false,
    this.borderDash,
    this.borderColor = BrandColors.ink,
  });

  /// A card: generous radius, the largest shadow.
  const CandySurface.card({
    Key? key,
    required Widget child,
    Color background = BrandColors.surface,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
    double? width,
    double? height,
  }) : this(
          key: key,
          background: background,
          padding: padding,
          width: width,
          height: height,
          child: child,
        );

  /// A pill: the small labelled chips used for annotations and tags.
  ///
  /// Its 32px height is a floor, not a fixed size. On a narrow screen the label
  /// wraps, and a fixed height would clip the second line.
  const CandySurface.pill({
    Key? key,
    required Widget child,
    Color background = BrandColors.surface,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    double minHeight = 32,
  }) : this(
          key: key,
          background: background,
          borderRadius: BrandShape.radiusPill,
          shadowOffset: BrandShape.shadowPill,
          padding: padding,
          minHeight: minHeight,
          alignment: Alignment.center,
          child: child,
        );

  /// A square tile: avatars and the app-icon lockup.
  const CandySurface.tile({
    Key? key,
    required Widget child,
    required double size,
    Color background = BrandColors.green,
    double borderRadius = BrandShape.radiusIconTile,
  }) : this(
          key: key,
          background: background,
          borderRadius: borderRadius,
          shadowOffset: BrandShape.shadowTile,
          width: size,
          height: size,
          alignment: Alignment.center,
          clip: true,
          child: child,
        );

  final Widget child;
  final Color background;
  final double borderRadius;
  final double borderWidth;

  /// Displacement of the hard shadow. The blur is always zero.
  final Offset shadowOffset;

  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  /// A floor on the height, for surfaces whose content may wrap.
  final double? minHeight;

  final AlignmentGeometry? alignment;

  /// Clips the child to the rounded rect. Needed when artwork would otherwise
  /// spill past the corners.
  final bool clip;

  /// When set, the outline is **dashed** with this pattern and the solid border
  /// is not drawn at all — not drawn underneath it.
  ///
  /// This is the shape half of BRD-1: solid means right, dashed means wrong,
  /// and the distinction has to survive a reader who cannot separate green from
  /// coral. It also moves the border into a `CustomPainter`, which is why this
  /// change widens the no-blur gate in the same merge (D22).
  final DashSpec? borderDash;

  /// The outline's colour, solid or dashed.
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final AlignmentGeometry? align = alignment;
    final DashSpec? dash = borderDash;

    // Container.alignment expands to its constraints, which turns a pill into a
    // full-width bar. Aligning with a factor on the unconstrained axes keeps
    // the surface hugging its content instead.
    final Widget body = align == null
        ? child
        : Align(
            alignment: align,
            widthFactor: width == null ? 1 : null,
            heightFactor: height == null ? 1 : null,
            child: child,
          );

    return Container(
      width: width,
      height: height,
      constraints:
          minHeight == null ? null : BoxConstraints(minHeight: minHeight!),
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: borderDash != null
            ? null
            : Border.all(color: borderColor, width: borderWidth),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: BrandColors.ink,
            offset: shadowOffset,
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: dash == null
          ? body
          : CustomPaint(
              foregroundPainter: DashedBorderPainter(
                dash: dash,
                color: borderColor,
                strokeWidth: borderWidth,
                radius: borderRadius,
              ),
              child: body,
            ),
    );
  }
}
