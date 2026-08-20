import 'package:akimath_app/features/account/policy/player_id.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> bytes(int fill) => List<int>.filled(16, fill);

void main() {
  group('an id this device minted', () {
    test('is a uuid, shaped the way one is written', () {
      expect(playerIdFrom(bytes(0)), '00000000-0000-4000-8000-000000000000');
    });

    test('and it is version 4 whatever the bytes were', () {
      // Sixteen random bytes formatted as a uuid fails the frozen pattern about
      // one time in eight — the kind of defect that ships and then bites one
      // player in eight.
      for (int fill = 0; fill < 256; fill++) {
        final String id = playerIdFrom(bytes(fill));
        expect(id[14], '4', reason: 'version nibble, fill $fill');
        expect('89ab'.contains(id[19]), isTrue, reason: 'variant nibble, fill $fill');
        expect(isPlayerId(id), isTrue, reason: 'fill $fill');
      }
    });

    test('the other bytes are carried through untouched', () {
      // Only the two nibbles the RFC pins are rewritten; an id that quietly
      // dropped entropy would collide far sooner than anybody would notice.
      final List<int> raw = List<int>.generate(16, (int i) => i * 16 + i);
      final String id = playerIdFrom(raw).replaceAll('-', '');

      for (int i = 0; i < 16; i++) {
        if (i == 6 || i == 8) {
          continue;
        }
        expect(id.substring(i * 2, i * 2 + 2), raw[i].toRadixString(16).padLeft(2, '0'));
      }
    });

    test('and the wrong number of bytes is refused rather than padded', () {
      expect(() => playerIdFrom(List<int>.filled(15, 0)), throwsArgumentError);
      expect(() => playerIdFrom(List<int>.filled(17, 0)), throwsArgumentError);
    });
  });

  group('what counts as one on the way out of storage', () {
    test('an id this device minted does', () {
      expect(isPlayerId(playerIdFrom(bytes(0xab))), isTrue);
    });

    test('and anything else does not', () {
      for (final String not in <String>[
        '',
        'not-a-uuid',
        '00000000-0000-0000-0000-000000000000', // the nil uuid: allowed by the
        // contract, but not something a device mints
        'ffffffff-ffff-ffff-ffff-ffffffffffff',
        '00000000-0000-4000-0000-000000000000', // no variant
        '00000000-0000-9000-8000-000000000000', // version 9
        'AAAAAAAA-0000-4000-8000-000000000000', // uppercase
        ' 00000000-0000-4000-8000-000000000000', // the anchors
      ]) {
        expect(isPlayerId(not), isFalse, reason: not);
      }
    });
  });
}
