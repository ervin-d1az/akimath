import 'package:meta/meta.dart';

import '../../../design/math/spec/es_mx_number.dart';

/// What `Sin conexión` can say about the pack already on the device.
///
/// **PURE** — two counts in, words out. No widget, no socket, no clock.
///
/// It exists because the screen's headline *is* a figure: *"TRAES 40 RETOS EN
/// LA BOLSA"*. Counting and spelling that figure is a decision — the plural,
/// the grouping, and whether there is anything worth saying at all — and a
/// screen that made it inline would be the one place in the app that spells a
/// number its own way.

/// One pile in the tally under the headline.
@immutable
class BagPile {
  const BagPile({required this.figure, required this.label});

  /// The count, already spelled es-MX.
  final String figure;

  /// What it counts, pluralised.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is BagPile && other.figure == figure && other.label == label;

  @override
  int get hashCode => Object.hash(figure, label);

  @override
  String toString() => 'BagPile($figure $label)';
}

/// The headline, one entry per drawn line.
///
/// The design breaks it after the count, and where a phrase turns is a
/// typographic decision rather than something the layout engine should choose
/// — which is why `CenteredStateView` takes a list.
List<String> offlineBagHeadline(int challenges) => <String>[
  'TRAES ${EsMxNumber.integer(challenges)} ${_challenge(challenges)}',
  'EN LA BOLSA',
];

/// The piles worth drawing, in the design's order.
///
/// **A pile with nothing in it is left out rather than printed as a zero.**
/// A pack with no boards is an ordinary pack, and `0 PUZZLES` is a figure a
/// player can do nothing with — the same reading that keeps `HISTORIAL` away
/// when there is nothing true to say.
List<BagPile> bagTally({required int challenges, required int puzzles}) =>
    <BagPile>[
      if (challenges > 0)
        BagPile(
          figure: EsMxNumber.integer(challenges),
          label: _challenge(challenges).toUpperCase(),
        ),
      if (puzzles > 0)
        BagPile(
          figure: EsMxNumber.integer(puzzles),
          label: _puzzle(puzzles).toUpperCase(),
        ),
    ];

/// Whether the state has a claim to make.
///
/// Nothing to solve offline means the screen's headline would read *"TRAES 0
/// RETOS EN LA BOLSA"*, which helps nobody — the caller stays on the banner
/// instead.
bool bagWorthShowing(int challenges) => challenges > 0;

String _challenge(int count) => count == 1 ? 'RETO' : 'RETOS';

String _puzzle(int count) => count == 1 ? 'PUZZLE' : 'PUZZLES';
