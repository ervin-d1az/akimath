import 'package:flutter/material.dart';

import '../../../design/brand/aki.dart';
import '../../../design/math/spec/es_mx_number.dart';
import '../../../design/widgets/speech_bubble.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/spec/verdict.dart';
import '../../../design/widgets/spec/verdict_copy.dart';
import '../../../design/widgets/stat_tile.dart';
import '../../../design/widgets/brand_button.dart';
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
/// The verdict preview and its legend. It earns its place by
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
    this.onCreateAccount,
    this.accountEmail,
  });

  /// Opens the account flow, or null while the build has no endpoints
  /// configured — a button that can only fail is worse than an absent one, the
  /// same reading that keeps every toggle off this screen (DR-P2).
  final VoidCallback? onCreateAccount;

  /// The linked account's address, once there is one. `4.1` greets the address
  /// because a player has no name (Q5).
  final String? accountEmail;

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
          if (onCreateAccount != null || accountEmail != null) ...<Widget>[
            Text('TU CUENTA', style: BrandText.eyebrow()),
            const SizedBox(height: BrandShape.space3),
            if (accountEmail != null)
              Text(
                accountEmail!,
                key: const Key('preferences-account-email'),
                style: BrandText.body(),
              )
            else
              BrandButton.primary(
                label: 'Crear cuenta',
                onPressed: onCreateAccount!,
              ),
            const SizedBox(height: BrandShape.space5),
          ],
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
          const SizedBox(height: BrandShape.space5),
          // **Aki is allowed here.** The rule is that she never appears while
          // the learner is *solving*; a settings screen is not a solve, which
          // is the same reading that puts her on the verdict screens and the
          // series summary and keeps her off `0.3`.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Aki(width: 120, semanticLabel: 'Aki'),
                const SizedBox(height: BrandShape.space3),
                const SpeechBubble(
                  text: 'Aquí guardo tu avance. Nada sale de este teléfono.',
                  maxWidth: 300,
                ),
              ],
            ),
          ),
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
          // **The same words the screens use** — from `verdict_copy.dart`, so
          // the key cannot teach a term a player will never meet. It used to
          // say *Acierto* and *Se torció* while `03` and `04` said *¡Bien
          // hecho!* and *Casi*.
          _legendRow(Verdict.correct),
          const SizedBox(height: BrandShape.space4),
          _legendRow(Verdict.wrong),
        ],
      ),
    );
  }

  Widget _legendRow(Verdict verdict) {
    final String title = verdictHeadline(verdict);
    final String meaning = verdictMarkDescription(verdict);
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
