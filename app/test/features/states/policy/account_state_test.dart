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
      expect(AccountState.values, hasLength(10));
    });
  });

  group('a link the server refused as a conflict', () {
    test('is a mismatch and nothing more, because the 409 says nothing more', () {
      // **The wire collapses two facts into one tag.** `linkOutcome` in
      // `packages/server/src/link.ts` knows whether the *account* already has a
      // player or the *player* already has an account, and `conflictResponse`
      // sends both as `already_linked` with the difference surviving only in an
      // English `message`. Branching on that prose would make a copy edit on the
      // server change what this app tells a player, so the link result alone
      // resolves to the state that claims the least.
      expect(
        linkStateFor(const LinkConflict('this account already has a player')),
        AccountState.mismatch,
      );
      expect(
        linkStateFor(const LinkConflict('that player already belongs to another account')),
        AccountState.mismatch,
      );
    });

    test('and none of the three is the player´s fault', () {
      expect(isOurFault(AccountState.mismatch), isFalse);
      expect(isOurFault(AccountState.otherDevice), isFalse);
      expect(isOurFault(AccountState.otherAccount), isFalse);
    });

    test('a link maps every way it can fail', () {
      // The control: a case added to `LinkResult` has to be classified, and
      // this fails if the switch grows a default instead.
      final List<LinkResult> every = <LinkResult>[
        LinkDone(Me(
          playerId: _devicePlayer,
          ageBand: AgeBand.adult,
          createdAt: DateTime.utc(2026),
        )),
        const LinkConflict(''),
        const LinkMalformed(''),
        const LinkRejected(tag: '', message: ''),
        const LinkFailed(status: 0, reason: ''),
        const LinkUnreachable(''),
      ];

      expect(
        every.map(linkStateFor).toSet(),
        <AccountState>{
          AccountState.linked,
          AccountState.mismatch,
          AccountState.serverError,
          AccountState.rejected,
          AccountState.offline,
        },
      );
    });
  });

  group('which way the conflict runs, asked of `GET /me`', () {
    // **The probe is exact, not a guess.** `linkOutcome` tests
    // `playerForAccount !== null` *before* `accountForPlayer !== null`, and
    // `GET /me` is `playerForAccount` — so a 200 naming a different player is
    // the first refusal and a 404 can only be the second.

    test('a player under the account, and not this one, is the other phone', () {
      expect(
        conflictStateFor(probe: MeFound(_otherPlayersProfile()), devicePlayerId: _devicePlayer),
        AccountState.otherDevice,
      );
    });

    test('no player under the account puts this phone´s player elsewhere', () {
      // What happened on a real device: one simulator, two accounts. The
      // account is new and has nothing; the id on disk was minted for the
      // first account and still belongs to it.
      expect(
        conflictStateFor(probe: const MeNoPlayer(), devicePlayerId: _devicePlayer),
        AccountState.otherAccount,
      );
    });

    test('the account already holding this very player is simply linked', () {
      // A 409 followed by a 200 naming *this* player is a race the one-to-one
      // constraint forbids from persisting, so the later answer wins rather
      // than earning a state of its own.
      expect(
        conflictStateFor(probe: MeFound(_thisPlayersProfile()), devicePlayerId: _devicePlayer),
        AccountState.linked,
      );
    });

    test('a probe that failed leaves the mismatch unrefined, never guessed', () {
      // The one direction that turns a fix into the bug it replaced: falling
      // through to either case´s copy would be inventing the answer the probe
      // did not give.
      expect(
        conflictStateFor(probe: const MeUnreachable('no route'), devicePlayerId: _devicePlayer),
        AccountState.mismatch,
      );
      expect(
        conflictStateFor(probe: const MeFailed(status: 500, reason: 'boom'), devicePlayerId: _devicePlayer),
        AccountState.mismatch,
      );
    });

    test('a token refused between the two calls is a refused token', () {
      // The 409 proved the token worked a moment earlier, so a 401 now means it
      // stopped working — which is both true and the one thing with a door.
      expect(
        conflictStateFor(
          probe: const MeRejected(tag: 'invalid_session', message: ''),
          devicePlayerId: _devicePlayer,
        ),
        AccountState.rejected,
      );
    });

    test('every probe result is classified, so a new one cannot slip through', () {
      final List<MeResult> every = <MeResult>[
        MeFound(_otherPlayersProfile()),
        const MeNoPlayer(),
        const MeRejected(tag: '', message: ''),
        const MeFailed(status: 0, reason: ''),
        const MeUnreachable(''),
      ];

      for (final MeResult probe in every) {
        expect(
          () => conflictStateFor(probe: probe, devicePlayerId: _devicePlayer),
          returnsNormally,
          reason: probe.runtimeType.toString(),
        );
      }
    });
  });

  group('the door a state offers', () {
    test('this phone´s progress belonging elsewhere is a sign-out', () {
      // Non-destructive and it actually works: signing back in as the account
      // the id belongs to makes `linkOutcome` answer `existing`, which is a 200.
      expect(accountDoorFor(AccountState.otherAccount), AccountDoor.signOut);
    });

    test('an unrefined mismatch is worth asking again', () {
      expect(accountDoorFor(AccountState.mismatch), AccountDoor.retry);
    });

    test('the account´s player being elsewhere offers nothing, and that is honest', () {
      // Moving a player between accounts is a product decision nobody has made,
      // and signing out would not recover the progress either.
      expect(accountDoorFor(AccountState.otherDevice), AccountDoor.none);
    });

    test('the doors already on disk are unchanged', () {
      expect(accountDoorFor(AccountState.serverError), AccountDoor.detail);
      expect(accountDoorFor(AccountState.offline), AccountDoor.retry);
      expect(accountDoorFor(AccountState.linked), AccountDoor.none);
      expect(accountDoorFor(AccountState.noPlayer), AccountDoor.none);
      expect(accountDoorFor(AccountState.rejected), AccountDoor.none);
    });

    test('every state has a door, so a new one cannot slip through', () {
      for (final AccountState state in AccountState.values) {
        expect(() => accountDoorFor(state), returnsNormally, reason: state.name);
      }
      expect(AccountState.values, hasLength(10));
    });
  });
}

const String _devicePlayer = '018f4e3c-0000-7000-8000-0000000000b1';

Me _thisPlayersProfile() => Me(
  playerId: _devicePlayer,
  ageBand: AgeBand.adult,
  createdAt: DateTime.utc(2026, 8, 20),
);

Me _otherPlayersProfile() => Me(
  playerId: '018f4e3c-0000-7000-8000-0000000000c2',
  ageBand: AgeBand.adult,
  createdAt: DateTime.utc(2026, 8, 20),
);
