import 'package:flutter/widgets.dart';

import 'brand_drawing_painter.dart';
import 'spec/amby_spec.dart';
import 'spec/brand_shapes.dart';

export 'spec/amby_spec.dart' show AmbyPose;

/// Amby, full body.
///
/// Per the brand rules, Amby only accompanies the mark on the splash screen,
/// the store listing, and the app header. Inside the app it never sits next to
/// the wordmark, and it never appears while the user is solving.
class Amby extends StatelessWidget {
  const Amby({
    super.key,
    required this.width,
    this.pose = AmbyPose.base,
    this.semanticLabel,
  }) : assert(width > 0, 'Amby needs a positive width.');

  /// Rendered width. Height follows from the artwork's aspect ratio.
  final double width;

  final AmbyPose pose;

  /// Leave null when Amby is decorative, which is the common case.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final BrandDrawing drawing = AmbySpec.body(pose);
    return _BrandArt(
      drawing: drawing,
      width: width,
      semanticLabel: semanticLabel,
    );
  }
}

/// Amby's face alone: the app icon and the profile avatar.
class AmbyFace extends StatelessWidget {
  const AmbyFace({
    super.key,
    required this.width,
    this.semanticLabel,
  }) : assert(width > 0, 'AmbyFace needs a positive width.');

  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _BrandArt(
      drawing: AmbySpec.face,
      width: width,
      semanticLabel: semanticLabel,
    );
  }
}

/// Sizes a drawing by width and paints it.
class _BrandArt extends StatelessWidget {
  const _BrandArt({
    required this.drawing,
    required this.width,
    required this.semanticLabel,
  });

  final BrandDrawing drawing;
  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Rect box = drawing.viewBox;
    final Widget art = SizedBox(
      width: width,
      height: width * box.height / box.width,
      child: CustomPaint(painter: BrandDrawingPainter(drawing)),
    );

    final String? label = semanticLabel;
    if (label == null) {
      return ExcludeSemantics(child: art);
    }
    return Semantics(label: label, image: true, child: art);
  }
}
