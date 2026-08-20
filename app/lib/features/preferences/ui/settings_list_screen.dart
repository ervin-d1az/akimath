import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/detail_header.dart';
import '../../../design/widgets/settings_row.dart';

/// `4.2 Ajustes` — the settings root, pushed from `Perfil`'s gear.
///
/// **Pushed, not rooted.** Declared rule 1 names the bar's homes as *inicio,
/// mapa, progreso y perfil*; Ajustes is not one, and the group badge over
/// `4.1`–`4.7` says *"Aquí sí va la barra inferior"* because the **stack** sits
/// above a home rather than replacing it. So this pushes onto the tab's own
/// navigator and the bar stays underneath.
///
/// **Two rows, because two destinations exist.** The design lists six.
/// `Notificaciones` needs a notification plugin and `Sonido y vibración` an
/// audio engine, neither of which is in `pubspec.yaml` and both of which are a
/// DEP-1 decision before they are a screen; `Ayuda` has no design at all; and
/// `Datos y privacidad`'s two halves are a server job and a **third erasure
/// path** against a schema that grants DELETE on `attempts` to `retention_job`
/// alone.
///
/// They are absent rather than greyed out. A control that cannot act reads as
/// broken rather than as unbuilt, and a player cannot tell *not yet* from *not
/// for you* (DR-P2).
class SettingsListScreen extends StatelessWidget {
  const SettingsListScreen({
    super.key,
    required this.onBack,
    required this.onOpenAccount,
    required this.onOpenLegend,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenLegend;

  /// How many rows this screen draws.
  ///
  /// Stated so the test can hold the list to it rather than to a number typed
  /// twice — and so adding a row is a diff that says so.
  static const int rowCount = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: 'AJUSTES', onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BrandShape.space4,
              BrandShape.space5,
              BrandShape.space4,
              BrandShape.space4,
            ),
            children: <Widget>[
              SettingsRow(label: 'Cuenta', onOpen: onOpenAccount),
              const SizedBox(height: BrandShape.space3),
              SettingsRow(
                label: 'Cómo se leen los retos',
                onOpen: onOpenLegend,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
