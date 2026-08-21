import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/detail_header.dart';
import '../../../design/widgets/settings_row.dart';
import 'accessibility_screen.dart';
import 'data_privacy_screen.dart';
import 'notifications_screen.dart';
import 'settings_detail_routes.dart';
import 'sound_screen.dart';

/// `4.2 Ajustes` — the settings root, pushed from `Perfil`'s gear.
///
/// **Pushed, not rooted.** Declared rule 1 names the bar's homes as *inicio,
/// mapa, progreso y perfil*; Ajustes is not one, and the group badge over
/// `4.1`–`4.7` says *"Aquí sí va la barra inferior"* because the **stack** sits
/// above a home rather than replacing it. So this pushes onto the tab's own
/// navigator and the bar stays underneath.
///
/// **Five of the design's six rows, plus one it does not draw.** `Ayuda` is the
/// one still absent: no document, no screen, nowhere for it to go. It is absent
/// rather than greyed out, because a control that cannot act reads as broken
/// rather than as unbuilt and a player cannot tell *not yet* from *not for you*
/// (DR-P2). `Cómo se leen los retos` is in no design and so sits after
/// everything that is.
///
/// **Four rows open their own screen and two report to the caller.** The split
/// is what each destination needs: `Cuenta` needs the signed-in address, which
/// only the route above this one holds, so it stays a callback. Notifications,
/// accessibility, sound and privacy need nothing but their own stores, so the
/// row builds them — see [pushSettingsDetail].
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
  static const int rowCount = 6;

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
            children: _spaced(_rows(context)),
          ),
        ),
      ],
    );
  }

  /// The rows with the design's gap between them, and none before the first.
  static List<Widget> _spaced(List<Widget> rows) {
    return <Widget>[
      for (int index = 0; index < rows.length; index++) ...<Widget>[
        if (index > 0) const SizedBox(height: BrandShape.space3),
        rows[index],
      ],
    ];
  }

  List<Widget> _rows(BuildContext context) {
    return <Widget>[
      SettingsRow(label: 'Cuenta', onOpen: onOpenAccount),
      SettingsRow(
        label: 'Notificaciones',
        onOpen: () => pushSettingsDetail(
          context,
          (VoidCallback back) => NotificationsScreen(onBack: back),
        ),
      ),
      SettingsRow(
        label: 'Accesibilidad',
        onOpen: () => pushSettingsDetail(
          context,
          (VoidCallback back) => AccessibilityScreen(onBack: back),
        ),
      ),
      SettingsRow(
        label: 'Sonido y vibración',
        onOpen: () => pushSettingsDetail(
          context,
          (VoidCallback back) => SoundScreen(onBack: back),
        ),
      ),
      SettingsRow(
        label: 'Datos y privacidad',
        onOpen: () => pushSettingsDetail(
          context,
          (VoidCallback back) => DataPrivacyScreen(onBack: back),
        ),
      ),
      SettingsRow(label: 'Cómo se leen los retos', onOpen: onOpenLegend),
    ];
  }
}
