import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/detail_header.dart';

/// Where `Cambiar contraseña` goes, which is a screen that says it cannot yet.
///
/// **A destination rather than an inert row.** DR-P2's objection is to a
/// control that looks like it acts and does not; this one acts — it opens a
/// screen — and what the screen does is tell the truth. The alternative is a
/// row with a chevron that goes nowhere, which is the thing the rule is about.
///
/// **It offers no field.** Changing a password is the identity provider's act,
/// not ours: this app holds no credential that could do it, and a form here
/// would either fail or, worse, look like it had worked. The only things worth
/// saying are that it is not built and that the password already in use still
/// works.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: 'CONTRASEÑA', onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BrandShape.space4,
              BrandShape.space5,
              BrandShape.space4,
              BrandShape.space4,
            ),
            children: <Widget>[
              CandySurface(
                borderRadius: BrandShape.radiusButton,
                shadowOffset: BrandShape.shadowTile,
                padding: const EdgeInsets.symmetric(
                  horizontal: BrandShape.space4,
                  vertical: BrandShape.space4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      changePasswordHeadline,
                      style: BrandText.cardTitle(size: 18),
                    ),
                    const SizedBox(height: BrandShape.space3),
                    Text(changePasswordDetail, style: BrandText.body()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the screen says, and it says it is not built.
const String changePasswordHeadline = 'Todavía no se puede desde aquí';

/// **It names who holds the password.** The same honesty the erasure screen
/// owes about the address: the credential lives with the identity provider, so
/// a sentence claiming we could change it would be the second lie this corner
/// of the app is able to tell.
const String changePasswordDetail =
    'Tu contraseña la guarda quien nos lleva las cuentas, no nosotros, y esa '
    'parte todavía no está conectada. Mientras tanto, la que ya tienes sigue '
    'funcionando.';
