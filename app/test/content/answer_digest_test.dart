import 'dart:convert';
import 'dart:io';

import 'package:akimath_app/content/answer_digest.dart';
import 'package:akimath_app/content/model/canon.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dart digest, held to the table `packages/contract` emitted.
///
/// **The fixture exists because this file does.** `canon.golden.json` pinned
/// how an answer is spelled and nothing pinned what it hashes to — harmless
/// while one stack computed digests, R2 the moment a second one did. The table
/// was written first, from the TypeScript code, so this is a matter of passing
/// a test rather than of reading a paragraph carefully.
Map<String, Object?> readGolden() {
  final File file = File('../contract/fixtures/digest.golden.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

void main() {
  final Map<String, Object?> golden = readGolden();
  final String salt = golden['pack_salt_hex']! as String;
  final List<Object?> vectors = golden['vectors']! as List<Object?>;

  group('the cross-stack digest table', () {
    test('has vectors, and the count is reported', () {
      // PROC-10: a parity test that matched nothing would pass in silence.
      expect(vectors, isNotEmpty, reason: 'digest vectors → ${vectors.length}');
    });

    for (final Object? raw in vectors) {
      final Map<String, Object?> vector = raw! as Map<String, Object?>;
      final String stored = vector['stored']! as String;
      final String canonical = vector['canonical']! as String;
      final String expected = vector['digest']! as String;

      test('"$stored" canonicalizes the way TypeScript says', () {
        final CanonResult result = canonicalise(stored, mode: CanonMode.stored);
        expect(result.ok, isTrue, reason: 'refused as ${result.tag}');
        expect(result.value, canonical);
      });

      test('"$stored" digests the way TypeScript says', () {
        expect(answerDigest(saltHex: salt, canonicalAnswer: canonical), expected);
      });
    }
  });

  group('the two mistakes a second implementation makes', () {
    test('the salt is bytes, not the characters that spell them', () {
      // An implementation that keys on the hex string gets a plausible digest
      // that matches nothing. Asserted here as well as in the table, so the
      // failure names the cause instead of listing ten wrong rows.
      final String asCharacters = utf8
          .encode(salt)
          .map((int b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      expect(
        answerDigest(saltHex: salt, canonicalAnswer: '7'),
        isNot(answerDigest(saltHex: asCharacters, canonicalAnswer: '7')),
      );
    });

    test('the message carries nothing but the answer', () {
      // No length prefix, no separator, no trailing newline. Each is a choice
      // somebody could make by accident and none of them is the contract.
      final String plain = answerDigest(saltHex: salt, canonicalAnswer: '1/2');
      expect(plain, isNot(answerDigest(saltHex: salt, canonicalAnswer: '1/2\n')));
      expect(plain, isNot(answerDigest(saltHex: salt, canonicalAnswer: '3:1/2')));
    });
  });

  group('what it refuses', () {
    test('a salt that is not hex', () {
      expect(
        () => answerDigest(saltHex: 'no soy hex', canonicalAnswer: '7'),
        throwsFormatException,
      );
    });

    test('a salt with an odd number of digits', () {
      expect(
        () => answerDigest(saltHex: 'abc', canonicalAnswer: '7'),
        throwsFormatException,
      );
    });
  });

  group('verifying an answer a player typed', () {
    test('accepts a different spelling of the same answer', () {
      // **This is why the typed side goes through learner mode and the pack
      // through stored.** A learner may pad, space or spell the minus
      // differently; the pack cannot. Canonicalizing before hashing is what
      // stops a child being marked wrong for a keystroke.
      final String seven = answerDigest(saltHex: salt, canonicalAnswer: '7');
      final String half = answerDigest(saltHex: salt, canonicalAnswer: '1/2');
      final String minusNine = answerDigest(saltHex: salt, canonicalAnswer: '-9');

      expect(answerMatches(saltHex: salt, typed: '007', digest: seven), isTrue);
      expect(answerMatches(saltHex: salt, typed: ' 7 ', digest: seven), isTrue);
      expect(answerMatches(saltHex: salt, typed: ' 1/2 ', digest: half), isTrue);
      // U+2212 MINUS SIGN, which is what the keypad emits.
      expect(answerMatches(saltHex: salt, typed: '\u22129', digest: minusNine), isTrue);
    });

    test('and a fraction is not reduced, on either side', () {
      // **`2/4` is not `1/2` to this contract.** The canonicalizer folds
      // spelling and never arithmetic, in both modes and in both stacks — so
      // the two are different answers with different digests, and the server
      // grades a submitted `2/4` exactly as this does. Recorded as a test
      // because the opposite is the intuition, and it was mine for a minute.
      final String half = answerDigest(saltHex: salt, canonicalAnswer: '1/2');

      expect(answerMatches(saltHex: salt, typed: '2/4', digest: half), isFalse);
    });

    test('refuses a different value', () {
      final String digest = answerDigest(saltHex: salt, canonicalAnswer: '1/2');

      expect(answerMatches(saltHex: salt, typed: '1/3', digest: digest), isFalse);
    });

    test('refuses what the canonicalizer cannot read, rather than throwing', () {
      // A player can type anything. An unreadable answer is wrong, not a crash.
      final String digest = answerDigest(saltHex: salt, canonicalAnswer: '7');

      expect(answerMatches(saltHex: salt, typed: 'x+1', digest: digest), isFalse);
      expect(answerMatches(saltHex: salt, typed: '', digest: digest), isFalse);
    });

    test('compares case-insensitively on the hex, since case is not meaning', () {
      final String digest = answerDigest(saltHex: salt, canonicalAnswer: '7');

      expect(
        answerMatches(saltHex: salt, typed: '7', digest: digest.toUpperCase()),
        isTrue,
      );
    });
  });

  group('grading an item, whichever way its answer is known', () {
    const Stimulus stimulus = ArithmeticStimulus(<PromptToken>[
      TextToken('5'),
      OperatorToken('+'),
      TextToken('8'),
      OperatorToken('='),
    ]);

    test('a plaintext item still grades the way it always did', () {
      const Item item = Item(
        id: 'claro',
        stimulus: stimulus,
        answer: PlainAnswer('13'),
        ladderStep: 1,
      );

      expect(gradeItem(item, '13'), Verdict.correct);
      expect(gradeItem(item, '14'), Verdict.wrong);
    });

    test('a digest item grades without the answer being in the file', () {
      // The whole point: the pack states an HMAC, the device says right or
      // wrong, and the answer is nowhere in the bytes it was handed.
      final Item item = Item(
        id: 'digerido',
        stimulus: stimulus,
        answer: DigestAnswer(
          digest: answerDigest(saltHex: salt, canonicalAnswer: '13'),
          saltHex: salt,
        ),
        ladderStep: 1,
      );

      expect(gradeItem(item, '13'), Verdict.correct);
      expect(gradeItem(item, '14'), Verdict.wrong);
    });

    test('and forgives a spelling the same way', () {
      final Item item = Item(
        id: 'digerido',
        stimulus: stimulus,
        answer: DigestAnswer(
          digest: answerDigest(saltHex: salt, canonicalAnswer: '13'),
          saltHex: salt,
        ),
        ladderStep: 1,
      );

      expect(gradeItem(item, ' 013 '), Verdict.correct);
    });

    test('reading a plaintext answer off a digest item is a mistake, loudly', () {
      // A caller reaching for an answer that does not exist has made an error
      // worth a stack trace rather than a silent empty string.
      final Item item = Item(
        id: 'digerido',
        stimulus: stimulus,
        answer: DigestAnswer(digest: 'a' * 64, saltHex: salt),
        ladderStep: 1,
      );

      expect(() => item.expected, throwsStateError);
    });
  });
}
