import 'package:akimath_app/features/states/policy/mastery_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('unlockedTopicsHeading', () {
    test('two reads the way the design writes it', () {
      expect(unlockedTopicsHeading(2), 'SE ABRIERON DOS TEMAS');
    });

    test('one is singular, verb and noun together', () {
      expect(unlockedTopicsHeading(1), 'SE ABRIÓ UN TEMA');
    });

    test('small counts are spelled, because a heading is prose', () {
      expect(unlockedTopicsHeading(3), 'SE ABRIERON TRES TEMAS');
      expect(unlockedTopicsHeading(5), 'SE ABRIERON CINCO TEMAS');
    });

    // Past the spelled range a numeral is honest and a wrong word is not.
    test('a count past the list falls back to the numeral', () {
      expect(unlockedTopicsHeading(11), 'SE ABRIERON 11 TEMAS');
    });
  });

  group('percentLabel', () {
    // The design closes the gap. `EsMxNumber.percent` would open it with a
    // narrow no-break space; this pins which of the two the screens draw, so
    // settling the question turns this test red on purpose.
    test('closes up the sign, the way both documents draw it', () {
      expect(percentLabel(38), '38%');
      expect(percentLabel(100), '100%');
    });
  });

  group('readyChallenges', () {
    test('plural', () => expect(readyChallenges(5), '5 retos listos'));
    test('singular', () => expect(readyChallenges(1), '1 reto listo'));
  });
}
