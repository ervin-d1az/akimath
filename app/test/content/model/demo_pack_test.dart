import 'package:akimath_app/content/model/canon.dart';
import 'package:akimath_app/content/model/demo_pack.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('every shipped item is well formed', () {
    test('the pack is not empty', () {
      expect(demoPack, isNotEmpty);
    });

    test('every expected answer is storage-canonical', () {
      // This caught a real defect: one item was written `−7` with U+2212, which
      // stored mode refuses. It would have shown a wrong verdict for the right
      // answer, on a device, with nothing anywhere reporting an error.
      for (final Item item in demoPack) {
        final CanonResult result =
            canonicalise(item.expected, mode: CanonMode.stored);
        expect(
          result.ok,
          isTrue,
          reason: '${item.id} stores "${item.expected}", which is not '
              'canonical (${result.tag})',
        );
      }
    });

    test('every item has a prompt and a positive ladder step', () {
      for (final Item item in demoPack) {
        expect(item.prompt, isNotEmpty, reason: '${item.id} has no prompt');
        expect(item.ladderStep, greaterThan(0), reason: item.id);
      }
    });

    test('ids are unique', () {
      final Set<String> ids = demoPack.map((Item i) => i.id).toSet();
      expect(ids, hasLength(demoPack.length));
    });
  });
}
