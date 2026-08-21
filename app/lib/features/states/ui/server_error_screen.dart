import 'package:flutter/widgets.dart';

import '../../../design/icons/brand_icon.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/centered_state_view.dart';
import 'state_chip.dart';

/// `4.10 Error de servidor` — the server did not answer, and it is ours.
///
/// **No Aki.** The design annotates this screen *"sin Aki: no le toca"*, and
/// the declared rules say the same thing twice: she is absent while solving and
/// absent from account and server errors. An apology from the dog reads as the
/// dog being at fault, which is the opposite of what the headline says.
///
/// **Coral, and only on the mark.** Coral is error and nothing else (BRD-1);
/// the cross on the server tile is the one thing here that carries it, and the
/// error is told by shape as much as by hue — a struck-through machine, not a
/// coral panel.
class ServerErrorScreen extends StatelessWidget {
  const ServerErrorScreen({
    super.key,
    required this.note,
    required this.onRetry,
    this.onSolveOffline,
  });

  /// The annotation chip, from `serverErrorNote`. Null where the caller knows
  /// neither a status nor a time, in which case no chip is drawn.
  final String? note;

  /// Ask again. Always offered: this screen exists because retrying is the
  /// thing worth doing, and it is the design's green button.
  final VoidCallback onRetry;

  /// Into a series played from the pack already on the device.
  ///
  /// **Optional, because not every caller has one.** The profile notices the
  /// server is down and cannot start a series from there; the design's second
  /// button is absent rather than dead (DR-P2), the same call
  /// `StreakAtRiskScreen` made about *"Recuérdame a las 21:00"*.
  final VoidCallback? onSolveOffline;

  /// The design's 150px tile, and the 74px mark inside it.
  static const double _tile = 150;
  static const double _mark = 74;

  @override
  Widget build(BuildContext context) {
    final String? chip = note;
    final VoidCallback? offline = onSolveOffline;

    return CenteredStateView(
      kicker: const _ServerTile(size: _tile, mark: _mark),
      headlineLines: const <String>['NO SOMOS TÚ,', 'SOMOS NOSOTROS'],
      body: 'El servidor no contestó. '
          'Tu progreso está a salvo en este teléfono.',
      content: chip == null ? null : Center(child: StateChip.note(label: chip)),
      primary: BrandButton.primary(
        label: 'Intentar de nuevo',
        onPressed: onRetry,
      ),
      secondary: offline == null
          ? null
          : BrandButton.secondary(
              label: 'Resolver sin conexión',
              onPressed: offline,
            ),
    );
  }
}

/// A machine with a cross through it.
///
/// **Composed from surfaces rather than drawn as a glyph.** The design's mark
/// is an inline `<svg>` on this screen alone, and `icon_paths.dart` holds the
/// sixteen marks that are *transcribed* from the icon sheet — adding a
/// seventeenth from a screen's own artwork would put a one-off in the set every
/// other screen shares. Two stacked units and a struck corner say the same
/// thing out of pieces the brand already owns.
class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.size, required this.mark});

  final double size;
  final double mark;

  @override
  Widget build(BuildContext context) => CandySurface(
    width: size,
    height: size,
    borderRadius: BrandShape.radiusSheet,
    shadowOffset: BrandShape.shadowCard,
    alignment: Alignment.center,
    child: SizedBox(
      width: mark,
      height: mark,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const _ServerUnit(),
              const SizedBox(height: BrandShape.space2),
              const _ServerUnit(),
            ],
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: BrandIcon(
              BrandGlyph.close,
              size: mark / 2,
              // The one coral thing on the screen, and it is a shape as well
              // as a hue — BRD-1 does not let the colour carry the meaning.
              color: BrandColorRole.error.color,
            ),
          ),
        ],
      ),
    ),
  );
}

/// One rack unit: an outlined bar with its indicator light.
class _ServerUnit extends StatelessWidget {
  const _ServerUnit();

  static const double _height = 26;
  static const double _light = 5;

  @override
  Widget build(BuildContext context) => CandySurface(
    height: _height,
    borderRadius: BrandShape.radiusSlot,
    borderWidth: BrandShape.borderWidthSmallSurface,
    shadowOffset: Offset.zero,
    padding: const EdgeInsets.symmetric(horizontal: BrandShape.space2),
    alignment: Alignment.centerLeft,
    child: Container(
      width: _light,
      height: _light,
      decoration: const BoxDecoration(
        color: BrandColors.ink,
        shape: BoxShape.circle,
      ),
    ),
  );
}
