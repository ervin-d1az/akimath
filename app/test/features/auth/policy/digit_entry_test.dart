import 'package:akimath_app/features/auth/policy/digit_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('typing digits into a fixed-length buffer', () {
    test('a press appends until the buffer is full', () {
      String buffer = '';
      for (final String digit in <String>['1', '2', '3', '4', '5', '6']) {
        buffer = DigitEntry.push(buffer, digit, max: 6);
      }
      expect(buffer, '123456');
    });

    test('a full buffer ignores the press rather than rolling over', () {
      // A silent rotation means the digits on screen are no longer the ones
      // typed, which on a code screen is unfixable by the person looking at it.
      expect(DigitEntry.push('123456', '7', max: 6), '123456');
    });

    test('backspace removes one, and does nothing on an empty buffer', () {
      expect(DigitEntry.pop('123'), '12');
      expect(DigitEntry.pop(''), '');
    });
  });

  group('eight digits as a birth date', () {
    test('a complete, real date parses', () {
      expect(DigitEntry.dateFrom('19082011'), DateTime.utc(2011, 8, 19));
      expect(DigitEntry.dateFrom('29022008'), DateTime.utc(2008, 2, 29));
    });

    test('an incomplete one is null, not an error', () {
      // The ordinary state of a field being typed into.
      for (final String partial in <String>['', '1', '1908', '1908201']) {
        expect(DigitEntry.dateFrom(partial), isNull, reason: partial);
      }
    });

    test('a day that does not exist is null, not the day after it', () {
      // `DateTime.utc(2026, 2, 30)` rolls forward to 2 March rather than
      // failing, so a parser that trusts it turns a typo into a real date.
      for (final String impossible in <String>[
        '30022026', '32012026', '00012026', '19132026', '31042026',
      ]) {
        expect(DigitEntry.dateFrom(impossible), isNull, reason: impossible);
      }
    });

    test('29 February is real in a leap year and not otherwise', () {
      expect(DigitEntry.dateFrom('29022028'), DateTime.utc(2028, 2, 29));
      expect(DigitEntry.dateFrom('29022025'), isNull);
    });
  });

  group('what the field shows while it is being typed', () {
    test('placeholders where the digits are not yet', () {
      expect(DigitEntry.maskedDate(''), 'DD / MM / AAAA');
      expect(DigitEntry.maskedDate('19'), '19 / MM / AAAA');
      expect(DigitEntry.maskedDate('1908'), '19 / 08 / AAAA');
      expect(DigitEntry.maskedDate('19082011'), '19 / 08 / 2011');
    });

    test('a half-typed group shows the digits it has', () {
      expect(DigitEntry.maskedDate('1'), '1D / MM / AAAA');
      expect(DigitEntry.maskedDate('190'), '19 / 0M / AAAA');
      expect(DigitEntry.maskedDate('190820'), '19 / 08 / 20AA');
    });

    test('the width never changes, so the field does not jump', () {
      final Set<int> widths = <int>{};
      for (int typed = 0; typed <= 8; typed += 1) {
        widths.add(DigitEntry.maskedDate('12345678'.substring(0, typed)).length);
      }
      expect(widths, hasLength(1));
    });
  });
}
