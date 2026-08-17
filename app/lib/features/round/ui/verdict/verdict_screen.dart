import 'package:flutter/material.dart';

import '../../../../design/brand/aki.dart';
import '../../../../design/math/spec/es_mx_number.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../design/widgets/brand_button.dart';
import '../../../../design/widgets/spec/verdict.dart';
import '../../../../design/widgets/stat_tile.dart';
import '../../../../design/widgets/verdict_ring.dart';

/// What a verdict screen is told. Two numbers and a result — nothing else.
///
/// **No rating, and no placeholder for one** (Q3, decided 2026-08-15). F2 has
/// no server and the rating is the server's exclusive authority (D17), so a
/// verdict screen in F2 carries **no number that sync can later contradict**.
/// The rating tile and the delta come back with `f3-attempt-sync`; this is a
/// subtraction with a named return phase, not a redesign.
class VerdictSummary {
  const VerdictSummary({
    required this.verdict,
    required this.elapsed,
    required this.streakDays,
  });

  final Verdict verdict;

  /// Measured quietly while solving and shown only here (`req-quiet-timing`).
  final Duration elapsed;

  /// A local calendar fact, from `StreakPolicy`.
  final int streakDays;
}

/// `03 Acierto` and `04 Error`, which are one screen with two moods.
///
/// **The copy never names the failure.** No "incorrecto", "error", "fallaste"
/// or "mal" appears on either mood — `req-diagnosis-copy`, asserted by a test
/// that scans the rendered tree. Aki's `slip` pose stoops a little and never
/// looks disappointed, and the tail curl growing back in green is the whole of
/// what a wrong answer costs.
///
/// The verdict itself is carried by `VerdictRing`: shape and glyph first, hue
/// second, so it survives a reader who cannot separate green from coral.
class VerdictScreen extends StatelessWidget {
  const VerdictScreen({
    super.key,
    required this.summary,
    required this.onContinue,
  });

  final VerdictSummary summary;
  final VoidCallback onContinue;

  bool get _correct => summary.verdict == Verdict.correct;

  /// Aki's art is 182 px inside a 156 px band — **26 px of deliberate upward
  /// overflow** on the error screen. In CSS it paints over; a fixed-height
  /// `Column` child in Flutter clips or throws, so the band is a `Stack` with
  /// the art aligned to its bottom and allowed to exceed it.
  static const double _bandHeight = 156;
  static const double _akiWidth = 182;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BrandShape.space4,
            vertical: BrandShape.space3,
          ),
          child: Column(
            children: <Widget>[
              const Spacer(),
              _band(),
              const SizedBox(height: BrandShape.space4),
              VerdictRing(summary.verdict),
              const SizedBox(height: BrandShape.space3),
              Text(
                _correct ? '¡Bien hecho!' : 'Casi. Mira cómo va.',
                style: BrandText.cardTitle(size: 22),
              ),
              const SizedBox(height: BrandShape.space5),
              _tiles(),
              const Spacer(),
              BrandButton.primary(
                label: _correct ? 'Siguiente' : 'Intentar otro',
                onPressed: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _band() {
    return SizedBox(
      height: _bandHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Aki(
            width: _akiWidth,
            pose: _correct ? AkiPose.correct : AkiPose.slip,
            semanticLabel: _correct ? 'Aki celebrando' : 'Aki intentando otra vez',
          ),
        ],
      ),
    );
  }

  /// **Two tiles, not three.** Time and streak. Q4 moved the rating delta to
  /// the series and Q3 hid the rating outright in F2.
  Widget _tiles() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        StatTile(
          label: 'TIEMPO',
          value: StatValue(
            EsMxNumber.seconds(summary.elapsed.inMilliseconds / 1000, places: 1),
            size: _variant.valueSize,
          ),
          variant: _variant,
        ),
        const SizedBox(width: BrandShape.space3),
        StatTile(
          label: 'RACHA',
          value: StatValue(
            EsMxNumber.integer(summary.streakDays),
            size: _variant.valueSize,
          ),
          variant: _variant,
        ),
      ],
    );
  }

  /// `03` draws raised tiles; `04` draws flat ones.
  StatTileVariant get _variant =>
      _correct ? StatTileVariant.raised : StatTileVariant.flat;
}
