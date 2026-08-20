import 'package:flutter/widgets.dart';

import '../../../design/brand/aki.dart';
import '../../../design/icons/brand_icon.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/icon_button_tile.dart';
import '../../states/policy/account_state.dart';
import '../../states/ui/account_state_view.dart';

/// `4.1 Perfil` — the third nav home, and the one the design names.
///
/// **The bar's homes are `inicio, mapa, progreso y perfil`** (declared rule 1).
/// The app's third root was `Ajustes`, which that rule explicitly does not name
/// — right while it was the only second destination there was, and a
/// contradiction from the day `Avance` arrived. This is the root; Ajustes is
/// the stack above it, reached from the gear.
///
/// **Thin, and honestly so.** The design draws a rating, a seven-day delta,
/// three aggregate figures and a history feed. The first four are F4 or need
/// totals no endpoint answers; the fifth exists and is **already on `Avance`**,
/// moved there because what a player has done is not a setting. Drawing it
/// twice would make two screens that can disagree about one feed. The
/// alternative to thin is a screen of figures nothing can compute, which this
/// project has now declined three times.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.accountState,
    required this.onOpenSettings,
    this.accountEmail,
    this.onCreateAccount,
    this.onRetryAccount,
  });

  /// The linked account's address, once there is one.
  ///
  /// `4.1` greets a name. A player has none — the app never asks for one — so
  /// the address stands in, which is the reading Q5 already settled.
  final String? accountEmail;

  /// Where the account stands with our own server.
  final AccountState accountState;

  /// Opens the settings stack. The one thing on this screen that navigates,
  /// and the design's own: `4.1` puts a 48×48 gear at the end of the identity
  /// row and nothing else on it goes anywhere.
  final VoidCallback onOpenSettings;

  /// Offered only where the build has endpoints to reach (DR-P2).
  final VoidCallback? onCreateAccount;

  /// Offered only where retrying could change the answer.
  final VoidCallback? onRetryAccount;

  /// The avatar tile: `4.1` clips a 66 px full-body Aki inside a 78 px tile.
  static const double _tile = 78;
  static const double _aki = 66;

  @override
  Widget build(BuildContext context) {
    final String? email = accountEmail;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              CandySurface.tile(
                size: _tile,
                // **Not `pinkSoft`.** The design fills this tile `#FFC9DC`,
                // which is seven, six and four off the token — a near miss
                // nobody has decided is the same colour (Q2). Until somebody
                // does, the tile takes the accent the app already has rather
                // than a seventeenth pink.
                background: BrandColors.pinkSoft,
                borderRadius: BrandShape.radiusCardMedium,
                child: Aki(width: _aki, semanticLabel: 'Aki'),
              ),
              const SizedBox(width: BrandShape.space3),
              Expanded(
                child: Text(
                  email ?? 'Sin cuenta en este teléfono',
                  style: email == null
                      ? BrandText.caption()
                      : BrandText.cardTitle(size: 16),
                ),
              ),
              const SizedBox(width: BrandShape.space2),
              Semantics(
                button: true,
                label: 'Ajustes',
                child: IconButtonTile(
                  onPressed: onOpenSettings,
                  child: const BrandIcon(BrandGlyph.gear, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: BrandShape.space5),
          if (email != null)
            // **No `email:`.** The identity row above owns the address, and
            // handing it to the state view too drew it twice — which the design
            // does not, and which a test caught before the screen was looked
            // at. What the view owns is the *state*: whether this device's
            // token still works, and whether that is ours to apologise for.
            AccountSection(
              child: AccountStateView(
                state: accountState,
                onRetry: onRetryAccount,
              ),
            )
          else if (onCreateAccount != null)
            BrandButton.primary(
              label: 'Crear cuenta',
              onPressed: onCreateAccount!,
            ),
        ],
      ),
    );
  }
}
