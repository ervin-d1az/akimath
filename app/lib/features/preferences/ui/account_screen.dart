import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/detail_header.dart';
import '../../../design/widgets/settings_row.dart';
import '../../../design/widgets/candy_surface.dart';
import '../policy/erasure.dart';

/// `4.3 Cuenta` — the address, the two acts on it, and the one way out.
///
/// **All four of the design's rows, and each one only where it can act.** The
/// row is drawn when its caller hands a callback and is absent when it does
/// not, which is the shape `onErase` already had: a control that cannot act
/// reads as broken rather than as unbuilt, and a player cannot tell *not yet*
/// from *not for you* (DR-P2).
///
/// **This screen navigates nowhere itself.** Every push in this corner of the
/// app belongs to `ProfileRoute`, which holds the session and the token; a
/// second navigation owner here would be two places deciding what `Cuenta`
/// leads to.
///
/// **The erasure is not a bottom sheet.** The design draws one. The question
/// has to carry a sentence about what *survives* — the address stays registered
/// with the identity provider, which is not ours to delete — and that does not
/// fit a sheet. It is a full screen, and it carries the design's typed `BORRAR`
/// gate.
class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.onBack,
    required this.email,
    this.onErase,
    this.onChangePassword,
    this.onSignOut,
  });

  final VoidCallback onBack;
  final String email;

  /// Offered only where this device holds a session the request could travel
  /// on — see `erasureOffered`. Absent rather than dead.
  final VoidCallback? onErase;

  /// Opens the screen that says a password change is not built yet. A chevron
  /// goes with it, because something does open.
  final VoidCallback? onChangePassword;

  /// Forgets the session this device is holding. **No chevron**: it acts in
  /// place, and the mark would promise a screen that never arrives.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? erase = onErase;
    final VoidCallback? changePassword = onChangePassword;
    final VoidCallback? signOut = onSignOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: 'CUENTA', onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BrandShape.space4,
              BrandShape.space5,
              BrandShape.space4,
              BrandShape.space4,
            ),
            children: <Widget>[
              // **A card, not a `SettingsRow` with a value.** The design's
              // value-bearing row carries `19:30`; an address is four times
              // that and overflowed the row at the text setting this app is
              // gated for — which the overflow gate caught before anybody
              // looked at it. A label over its value has room for both, and it
              // is the same card language the rest of the document uses.
              CandySurface(
                borderRadius: BrandShape.radiusButton,
                shadowOffset: BrandShape.shadowTile,
                padding: const EdgeInsets.symmetric(
                  horizontal: BrandShape.space4,
                  vertical: BrandShape.space3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('CORREO', style: BrandText.eyebrow()),
                    const SizedBox(height: BrandShape.space1),
                    Text(email, style: BrandText.cardTitle(size: 16)),
                  ],
                ),
              ),
              if (changePassword != null) ...<Widget>[
                const SizedBox(height: BrandShape.space3),
                SettingsRow(
                  label: 'Cambiar contraseña',
                  onOpen: changePassword,
                ),
              ],
              if (signOut != null) ...<Widget>[
                const SizedBox(height: BrandShape.space3),
                SettingsRow(
                  label: 'Cerrar sesión',
                  onOpen: signOut,
                  showChevron: false,
                ),
              ],
              if (erase != null) ...<Widget>[
                const SizedBox(height: BrandShape.space5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BrandButton.text(
                    label: erasureDoorLabel,
                    onPressed: erase,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
