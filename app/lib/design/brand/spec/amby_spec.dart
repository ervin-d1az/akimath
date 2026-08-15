import 'dart:ui' show Offset, Rect;

import '../../tokens/brand_colors.dart';
import 'brand_shapes.dart';

/// The poses of Amby that exist as static artwork.
///
/// The plan calls for six Rive inputs (`idle`, `thinking`, `correct`, `wrong`,
/// `streak`, `levelUp`). These three carry the app until that animation exists.
enum AmbyPose {
  /// At rest. Splash and store listing use this one.
  base,

  /// Gills fanned open: celebration.
  fan,

  /// One gill detached: something went wrong.
  error,
}

/// A gill's root→tip pair.
typedef _Gill = (Offset root, Offset tip);

/// Amby's geometry, described as data.
///
/// A direct translation of `Amby.dc.html` and `AmbyCara.dc.html`. Coordinates
/// are the original `viewBox` ones; scaling is the adapter's job.
abstract final class AmbySpec {
  /// Logical box of the standalone face.
  static const Rect faceViewBox = Rect.fromLTWH(0, 0, 200, 200);

  /// Logical box of the full body. [AmbyPose.error] is wider because the loose
  /// gill flies off to the right.
  static Rect bodyViewBox(AmbyPose pose) => switch (pose) {
        AmbyPose.base || AmbyPose.fan => const Rect.fromLTWH(0, 0, 240, 210),
        AmbyPose.error => const Rect.fromLTWH(0, 0, 250, 210),
      };

  /// The face alone: this is the app icon and the profile avatar.
  ///
  /// Built once. Painters compare drawings by identity to decide whether to
  /// repaint, so handing out a fresh instance per call would repaint forever.
  static final BrandDrawing face = _buildFace();

  static BrandDrawing _buildFace() {
    const List<_Gill> gills = <_Gill>[
      (Offset(56, 80), Offset(26, 36)),
      (Offset(40, 102), Offset(14, 72)),
      (Offset(38, 124), Offset(16, 112)),
      (Offset(144, 80), Offset(174, 36)),
      (Offset(160, 102), Offset(186, 72)),
      (Offset(162, 124), Offset(184, 112)),
    ];

    return BrandDrawing(
      viewBox: faceViewBox,
      marks: <BrandMark>[
        ..._gillStrokes(gills, inkWidth: 26, coreWidth: 15),
        ..._gillTips(gills, radius: 13, inkWidth: 7),
        const InkOval(
          center: Offset(100, 116),
          radiusX: 80,
          radiusY: 62,
          fill: BrandColors.pinkFace,
          inkWidth: 7,
        ),
        _smile(
          const Offset(84, 142),
          const Offset(100, 160),
          const Offset(116, 142),
          inkWidth: 8,
        ),
        ..._cheeks(const Offset(56, 140), const Offset(144, 140), radius: 13),
        ..._eyes(const Offset(76, 112), const Offset(124, 112), radius: 11),
      ],
    );
  }

  /// The full body in the requested pose.
  static BrandDrawing body(AmbyPose pose) => switch (pose) {
        AmbyPose.base => _base,
        AmbyPose.fan => _fan,
        AmbyPose.error => _error,
      };

  // ── Poses ────────────────────────────────────────────────────────────────

  static final BrandDrawing _base = _buildBase();
  static final BrandDrawing _fan = _buildFan();
  static final BrandDrawing _error = _buildError();

  static BrandDrawing _buildBase() {
    const List<_Gill> gills = <_Gill>[
      (Offset(74, 74), Offset(52, 48)),
      (Offset(64, 84), Offset(34, 64)),
      (Offset(60, 96), Offset(24, 86)),
      (Offset(166, 74), Offset(188, 48)),
      (Offset(176, 84), Offset(206, 64)),
      (Offset(180, 96), Offset(216, 86)),
    ];

    return BrandDrawing(
      viewBox: bodyViewBox(AmbyPose.base),
      marks: <BrandMark>[
        _tail(
          const Offset(146, 156),
          const Offset(188, 162),
          const Offset(212, 148),
          const Offset(216, 116),
        ),
        ..._standing(feetY: 184, bodyCenterY: 152),
        ..._gillStrokes(gills, inkWidth: 15, coreWidth: 8),
        ..._gillTips(gills, radius: 8.5, inkWidth: _bodyInk),
        _head(96),
        _smile(
          const Offset(108, 114),
          const Offset(120, 126),
          const Offset(132, 114),
          inkWidth: 4,
        ),
        ..._cheeks(const Offset(80, 112), const Offset(160, 112), radius: 9.5),
        ..._eyes(const Offset(100, 94), const Offset(142, 94), radius: 7.5),
      ],
    );
  }

  static BrandDrawing _buildFan() {
    const List<_Gill> gills = <_Gill>[
      (Offset(74, 74), Offset(44, 32)),
      (Offset(64, 84), Offset(20, 56)),
      (Offset(60, 96), Offset(12, 80)),
      (Offset(166, 74), Offset(196, 32)),
      (Offset(176, 84), Offset(220, 56)),
      (Offset(180, 96), Offset(228, 80)),
    ];

    return BrandDrawing(
      viewBox: bodyViewBox(AmbyPose.fan),
      marks: <BrandMark>[
        _tail(
          const Offset(146, 156),
          const Offset(190, 164),
          const Offset(216, 148),
          const Offset(220, 112),
        ),
        ..._standing(feetY: 184, bodyCenterY: 152),
        ..._gillStrokes(gills, inkWidth: 15, coreWidth: 8),
        ..._gillTips(gills, radius: 9.5, inkWidth: _bodyInk),
        _head(96),
        _smile(
          const Offset(108, 114),
          const Offset(120, 126),
          const Offset(132, 114),
          inkWidth: 4,
        ),
        ..._cheeks(const Offset(80, 112), const Offset(160, 112), radius: 9.5),
        ..._eyes(const Offset(100, 94), const Offset(142, 94), radius: 7.5),
      ],
    );
  }

  static BrandDrawing _buildError() {
    // Five gills still in place: the middle one on the right is gone.
    const List<_Gill> gills = <_Gill>[
      (Offset(74, 76), Offset(52, 50)),
      (Offset(64, 86), Offset(34, 66)),
      (Offset(60, 98), Offset(24, 88)),
      (Offset(166, 76), Offset(188, 50)),
      (Offset(180, 98), Offset(216, 88)),
    ];

    return BrandDrawing(
      viewBox: bodyViewBox(AmbyPose.error),
      marks: <BrandMark>[
        _tail(
          const Offset(146, 158),
          const Offset(188, 164),
          const Offset(212, 150),
          const Offset(216, 118),
        ),
        ..._standing(feetY: 186, bodyCenterY: 154),
        ..._gillStrokes(gills, inkWidth: 15, coreWidth: 8),
        ..._gillTips(gills, radius: 8.5, inkWidth: _bodyInk),

        // The green stub: what is left of the gill that came off.
        InkStroke.line(
          const Offset(176, 86),
          const Offset(196, 72),
          inkWidth: 14,
          coreColor: BrandColors.green,
          coreWidth: 7,
        ),
        const InkDot(
          center: Offset(198, 71),
          radius: 7,
          fill: BrandColors.green,
          inkWidth: _bodyInk,
        ),

        // The loose gill, mid-flight. The original wraps this in a
        // `rotate(34 222 26)` group; the coordinates here are pre-rotated so a
        // transform primitive does not have to exist for a single use.
        InkStroke.line(
          const Offset(203.18, 18.13),
          const Offset(227.55, 24.92),
          inkWidth: 14,
          coreColor: BrandColors.pink,
          coreWidth: 7,
        ),
        const InkDot(
          center: Offset(229.21, 26.04),
          radius: 8,
          fill: BrandColors.pink,
          inkWidth: _bodyInk,
        ),

        _head(98),
        _smile(
          const Offset(108, 116),
          const Offset(120, 128),
          const Offset(132, 116),
          inkWidth: 4,
        ),

        // Dust from the break.
        const InkDot(
          center: Offset(216, 48),
          radius: 3,
          fill: BrandColors.pink,
          opacity: 0.55,
        ),
        const InkDot(
          center: Offset(208, 58),
          radius: 2.4,
          fill: BrandColors.pink,
          opacity: 0.4,
        ),

        ..._cheeks(const Offset(80, 114), const Offset(160, 114), radius: 9.5),
        ..._eyes(const Offset(100, 96), const Offset(142, 96), radius: 7.5),
      ],
    );
  }

  // ── Shared pieces ────────────────────────────────────────────────────────

  /// Outline width for the full body. The standalone face uses a different one
  /// because it is drawn much larger.
  static const double _bodyInk = 3.6;

  static InkStroke _tail(Offset from, Offset a, Offset b, Offset to) {
    return InkStroke(
      start: from,
      steps: <PathStep>[CubicTo(a, b, to)],
      inkWidth: 27,
      coreColor: BrandColors.pinkBody,
      coreWidth: 18,
    );
  }

  /// Feet and torso. Painted before the head so the head covers them.
  static List<BrandMark> _standing({
    required double feetY,
    required double bodyCenterY,
  }) {
    return <BrandMark>[
      InkOval(
        center: Offset(98, feetY),
        radiusX: 15,
        radiusY: 10,
        fill: BrandColors.pinkBody,
        inkWidth: _bodyInk,
      ),
      InkOval(
        center: Offset(142, feetY),
        radiusX: 15,
        radiusY: 10,
        fill: BrandColors.pinkBody,
        inkWidth: _bodyInk,
      ),
      InkOval(
        center: Offset(120, bodyCenterY),
        radiusX: 44,
        radiusY: 32,
        fill: BrandColors.pinkBody,
        inkWidth: _bodyInk,
      ),
    ];
  }

  static InkOval _head(double centerY) => InkOval(
        center: Offset(120, centerY),
        radiusX: 62,
        radiusY: 46,
        fill: BrandColors.pinkFace,
        inkWidth: _bodyInk,
      );

  static List<InkStroke> _gillStrokes(
    List<_Gill> gills, {
    required double inkWidth,
    required double coreWidth,
  }) {
    return <InkStroke>[
      for (final (Offset root, Offset tip) in gills)
        InkStroke.line(
          root,
          tip,
          inkWidth: inkWidth,
          coreColor: BrandColors.pink,
          coreWidth: coreWidth,
        ),
    ];
  }

  static List<InkDot> _gillTips(
    List<_Gill> gills, {
    required double radius,
    required double inkWidth,
  }) {
    return <InkDot>[
      for (final (Offset _, Offset tip) in gills)
        InkDot(
          center: tip,
          radius: radius,
          fill: BrandColors.pink,
          inkWidth: inkWidth,
        ),
    ];
  }

  static InkStroke _smile(
    Offset from,
    Offset control,
    Offset to, {
    required double inkWidth,
  }) {
    return InkStroke(
      start: from,
      steps: <PathStep>[QuadTo(control, to)],
      inkWidth: inkWidth,
    );
  }

  /// Cheeks: translucent pink, no outline. They sit on top of the head.
  static List<InkDot> _cheeks(
    Offset left,
    Offset right, {
    required double radius,
  }) {
    return <InkDot>[
      for (final Offset center in <Offset>[left, right])
        InkDot(
          center: center,
          radius: radius,
          fill: BrandColors.pink,
          opacity: 0.28,
        ),
    ];
  }

  /// Eyes: solid ink, no outline. Amby never blinks or changes gaze — the
  /// expression lives in the gills.
  static List<InkDot> _eyes(
    Offset left,
    Offset right, {
    required double radius,
  }) {
    return <InkDot>[
      for (final Offset center in <Offset>[left, right])
        InkDot(center: center, radius: radius, fill: BrandColors.ink),
    ];
  }
}
