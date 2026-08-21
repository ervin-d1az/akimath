import 'package:flutter/material.dart';

import '../../../../content/model/diagnosis.dart';
import '../../../../demo/demo_figures.dart';
import '../../../../design/brand/aki.dart';
import '../../../../design/math/spec/es_mx_number.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../design/widgets/baseline_meter.dart';
import '../../../../design/widgets/brand_button.dart';
import '../../../../design/widgets/candy_surface.dart';
import '../../../../design/widgets/spec/verdict.dart';
import '../../../../design/widgets/speech_bubble.dart';
import '../../../../design/widgets/stat_tile.dart';
import '../../../../design/widgets/verdict_ring.dart';

/// How a finished series went.
///
/// **Everything here except the rating and the mastery bars is measured.** The
/// round graded every item and held the clock, so the per-item outcomes, the
/// total time and the streak are facts it hands over. The two that are not
/// come from `DemoFigures`, which is the one quarantined home for an invented
/// number — rating never runs in Dart, and nothing tracks mastery per skill.
class SeriesResult {
  const SeriesResult({
    required this.correct,
    required this.total,
    required this.elapsed,
    required this.streakDays,
    this.outcomes = const <Verdict>[],
    this.stumble,
  });

  final int correct;
  final int total;

  /// Measured quietly across the whole series (`req-quiet-timing`).
  final Duration elapsed;

  /// A local calendar fact, from `StreakPolicy`.
  final int streakDays;

  /// Every verdict, in the order the items were answered, from `RoundOutcome`.
  ///
  /// **Defaulted to empty because a caller may not have it yet**, and the
  /// screen states the score in words when it does not — an empty ring row
  /// would read as a clean sheet, which is the one wrong thing it could say.
  final List<Verdict> outcomes;

  /// The pack's words for the first slip, or null.
  ///
  /// Null on a clean series, and null when the pack declares no misconception
  /// copy. The block is absent either way: a heading over nothing is the thing
  /// `HISTORIAL` does not do on `4.1`.
  final Diagnosis? stumble;
}

/// `2.5 Resumen de serie` — the screen that makes a series a thing you finish.
///
/// Before this existed the round wrapped modulo its item list and played
/// forever, which is an exercise rather than a game.
///
/// **Aki is here, and the design is not why.** `2.5` draws no dog; the corpus
/// rule is that she never appears while the learner is *solving*, and
/// `quiet_while_you_solve_test.dart` names this screen among the three she must
/// be on. A summary is not a solve. The design departure is deliberate and the
/// committed test is the reason.
///
/// **It scrolls.** The design lays five blocks out in a fixed flex column that
/// happens to fit at `textScaler` 1.0; at 1.3 it does not, and the overflow
/// gate checks both. The button stays outside the scroll view so the way out is
/// never below the fold.
class SeriesSummaryScreen extends StatelessWidget {
  const SeriesSummaryScreen({
    super.key,
    required this.result,
    required this.onDone,
  });

  final SeriesResult result;
  final VoidCallback onDone;

  static const double _akiWidth = 120;

  /// The mark for one answered item.
  ///
  /// 22 and not the design's 18: `VerdictRing.defaultSize`'s own comment
  /// anticipates *"the strip passes 22 when it lands"*, and the glyph inside it
  /// — which is what makes the mark readable without hue — needs the room
  /// (BRD-2c).
  static const double _markSize = 22;

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
        child: Column(
          children: <Widget>[
            Expanded(child: _scrollingBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BrandShape.space4,
                BrandShape.space2,
                BrandShape.space4,
                BrandShape.space3,
              ),
              // **One button, and no `Ver el reto que falló`.** The design draws
              // a second one; nothing reviews a past item, so it would be a
              // control that does nothing. Absent rather than dead.
              child: BrandButton.primary(
                label: 'Volver al inicio',
                onPressed: onDone,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scrollingBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Aki(
              width: _akiWidth,
              pose: AkiPose.correct,
              semanticLabel: 'Aki',
            ),
          ),
          const SizedBox(height: BrandShape.space2),
          Center(child: SpeechBubble(text: _line, maxWidth: 280)),
          const SizedBox(height: BrandShape.space4),
          _headline(),
          const SizedBox(height: BrandShape.space3),
          _tiles(),
          if (DemoFigures.enabled) ...<Widget>[
            const SizedBox(height: BrandShape.space3),
            _whatImproved(),
          ],
          ..._whatWentWrong(),
          if (DemoFigures.enabled) ...<Widget>[
            const SizedBox(height: BrandShape.space3),
            _whatIsNext(),
          ],
        ],
      ),
    );
  }

  /// `SERIE COMPLETA`, and the ring of per-item outcomes under it.
  ///
  /// The design puts them on one row. Five marks and a 40 px display face do not
  /// share 350 px, and at `textScaler` 1.3 they share less — so the ring gets
  /// its own row and keeps the mark size the glyph needs.
  Widget _headline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('SERIE COMPLETA', style: BrandText.sectionTitle(size: 28)),
        const SizedBox(height: BrandShape.space2),
        _score(),
      ],
    );
  }

  /// The ring, or the count in words when the outcomes are not known.
  ///
  /// **Never nothing.** A caller that hands over no outcomes still played a
  /// series, and an empty row where the marks go reads as a clean sheet.
  Widget _score() {
    if (result.outcomes.isEmpty) {
      return Text(
        '${result.correct} de ${result.total}',
        style: BrandText.numeral(24),
      );
    }
    return Wrap(
      spacing: BrandShape.space1,
      runSpacing: BrandShape.space1,
      children: <Widget>[
        for (final Verdict outcome in result.outcomes)
          VerdictRing(outcome, size: _markSize),
      ],
    );
  }

  /// Three tiles, as the design draws them: the rating, the time, the streak.
  ///
  /// **`RACHA` and not the design's `DÍAS`.** `4.1` already labels *days
  /// practised* `DÍAS`, and that is a different figure from a streak; one word
  /// for two facts teaches a reader the wrong one.
  ///
  /// **Each figure scales down inside its tile.** Three natural-width tiles
  /// overflowed 390 px by 98, and `FittedBox` keeps a long figure inside its own
  /// tile rather than pushing the next one off the edge — which is what has to
  /// hold at `textScaler` 1.3.
  Widget _tiles() {
    return Row(
      children: <Widget>[
        Expanded(child: _ratingTile()),
        const SizedBox(width: BrandShape.space2),
        Expanded(
          child: _tile(
            'EN TOTAL',
            EsMxNumber.seconds(result.elapsed.inMilliseconds / 1000, places: 1),
          ),
        ),
        const SizedBox(width: BrandShape.space2),
        Expanded(child: _tile('RACHA', EsMxNumber.integer(result.streakDays))),
      ],
    );
  }

  /// The one invented figure on the screen, from the file that holds them.
  ///
  /// **Not `StatTile.delta`, and that is a workaround.** That factory renders
  /// its two runs unfitted, so at `textScaler` 1.3 `+ 12` overflows a third of
  /// this row by 3 px and the overflow gate goes red. The fix belongs inside
  /// the factory — every other figure on this screen is already wrapped — and
  /// `design/widgets/` was not this change's to edit. `deltaParts` is public
  /// precisely so no caller concatenates a sign by hand, which is what keeps
  /// U+2212 correct here.
  Widget _ratingTile() {
    final DeltaParts parts =
        EsMxNumber.deltaParts(DemoFigures.seriesRatingDelta);
    return StatTile(
      label: 'RATING',
      variant: StatTileVariant.compact,
      value: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            if (parts.sign.isNotEmpty) ...<Widget>[
              // 15 against the digits' 24: the sign is a modifier on the
              // number, not a second number beside it.
              Text(parts.sign, style: BrandText.action(size: 15)),
              const SizedBox(width: BrandShape.space1),
            ],
            Text(
              parts.digits,
              style: BrandText.numeral(StatTileVariant.compact.valueSize),
            ),
          ],
        ),
      ),
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

  /// `QUÉ MEJORÓ` — two invented mastery bars.
  Widget _whatImproved() {
    return _card(
      label: 'QUÉ MEJORÓ',
      children: <Widget>[
        for (final DemoSkillBar bar in DemoFigures.seriesSkills) ...<Widget>[
          const SizedBox(height: BrandShape.space2),
          _skillBar(bar),
        ],
      ],
    );
  }

  Widget _skillBar(DemoSkillBar bar) {
    return Row(
      children: <Widget>[
        // Flexible rather than the design's fixed 96 px: at `textScaler` 1.3 a
        // longer skill name would overflow a box it cannot grow out of.
        Expanded(
          flex: 2,
          child: Text(bar.skill, style: BrandText.action(size: 13)),
        ),
        const SizedBox(width: BrandShape.space2),
        Expanded(
          flex: 3,
          child: BaselineMeter(
            fill: bar.level,
            fraction: bar.percent / 100,
            baseline: bar.before / 100,
          ),
        ),
        const SizedBox(width: BrandShape.space2),
        Text(EsMxNumber.percent(bar.percent), style: BrandText.numeral(15)),
      ],
    );
  }

  /// `QUÉ SE TORCIÓ` — the pack's own words for the first slip, or nothing.
  ///
  /// Returns a list so the gap above it disappears with it; a `SizedBox` left
  /// behind is a paragraph of blank cream nobody can explain.
  List<Widget> _whatWentWrong() {
    final Diagnosis? stumble = result.stumble;
    if (stumble == null) {
      return const <Widget>[];
    }
    return <Widget>[
      const SizedBox(height: BrandShape.space3),
      CandySurface(
        background: BrandColorRole.error.color,
        borderRadius: BrandShape.radiusCard,
        padding: const EdgeInsets.all(BrandShape.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'QUÉ SE TORCIÓ',
              // Ink, not the default muted: `4.1`'s muted eyebrow sits on white,
              // and the design sets this one on ink because the card is coral.
              style: BrandText.eyebrow(color: BrandColors.ink),
            ),
            for (final String step in stumble.steps) ...<Widget>[
              const SizedBox(height: BrandShape.space2),
              Text(step, style: BrandText.body()),
            ],
          ],
        ),
      ),
    ];
  }

  /// `QUÉ SIGUE · UNA SOLA COSA` — one invented recommendation.
  Widget _whatIsNext() {
    return _card(
      label: 'QUÉ SIGUE · UNA SOLA COSA',
      children: <Widget>[
        const SizedBox(height: BrandShape.space2),
        Text(DemoFigures.seriesNext, style: BrandText.sectionTitle(size: 22)),
        const SizedBox(height: BrandShape.space1),
        Text(DemoFigures.seriesNextNote, style: BrandText.caption()),
      ],
    );
  }

  Widget _card({required String label, required List<Widget> children}) {
    return CandySurface(
      borderRadius: BrandShape.radiusCard,
      padding: const EdgeInsets.all(BrandShape.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: BrandText.eyebrow()),
          ...children,
        ],
      ),
    );
  }
}
