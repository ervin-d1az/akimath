import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/model/pack.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/features/round/policy/series_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// What kind of question an item asks, as a name a failure can print.
String _family(Item item) => switch (item.stimulus) {
      ArithmeticStimulus() => 'arithmetic',
      NumberSeriesStimulus() => 'numberSeries',
      MatrixStimulus() => 'matrix',
      AnalogyStimulus() => 'analogy',
      HiddenOperationStimulus() => 'hiddenOperation',
      FigurateStimulus() => 'figurate',
    };

/// **The shipped pack's order is a product decision, and this is the gate.**
///
/// `seriesPlan` takes five items in pack order and is deliberately dull —
/// choosing *which* items a player should get is the adaptive question and it
/// belongs to `f4-calibration`. That means variety is not the policy's job; it
/// is the pack's, and a pack grouped by family would be a player answering
/// twenty sums before meeting anything else.
///
/// That is not hypothetical. It is what the pack did when the families were
/// added one after another, each appending its ten to the end, and the report
/// was *"I can only play the most basic ones"*.
void main() {
  late Pack pack;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    pack = await const PackReader().load();
  });

  group('the pack that ships offers more than one kind of question', () {
    test('it carries every family the app can draw', () {
      final Set<String> families = pack.items.map(_family).toSet();

      expect(families, hasLength(6), reason: 'families found: $families');
      // ignore: avoid_print
      print('  pack variety · ${pack.items.length} items → '
          '${families.length} families');
    });

    test('no family is a token presence', () {
      // Ten of each non-arithmetic family, twenty sums. A family with two items
      // would satisfy the count above and still never be seen twice.
      final Map<String, int> perFamily = <String, int>{};
      for (final Item item in pack.items) {
        perFamily[_family(item)] = (perFamily[_family(item)] ?? 0) + 1;
      }

      for (final MapEntry<String, int> entry in perFamily.entries) {
        expect(entry.value, greaterThanOrEqualTo(seriesLength * 2),
            reason: '${entry.key} has only ${entry.value} items');
      }
    });
  });

  group('a player meets the variety immediately, not eventually', () {
    test('the first series is a mix, not five of a kind', () {
      final Set<String> first =
          seriesPlan(pack.items).map(_family).toSet();

      expect(first.length, greaterThanOrEqualTo(3),
          reason: 'the opening series was all $first');
    });

    test('the first two series between them show every family', () {
      // Ten items — two sittings. Beyond that a player has formed a view of
      // what this app is, and "sums" would be the wrong one.
      final Set<String> seen = <String>{
        ...seriesPlan(pack.items).map(_family),
        ...seriesPlan(pack.items, from: seriesLength).map(_family),
      };

      expect(seen, hasLength(6), reason: 'after ten items a player had seen $seen');
    });

    test('no series repeats a family more than twice', () {
      // Arithmetic is twice as common as the rest, so twice in five is its fair
      // share and three would mean the interleave has clumped.
      for (int from = 0; from < pack.items.length; from += seriesLength) {
        final Map<String, int> perFamily = <String, int>{};
        for (final Item item in seriesPlan(pack.items, from: from)) {
          perFamily[_family(item)] = (perFamily[_family(item)] ?? 0) + 1;
        }

        for (final MapEntry<String, int> entry in perFamily.entries) {
          expect(entry.value, lessThanOrEqualTo(2),
              reason: 'the series from $from had ${entry.value} '
                  '${entry.key} items');
        }
      }
    });
  });
}
