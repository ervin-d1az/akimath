import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:flutter_test/flutter_test.dart';

/// U+202F NARROW NO-BREAK SPACE — the thousands separator (D8).
const String narrowNoBreakSpace = ' ';

/// U+2212 MINUS SIGN. Never U+002D HYPHEN-MINUS.
const String minusSign = '−';

void main() {
  group('a rating and a time are formatted', () {
    test('integer groups thousands with U+202F, not a plain space', () {
      expect(EsMxNumber.integer(1180), '1${narrowNoBreakSpace}180');

      // Asserted as a code point rather than by eye: a plain space renders
      // almost identically and wraps inside a 48px pill at textScaler 1.3,
      // which is the whole reason D8 chose the narrow no-break form.
      expect(EsMxNumber.integer(1180).codeUnits, contains(0x202F));
      expect(EsMxNumber.integer(1180), isNot(contains(' ')));
    });

    test('seconds carry a comma decimal and a unit', () {
      expect(EsMxNumber.seconds(4.2, places: 1), '4,2${narrowNoBreakSpace}s');
    });

    test('a value below the grouping threshold is left alone', () {
      expect(EsMxNumber.integer(999), '999');
    });

    test('grouping continues past a million', () {
      expect(
        EsMxNumber.integer(1234567),
        '1${narrowNoBreakSpace}234${narrowNoBreakSpace}567',
      );
    });
  });

  group('a counter chip and a delta go through the same module', () {
    test('ratio spaces the slash on both sides', () {
      expect(
        EsMxNumber.ratio(3, 9),
        '3$narrowNoBreakSpace/${narrowNoBreakSpace}9',
      );
    });

    test('deltaParts returns a sign run and a digit run', () {
      final DeltaParts negative = EsMxNumber.deltaParts(-6);
      expect(negative.sign, minusSign);
      expect(negative.digits, '6');

      final DeltaParts positive = EsMxNumber.deltaParts(6);
      expect(positive.sign, '+');
      expect(positive.digits, '6');
    });

    test('a zero delta carries no sign at all', () {
      // A "+0" or "−0" is a lie about direction. The caller renders the sign
      // run, so an empty run is how it draws nothing.
      expect(EsMxNumber.deltaParts(0).sign, isEmpty);
      expect(EsMxNumber.deltaParts(0).digits, '0');
    });

    test('the digit run never carries the sign', () {
      // This is the property that stops a call site composing "−" + digits by
      // hand and getting a hyphen.
      expect(EsMxNumber.deltaParts(-1180).digits, isNot(contains(minusSign)));
      expect(EsMxNumber.deltaParts(-1180).digits, isNot(contains('-')));
      expect(
        EsMxNumber.deltaParts(-1180).digits,
        '1${narrowNoBreakSpace}180',
      );
    });
  });

  group('the minus sign is never a hyphen', () {
    // Enumerating the surface is the point. A test that checks deltaParts
    // alone passes while any other entry point emits U+002D.
    final Map<String, String> negatives = <String, String>{
      'integer': EsMxNumber.integer(-1180),
      'decimal': EsMxNumber.decimal(-4.2, places: 1),
      'seconds': EsMxNumber.seconds(-4.2, places: 1),
      'percent': EsMxNumber.percent(-12),
      'delta': EsMxNumber.deltaParts(-6).sign,
    };

    for (final MapEntry<String, String> entry in negatives.entries) {
      test('${entry.key} uses U+2212 and never U+002D', () {
        expect(
          entry.value,
          contains(minusSign),
          reason: '${entry.key} must lead with U+2212',
        );
        expect(
          entry.value,
          isNot(contains('-')),
          reason: '${entry.key} leaked a hyphen-minus',
        );
      });
    }

    test('every negatable entry point is covered by this test', () {
      // Fails when someone adds a formatter that can emit a negative without
      // adding it above. The module publishes the list; the test consumes it.
      expect(
        negatives.keys.toSet(),
        EsMxNumber.negatableEntryPoints,
        reason: 'a formatter that can go negative is missing a minus assertion',
      );
    });
  });

  group('the rest of the surface', () {
    test('decimal uses a comma', () {
      expect(EsMxNumber.decimal(4.25, places: 2), '4,25');
    });

    test('percent spaces its sign the way es-MX sets it', () {
      expect(EsMxNumber.percent(45), '45$narrowNoBreakSpace%');
    });

    test('clockTime pads the minute', () {
      expect(EsMxNumber.clockTime(hour: 19, minute: 30), '19:30');
      expect(EsMxNumber.clockTime(hour: 9, minute: 5), '9:05');
    });

    test('elapsed reads as minutes and seconds', () {
      expect(EsMxNumber.elapsed(const Duration(seconds: 83)), '1:23');
      expect(EsMxNumber.elapsed(const Duration(seconds: 5)), '0:05');
    });

    test('durationCoarse rounds to a unit a child can read', () {
      expect(
        EsMxNumber.durationCoarse(const Duration(seconds: 45)),
        '45${narrowNoBreakSpace}s',
      );
      expect(
        EsMxNumber.durationCoarse(const Duration(minutes: 3)),
        '3${narrowNoBreakSpace}min',
      );
    });

    test('dimensions use a multiplication sign with spaces', () {
      expect(
        EsMxNumber.dimensions(6, 6),
        '6$narrowNoBreakSpace×${narrowNoBreakSpace}6',
      );
    });

    test('noValue is an em dash, not an empty string', () {
      // An empty cell and an unmeasured one look identical and mean different
      // things; every screen printing a measured number needs the second.
      expect(EsMxNumber.noValue, '—');
    });
  });

  group('no output can wrap mid-value', () {
    // D8's reasoning is not specific to thousands: every space this module
    // emits sits inside a pill, chip or tile that is sized to its content, and
    // any one of them breaking across two lines is the same defect. So the rule
    // is stated once, over the whole surface, rather than per formatter.
    test('every formatter emits U+202F and never U+0020', () {
      final Iterable<String> outputs = <String>[
        EsMxNumber.integer(1234567),
        EsMxNumber.decimal(4.25, places: 2),
        EsMxNumber.seconds(4.2, places: 1),
        EsMxNumber.percent(45),
        EsMxNumber.clockTime(hour: 19, minute: 30),
        EsMxNumber.elapsed(const Duration(seconds: 83)),
        EsMxNumber.durationCoarse(const Duration(minutes: 3)),
        EsMxNumber.dimensions(6, 6),
        EsMxNumber.ratio(3, 9),
        EsMxNumber.noValue,
      ];

      for (final String output in outputs) {
        expect(
          output,
          isNot(contains(' ')),
          reason: '"$output" carries a breaking space',
        );
      }
    });
  });
}
