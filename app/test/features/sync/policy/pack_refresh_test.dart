import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:akimath_app/features/sync/policy/pack_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 12);

  PackRefresh decide({
    PackAccount account = PackAccount.linked,
    String? storedPackId = 'pk_1',
    DateTime? expiresAt,
  }) =>
      packRefresh(
        account: account,
        storedPackId: storedPackId,
        expiresAt: expiresAt,
        now: now,
      );

  group('what a launch owes the pack', () {
    test('no player, nothing to ask', () {
      // Two ways to have none, and neither is a pack request. No session at
      // all means unlinked play, which is entirely offline (ADR 0002) — the
      // bundled pack is the whole of it, for ever and by design. A session
      // whose link has not landed means `POST /packs` would 404, which is the
      // race the deployed server caught on 2026-09-02.
      expect(decide(account: PackAccount.noPlayer), PackRefresh.none);
      expect(
        decide(account: PackAccount.noPlayer, storedPackId: null),
        PackRefresh.none,
      );
      expect(
        decide(
          account: PackAccount.noPlayer,
          expiresAt: DateTime.utc(2020),
        ),
        PackRefresh.none,
        reason: 'a lapsed pack is still not a reason to ask without a player',
      );
    });

    test('a linked player and no stored id asks for one', () {
      expect(decide(storedPackId: null), PackRefresh.issue);
      expect(decide(storedPackId: ''), PackRefresh.issue);
    });

    test('a stored id is fetched, not reissued', () {
      // The whole point. The server rebuilds byte for byte, so this is the same
      // pack; issuing again would leave a row behind per launch per player.
      expect(
        decide(expiresAt: DateTime.utc(2026, 9, 20)),
        PackRefresh.fetch,
      );
    });

    test('an id with an unknown expiry is still fetched', () {
      // A store that could not be read knows the id and not the window. The
      // server refuses a lapsed pack with a 404, which is the one answer that
      // means issue — so the wrong guess costs a round trip and not a defect.
      expect(decide(expiresAt: null), PackRefresh.fetch);
    });

    test('a lapsed pack is issued rather than fetched', () {
      expect(
        decide(expiresAt: DateTime.utc(2026, 8, 19)),
        PackRefresh.issue,
      );
    });

    test('and one about to lapse counts as lapsed', () {
      // The window is measured in weeks. Handing a player a pack that dies
      // mid-series to save one request is the wrong trade.
      expect(decide(expiresAt: now.add(const Duration(seconds: 30))),
          PackRefresh.issue);
      expect(decide(expiresAt: now), PackRefresh.issue);
    });

    test('the margin is where the boundary falls, and it falls once', () {
      expect(decide(expiresAt: now.add(expiryMargin)), PackRefresh.issue);
      expect(
        decide(expiresAt: now.add(expiryMargin + const Duration(seconds: 1))),
        PackRefresh.fetch,
      );
    });
  });

  group('which account states hold a player to issue to', () {
    test('exactly one of them does', () {
      // **The list is walked rather than the one case asserted**, because the
      // claim is *only* `linked` — an eleventh state defaulting to issuable is
      // the shape of the defect this exists to prevent, and a test naming one
      // input could not see it (PROC-10).
      final List<AccountState> issuable = AccountState.values
          .where((AccountState s) => packAccountFor(s) == PackAccount.linked)
          .toList();

      expect(issuable, <AccountState>[AccountState.linked],
          reason: 'swept ${AccountState.values.length} account states');
    });

    test('the link landing is what flips it', () {
      // The two states a first launch passes through, in order. `loading` is
      // set the instant a session appears — which is the instant the home used
      // to ask, and lose.
      expect(packAccountFor(AccountState.none), PackAccount.noPlayer);
      expect(packAccountFor(AccountState.loading), PackAccount.noPlayer);
      expect(packAccountFor(AccountState.linked), PackAccount.linked);
    });

    test('a conflict is not a player of this device`s', () {
      // The account has a player and it is not this one, or which way round is
      // unknown. The app has already stopped and said so; a pack issued here
      // would be addressed to somebody else's progress.
      expect(packAccountFor(AccountState.otherDevice), PackAccount.noPlayer);
      expect(packAccountFor(AccountState.otherAccount), PackAccount.noPlayer);
      expect(packAccountFor(AccountState.mismatch), PackAccount.noPlayer);
    });
  });
}
