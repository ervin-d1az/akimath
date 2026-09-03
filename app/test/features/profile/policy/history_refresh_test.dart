import 'package:akimath_app/features/profile/policy/history_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether `GET /me/history` is worth asking a second time.
///
/// **PURE, and no clock in it.** Measured on 2026-09-02 against the deployed
/// server: history was asked at `03:51:04.581` and answered empty, and the
/// batch of five landed at `03:51:04.697` — 116 ms later. Perfil drew no
/// `HISTORIAL` section at all while the server held a complete session, and
/// only a relaunch showed it.
///
/// The counter is what makes the question answerable without a clock: the
/// server's history changes when — and only when — a batch is recorded, so a
/// tally of recordings compared against the tally at the last ask is exactly
/// "is there something new to read".
void main() {
  group('historyOutdated', () {
    test('a batch recorded since the last ask is worth asking again', () {
      expect(historyOutdated(recordedWhenAsked: 3, recordedNow: 4), isTrue);
    });

    test('nothing recorded since the last ask is not worth a request', () {
      expect(historyOutdated(recordedWhenAsked: 3, recordedNow: 3), isFalse);
      expect(historyOutdated(recordedWhenAsked: 0, recordedNow: 0), isFalse);
    });

    test('a first ask is owed however many batches this device has sent', () {
      // Null is "this root has not asked yet" — which is the state of a profile
      // whose session arrived after `initState`, and it is not the same fact as
      // having asked at zero.
      expect(historyOutdated(recordedWhenAsked: null, recordedNow: 0), isTrue);
      expect(historyOutdated(recordedWhenAsked: null, recordedNow: 7), isTrue);
    });

    test('a counter that went backwards is asked again rather than trusted',
        () {
      // Storage was cleared, or read as absent while a write was in flight.
      // Asking once too often costs a request; not asking loses the section a
      // player just earned, which is the defect this exists for.
      expect(historyOutdated(recordedWhenAsked: 4, recordedNow: 1), isTrue);
    });
  });
}
