import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../policy/data_privacy.dart';
import 'settings_detail_scaffold.dart';

/// `4.7 Datos y privacidad` — what the app would hand over, and what it cannot
/// hand over yet.
///
/// **The cards are drawn and the buttons are not.** `Pedir mi archivo` has no
/// endpoint behind it, and `Borrar historial` has none either — `DELETE /me`
/// erases the player and everything under it, which is a different act with
/// its own screen on `4.3 Cuenta`. A button that produces nothing is the
/// control DR-P2 rules out, and it is a worse lie than an absent one because
/// the player *does* something and is told nothing.
///
/// A switch is a different case and this screen is deliberately not treated
/// like `4.4`: a switch that records a real answer has done what it claims, and
/// a button whose action does not exist has not.
///
/// **`Aviso de privacidad` and `Términos` are absent**, because neither
/// document has been written. A row to an empty screen is the same failure one
/// level up.
class DataPrivacyScreen extends StatelessWidget {
  const DataPrivacyScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  /// How many cards this screen draws, stated once so its test holds the list
  /// to a number rather than to one typed twice.
  static const int cardCount = 2;

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: 'DATOS Y PRIVACIDAD',
      onBack: onBack,
      children: <Widget>[
        for (final DataRequest request in DataRequest.values)
          _RequestCard(request),
      ],
    );
  }
}

/// One request: what it is, what it would do, and why it cannot be made.
class _RequestCard extends StatelessWidget {
  const _RequestCard(this.request);

  final DataRequest request;

  @override
  Widget build(BuildContext context) {
    return SettingsGroupCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(request.title, style: BrandText.cardTitle(size: 16)),
          const SizedBox(height: BrandShape.space2),
          Text(request.description, style: BrandText.caption()),
          const SizedBox(height: BrandShape.space2),
          Text(request.unavailable, style: BrandText.caption()),
        ],
      ),
    );
  }
}
