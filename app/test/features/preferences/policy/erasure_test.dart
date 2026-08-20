import 'package:akimath_app/api/me_result.dart';
import 'package:akimath_app/features/preferences/policy/erasure.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what erasure came back as', () {
    test('nothing yet is the request still in flight', () {
      expect(erasureStepFor(null), ErasureStep.erasing);
    });

    test('erased and nothing-to-erase are the same outcome to the player', () {
      // Two different facts to whoever reads a log, one fact to whoever asked
      // to be forgotten: there is nothing left. Collapsed here, in one place,
      // rather than in whichever screen happens to switch on the result.
      expect(erasureStepFor(const EraseDone()), ErasureStep.gone);
      expect(erasureStepFor(const EraseNothingThere()), ErasureStep.gone);
    });

    test('a refused session, an unreadable answer and no answer differ', () {
      expect(
        erasureStepFor(const EraseRejected(tag: 'invalid_session', message: '')),
        ErasureStep.rejected,
      );
      expect(
        erasureStepFor(const EraseFailed(status: 500, reason: '')),
        ErasureStep.serverError,
      );
      expect(erasureStepFor(const EraseUnreachable('no route')), ErasureStep.offline);
    });
  });

  group('when a retry is worth offering', () {
    test('only where trying again could answer differently', () {
      expect(canRetryErasure(ErasureStep.offline), isTrue);
      expect(canRetryErasure(ErasureStep.serverError), isTrue);
    });

    test('and never where it cannot', () {
      // A dead token does not recover by being sent twice, and there is nothing
      // to erase a second time.
      expect(canRetryErasure(ErasureStep.rejected), isFalse);
      expect(canRetryErasure(ErasureStep.gone), isFalse);
      expect(canRetryErasure(ErasureStep.erasing), isFalse);
    });
  });

  group('when the door is offered at all', () {
    test('only where this device holds a session the server accepts', () {
      expect(erasureOffered(AccountState.linked), isTrue);
      // Nothing on the server yet, and the act still means something: it is how
      // a device stops being attached to an account.
      expect(erasureOffered(AccountState.noPlayer), isTrue);
    });

    test('and not where it could only fail or does not apply', () {
      for (final AccountState state in <AccountState>[
        AccountState.none,
        AccountState.loading,
        AccountState.rejected,
        AccountState.offline,
        AccountState.serverError,
      ]) {
        expect(erasureOffered(state), isFalse, reason: state.name);
      }
    });
  });

  group('the copy', () {
    test('every step has a headline and a line under it', () {
      for (final ErasureStep step in ErasureStep.values) {
        expect(erasureHeadline(step), isNotEmpty, reason: step.name);
        expect(erasureDetail(step), isNotEmpty, reason: step.name);
      }
    });

    test('and no two steps say the same thing', () {
      // A screen that cannot be told apart from another screen is one the
      // player reads as "it did nothing".
      final Set<String> headlines =
          ErasureStep.values.map(erasureHeadline).toSet();
      expect(headlines, hasLength(ErasureStep.values.length));
    });

    test('the confirmation names what survives, because something does', () {
      // The account is not ours to delete. A screen that says "todo borrado"
      // while the sign-in still works is the one lie this flow can tell.
      expect(erasureConfirmDetail, contains('correo'));
      expect(erasureHeadline(ErasureStep.gone), isNot(contains('Todo')));
      expect(erasureDetail(ErasureStep.gone), contains('correo'));
    });

    test('and a failure never claims to know what happened', () {
      // A 500 can arrive after a commit. "No se borró nada" would be a guess.
      expect(erasureDetail(ErasureStep.serverError), isNot(contains('No se borró')));
    });
  });
}
