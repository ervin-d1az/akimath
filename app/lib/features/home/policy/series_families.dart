/// The families a series will draw, in the order it will draw them.
///
/// **PURE** — items in, names out. It reads the plan the player is about to be
/// served rather than describing the pack, and the difference matters: the pack
/// holds six families and any one series holds five. Telling a player the pack
/// is varied when today is not would be a different, and quietly wrong,
/// statement.
///
/// Each family appears once even when the series serves it twice; the row says
/// what kinds of question are coming, not how many of each.
library;

import '../../../content/model/item.dart';

/// What a family is called on the home, in es-MX.
///
/// Short enough to sit in a chip beside five others at large text — `Operación
/// oculta` is the honest name for the function machine and does not fit, so the
/// row says `Máquina`, which is what the screen itself is shaped like.
String familyLabel(Stimulus stimulus) => switch (stimulus) {
      ArithmeticStimulus() => 'Cuentas',
      NumberSeriesStimulus() => 'Series',
      MatrixStimulus() => 'Cuadros',
      AnalogyStimulus() => 'Parejas',
      HiddenOperationStimulus() => 'Máquina',
      FigurateStimulus() => 'Figuras',
    };

/// The distinct families in [plan], in first-appearance order.
List<String> seriesFamilies(List<Item> plan) {
  final List<String> names = <String>[];
  for (final Item item in plan) {
    final String label = familyLabel(item.stimulus);
    if (!names.contains(label)) {
      names.add(label);
    }
  }
  return names;
}
