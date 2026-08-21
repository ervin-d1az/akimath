import 'package:akimath_app/api/auth_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// The auth vocabulary, split out of the client so a pure policy may read it.
///
/// **The split is `me_result.dart`'s, verbatim.** That file records the reason:
/// `api_client.dart` imports `dart:io` and `dart:convert` to hold a socket, so
/// a policy switching on its results would reach a socket three hops away and
/// `pure_boundary_test.dart` would say so. `auth_client.dart` is the same shape
/// and now has the same split — which is what lets `LinkedSession` carry an
/// [AuthSession] and `sessionRestore` switch on an [AuthResult].
void main() {
  group('a session is a value', () {
    test('two sessions holding the same cookie are the same session', () {
      // **It has to be a value, because `LinkedSession` compares by value.**
      // Without this the shell's `==` would compare two cookies by identity:
      // equal for the canonicalised `const` a test writes, unequal for the
      // one a real sign-in builds — green in the suite, wrong on a device.
      expect(
        AuthSession(String.fromCharCodes('s=abc'.codeUnits)),
        const AuthSession('s=abc'),
      );
      expect(
        AuthSession(String.fromCharCodes('s=abc'.codeUnits)).hashCode,
        const AuthSession('s=abc').hashCode,
      );
    });

    test('and two holding different cookies are not', () {
      expect(const AuthSession('s=abc'), isNot(const AuthSession('s=xyz')));
    });

    test('the cookie is not in toString', () {
      // `toString` reaches logs, crash reports and the debugger's watch pane.
      // A credential that appears in any of those has left the device.
      expect(const AuthSession('s=abc').toString(), isNot(contains('abc')));
      expect(const AuthSession('s=abc').toString(), 'AuthSession(<redacted>)');
    });
  });
}
