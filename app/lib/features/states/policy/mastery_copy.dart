/// The prose `4.14` and `4.15` compose from counts.
///
/// **PURE** — a count in, a line out. No widget, no clock.
///
/// It exists because both screens announce a quantity in a sentence rather
/// than in a figure, and a sentence that agrees with its number is a decision:
/// *"SE ABRIERON DOS TEMAS"* and *"SE ABRIÓ UN TEMA"* are not one string with
/// a plural `s` bolted on.
library;

/// The numbers a heading spells rather than prints.
///
/// **Prose spells small numbers, and this heading is prose.** The design writes
/// *DOS*, not *2*. Past this list a numeral is honest and an invented word is
/// not, so the fallback prints the figure — the alternative is a table of every
/// Spanish number for a screen that will never show eleven.
const List<String> _spelled = <String>[
  'CERO',
  'UN',
  'DOS',
  'TRES',
  'CUATRO',
  'CINCO',
];

/// What opened, announced.
String unlockedTopicsHeading(int count) {
  if (count == 1) {
    return 'SE ABRIÓ UN TEMA';
  }
  final String amount = count < _spelled.length ? _spelled[count] : '$count';
  return 'SE ABRIERON $amount TEMAS';
}

/// How much is waiting under a topic the player has not started.
String readyChallenges(int count) =>
    count == 1 ? '1 reto listo' : '$count retos listos';
