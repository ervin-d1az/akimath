import 'package:flutter/widgets.dart';

import 'brand_drawing_painter.dart';
import 'spec/aki_spec.dart';
import 'spec/brand_shapes.dart';

export 'spec/aki_spec.dart' show AkiPose;

/// Aki, full body.
///
/// She accompanies the mark on the splash screen, the store listing, and the
/// app header. Inside the app she never sits next to the wordmark, and she
/// never appears while the user is solving.
class Aki extends StatelessWidget {
  const Aki({
    super.key,
    required this.width,
    this.pose = AkiPose.base,
    this.semanticLabel,
  }) : assert(width > 0, 'Aki needs a positive width.');

  /// Rendered width. Height follows from the artwork's aspect ratio.
  final double width;

  final AkiPose pose;

  /// Leave null when Aki is decorative, which is the common case.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _BrandArt(
      drawing: AkiSpec.body(pose),
      width: width,
      semanticLabel: semanticLabel,
    );
  }
}

/// Aki's face alone: the app icon and the profile avatar.
class AkiFace extends StatelessWidget {
  const AkiFace({
    super.key,
    required this.width,
    this.semanticLabel,
  }) : assert(width > 0, 'AkiFace needs a positive width.');

  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _BrandArt(
      drawing: AkiSpec.face,
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
