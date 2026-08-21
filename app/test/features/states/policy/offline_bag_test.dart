import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/features/states/policy/offline_bag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('offlineBagHeadline', () {
    test('counts what the bag holds, on the design\'s two lines', () {
      expect(
        offlineBagHeadline(40),
        <String>['TRAES 40 RETOS', 'EN LA BOLSA'],
      );
    });

    test('one challenge is singular', () {
      expect(offlineBagHeadline(1), <String>['TRAES 1 RETO', 'EN LA BOLSA']);
    });

    // The shipped pack carries seventy, and es-MX groups a thousand with a
    // thin space rather than a comma. Delegated to `EsMxNumber` rather than
    // interpolated, or this headline would be the one place in the app that
    // spells a number its own way.
    test('a four-figure bag is grouped the way every other figure is', () {
      final String line = offlineBagHeadline(1200).first;

      expect(line, 'TRAES ${EsMxNumber.integer(1200)} RETOS');
      // The half that carries information: the mutation this kills is
      // `'TRAES $challenges RETOS'`, which passes the line above only if
      // grouping happens to be a no-op. es-MX groups with a narrow space, so
      // the raw digits must not appear.
      expect(line.contains('1200'), isFalse);
    });
  });

  group('bagTally', () {
    test('names both piles, plural', () {
      expect(bagTally(challenges: 40, puzzles: 2), <BagPile>[
        BagPile(figure: '40', label: 'RETOS'),
        BagPile(figure: '2', label: 'PUZZLES'),
      ]);
    });

    test('one of each is singular', () {
      expect(bagTally(challenges: 1, puzzles: 1), <BagPile>[
        BagPile(figure: '1', label: 'RETO'),
        BagPile(figure: '1', label: 'PUZZLE'),
      ]);
    });

    // A pack with no boards is a real pack — the tally reports what is there
    // and stays silent about what is not, rather than printing a zero the
    // player can do nothing with.
    test('a pile with nothing in it is not drawn', () {
      expect(bagTally(challenges: 40, puzzles: 0), <BagPile>[
        BagPile(figure: '40', label: 'RETOS'),
      ]);
    });
  });

  group('bagWorthShowing', () {
    test('a bag with challenges in it is worth a screen', () {
      expect(bagWorthShowing(1), isTrue);
    });

    // Nothing to solve offline means this screen has no claim to make, and
    // "TRAES 0 RETOS EN LA BOLSA" is a headline that helps nobody.
    test('an empty bag is not', () {
      expect(bagWorthShowing(0), isFalse);
    });
  });
}
