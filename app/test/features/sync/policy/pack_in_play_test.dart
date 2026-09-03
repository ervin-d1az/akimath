import 'dart:convert';

import 'package:akimath_app/api/sync.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/model/pack.dart';
import 'package:akimath_app/features/sync/policy/pack_in_play.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pack that carries nothing but an id and a window, which is all this
/// decision reads. Its items are somebody else's question.
Pack _pack({required String id, required DateTime expiresAt}) => Pack(
      id: id,
      issuedAt: DateTime.utc(2026, 8, 1),
      expiresAt: expiresAt,
      items: const <Item>[],
    );

/// A pack in the **frozen** format, which is what the server issues: one number
/// series whose answer is a digest. `readIssuedPack` mints each item's id as
/// `packId#index`, which is the address an attempt is submitted under.
const String _issuedContent = '''
{
  "pack_format_version": 1,
  "pack_salt": "a1b2c3d4e5f60718293a4b5c6d7e8f90",
  "skill_nodes": [],
  "skill_fallbacks": [
    {"skill_id": 1, "diagnosis": {"misconception": "no_specific_diagnosis",
      "steps": ["Lee otra vez el reto, sin prisa."],
      "explain": "Repasa el reto con calma."}}
  ],
  "puzzles": [],
  "items": [
    {"skill_id": 1, "ladder_step": 1, "keypad": "item",
     "stimulus": {"kind": "numberSeries",
       "payload": {"terms": [2, 4, 6, 8], "unknown_index": 3}},
     "answer": {"shape": "integer",
       "digest": "0f0e0d0c0b0a09080706050403020100"},
     "diagnosis": null}
  ]
}
''';

IssuedPack _issuedPack(String content) => IssuedPack(
      packId: 'pk-1',
      issuedAt: DateTime.utc(2026, 8, 1),
      expiresAt: DateTime.utc(2026, 9, 1),
      pack: json.decode(content) as Map<String, dynamic>,
    );

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 12);
  final DateTime open = DateTime.utc(2026, 9, 20);
  final DateTime closed = DateTime.utc(2026, 8, 1);

  group('which pack is in play', () {
    test('nothing read yet is pending, not a refusal', () {
      // A launch state. Both roots draw a skeleton here; neither may say the
      // pack has lapsed, which is a claim about a pack it has not seen.
      expect(
        packInPlay(issued: null, bundled: null, now: now),
        isA<PackPending>(),
      );
    });

    test('the bundled pack plays when no pack has been issued', () {
      final PackInPlay answer = packInPlay(
        issued: null,
        bundled: _pack(id: 'starter', expiresAt: open),
        now: now,
      );

      expect(answer, isA<PackReady>());
      expect((answer as PackReady).pack.id, 'starter');
    });

    test('an issued pack replaces the bundled one', () {
      // Same families, same boards; the difference is that every item carries a
      // `(packId, index)` the server can grade.
      final PackInPlay answer = packInPlay(
        issued: _pack(id: 'pk-1', expiresAt: open),
        bundled: _pack(id: 'starter', expiresAt: open),
        now: now,
      );

      expect((answer as PackReady).pack.id, 'pk-1');
    });

    test('a lapsed issued pack is lapsed, and does not fall back to the '
        'bundled one', () {
      // **The case that tells the two halves of this decision apart.** Which
      // pack wins and whether it may be played are separate questions, and a
      // fixture where both packs share a window cannot see the difference —
      // `_issued ?? bundled` with no expiry check passes that one. Falling back
      // here would hand a player items no attempt can be addressed to;
      // `packRefresh` is what asks for a replacement.
      expect(
        packInPlay(
          issued: _pack(id: 'pk-1', expiresAt: closed),
          bundled: _pack(id: 'starter', expiresAt: open),
          now: now,
        ),
        isA<PackLapsed>(),
      );
    });

    test('and a live issued pack survives a lapsed bundled one', () {
      // The mirror, so precedence is pinned in both directions rather than
      // being read off whichever pack happened to be open.
      final PackInPlay answer = packInPlay(
        issued: _pack(id: 'pk-1', expiresAt: open),
        bundled: _pack(id: 'starter', expiresAt: closed),
        now: now,
      );

      expect((answer as PackReady).pack.id, 'pk-1');
    });

    test('a lapsed bundled pack is refused with no server involved', () {
      // The live divergence this module was written for: the day the file the
      // app ships runs out, with no account and no network in the story.
      expect(
        packInPlay(
          issued: null,
          bundled: _pack(id: 'starter', expiresAt: closed),
          now: now,
        ),
        isA<PackLapsed>(),
      );
    });

    test('the instant the window closes counts as lapsed', () {
      // The boundary falls on the closed side, which is `isExpiredAt`'s own
      // reading: a pack that dies mid-series is worse than one refused a
      // moment early.
      expect(
        packInPlay(
          issued: null,
          bundled: _pack(id: 'starter', expiresAt: now),
          now: now,
        ),
        isA<PackLapsed>(),
      );
      expect(
        packInPlay(
          issued: null,
          bundled: _pack(
            id: 'starter',
            expiresAt: now.add(const Duration(microseconds: 1)),
          ),
          now: now,
        ),
        isA<PackReady>(),
      );
    });

    test('the same moment in two zones gives the same answer', () {
      // Why the doc says a caller need not convert: both call sites in
      // `HomeRoute` wrote `.toUtc()` and neither had to. If that ever stops
      // being true this goes red rather than a player's zone deciding whether
      // a pack has run out.
      final DateTime local = DateTime.utc(2026, 8, 20, 12).toLocal();

      expect(local.isUtc, isFalse);
      expect(
        packInPlay(
          issued: null,
          bundled: _pack(id: 'starter', expiresAt: closed),
          now: local,
        ),
        isA<PackLapsed>(),
      );
      expect(
        packInPlay(
          issued: null,
          bundled: _pack(id: 'starter', expiresAt: open),
          now: local,
        ),
        isA<PackReady>(),
      );
    });
  });

  group('the pack inside what the server issued', () {
    test('is read, with every item addressed by packId#index', () {
      final Pack? pack = packFrom(_issuedPack(_issuedContent));

      expect(pack, isNotNull);
      expect(pack!.id, 'pk-1');
      expect(pack.items.single.id, 'pk-1#0');
      expect(pack.expiresAt, DateTime.utc(2026, 9, 1));
    });

    test('and one this app cannot read is nothing at all', () {
      // A pack this app cannot read is a pack it does not play. The bundled one
      // is still there, and a fetch nobody asked for is not worth a crash.
      expect(packFrom(_issuedPack('{"items": []}')), isNull);
    });
  });
}
