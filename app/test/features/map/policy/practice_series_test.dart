import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/map/policy/practice_series.dart';
import 'package:flutter_test/flutter_test.dart';

Item _item(String id, Stimulus stimulus) => Item(
      id: id,
      stimulus: stimulus,
      answer: const PlainAnswer('1'),
      ladderStep: 1,
    );

Item _sum(String id) => _item(
      id,
      const ArithmeticStimulus(<PromptToken>[PromptToken.text('1')]),
    );

Item _series(String id) => _item(
      id,
      const NumberSeriesStimulus(terms: <int>[1, 2, 3], unknownIndex: 2),
    );

void main() {
  test('serves only the topic that was asked for', () {
    final List<Item> pack = <Item>[_sum('a'), _series('b'), _sum('c')];

    expect(
      practiceSeries(items: pack, label: 'Cuentas', itemsServed: 0)
          .map((Item item) => item.id),
      <String>['a', 'c'],
    );
  });

  test('a topic the pack does not carry serves nothing', () {
    expect(
      practiceSeries(items: <Item>[_sum('a')], label: 'Figuras', itemsServed: 0),
      isEmpty,
    );
  });

  test('starts with what the player has not met yet', () {
    final List<Item> pack = <Item>[_sum('a'), _sum('b'), _sum('c')];

    expect(
      practiceSeries(items: pack, label: 'Cuentas', itemsServed: 1)
          .map((Item item) => item.id),
      <String>['b', 'c', 'a'],
    );
  });

  test('never serves more than a series holds, and never repeats one', () {
    final List<Item> pack = <Item>[
      for (int index = 0; index < 9; index++) _sum('item$index'),
    ];

    final List<Item> served =
        practiceSeries(items: pack, label: 'Cuentas', itemsServed: 0);

    expect(served, hasLength(5));
    expect(served.map((Item item) => item.id).toSet(), hasLength(5));
  });

  test('a cursor past the pack still serves the topic from its start', () {
    // `seriesStart` wraps and the stored total keeps climbing, so this is the
    // ordinary case after one pass and not an edge one.
    final List<Item> pack = <Item>[_sum('a'), _sum('b')];

    expect(
      practiceSeries(items: pack, label: 'Cuentas', itemsServed: 7)
          .map((Item item) => item.id),
      <String>['a', 'b'],
    );
  });
}
