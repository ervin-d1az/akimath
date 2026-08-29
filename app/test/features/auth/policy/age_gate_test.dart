import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/auth/policy/age_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the gate refuses rather than routes', () {
    test('exactly one band reaches the account form, and it is adult', () {
      // Enumerated over `AgeBand.values` rather than over a list written here:
      // the frozen contract still names three bands and nothing under
      // `packages/` narrowed, so a band this gate has never seen would land in
      // this loop rather than slip past a hand-written list (ADR 0004).
      final Set<AgeBand> admitted = AgeBand.values
          .where((AgeBand band) =>
              AgeGate.next(band) == AgeGateOutcome.createAccount)
          .toSet();
      expect(admitted, <AgeBand>{AgeBand.adult});
    });

    test('every band below adult is refused, and refused identically', () {
      // `under_13` and `13_17` were two destinations because the band routed a
      // player into child protections or out of them. There is one population
      // now, so the two bands are the same answer — and that is asserted rather
      // than left to a reader of the switch.
      expect(AgeGate.next(AgeBand.under13), AgeGateOutcome.refused);
      expect(AgeGate.next(AgeBand.thirteenToSeventeen), AgeGateOutcome.refused);
    });

    test('no band both creates and is refused', () {
      // The outcomes are exhaustive and disjoint by construction; this says so
      // out loud, so a third outcome added later has to be placed deliberately.
      final Set<AgeGateOutcome> reached =
          AgeBand.values.map(AgeGate.next).toSet();
      expect(reached, <AgeGateOutcome>{
        AgeGateOutcome.createAccount,
        AgeGateOutcome.refused,
      });
    });

    test('the threshold is one constant, and it is 18', () {
      // ADR 0004: the number stops meaning "may consent unaided" and starts
      // meaning "is an adult". Keeping it named is what makes a change to it a
      // one-line change rather than a re-reading of every branch.
      expect(AgeGate.adultAge, 18);
    });

    test('the band split the gate no longer acts on is still 13', () {
      // The frozen `CHECK` and the frozen contract both still name `under_13`
      // and `13_17`, and this change deliberately narrows neither. So the
      // reduction still has to tell them apart even though the gate answers
      // both the same way.
      expect(AgeGate.teenBandAge, 13);
    });
  });

  group('the birth date never leaves the device', () {
    test('a date becomes a band and nothing else', () {
      // The entry is a neutral date, not a leading "are you over 18?", and the
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
      // Someone turning 18 tomorrow is still 17 today. Computing the band from
      // year subtraction alone gets this wrong for up to 364 days a year, and
      // for the 18 boundary that is now the difference between an account and a
      // refusal.
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

    test('the day before adulthood is refused and the day of it is not', () {
      // The pair the whole decision turns on, stated end to end rather than as
      // two facts a reader has to compose: a date in, an outcome out.
      final DateTime today = DateTime.utc(2026, 8, 19);
      AgeGateOutcome outcomeFor(DateTime bornOn) =>
          AgeGate.next(AgeGate.bandFor(bornOn: bornOn, today: today));

      expect(outcomeFor(DateTime.utc(2008, 8, 20)), AgeGateOutcome.refused);
      expect(
        outcomeFor(DateTime.utc(2008, 8, 19)),
        AgeGateOutcome.createAccount,
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
      // age quietly becoming `under_13` would be a refusal an adult never
      // earned.
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
