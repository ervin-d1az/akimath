import 'package:akimath_app/features/auth/policy/credential_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _issued = DateTime.utc(2026, 8, 19, 9, 15);

void main() {
  group('the resend cooldown is a function of two timestamps', () {
    test('eighteen seconds in, forty-two are left and it reads 0:42', () {
      // The plan's own example, kept verbatim so the rule and its record cannot
      // drift apart.
      final Duration left = CredentialRules.remainingCooldown(
        _issued,
        _issued.add(const Duration(seconds: 18)),
      );

      expect(left, const Duration(seconds: 42));
      expect(CredentialRules.formatCooldown(left), '0:42');
      expect(CredentialRules.canResend(_issued, _issued.add(const Duration(seconds: 18))),
          isFalse);
    });

    test('it reaches zero exactly on the boundary, and resend opens there', () {
      final DateTime atSixty = _issued.add(CredentialRules.resendCooldown);
      expect(CredentialRules.remainingCooldown(_issued, atSixty), Duration.zero);
      expect(CredentialRules.canResend(_issued, atSixty), isTrue);
    });

    test('it never goes negative, however late the caller looks', () {
      // `-0:03` on a button is the kind of thing that ships.
      final Duration left = CredentialRules.remainingCooldown(
        _issued,
        _issued.add(const Duration(hours: 3)),
      );
      expect(left, Duration.zero);
      expect(CredentialRules.formatCooldown(left), '0:00');
    });

    test('a clock that went backwards keeps the button disabled', () {
      // Not hypothetical on a phone: an NTP correction or a manual change moves
      // it either way, and "now is before issue" must not read as "ready".
      expect(
        CredentialRules.canResend(_issued, _issued.subtract(const Duration(minutes: 5))),
        isFalse,
      );
    });

    test('it pads the seconds, so the width never jumps', () {
      expect(CredentialRules.formatCooldown(const Duration(seconds: 9)), '0:09');
      expect(CredentialRules.formatCooldown(const Duration(seconds: 60)), '1:00');
      expect(CredentialRules.formatCooldown(const Duration(seconds: 61)), '1:01');
    });

    test('it reads no clock of its own', () {
      // Two calls with the same arguments and a real interval between them.
      // A module that read `DateTime.now()` would disagree with itself here.
      final DateTime now = _issued.add(const Duration(seconds: 30));
      final Duration first = CredentialRules.remainingCooldown(_issued, now);
      final Duration second = CredentialRules.remainingCooldown(_issued, now);
      expect(first, second);
      expect(first, const Duration(seconds: 30));
    });
  });

  group('what the form will send', () {
    test('a password shorter than the provider accepts is caught here', () {
      // Better Auth refuses below 8. Catching it locally is the difference
      // between a message under the field and a round trip that says 400.
      expect(CredentialRules.longEnough('1234567'), isFalse);
      expect(CredentialRules.longEnough('12345678'), isTrue);
      expect(CredentialRules.minimumPasswordLength, 8);
    });

    test('the address check catches what a form can be sure about', () {
      for (final String bad in <String>[
        '', '   ', 'nobody', 'no@at@all.com', '@example.com', 'someone@',
        'someone@nodot', 'some one@example.com', 'someone@.com', 'someone@example.',
      ]) {
        expect(CredentialRules.looksLikeEmail(bad), isFalse, reason: '"$bad"');
      }
    });

    test('and refuses nothing a provider would have accepted', () {
      // The failure that matters is the opposite one: a player with a valid
      // address who cannot sign up and cannot find out why. Plus signs,
      // subdomains and long suffixes are all ordinary.
      for (final String good in <String>[
        'someone@example.com',
        'someone+akimath@example.com',
        'someone@mail.example.co.uk',
        'a@b.co',
        "o'brien@example.com",
        '  spaced@example.com  ',
      ]) {
        expect(CredentialRules.looksLikeEmail(good), isTrue, reason: '"$good"');
      }
    });

    test('a code is six digits and nothing else', () {
      expect(CredentialRules.looksLikeCode('123456'), isTrue);
      for (final String bad in <String>['12345', '1234567', '12345a', '', ' 123456']) {
        expect(CredentialRules.looksLikeCode(bad), isFalse, reason: '"$bad"');
      }
    });
  });
}
