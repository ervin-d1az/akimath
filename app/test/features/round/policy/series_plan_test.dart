import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/round/policy/series_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Item item(String id) => Item(
      id: id,
      stimulus: ArithmeticStimulus(<PromptToken>[
        PromptToken.text('1'),
        PromptToken.operator('+'),
        PromptToken.text('1'),
        PromptToken.operator('='),
      ]),
      answer: PlainAnswer('2'),
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

  group('a second series is not the first series again', () {
    test('the offset advances through the pack', () {
      final List<Item> source = pack(20);

      expect(
        seriesPlan(source, from: 0).map((Item i) => i.id).toList(),
        <String>['i0', 'i1', 'i2', 'i3', 'i4'],
      );
      expect(
        seriesPlan(source, from: 5).map((Item i) => i.id).toList(),
        <String>['i5', 'i6', 'i7', 'i8', 'i9'],
      );
      expect(
        seriesPlan(source, from: 10).map((Item i) => i.id).toList(),
        <String>['i10', 'i11', 'i12', 'i13', 'i14'],
      );
    });

    test('it wraps rather than running out', () {
      // Four series into a pack of twenty and the fifth has to come from
      // somewhere. Wrapping beats an empty series or a crash.
      final List<Item> source = pack(20);

      expect(
        seriesPlan(source, from: 18).map((Item i) => i.id).toList(),
        <String>['i18', 'i19', 'i0', 'i1', 'i2'],
      );
      expect(
        seriesPlan(source, from: 20).map((Item i) => i.id).toList(),
        seriesPlan(source, from: 0).map((Item i) => i.id).toList(),
      );
      expect(
        seriesPlan(source, from: 45).map((Item i) => i.id).toList(),
        seriesPlan(source, from: 5).map((Item i) => i.id).toList(),
      );
    });

    test('no item repeats inside one series', () {
      // Wrapping must not hand the same item twice in one sitting, which it
      // would the moment a pack is shorter than a series.
      for (final int size in <int>[5, 6, 20]) {
        for (int from = 0; from < size; from++) {
          final List<Item> plan = seriesPlan(pack(size), from: from);
          expect(
            plan.map((Item i) => i.id).toSet(),
            hasLength(plan.length),
            reason: 'pack $size from $from',
          );
        }
      }
    });

    test('a pack shorter than a series still yields it whole, once', () {
      final List<Item> plan = seriesPlan(pack(3), from: 7);

      expect(plan, hasLength(3));
      expect(plan.map((Item i) => i.id).toSet(), hasLength(3));
    });

    test('an offset into an empty pack is still empty, not a crash', () {
      expect(seriesPlan(<Item>[], from: 9), isEmpty);
    });

    test('a negative offset is refused rather than reinterpreted', () {
      // `-1 % 20` is 19 in Dart, so a negative offset would silently start near
      // the end of the pack instead of failing.
      expect(() => seriesPlan(pack(20), from: -1), throwsRangeError);
    });
  });

  group('the positions the series is drawn from', () {
    test('are the ones the items come from, so nothing recomputes the wrap', () {
      // A synced attempt names `(packId, index)` — the pack format gives its
      // items no identifier, so position *is* identity. A caller deriving it
      // separately would be a second implementation of the one rule that says
      // which item a player just answered.
      final List<Item> nine = pack(9);

      for (final int from in <int>[0, 1, 5, 8, 9, 14]) {
        final List<int> indices = seriesIndices(nine.length, from: from);
        expect(
          seriesPlan(nine, from: from),
          indices.map((int i) => nine[i]).toList(),
          reason: 'from $from',
        );
      }
    });

    test('they wrap the way the plan wraps', () {
      expect(seriesIndices(9, from: 7), <int>[7, 8, 0, 1, 2]);
    });

    test('an empty pack has none', () {
      expect(seriesIndices(0), isEmpty);
      expect(seriesIndices(-1), isEmpty);
    });

    test('and a pack shorter than a series gives every position once', () {
      expect(seriesIndices(3), <int>[0, 1, 2]);
    });
  });
}
