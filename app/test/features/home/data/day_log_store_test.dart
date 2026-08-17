import 'package:akimath_app/features/home/data/day_log_store.dart';
import 'package:akimath_app/features/home/policy/day_log.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime day(int y, int m, int d) => DateTime(y, m, d);

void main() {
  group('the in-memory store', () {
    test('starts empty', () async {
      expect((await InMemoryDayLogStore().read()).days, isEmpty);
    });

    test('remembers what it recorded', () async {
      final DayLogStore store = InMemoryDayLogStore();
      await store.record(day(2026, 8, 15));
      await store.record(day(2026, 8, 16));

      expect((await store.read()).days, <DateTime>[
        day(2026, 8, 15),
        day(2026, 8, 16),
      ]);
    });

    test('recording twice in a day records one day', () async {
      final DayLogStore store = InMemoryDayLogStore();
      await store.record(DateTime(2026, 8, 16, 8));
      await store.record(DateTime(2026, 8, 16, 20));

      expect((await store.read()).days, hasLength(1));
    });

    test('record returns the log it just wrote', () async {
      final DayLogStore store = InMemoryDayLogStore();
      final DayLog after = await store.record(day(2026, 8, 16));

      expect(after.days, (await store.read()).days);
    });

    test('it can be seeded, which is how a test stands in for a launch', () async {
      final DayLogStore store = InMemoryDayLogStore(
        DayLog.empty.recording(day(2026, 8, 14)).recording(day(2026, 8, 15)),
      );

      expect((await store.read()).days, hasLength(2));
    });
  });

  group('the seam', () {
    test('a persistent store would satisfy the same interface', () async {
      // The whole point of the seam: swapping the implementation is a
      // constructor argument, not a change to anything that uses it.
      final List<DayLogStore> stores = <DayLogStore>[
        InMemoryDayLogStore(),
        InMemoryDayLogStore(DayLog.empty.recording(day(2026, 8, 1))),
      ];

      for (final DayLogStore store in stores) {
        await store.record(day(2026, 8, 16));
        expect((await store.read()).days, contains(day(2026, 8, 16)));
      }
    });
  });
}
