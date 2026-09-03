import 'package:akimath_app/features/account/policy/token_renewal.dart';
import 'package:flutter_test/flutter_test.dart';

/// The instant the token in hand was minted. Every case below is read off it.
final DateTime minted = DateTime.utc(2026, 9, 2, 3, 29, 5);

TokenRenewal after(Duration age, {Duration? reuseFor}) => tokenRenewal(
      mintedAt: minted,
      now: minted.add(age),
      reuseFor: reuseFor ?? tokenReuseWindow,
    );

void main() {
  group('is the token in hand worth reusing', () {
    test('a token just minted is', () {
      expect(after(Duration.zero), TokenRenewal.reuse);
    });

    test('and one still inside the window is', () {
      expect(
        after(tokenReuseWindow - const Duration(seconds: 1)),
        TokenRenewal.reuse,
      );
    });

    test('a token as old as the window is not', () {
      // The boundary belongs to the safe side: at exactly the window the token
      // has had its whole allowance, and one more request on it is the request
      // that comes back 401.
      expect(after(tokenReuseWindow), TokenRenewal.mint);
    });

    test('nor is the twenty-minute-old one the playthrough measured', () {
      // `docs/qa/2026-09-02-first-production-playthrough.md` §2: minted at
      // 03:29:05, refused at 03:49:30. This is the case the change exists for.
      expect(after(const Duration(minutes: 20, seconds: 25)), TokenRenewal.mint);
    });
  });

  group('a clock that is not moving forward', () {
    test('a token minted in the future is not reused', () {
      // A device whose clock jumped backwards — a timezone fix, a manual
      // change, an NTP correction — would otherwise hold one token for as long
      // as the jump lasted, which is the defect back with a rarer trigger.
      // Minting is the cheap direction to be wrong in: one extra request.
      expect(after(const Duration(seconds: -1)), TokenRenewal.mint);
    });

    test('and neither is one minted long in the future', () {
      expect(after(const Duration(days: -1)), TokenRenewal.mint);
    });
  });

  group('the window itself', () {
    test('is well under the only lifetime anyone has measured', () {
      // The measurement is a ceiling and not the provider's default: the token
      // was good at 0 and refused at 20 minutes, so anything at or above 20 is
      // known to be too long. What is left over is the margin this buys.
      expect(tokenReuseWindow, lessThan(const Duration(minutes: 20)));
      expect(tokenReuseWindow, greaterThan(Duration.zero));
    });

    test('and is a parameter, so the caller is what is under test', () {
      expect(
        after(const Duration(minutes: 3), reuseFor: const Duration(minutes: 5)),
        TokenRenewal.reuse,
      );
      expect(
        after(const Duration(minutes: 6), reuseFor: const Duration(minutes: 5)),
        TokenRenewal.mint,
      );
    });
  });
}
