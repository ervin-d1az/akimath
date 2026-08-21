import 'package:akimath_app/features/states/policy/server_error_note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('serverErrorNote', () {
    test('names the status and the clock time the design draws', () {
      expect(
        serverErrorNote(status: 503, at: DateTime(2026, 8, 20, 18, 42)),
        'error 503 · 18:42',
      );
    });

    // `accountStateFor` collapses every unusable answer into one enum member,
    // so a caller that has the state and not the response cannot name a code.
    // Saying *when* is still worth saying — it is what tells a player whether
    // they are looking at a stale screen.
    test('drops the code it does not have, and keeps the time', () {
      expect(
        serverErrorNote(status: null, at: DateTime(2026, 8, 20, 18, 42)),
        'error · 18:42',
      );
    });

    test('drops the time it does not have, and keeps the code', () {
      expect(serverErrorNote(status: 503, at: null), 'error 503');
    });

    // Nothing true to put in the chip means no chip — the same reading that
    // keeps `HISTORIAL` away when there is nothing to say. A bare `error` is
    // the headline repeated in a smaller font.
    test('is absent when it knows neither', () {
      expect(serverErrorNote(status: null, at: null), isNull);
    });

    // `EsMxNumber.clockTime` pads the minute and deliberately does not pad the
    // hour. Spelled by that function rather than here, so the app has one
    // wall-clock format and not a second one that only this chip uses.
    test('spells the time the way the rest of the app spells a clock', () {
      expect(
        serverErrorNote(status: 500, at: DateTime(2026, 8, 20, 9, 5)),
        'error 500 · 9:05',
      );
    });
  });
}
