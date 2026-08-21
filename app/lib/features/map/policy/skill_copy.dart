/// Every word the map and `2.7` put on screen.
///
/// **PURE** — a value in, a string out. It sits beside `skill_map.dart` rather
/// than inside the two screens for the reason `puzzle_menu.dart` gives: the
/// switch is exhaustive over `Stimulus`, so a seventh family cannot be added
/// without deciding what the map should say about it, because the switch stops
/// compiling until somebody does.
///
/// The strings are es-MX because they are the only thing here a player reads.
/// Everything around them stays English (LANG-1).
library;

import '../../../content/model/item.dart';
import '../../../design/widgets/spec/mastery_level.dart';

/// What a topic asks of a player, in one sentence.
///
/// It describes the **question family**, not a curriculum topic: the design
/// draws *Fracciones* and *Álgebra*, and this app has no notion of either. What
/// it has is six frozen kinds of stimulus, and saying what each one asks is
/// something the app can state truthfully.
String skillBlurb(Stimulus stimulus) => switch (stimulus) {
      ArithmeticStimulus() =>
        'Sumar, restar y comparar: cuentas con enteros y con fracciones.',
      NumberSeriesStimulus() =>
        'Encontrar la regla de una fila de números y decir cuál sigue.',
      MatrixStimulus() =>
        'Cuadros de números donde cada fila y cada columna esconden una regla.',
      AnalogyStimulus() =>
        'Dos parejas con la misma relación: si entiendes una, tienes la otra.',
      HiddenOperationStimulus() =>
        'Una máquina que transforma números. Averigua qué les hace por dentro.',
      FigurateStimulus() =>
        'Figuras de puntos que crecen con un patrón. ¿Cuántos trae la que sigue?',
    };

/// How a state is named on the legend and on `2.7`'s status chip.
///
/// **Four, where the design's legend draws three.** *Disponible* is the fourth
/// entry `MasteryLevel`'s own doc comment records this screen as bringing: the
/// design's white nodes are drawn but never named in its key.
String masteryName(MasteryLevel level) => switch (level) {
      MasteryLevel.locked => 'Bloqueado',
      MasteryLevel.available => 'Disponible',
      MasteryLevel.inProgress => 'En curso',
      MasteryLevel.mastered => 'Dominado',
    };

/// What `2.7` says about where the player stands, under the meter.
///
/// It reads the ladder rather than a rating, because the ladder is what exists:
/// [reachedStep] and [topStep] are both facts about the pack in hand.
String masteryNote({
  required MasteryLevel level,
  required int reachedStep,
  required int topStep,
}) =>
    switch (level) {
      MasteryLevel.locked => 'Todavía no está en tu paquete de retos.',
      MasteryLevel.available => 'Todavía no lo empiezas. Es buen momento.',
      MasteryLevel.inProgress =>
        'Vas en el nivel $reachedStep de $topStep que trae el paquete.',
      MasteryLevel.mastered =>
        'Llegaste al nivel más difícil que trae el paquete.',
    };

/// The line `2.7` draws over the topic that comes before this one.
///
/// The design's is *"Viene de División, que ya dominas"*. The relation behind
/// it here is the order the pack introduces its families in — the order a
/// player actually meets them — and whether that earlier topic is finished is
/// read, not assumed.
String arrivesFrom({
  required String? previousLabel,
  required MasteryLevel? previousLevel,
}) {
  if (previousLabel == null) {
    return 'Es por donde empieza el mapa.';
  }
  return previousLevel == MasteryLevel.mastered
      ? 'Viene de $previousLabel, que ya dominas.'
      : 'Viene de $previousLabel.';
}
