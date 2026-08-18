import 'package:akimath_app/design/widgets/spec/mastery_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a mastery level carries no colour', () {
    test('no member of the type is a Color', () {
      for (final MasteryLevel level in MasteryLevel.values) {
        expect(level.toString(), isNot(contains('Color')));
      }
    });

    test('the four levels are the four the skill-map legend names', () {
      // Grounded rather than invented: `f5-skill-map` records that the legend
      // gains a fourth entry, "Disponible", and `4.14` is `Habilidad dominada`.
      expect(MasteryLevel.values, hasLength(4));
      expect(
        MasteryLevel.values.map((MasteryLevel l) => l.name).toList(),
        <String>['locked', 'available', 'inProgress', 'mastered'],
      );
    });

    test('the levels are ordered from least to most progress', () {
      // The order is meaningful: a meter fills as the level rises, so a
      // comparison between two levels is the legitimate form of the comparison
      // `no_hue_by_comparison_test` forbids on raw numbers.
      expect(MasteryLevel.locked.index, lessThan(MasteryLevel.mastered.index));
      expect(
        MasteryLevel.available.index,
        lessThan(MasteryLevel.inProgress.index),
      );
    });
  });
}
