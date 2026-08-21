import 'package:flutter/widgets.dart';

import '../../../design/icons/brand_icon.dart';
import '../../../design/icons/spec/brand_glyph.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/centered_state_view.dart';
import '../policy/offline_bag.dart';

/// `4.9 Sin conexión` — no signal, and a pack already in the bag.
///
/// **Yellow, never coral.** The declared rules are explicit: *"Sin conexión no
/// es un error del usuario: va en amarillo."* Nothing here is anybody's
/// mistake, so nothing here is drawn as one.
///
/// **The banner is inside the screen, not in the shell's slot.** `AppShell`
/// has one and `fullScreenSession` does not, and this state is pushed as a
/// session — so a screen relying on the slot would lose its banner exactly
/// where the design draws it. The markup agrees: `4.9` draws the notice band
/// *within* the phone frame, above its own content.
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({
    super.key,
    required this.challenges,
    required this.puzzles,
    required this.onSolveOffline,
  });

  /// What the pack on this device holds. Counted by the caller from the real
  /// pack — this screen invents no figure.
  final int challenges;
  final int puzzles;

  /// Into a series played from that pack.
  ///
  /// **Required, because a state with no way out is a dead end** and this one
  /// has an obvious way out: the pack is already here. Only a caller holding
  /// the pack and the navigator can honour it, which is why this screen is
  /// pushed from the home and not from the profile — see the class comment.
  final VoidCallback onSolveOffline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            BrandShape.space4,
            BrandShape.space2,
            BrandShape.space4,
            0,
          ),
          child: OfflineNotice(),
        ),
        Expanded(
          child: CenteredStateView(
            aki: true,
            headlineLines: offlineBagHeadline(challenges),
            content: _bag(),
            primary: BrandButton.primary(
              label: 'Resolver sin conexión',
              onPressed: onSolveOffline,
            ),
          ),
        ),
      ],
    );
  }

  /// The pack, counted.
  Widget _bag() {
    final List<BagPile> piles = bagTally(
      challenges: challenges,
      puzzles: puzzles,
    );

    return CandySurface(
      borderRadius: BrandShape.radiusPanel,
      shadowOffset: BrandShape.shadowButton,
      padding: const EdgeInsets.all(BrandShape.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('PAQUETE DESCARGADO', style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space3),
          Row(
            children: <Widget>[
              for (int i = 0; i < piles.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: BrandShape.space2),
                Expanded(child: _pile(piles[i])),
              ],
            ],
          ),
          const SizedBox(height: BrandShape.space3),
        // **Not the design's "Tu rating se guarda aquí".** Rating is F4 and
        // `GET /me/standing` returns no figure, so the sentence keeps the half
        // the app can honour: `AttemptSync` journals every answer and flushes
        // it when a session exists. Same carve-out `StreakLostScreen` took.
          Text(
            'Lo que resuelvas se guarda aquí y se pone al día cuando haya señal.',
            style: BrandText.body(height: 1.4),
          ),
        ],
      ),
    );
  }

  /// One pile: a figure over what it counts.
  ///
  /// Composed here rather than taken from `StatTile`, which fixes its own
  /// background to white — the design sets these cream against the white card,
  /// and a white tile on a white card is not a tile.
  Widget _pile(BagPile pile) => CandySurface(
    background: BrandColorRole.canvas.color,
    borderRadius: BrandShape.radiusStatTileFlat,
    borderWidth: BrandShape.borderWidthSmallSurface,
    shadowOffset: Offset.zero,
    padding: const EdgeInsets.symmetric(vertical: BrandShape.space2),
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(pile.figure, style: BrandText.numeral(24)),
        const SizedBox(height: BrandShape.space1),
        Text(pile.label, style: BrandText.eyebrow(size: 10)),
      ],
    ),
  );
}

/// The notice band `4.9` carries: yellow, a struck-through signal mark, one
/// line.
///
/// **Its own widget, so a test can name it.** Asserting the copy proves the
/// words; asserting the type proves the band is the *notice* and not an error
/// banner that happens to read the same — which is the half BRD-1 is about.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({super.key});

  @override
  Widget build(BuildContext context) => CandySurface(
    background: BrandColorRole.highlight.color,
    borderRadius: BrandShape.radiusPill,
    shadowOffset: BrandShape.shadowPill,
    padding: const EdgeInsets.symmetric(
      horizontal: BrandShape.space3,
      vertical: BrandShape.space2,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const BrandIcon(BrandGlyph.wifiOff, size: 18),
        const SizedBox(width: BrandShape.space2),
        Flexible(
          child: Text(
            'Sin conexión · se sincroniza al volver',
            style: BrandText.cardTitle(size: 13),
          ),
        ),
      ],
    ),
  );
}
