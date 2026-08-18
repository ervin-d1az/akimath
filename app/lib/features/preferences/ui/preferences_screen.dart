import 'package:flutter/material.dart';

import '../../../design/math/spec/es_mx_number.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/spec/verdict.dart';
import '../../../design/widgets/stat_tile.dart';
import '../../../design/widgets/verdict_ring.dart';

/// `4.5`, reduced to what F2 can source — the second root, and the one that
/// gives the shell a bar.
///
/// **Two figures and one card.**
///
/// The figures are the only ones a device can compute: days practised and the
/// current run. Everything else `4.1 Perfil` prints — rating, a seven-day
/// delta, accuracy, mean time, a history feed — is the server's at F3. A
/// settings screen that showed them would be printing numbers nothing can
/// calculate, which is the same reason the verdict screens show no rating.
///
/// The card is the one the implementation plan already decided v1 ships: the
/// `Acierto` / `Se torció` preview and its legend. It earns its place by
/// teaching the pair somewhere other than mid-round — a learner meets these two
/// marks in the second where they most want to know what happened.
///
/// **No toggles.** `Reducir movimiento` acquires an effect at F8, `TAMAÑO DE
/// TEXTO` and `Alto contraste` have no specification, and `Modo daltonismo`
/// would change nothing while shape already carries every verdict. A switch
/// that does nothing is worse than an absent one, so none is drawn (DR-P2).
class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({
    super.key,
    required this.daysPractised,
    required this.streakDays,
  });

  /// Distinct days recorded on this device.
  final int daysPractised;

  /// From `StreakPolicy` — the same local fact the home shows.
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('TU PROGRESO', style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space3),
          Row(
            children: <Widget>[
              Expanded(child: _tile('DÍAS', daysPractised)),
              const SizedBox(width: BrandShape.space2),
              Expanded(child: _tile('RACHA', streakDays)),
            ],
          ),
          const SizedBox(height: BrandShape.space5),
          Text('CÓMO SE LEEN LOS RETOS', style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space3),
          _legend(),
        ],
      ),
    );
  }

  Widget _tile(String label, int value) => StatTile(
        label: label,
        value: FittedBox(
          fit: BoxFit.scaleDown,
          child: StatValue(
            EsMxNumber.integer(value),
            size: StatTileVariant.compact.valueSize,
          ),
        ),
        variant: StatTileVariant.compact,
      );

  /// The two marks, side by side, with what each one means.
  ///
  /// They differ by **shape** before they differ by hue — a solid ring against
  /// a dashed one — which is the whole reason `Verdict` carries an outline and
  /// a glyph and not a colour (BRD-1). Shown together so the difference is
  /// legible as a difference, which it never is one screen at a time.
  Widget _legend() {
    return CandySurface(
      borderRadius: BrandShape.radiusCardMedium,
      padding: const EdgeInsets.all(BrandShape.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _legendRow(
            Verdict.correct,
            'Acierto',
            'El aro va completo, sin cortes.',
          ),
          const SizedBox(height: BrandShape.space4),
          _legendRow(
            Verdict.wrong,
            'Se torció',
            'El aro va cortado. Lo vuelves a intentar.',
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Verdict verdict, String title, String meaning) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        VerdictRing(verdict, size: 44),
        const SizedBox(width: BrandShape.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: BrandText.cardTitle()),
              const SizedBox(height: 2),
              Text(meaning, style: BrandText.caption()),
            ],
          ),
        ),
      ],
    );
  }
}
