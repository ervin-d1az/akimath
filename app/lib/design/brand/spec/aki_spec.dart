import 'dart:ui' show Offset, Radius, Rect;

import '../../tokens/brand_colors.dart';
import 'brand_shapes.dart';

/// The poses of Aki that exist as static artwork.
enum AkiPose {
  /// At rest. Splash, store listing, and the start of a round.
  base,

  /// Ears up, wider smile, tail wagging. A right answer.
  correct,

  /// The tail curl has come undone and the new one is already growing back in
  /// green. A wrong answer — she stoops a little, but never looks disappointed.
  slip,
}

/// A straight whisker, root to tip.
typedef _Whisker = (Offset root, Offset tip);

/// Aki's geometry, described as data.
///
/// A direct translation of `Aki.dc.html` and `AkiCara.dc.html`. Coordinates are
/// the original `viewBox` ones; scaling is the adapter's job.
///
/// The one thing the artwork must carry is a body part that can be **lost and
/// come back**. On the axolotl it was a gill; on Aki it is the curl of the
/// tail. Everything else about her holds still across the three poses: she does
/// not scold, does not look let down, and does not appear while you are solving.
abstract final class AkiSpec {
  /// Logical box of the standalone face.
  static const Rect faceViewBox = Rect.fromLTWH(0, 0, 200, 200);

  /// Logical box of the full body, the same for every pose.
  static const Rect bodyViewBox = Rect.fromLTWH(0, 0, 240, 236);

  /// The face alone: the app icon and the profile avatar.
  static final BrandDrawing face = _buildFace();

  /// The full body in the requested pose.
  static BrandDrawing body(AkiPose pose) => switch (pose) {
        AkiPose.base => _base,
        AkiPose.correct => _correct,
        AkiPose.slip => _slip,
      };

  static final BrandDrawing _base = _buildBase();
  static final BrandDrawing _correct = _buildCorrect();
  static final BrandDrawing _slip = _buildSlip();

  // ── Face ─────────────────────────────────────────────────────────────────

  static const double _faceInk = 6;

  static BrandDrawing _buildFace() {
    return const BrandDrawing(
      viewBox: faceViewBox,
      marks: <BrandMark>[
        // Ears first: the head is painted over their bases.
        InkShape(
          start: Offset(42, 30),
          steps: <PathStep>[
            CubicTo(Offset(12, 28), Offset(2, 82), Offset(24, 106)),
            CubicTo(Offset(38, 122), Offset(62, 112), Offset(62, 88)),
            CubicTo(Offset(62, 62), Offset(58, 32), Offset(42, 30)),
          ],
          fill: BrandColors.akiEars,
          inkWidth: _faceInk,
        ),
        InkShape(
          start: Offset(158, 30),
          steps: <PathStep>[
            CubicTo(Offset(188, 28), Offset(198, 82), Offset(176, 106)),
            CubicTo(Offset(162, 122), Offset(138, 112), Offset(138, 88)),
            CubicTo(Offset(138, 62), Offset(142, 32), Offset(158, 30)),
          ],
          fill: BrandColors.akiEars,
          inkWidth: _faceInk,
        ),

        InkOval(
          center: Offset(100, 102),
          radiusX: 86,
          radiusY: 70,
          fill: BrandColors.akiCoat,
          inkWidth: _faceInk,
        ),

        // Forehead crease, then the two brows. This is the whole expression.
        InkStroke(
          start: Offset(76, 52),
          steps: <PathStep>[QuadTo(Offset(100, 42), Offset(124, 52))],
          width: _faceInk,
        ),
        InkStroke(
          start: Offset(50, 74),
          steps: <PathStep>[QuadTo(Offset(68, 62), Offset(86, 74))],
          width: 7,
        ),
        InkStroke(
          start: Offset(114, 74),
          steps: <PathStep>[QuadTo(Offset(132, 62), Offset(150, 74))],
          width: 7,
        ),

        InkRect(
          rect: Rect.fromLTWH(60, 108, 80, 58),
          radius: Radius.circular(29),
          fill: BrandColors.akiMuzzle,
          inkWidth: _faceInk,
        ),
        InkOval(
          center: Offset(100, 126),
          radiusX: 16,
          radiusY: 11,
          fill: BrandColors.ink,
        ),
        // The mouth is cut into the dark muzzle in coat color, not outlined.
        InkStroke(
          start: Offset(80, 142),
          steps: <PathStep>[QuadTo(Offset(100, 158), Offset(120, 142))],
          width: 5.5,
          color: BrandColors.akiCoat,
        ),

        InkDot(center: Offset(68, 96), radius: 16, fill: BrandColors.ink),
        InkDot(center: Offset(132, 96), radius: 16, fill: BrandColors.ink),
        InkDot(center: Offset(73, 90), radius: 5.4, fill: BrandColors.surface),
        InkDot(center: Offset(137, 90), radius: 5.4, fill: BrandColors.surface),

        InkStroke(
          start: Offset(53, 86),
          steps: <PathStep>[LineTo(Offset(40, 77))],
          width: _faceInk,
        ),
        InkStroke(
          start: Offset(51, 95),
          steps: <PathStep>[LineTo(Offset(36, 94))],
          width: _faceInk,
        ),
        InkStroke(
          start: Offset(147, 86),
          steps: <PathStep>[LineTo(Offset(160, 77))],
          width: _faceInk,
        ),
        InkStroke(
          start: Offset(149, 95),
          steps: <PathStep>[LineTo(Offset(164, 94))],
          width: _faceInk,
        ),
      ],
    );
  }

  // ── Poses ────────────────────────────────────────────────────────────────

  static const double _bodyInk = 4;

  static BrandDrawing _buildBase() {
    return BrandDrawing(
      viewBox: bodyViewBox,
      marks: <BrandMark>[
        // The curl, intact.
        ..._tail(
          const Offset(174, 182),
          const <PathStep>[
            CubicTo(Offset(204, 182), Offset(208, 152), Offset(190, 148)),
            CubicTo(Offset(177, 145), Offset(173, 162), Offset(186, 164)),
          ],
        ),
        ..._stance(bodyCenterY: 180, legsTop: 196, legsHeight: 34, collarTop: 150),
        ..._ears(
          const Offset(60, 50),
          const <PathStep>[
            CubicTo(Offset(36, 48), Offset(28, 86), Offset(46, 104)),
            CubicTo(Offset(56, 114), Offset(74, 106), Offset(74, 90)),
            CubicTo(Offset(74, 72), Offset(70, 52), Offset(60, 50)),
          ],
          const Offset(180, 50),
          const <PathStep>[
            CubicTo(Offset(204, 48), Offset(212, 86), Offset(194, 104)),
            CubicTo(Offset(184, 114), Offset(166, 106), Offset(166, 90)),
            CubicTo(Offset(166, 72), Offset(170, 52), Offset(180, 50)),
          ],
        ),
        ..._face(
          headCenterY: 96,
          foreheadY: 54,
          foreheadControlY: 46,
          browY: 72,
          browControlY: 63,
          muzzleTop: 100,
          noseY: 116,
          mouth: _Mouth(104, 130, 120, 143, 136, 130, 4),
          eyeY: 88,
          catchlightY: 83,
          whiskerY: 79,
        ),
      ],
    );
  }

  static BrandDrawing _buildCorrect() {
    return BrandDrawing(
      viewBox: bodyViewBox,
      marks: <BrandMark>[
        // Same curl, lifted — plus two motion ticks. No confetti, no stars.
        ..._tail(
          const Offset(174, 178),
          const <PathStep>[
            CubicTo(Offset(206, 176), Offset(210, 144), Offset(190, 140)),
            CubicTo(Offset(176, 137), Offset(172, 156), Offset(186, 158)),
          ],
        ),
        InkStroke.line(
          const Offset(212, 124),
          const Offset(222, 114),
          width: _bodyInk,
        ),
        InkStroke.line(
          const Offset(201, 118),
          const Offset(207, 106),
          width: _bodyInk,
        ),
        ..._stance(bodyCenterY: 180, legsTop: 196, legsHeight: 34, collarTop: 150),
        // Ears up.
        ..._ears(
          const Offset(58, 40),
          const <PathStep>[
            CubicTo(Offset(34, 36), Offset(24, 74), Offset(42, 94)),
            CubicTo(Offset(52, 104), Offset(72, 98), Offset(74, 82)),
            CubicTo(Offset(76, 64), Offset(68, 42), Offset(58, 40)),
          ],
          const Offset(182, 40),
          const <PathStep>[
            CubicTo(Offset(206, 36), Offset(216, 74), Offset(198, 94)),
            CubicTo(Offset(188, 104), Offset(168, 98), Offset(166, 82)),
            CubicTo(Offset(164, 64), Offset(172, 42), Offset(182, 40)),
          ],
        ),
        ..._face(
          headCenterY: 96,
          foreheadY: 54,
          foreheadControlY: 46,
          browY: 70,
          browControlY: 60,
          muzzleTop: 100,
          noseY: 116,
          mouth: _Mouth(100, 128, 120, 146, 140, 128, 4.5),
          eyeY: 88,
          catchlightY: 83,
          whiskerY: 79,
        ),
      ],
    );
  }

  static BrandDrawing _buildSlip() {
    return BrandDrawing(
      viewBox: bodyViewBox,
      marks: <BrandMark>[
        // The curl has come undone: the tail runs straight out.
        ..._tail(
          const Offset(172, 184),
          const <PathStep>[
            CubicTo(Offset(196, 184), Offset(212, 176), Offset(226, 162)),
          ],
        ),
        // And the new one is already growing back, in green.
        const InkStroke(
          start: Offset(214, 152),
          steps: <PathStep>[
            CubicTo(Offset(224, 142), Offset(236, 146), Offset(234, 156)),
          ],
          width: 14,
          coreColor: BrandColors.green,
          coreWidth: 7,
        ),
        ..._stance(bodyCenterY: 182, legsTop: 198, legsHeight: 32, collarTop: 154),
        ..._ears(
          const Offset(60, 56),
          const <PathStep>[
            CubicTo(Offset(36, 54), Offset(28, 92), Offset(46, 110)),
            CubicTo(Offset(56, 120), Offset(74, 112), Offset(74, 96)),
            CubicTo(Offset(74, 78), Offset(70, 58), Offset(60, 56)),
          ],
          const Offset(180, 56),
          const <PathStep>[
            CubicTo(Offset(204, 54), Offset(212, 92), Offset(194, 110)),
            CubicTo(Offset(184, 120), Offset(166, 112), Offset(166, 96)),
            CubicTo(Offset(166, 78), Offset(170, 58), Offset(180, 56)),
          ],
        ),
        ..._face(
          headCenterY: 100,
          foreheadY: 58,
          foreheadControlY: 50,
          browY: 78,
          browControlY: 70,
          muzzleTop: 104,
          noseY: 120,
          mouth: _Mouth(106, 134, 120, 146, 138, 133, 4),
          eyeY: 94,
          catchlightY: 89,
          whiskerY: 85,
        ),
        // Dust from where the old curl let go.
        const InkDot(
          center: Offset(206, 136),
          radius: 3.4,
          fill: BrandColors.green,
          opacity: 0.6,
        ),
        const InkDot(
          center: Offset(198, 146),
          radius: 2.6,
          fill: BrandColors.green,
          opacity: 0.45,
        ),
      ],
    );
  }

  // ── Shared pieces ────────────────────────────────────────────────────────

  /// The tail: ink first, coat color over it.
  static List<BrandMark> _tail(Offset start, List<PathStep> steps) {
    return <BrandMark>[
      InkStroke(
        start: start,
        steps: steps,
        width: 21,
        coreColor: BrandColors.akiCoat,
        coreWidth: 12,
      ),
    ];
  }

  /// Torso, front legs, collar and tag. Painted before the head.
  static List<BrandMark> _stance({
    required double bodyCenterY,
    required double legsTop,
    required double legsHeight,
    required double collarTop,
  }) {
    final double tagY = collarTop + 9;

    return <BrandMark>[
      InkOval(
        center: Offset(120, bodyCenterY),
        radiusX: 58,
        radiusY: 42,
        fill: BrandColors.akiCoat,
        inkWidth: _bodyInk,
      ),
      for (final double x in <double>[80, 130])
        InkRect(
          rect: Rect.fromLTWH(x, legsTop, 30, legsHeight),
          radius: const Radius.circular(14),
          fill: BrandColors.akiCoat,
          inkWidth: _bodyInk,
        ),
      InkRect(
        rect: Rect.fromLTWH(74, collarTop, 92, 18),
        radius: const Radius.circular(9),
        fill: BrandColors.pink,
        inkWidth: _bodyInk,
      ),
      // The bow on the collar: two facets and a bead.
      InkShape(
        start: Offset(142, tagY),
        steps: <PathStep>[
          LineTo(Offset(130, tagY - 8)),
          LineTo(Offset(130, tagY + 8)),
        ],
        fill: BrandColors.pinkSoft,
        inkWidth: 3,
      ),
      InkShape(
        start: Offset(148, tagY),
        steps: <PathStep>[
          LineTo(Offset(160, tagY - 8)),
          LineTo(Offset(160, tagY + 8)),
        ],
        fill: BrandColors.pinkSoft,
        inkWidth: 3,
      ),
      InkDot(
        center: Offset(145, tagY),
        radius: 5,
        fill: BrandColors.pinkSoft,
        inkWidth: 3,
      ),
    ];
  }

  static List<BrandMark> _ears(
    Offset leftStart,
    List<PathStep> leftSteps,
    Offset rightStart,
    List<PathStep> rightSteps,
  ) {
    return <BrandMark>[
      InkShape(
        start: leftStart,
        steps: leftSteps,
        fill: BrandColors.akiEars,
        inkWidth: _bodyInk,
      ),
      InkShape(
        start: rightStart,
        steps: rightSteps,
        fill: BrandColors.akiEars,
        inkWidth: _bodyInk,
      ),
    ];
  }

  /// Everything from the head oval down to the whiskers.
  ///
  /// The three poses move this block vertically and reshape the brows and the
  /// mouth. Nothing else about the face changes — the eyes never narrow and
  /// never look away.
  static List<BrandMark> _face({
    required double headCenterY,
    required double foreheadY,
    required double foreheadControlY,
    required double browY,
    required double browControlY,
    required double muzzleTop,
    required double noseY,
    required _Mouth mouth,
    required double eyeY,
    required double catchlightY,
    required double whiskerY,
  }) {
    final List<_Whisker> whiskers = <_Whisker>[
      (Offset(80, whiskerY), Offset(71, whiskerY - 7)),
      (Offset(78, whiskerY + 7), Offset(67, whiskerY + 6)),
      (Offset(160, whiskerY), Offset(169, whiskerY - 7)),
      (Offset(162, whiskerY + 7), Offset(173, whiskerY + 6)),
    ];

    return <BrandMark>[
      InkOval(
        center: Offset(120, headCenterY),
        radiusX: 70,
        radiusY: 56,
        fill: BrandColors.akiCoat,
        inkWidth: _bodyInk,
      ),
      InkStroke(
        start: Offset(100, foreheadY),
        steps: <PathStep>[
          QuadTo(Offset(120, foreheadControlY), Offset(140, foreheadY)),
        ],
        width: _bodyInk,
      ),
      InkStroke(
        start: Offset(78, browY),
        steps: <PathStep>[QuadTo(Offset(92, browControlY), Offset(106, browY))],
        width: 5,
      ),
      InkStroke(
        start: Offset(134, browY),
        steps: <PathStep>[QuadTo(Offset(148, browControlY), Offset(162, browY))],
        width: 5,
      ),
      InkRect(
        rect: Rect.fromLTWH(86, muzzleTop, 68, 50),
        radius: const Radius.circular(25),
        fill: BrandColors.akiMuzzle,
        inkWidth: _bodyInk,
      ),
      InkOval(
        center: Offset(120, noseY),
        radiusX: 13,
        radiusY: 9,
        fill: BrandColors.ink,
      ),
      InkStroke(
        start: Offset(mouth.startX, mouth.startY),
        steps: <PathStep>[
          QuadTo(
            Offset(mouth.controlX, mouth.controlY),
            Offset(mouth.endX, mouth.endY),
          ),
        ],
        width: mouth.width,
        color: BrandColors.akiCoat,
      ),
      for (final double x in <double>[92, 148])
        InkDot(center: Offset(x, eyeY), radius: 13, fill: BrandColors.ink),
      for (final double x in <double>[96, 152])
        InkDot(
          center: Offset(x, catchlightY),
          radius: 4.4,
          fill: BrandColors.surface,
        ),
      for (final (Offset root, Offset tip) in whiskers)
        InkStroke.line(root, tip, width: _bodyInk),
    ];
  }
}

/// The mouth curve for one pose. A record would do; a named type makes the
/// six loose numbers at each call site readable.
class _Mouth {
  const _Mouth(
    this.startX,
    this.startY,
    this.controlX,
    this.controlY,
    this.endX,
    this.endY,
    this.width,
  );

  final double startX;
  final double startY;
  final double controlX;
  final double controlY;
  final double endX;
  final double endY;
  final double width;
}
