import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/auth/policy/age_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a band below the threshold never reaches the account form', () {
    test('every band in the declared set routes somewhere, and only one way', () {
      // Enumerated over `AgeBand.values` rather than over a list written here:
      // a band added to the contract lands in this loop automatically, which is
      // the difference between a gate and a snapshot of one.
      for (final AgeBand band in AgeBand.values) {
        final AgeGateRoute route = AgeGate.next(band);
        expect(
          route,
          band == AgeBand.under13 ? AgeGateRoute.tutorConsent : AgeGateRoute.createAccount,
          reason: band.wireName,
        );
      }
    });

    test('the threshold is one constant, and its recorded default is 13', () {
      // Gate A may move it. Keeping it named is what makes that a one-line
      // change rather than a re-reading of every branch.
      expect(AgeGate.consentAge, 13);
    });

    test('no band both consents and creates', () {
      // The routes are exhaustive and disjoint by construction; this is the
      // assertion that says so out loud, so a third route added later has to
      // be placed deliberately.
      final Set<AgeGateRoute> reached =
          AgeBand.values.map(AgeGate.next).toSet();
      expect(reached, <AgeGateRoute>{AgeGateRoute.tutorConsent, AgeGateRoute.createAccount});
    });
  });

  group('the birth date never leaves the device', () {
    test('a date becomes a band and nothing else', () {
      // The entry is a neutral date, not a leading "are you over 13?", and the
      // *only* thing that survives it is the band.
      expect(
        AgeGate.bandFor(bornOn: DateTime.utc(2011, 6, 1), today: DateTime.utc(2026, 8, 19)),
        AgeBand.thirteenToSeventeen,
        reason: '15 years old',
      );
      expect(
        AgeGate.bandFor(bornOn: DateTime.utc(2015, 6, 1), today: DateTime.utc(2026, 8, 19)),
        AgeBand.under13,
        reason: '11 years old',
      );
    });

    test('the boundaries fall on the birthday, not on the year', () {
      // Someone turning 13 tomorrow is still 12 today. Computing the band from
      // year subtraction alone gets this wrong for up to 364 days a year.
      final DateTime today = DateTime.utc(2026, 8, 19);
      expect(
        AgeGate.bandFor(bornOn: DateTime.utc(2013, 8, 20), today: today),
        AgeBand.under13,
        reason: 'turns 13 tomorrow',
      );
      expect(
        AgeGate.bandFor(bornOn: DateTime.utc(2013, 8, 19), today: today),
        AgeBand.thirteenToSeventeen,
        reason: 'turns 13 today',
      );
      expect(
        AgeGate.bandFor(bornOn: DateTime.utc(2008, 8, 20), today: today),
        AgeBand.thirteenToSeventeen,
        reason: 'turns 18 tomorrow',
      );
      expect(
        AgeGate.bandFor(bornOn: DateTime.utc(2008, 8, 19), today: today),
        AgeBand.adult,
        reason: 'turns 18 today',
      );
    });

    test('a 29 February birthday is not an error on a common year', () {
      // The one date that does not exist in three years out of four. Whatever
      // it resolves to, it must resolve.
      expect(
        AgeGate.bandFor(bornOn: DateTime.utc(2008, 2, 29), today: DateTime.utc(2026, 2, 28)),
        AgeBand.thirteenToSeventeen,
        reason: 'the day before the birthday it would have had',
      );
      expect(
        AgeGate.bandFor(bornOn: DateTime.utc(2008, 2, 29), today: DateTime.utc(2026, 3, 1)),
        AgeBand.adult,
      );
    });

    test('a date in the future is refused rather than made into a band', () {
      // A typo in a year field is the ordinary way this happens, and a negative
      // age quietly becoming `under_13` would route an adult into consent.
      expect(
        () => AgeGate.bandFor(
          bornOn: DateTime.utc(2027, 1, 1),
          today: DateTime.utc(2026, 8, 19),
        ),
        throwsArgumentError,
      );
    });

    test('the band is the whole of what is kept', () {
      // `AgeBand` carries a wire name and nothing else — no day, no month, no
      // year — so there is no field for a date to hide in.
      final AgeBand band = AgeGate.bandFor(
        bornOn: DateTime.utc(1990, 3, 14),
        today: DateTime.utc(2026, 8, 19),
      );
      expect(band.wireName, 'adult');
      expect(<String>['1990', '03', '14', '3', '14'].any(band.wireName.contains), isFalse);
    });
  });
}
