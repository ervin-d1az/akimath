import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/round/policy/series_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Item item(String id) => Item(
      id: id,
      prompt: <PromptToken>[
        PromptToken.text('1'),
        PromptToken.operator('+'),
        PromptToken.text('1'),
        PromptToken.operator('='),
      ],
      expected: '2',
      ladderStep: 1,
    );

List<Item> pack(int count) =>
    List<Item>.generate(count, (int i) => item('i$i'));

void main() {
  group('a series is five items', () {
    test('a pack of twenty yields five, all distinct', () {
      final List<Item> plan = seriesPlan(pack(20));

      expect(plan, hasLength(seriesLength));
      expect(seriesLength, 5, reason: 'ARCHITECTURE.md §9 fixes the number');
      expect(plan.map((Item i) => i.id).toSet(), hasLength(5));
    });

    test('every item comes from the pack it was drawn from', () {
      final List<Item> source = pack(20);
      final Set<String> ids = source.map((Item i) => i.id).toSet();

      for (final Item drawn in seriesPlan(source)) {
        expect(ids, contains(drawn.id));
      }
    });

    test('a pack shorter than a series is not padded', () {
      // Repeating an item would show a player something they answered ninety
      // seconds ago and call it a challenge.
      final List<Item> plan = seriesPlan(pack(3));

      expect(plan, hasLength(3));
      expect(plan.map((Item i) => i.id).toSet(), hasLength(3));
    });

    test('an empty pack yields an empty plan rather than throwing', () {
      // `RoundScreen` asserts a non-empty item list, so the caller has to be
      // able to see this coming. `Pack.fromJson` refuses an empty pack, which
      // makes this defensive rather than reachable — and one `min` beats a
      // crash nobody can reproduce.
      expect(seriesPlan(<Item>[]), isEmpty);
    });
  });

  group('the same pack gives the same series', () {
    test('drawn twice, identical', () {
      // What a player is about to be asked must not depend on when they asked.
      // Deterministic on purpose: a shuffle would look adaptive, would not be,
      // and would hand `f4-calibration` a behaviour to preserve that nobody
      // chose.
      final List<Item> source = pack(20);

      expect(
        seriesPlan(source).map((Item i) => i.id).toList(),
        seriesPlan(source).map((Item i) => i.id).toList(),
      );
    });

    test('it reads the pack in order, which is the whole rule today', () {
      final List<Item> source = pack(20);

      expect(
        seriesPlan(source).map((Item i) => i.id).toList(),
        <String>['i0', 'i1', 'i2', 'i3', 'i4'],
      );
    });

    test('a different pack gives a different series', () {
      // The control: every assertion above is satisfied by a function that
      // ignores its argument and returns a fixed list.
      final List<Item> other = <Item>[item('z0'), item('z1')];

      expect(seriesPlan(other).map((Item i) => i.id).toList(), <String>['z0', 'z1']);
    });
  });
}
