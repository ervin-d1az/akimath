import 'package:akimath_app/features/account/policy/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const LinkedSession session = LinkedSession(
    email: 'alguien@ejemplo.com',
    accessToken: 'a.bearer.token',
  );

  test('it carries the address, because a player has no name', () {
    expect(session.email, 'alguien@ejemplo.com');
  });

  test('and its description does not carry the token', () {
    // `toString` reaches logs, crash reports and the debugger's watch pane. A
    // credential that appears in any of those has left the device.
    expect(session.toString(), contains('alguien@ejemplo.com'));
    expect(session.toString(), isNot(contains('a.bearer.token')));
  });

  test('two sessions for the same account and token are the same session', () {
    expect(
      session,
      const LinkedSession(email: 'alguien@ejemplo.com', accessToken: 'a.bearer.token'),
    );
    expect(
      session.hashCode,
      const LinkedSession(email: 'alguien@ejemplo.com', accessToken: 'a.bearer.token').hashCode,
    );
    expect(
      session,
      isNot(const LinkedSession(email: 'alguien@ejemplo.com', accessToken: 'otro')),
    );
  });
}
