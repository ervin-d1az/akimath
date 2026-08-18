import 'dart:convert';
import 'dart:io';

import 'package:akimath_app/content/model/canon.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frozen oracle both implementations answer to.
///
/// Read from `contract/` rather than copied into this file: a copy is a second
/// source of truth, and R2 is precisely the risk that the Dart and TypeScript
/// canonicalisers drift. If the emitter regenerates this file, this test moves
/// with it or goes red.
Map<String, dynamic> _golden() {
  final File file = File('../contract/fixtures/canon.golden.json');
  if (!file.existsSync()) {
    // Thrown rather than asserted: this runs while the test file is being
    // loaded, before any test body, where `expect` has nowhere to report.
    throw StateError(
      'the frozen canon fixture is missing at ${file.path} — parity cannot be '
      'checked, and a silently skipped parity test is worse than none',
    );
  }
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final Map<String, dynamic> golden = _golden();
  final List<dynamic> vectors = golden['vectors'] as List<dynamic>;

  test('the fixture has vectors and the check is not vacuous', () {
    expect(vectors, isNotEmpty);
    // ignore: avoid_print
    print('  canon parity · vectors → ${vectors.length}');
  });

  group('the Dart canonicaliser agrees with the frozen fixture', () {
    for (final dynamic entry in vectors) {
      final Map<String, dynamic> vector = entry as Map<String, dynamic>;
      final String raw = vector['raw'] as String;
      final Map<String, dynamic> learner =
          vector['learner'] as Map<String, dynamic>;
      final Map<String, dynamic> stored =
          vector['stored'] as Map<String, dynamic>;

      test('learner ${json.encode(raw)}', () {
        final CanonResult result = canonicalise(raw, mode: CanonMode.learner);

        expect(result.ok, learner['ok'],
            reason: 'ok differs for ${json.encode(raw)}');
        if (learner['ok'] as bool) {
          expect(result.value, learner['value']);
        } else {
          expect(result.tag, learner['tag']);
        }
      });

      test('stored ${json.encode(raw)}', () {
        final CanonResult result = canonicalise(raw, mode: CanonMode.stored);

        expect(result.ok, stored['ok'],
            reason: 'ok differs for ${json.encode(raw)}');
        if (stored['ok'] as bool) {
          expect(result.value, stored['value']);
        } else {
          expect(result.tag, stored['tag']);
        }
      });
    }
  });

  group('the character map is the one the fixture declares', () {
    test('the fixture still declares the three mappings this relies on', () {
      final Map<String, dynamic> charMap =
          golden['char_map'] as Map<String, dynamic>;
      // Asserted against the fixture rather than hard-coded here, so adding a
      // mapping on the TypeScript side surfaces as a failure rather than drift.
      expect(charMap.keys, containsAll(<String>[' ', '⁄', '−']));
      expect(charMap[' '], '');
      expect(charMap['⁄'], '/');
      expect(charMap['−'], '-');
    });
  });

  group('a fraction is not reduced', () {
    test('2/4 stays 2/4', () {
      // The contract compares what was typed, not what it simplifies to.
      // Reducing here would make 2/4 and 1/2 the same answer, which is a
      // pedagogical decision this layer does not get to take.
      expect(canonicalise('2/4', mode: CanonMode.learner).value, '2/4');
    });
  });

  group('a zero magnitude drops its sign in BOTH shapes', () {
    // Found by differential fuzzing against the real `packages/contract`
    // implementation over 22,440 inputs, not by the golden fixture — whose 19
    // vectors contain no `-0/n` case at all. The fixture approximates the
    // cross-stack check; it does not replace it.
    //
    // The bug: the integer branch suppressed the sign on `-0` and the fraction
    // branch re-applied it, so `-0/5` canonicalised to `-0/5` in Dart and `0/5`
    // in TypeScript. In stored mode Dart *accepted* `-0/5` as canonical where
    // the contract rejects it — so a pack authored with that answer loaded
    // clean and told a child typing `0/5` they were wrong.
    test('an integer zero drops its sign', () {
      expect(canonicalise('-0', mode: CanonMode.learner).value, '0');
    });

    test('a fraction with a zero numerator drops its sign', () {
      expect(canonicalise('-0/5', mode: CanonMode.learner).value, '0/5');
      expect(canonicalise('-00/11', mode: CanonMode.learner).value, '0/11');
      expect(canonicalise('−0/70', mode: CanonMode.learner).value, '0/70');
    });

    test('a signed zero fraction is not storage-canonical', () {
      final CanonResult stored =
          canonicalise('-0/5', mode: CanonMode.stored);
      expect(stored.ok, isFalse);
      expect(stored.tag, 'not_canonical');
    });

    test('a non-zero magnitude keeps its sign in both shapes', () {
      expect(canonicalise('-7', mode: CanonMode.learner).value, '-7');
      expect(canonicalise('-1/5', mode: CanonMode.learner).value, '-1/5');
    });
  });
}
