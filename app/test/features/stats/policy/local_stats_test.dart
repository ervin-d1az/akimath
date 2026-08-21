import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/features/stats/policy/local_stats.dart';
import 'package:flutter_test/flutter_test.dart';

AnsweredItem _right([int ms = 5000]) =>
    AnsweredItem(verdict: Verdict.correct, elapsed: Duration(milliseconds: ms));

AnsweredItem _wrong([int ms = 5000]) =>
    AnsweredItem(verdict: Verdict.wrong, elapsed: Duration(milliseconds: ms));

List<AnsweredItem> _many(int count) =>
    List<AnsweredItem>.generate(count, (int at) => _right(at));

void main() {
  group('accuracy over no answers is absent, not zero', () {
    test('an empty record reports null and not 0%', () {
      // A new player has answered nothing. `0%` is a claim about them that is
      // false — it says they got everything wrong. Absent is the only honest
      // answer, and it is what lets a screen draw nothing at all.
      final LocalStats stats = LocalStats.of(const <AnsweredItem>[]);

      expect(stats.answered, 0);
      expect(stats.accuracy, isNull);
      expect(stats.accuracyPercent, isNull);
      expect(stats.meanTime, isNull);
    });

    test('one wrong answer is 0% — which is a different fact', () {
      // The control for the test above: zero *is* reportable once somebody has
      // answered. A policy that returned null here would hide a real figure.
      final LocalStats stats = LocalStats.of(<AnsweredItem>[_wrong()]);

      expect(stats.answered, 1);
      expect(stats.accuracy, 0);
      expect(stats.accuracyPercent, 0);
    });
  });

  group('what the figures are', () {
    test('accuracy is the fraction of answers that were right', () {
      final LocalStats stats = LocalStats.of(<AnsweredItem>[
        _right(),
        _right(),
        _right(),
        _wrong(),
      ]);

      expect(stats.answered, 4);
      expect(stats.correct, 3);
      expect(stats.accuracy, 0.75);
      expect(stats.accuracyPercent, 75);
    });

    test('the whole percent is rounded, not truncated', () {
      // 7 of 9 is 77.7…, and a screen printing `77%` is a fifth of a point
      // meaner than the truth. Rounding is a decision, so it is made here
      // rather than at whichever call site formats it.
      final LocalStats stats = LocalStats.of(<AnsweredItem>[
        for (int at = 0; at < 7; at++) _right(),
        for (int at = 0; at < 2; at++) _wrong(),
      ]);

      expect(stats.accuracyPercent, 78);
    });

    test('mean time counts every answer, right or wrong', () {
      // How long an item takes me, not how long a *win* takes me. Averaging
      // the wins alone makes a bad sitting look fast, which is the opposite of
      // what the figure is for.
      final LocalStats stats = LocalStats.of(<AnsweredItem>[
        _right(4000),
        _wrong(10000),
      ]);

      expect(stats.meanTime, const Duration(milliseconds: 7000));
    });

    test('the mean keeps the milliseconds it was given', () {
      // 3 answers over 10001 ms is 3333⅔ ms. Truncating to seconds here would
      // make `6,8 s` unreachable however the screen formats it.
      final LocalStats stats = LocalStats.of(<AnsweredItem>[
        _right(3000),
        _right(3000),
        _right(4001),
      ]);

      expect(stats.meanTime, const Duration(milliseconds: 3333));
    });
  });

  group('the record is a window and not a lifetime', () {
    test('it keeps the most recent answersKept and drops the oldest', () {
      List<AnsweredItem> record = _many(answersKept);
      record = recordedWith(record, _wrong(99999));

      expect(record, hasLength(answersKept));
      // The newest is at the end and the oldest is gone.
      expect(record.last, _wrong(99999));
      expect(record.first, _right(1));
    });

    test('below the ceiling it simply appends', () {
      final List<AnsweredItem> record =
          recordedWith(<AnsweredItem>[_right(1)], _wrong(2));

      expect(record, <AnsweredItem>[_right(1), _wrong(2)]);
    });

    test('it never mutates what it was handed', () {
      // The store reads, records and writes; a policy that edited the list in
      // place would make the read and the write the same object.
      final List<AnsweredItem> before = <AnsweredItem>[_right(1)];
      recordedWith(before, _wrong(2));

      expect(before, hasLength(1));
    });

    test('recording past the ceiling, one answer at a time, never grows it', () {
      // The ceiling has to hold under the way it is actually reached — one
      // `record` call per answer, for as long as the app is installed — and not
      // only when a long list is handed over at once.
      List<AnsweredItem> record = const <AnsweredItem>[];
      for (int at = 0; at < answersKept + 50; at++) {
        record = recordedWith(record, _right(at));
      }

      expect(record, hasLength(answersKept));
      expect(record.first, _right(50));
      expect(record.last, _right(answersKept + 49));
    });
  });

  group('a stored answer survives a round trip', () {
    test('both verdicts, and the elapsed time to the millisecond', () {
      for (final AnsweredItem answer in <AnsweredItem>[_right(4200), _wrong(7)]) {
        expect(AnsweredItem.fromJson(answer.toJson()), answer);
      }
    });

    test('an unknown verdict is refused rather than counted as wrong', () {
      // A row this build cannot read is a row it must not score. Guessing
      // `wrong` would invent a mistake the player never made.
      expect(
        () => AnsweredItem.fromJson(<String, Object?>{
          'verdict': 'skipped',
          'elapsedMs': 10,
        }),
        throwsFormatException,
      );
    });

    test('a row missing its elapsed time is refused', () {
      expect(
        () => AnsweredItem.fromJson(<String, Object?>{'verdict': 'correct'}),
        throwsFormatException,
      );
    });
  });
}
