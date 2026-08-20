import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/detail_header.dart';
import '../../../design/widgets/candy_surface.dart';
import '../policy/erasure.dart';

/// `4.3 Cuenta` — the address, and the one way out.
///
/// **Two of the design's four rows.** `Cambiar contraseña` needs a Neon Auth
/// flow nobody has built and `Cerrar sesión` needs somewhere for a signed-out
/// device to go that is not the erasure's answer; both are absent rather than
/// inert (DR-P2).
///
/// **The erasure is not a bottom sheet.** The design draws one, with a typed
/// `BORRAR` gate. The question has to carry a sentence about what *survives* —
/// the address stays registered with the identity provider, which is not ours
/// to delete — and that does not fit a sheet. It is a full screen, and the
/// typed gate is worth taking on its own.
class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.onBack,
    required this.email,
    this.onErase,
  });

  final VoidCallback onBack;
  final String email;

  /// Offered only where this device holds a session the request could travel
  /// on — see `erasureOffered`. Absent rather than dead.
  final VoidCallback? onErase;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? erase = onErase;

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
