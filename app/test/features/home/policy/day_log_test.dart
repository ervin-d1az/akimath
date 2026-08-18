import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime day(int y, int m, int d) => DateTime(y, m, d);

void main() {
  group('a day log records days, not moments', () {
    test('two attempts on one day are one entry', () {
      final DayLog log = DayLog.empty
          .recording(DateTime(2026, 8, 16, 9))
          .recording(DateTime(2026, 8, 16, 21));

      expect(log.days, <DateTime>[day(2026, 8, 16)]);
    });

    test('recording is a value operation', () {
      const DayLog start = DayLog.empty;
      final DayLog after = start.recording(day(2026, 8, 16));

      expect(start.days, isEmpty);
      expect(after.days, hasLength(1));
    });

    test('days come back in order, oldest first', () {
      final DayLog log = DayLog.empty
          .recording(day(2026, 8, 16))
          .recording(day(2026, 8, 14))
          .recording(day(2026, 8, 15));

      expect(log.days, <DateTime>[
        day(2026, 8, 14),
        day(2026, 8, 15),
        day(2026, 8, 16),
      ]);
    });
  });

  group('the log does not grow forever', () {
    test('days older than the window are dropped on record', () {
      // A log kept for a year is a year of a child's activity sitting on the
      // device for a figure that only needs the current run. Retention is a
      // privacy decision as much as a storage one.
      DayLog log = DayLog.empty;
      for (int i = 0; i < 400; i++) {
        log = log.recording(day(2026, 1, 1).add(Duration(days: i)));
      }

      expect(log.days.length, lessThanOrEqualTo(DayLog.retainedDays));
    });

    test('pruning keeps the most recent days, not the oldest', () {
      DayLog log = DayLog.empty;
      for (int i = 0; i < DayLog.retainedDays + 10; i++) {
        log = log.recording(day(2026, 1, 1).add(Duration(days: i)));
      }

      final DateTime newest =
          day(2026, 1, 1).add(Duration(days: DayLog.retainedDays + 9));
      expect(log.days.last, newest);
    });

    test('a streak longer than the window is still counted to the window', () {
      // Stated so the limit is read as a limit rather than found as a bug: a
      // streak cannot be reported longer than the log retains.
      expect(DayLog.retainedDays, greaterThanOrEqualTo(60));
    });
  });

  group('a log survives a round trip', () {
    test('encode then decode gives the same days', () {
      final DayLog log = DayLog.empty
          .recording(day(2026, 8, 14))
          .recording(day(2026, 8, 16));

      expect(DayLog.decode(log.encode()).days, log.days);
    });

    test('an empty log round-trips', () {
      expect(DayLog.decode(DayLog.empty.encode()).days, isEmpty);
    });

    test('unreadable text decodes to an empty log rather than throwing', () {
      // Storage is the one input nobody reviews. A corrupt file must cost the
      // streak, never the launch.
      for (final String junk in <String>['', 'not a log', '2026-13-45', '{}']) {
        expect(DayLog.decode(junk).days, isEmpty, reason: 'on "$junk"');
      }
    });

    test('a partially unreadable log keeps the days it can read', () {
      expect(
        DayLog.decode('2026-08-14,rubbish,2026-08-16').days,
        <DateTime>[day(2026, 8, 14), day(2026, 8, 16)],
      );
    });

    test('the encoding carries a date and never a time', () {
      // The log is a privacy surface: what time of day a child plays is not
      // something this needs, so it is not something it stores.
      final String encoded =
          DayLog.empty.recording(DateTime(2026, 8, 16, 21, 47)).encode();

      expect(encoded, '2026-08-16');
      expect(encoded, isNot(contains(':')));
    });
  });
}
