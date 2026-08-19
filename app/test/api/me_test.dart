import 'package:akimath_app/api/me.dart';
import 'package:flutter_test/flutter_test.dart';

const String _playerId = '018f4e3c-0000-7000-8000-0000000000b1';
const String _createdAt = '2026-08-19T09:15:00.000Z';

Map<String, Object?> _json({
  String playerId = _playerId,
  String ageBand = 'under_13',
  String createdAt = _createdAt,
}) => <String, Object?>{
  'playerId': playerId,
  'ageBand': ageBand,
  'createdAt': createdAt,
};

void main() {
  group('a profile off the wire', () {
    test('reads the three fields the frozen schema requires', () {
      final Me me = Me.fromJson(_json());

      expect(me.playerId, _playerId);
      expect(me.ageBand, AgeBand.under13);
      expect(me.createdAt, DateTime.utc(2026, 8, 19, 9, 15));
      expect(me.createdAt.isUtc, isTrue);
    });

    test('each band the contract names has a Dart value', () {
      // The enum is the closed union `ErrorTag` was always meant to be: a
      // `switch` over it is exhaustive, so a band added server-side is a
      // compile error here rather than a silent `default`.
      expect(Me.fromJson(_json(ageBand: 'under_13')).ageBand, AgeBand.under13);
      expect(Me.fromJson(_json(ageBand: '13_17')).ageBand, AgeBand.thirteenToSeventeen);
      expect(Me.fromJson(_json(ageBand: 'adult')).ageBand, AgeBand.adult);
    });

    test('a band nobody decided is refused, not defaulted', () {
      // Defaulting to `adult` would route a child out of their own protections;
      // defaulting to `under_13` would be a lie about who is playing. Neither
      // is a decision a parser gets to make.
      expect(() => Me.fromJson(_json(ageBand: '18_plus')), throwsFormatException);
    });

    test('a missing field is refused', () {
      for (final String absent in <String>['playerId', 'ageBand', 'createdAt']) {
        final Map<String, Object?> body = _json()..remove(absent);
        expect(() => Me.fromJson(body), throwsFormatException, reason: absent);
      }
    });

    test('a field of the wrong type is refused rather than coerced', () {
      expect(
        () => Me.fromJson(<String, Object?>{..._json(), 'playerId': 42}),
        throwsFormatException,
      );
    });
  });

  group('createdAt is held to the contract, not to DateTime.parse', () {
    // `DateTime.parse` accepts far more than the frozen pattern allows — no
    // milliseconds, a `+00:00` offset, a local time with no zone at all. Every
    // one of those round-trips to different bytes than it arrived as, which is
    // how a client and a server stop agreeing about an instant.

    test('accepts what the pattern accepts', () {
      expect(Me.fromJson(_json(createdAt: '2026-01-02T03:04:05.678Z')).createdAt,
          DateTime.utc(2026, 1, 2, 3, 4, 5, 678));
      // Seconds and the fractional part are both optional in the pattern.
      expect(Me.fromJson(_json(createdAt: '2026-01-02T03:04Z')).createdAt,
          DateTime.utc(2026, 1, 2, 3, 4));
    });

    test('refuses what the pattern refuses, however parseable it is', () {
      for (final String off in <String>[
        '2026-01-02T03:04:05.678+00:00', // an offset, not Z
        '2026-01-02T03:04:05.678', // no zone at all
        '2026-01-02 03:04:05.678Z', // a space instead of T
        '2026-02-30T00:00:00.000Z', // a day February never has
        '2025-02-29T00:00:00.000Z', // not a leap year
      ]) {
        expect(() => Me.fromJson(_json(createdAt: off)), throwsFormatException,
            reason: off);
      }
    });

    test('a leap day in a leap year is fine', () {
      // The control. A pattern that refused every 29 February would satisfy the
      // test above and would break one day in every 1461.
      expect(Me.fromJson(_json(createdAt: '2028-02-29T00:00:00.000Z')).createdAt,
          DateTime.utc(2028, 2, 29));
    });
  });

  group('a profile survives the round trip', () {
    test('back to the bytes it arrived as', () {
      // The client never sends a `Me`, so `toJson` exists for this test and for
      // the day something caches one. Its value is that it proves nothing was
      // lost on the way in.
      final Map<String, Object?> body = _json();
      expect(Me.fromJson(body).toJson(), body);
    });

    test('including a time with no seconds, which normalises', () {
      // The one case where the bytes legitimately change: the pattern allows
      // `03:04Z`, and there is one canonical way to write that instant back.
      // Named here so nobody reads the round trip above as universal.
      expect(Me.fromJson(_json(createdAt: '2026-01-02T03:04Z')).toJson()['createdAt'],
          '2026-01-02T03:04:00.000Z');
    });
  });
}
