import 'package:flutter/material.dart';

import '../../../../design/brand/aki.dart';
import '../../../../design/math/spec/es_mx_number.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../design/widgets/brand_button.dart';
import '../../../../design/widgets/speech_bubble.dart';
import '../../../../design/widgets/stat_tile.dart';

/// What a finished series is told. Three numbers, and nothing else.
///
/// **No rating and no delta** — the same subtraction the verdict screens already
/// make, for the same reason. The design makes `2.5` the one screen where a
/// rating change is genuinely meaningful, and Q3/D17 put the rating behind a
/// server that does not exist. A greyed-out pill for a figure nobody can compute
/// is precisely what that decision rejected: F2 shows no number a later sync
/// could contradict. It comes back with `f3-attempt-sync`.
class SeriesResult {
  const SeriesResult({
    required this.correct,
    required this.total,
    required this.elapsed,
    required this.streakDays,
  });

  final int correct;
  final int total;

  /// Measured quietly across the whole series (`req-quiet-timing`).
  final Duration elapsed;

  /// A local calendar fact, from `StreakPolicy`.
  final int streakDays;
}

/// `2.5 Resumen de serie` — the screen that makes a series a thing you finish.
///
/// Before this existed the round wrapped modulo its item list and played
/// forever, which is an exercise rather than a game. `ARCHITECTURE.md` §9's
/// definition of the first playable build is *"five items played on a plane"*,
/// and "played" needs an end.
///
/// **Aki is here.** The rule is that she never appears while the learner is
/// *solving*; a summary is not a solve, which is the same reading that puts her
/// on the verdict screens and keeps her off `0.3`.
class SeriesSummaryScreen extends StatelessWidget {
  const SeriesSummaryScreen({
    super.key,
    required this.result,
    required this.onDone,
  });

  final SeriesResult result;
  final VoidCallback onDone;

  static const double _akiWidth = 170;

  /// What Aki says, which is a function of the score and never of the failure.
  ///
  /// Four bands rather than one sentence: a fixed line would pass every copy
  /// assertion and tell a player who got none the same thing as a player who got
  /// all five. None of them names a mistake — `req-diagnosis-copy` is about the
  /// product, not about the verdict screen.
  String get _line {
    if (result.total == 0) return 'Listo.';
    if (result.correct == result.total) return '¡Todas! Qué manera de cerrar.';
    if (result.correct == 0) return 'Ya está la serie. La próxima cae otra.';
    if (result.correct * 2 >= result.total) return 'Buena serie. Vas bien.';
    return 'Serie terminada. Poco a poco.';
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold, not a bare ColoredBox: without a Material ancestor Flutter
    // paints a yellow debug underline under every run of text, which looks like
    // a defect and which `screen_text_style_test.dart` now fails on.
    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BrandShape.space4,
            vertical: BrandShape.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              Center(
                child: Aki(
                  width: _akiWidth,
                  pose: AkiPose.correct,
                  semanticLabel: 'Aki',
                ),
              ),
              const SizedBox(height: BrandShape.space3),
              Center(child: SpeechBubble(text: _line, maxWidth: 280)),
              const SizedBox(height: BrandShape.space5),
              _tiles(),
              const Spacer(),
              BrandButton.primary(label: 'Volver al inicio', onPressed: onDone),
            ],
          ),
        ),
      ),
    );
  }

  /// Three tiles: how many, how long, the streak.
  ///
  /// Three and not the five the design draws, because two of those are the
  /// server's. Same shape as the verdict screens' two.
  ///
  /// **Each takes a third of the row, and each figure scales down inside it.**
  /// Three natural-width tiles overflowed 390 px by 98, and `4 de 5` is the
  /// widest figure on any screen in the app. `Expanded` divides the row and the
  /// `FittedBox` keeps a long figure inside its own tile rather than pushing the
  /// next one off the edge — which is what has to hold at `textScaler` 1.3, the
  /// viewport the overflow gate actually checks.
  Widget _tiles() {
    return Row(
      children: <Widget>[
        Expanded(child: _tile('ACIERTOS', '${result.correct} de ${result.total}')),
        const SizedBox(width: BrandShape.space2),
        Expanded(
          child: _tile(
            'TIEMPO',
            EsMxNumber.seconds(result.elapsed.inMilliseconds / 1000, places: 1),
          ),
        ),
        const SizedBox(width: BrandShape.space2),
        Expanded(child: _tile('RACHA', EsMxNumber.integer(result.streakDays))),
      ],
    );
  }

  Widget _tile(String label, String figure) {
    return StatTile(
      label: label,
      value: FittedBox(
        fit: BoxFit.scaleDown,
        child: StatValue(figure, size: StatTileVariant.compact.valueSize),
      ),
      variant: StatTileVariant.compact,
    );
  }
}
