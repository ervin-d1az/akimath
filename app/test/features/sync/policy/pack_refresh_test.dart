import 'package:akimath_app/features/sync/policy/pack_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 12);

  PackRefresh decide({
    bool hasSession = true,
    String? storedPackId = 'pk_1',
    DateTime? expiresAt,
  }) =>
      packRefresh(
        hasSession: hasSession,
        storedPackId: storedPackId,
        expiresAt: expiresAt,
        now: now,
      );

  group('what a launch owes the pack', () {
    test('no session, nothing to ask', () {
      // Unlinked play is entirely offline (ADR 0002): the bundled pack is the
      // whole of it, for ever and by design.
      expect(decide(hasSession: false), PackRefresh.none);
      expect(
        decide(hasSession: false, storedPackId: null),
        PackRefresh.none,
      );
    });

    test('a session and no stored id asks for one', () {
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
}
