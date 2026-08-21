import 'package:flutter/material.dart';

import '../../shell/ui/app_shell.dart';

/// Pushes one of `4.2`'s own destinations onto the tab's navigator.
///
/// **Not `pushSession`.** That route exists to make a *round* or a *board* take
/// the whole screen with no way out but finishing. The group badge over
/// `4.1`–`4.7` says the opposite — *"Aquí sí va la barra inferior"* — so a
/// settings screen pushes under the bar and its back control is a pop.
///
/// It is the same shape `ProfileRoute` uses for `Cuenta`, written here because
/// the four screens it opens need nothing a caller holds: no session, no token,
/// no address. A row that can build its own destination does, and only the two
/// that cannot — `Cuenta`, which needs the signed-in address — stay callbacks
/// on `SettingsListScreen`.
void pushSettingsDetail(
  BuildContext context,
  Widget Function(VoidCallback back) build,
) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (BuildContext pushed) => AppShell(
      child: build(() => Navigator.of(pushed).pop()),
    ),
  ));
}
