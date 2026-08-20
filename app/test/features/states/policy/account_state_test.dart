import 'package:akimath_app/api/api_client.dart';
import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:flutter_test/flutter_test.dart';

final Me _me = Me(
  playerId: '018f4e3c-0000-7000-8000-0000000000b1',
  ageBand: AgeBand.adult,
  createdAt: DateTime.utc(2026, 8, 19),
);

void main() {
  group('every answer the client can give has a state', () {
    test('and no two share one', () {
      // Exhaustive by construction — the switch is over a sealed union, so a
      // sixth `MeResult` is a compile error here rather than a screen that
      // renders nothing.
      final Map<MeResult, AccountState> expected = <MeResult, AccountState>{
        MeFound(_me): AccountState.linked,
        const MeNoPlayer(): AccountState.noPlayer,
        const MeRejected(tag: 'invalid_session', message: ''): AccountState.rejected,
        const MeFailed(status: 500, reason: ''): AccountState.serverError,
        const MeUnreachable('no route'): AccountState.offline,
      };
      expected.forEach((MeResult result, AccountState state) {
        expect(accountStateFor(result), state, reason: '$result');
      });
      expect(expected.values.toSet(), hasLength(expected.length));
    });

    test('and no answer at all is loading, which is not a MeResult', () {
      // `4.11 Cargando` is the absence of a result, so it cannot come from the
      // union — which is exactly why this mapping is a function and not a
      // `switch` written inline on a screen.
      expect(accountStateFor(null), AccountState.loading);
    });
  });

  group('whose fault it is decides the colour', () {
    test('losing signal is nobody\'s mistake', () {
      // The plan says it in its own words: "Sin conexión no es un error del
      // usuario: va en amarillo."
      expect(isOurFault(AccountState.offline), isFalse);
    });

    test('a broken answer and a refused session are ours', () {
      expect(isOurFault(AccountState.serverError), isTrue);
      expect(isOurFault(AccountState.rejected), isTrue);
    });

    test('nothing ordinary is anybody\'s fault', () {
      for (final AccountState state in <AccountState>[
        AccountState.none,
        AccountState.loading,
        AccountState.linked,
        AccountState.noPlayer,
      ]) {
        expect(isOurFault(state), isFalse, reason: state.name);
      }
    });

    test('every state is classified, so a new one cannot slip through', () {
      for (final AccountState state in AccountState.values) {
        expect(() => isOurFault(state), returnsNormally, reason: state.name);
      }
      expect(AccountState.values, hasLength(7));
    });
  });
}
