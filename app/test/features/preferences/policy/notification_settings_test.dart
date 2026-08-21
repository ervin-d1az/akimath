import 'package:akimath_app/features/preferences/policy/notification_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('4.4 the reminder hour is a closed set', () {
    test('the three the design offers, and no free entry', () {
      // The design draws three preset chips and no keyboard. A free `TimeOfDay`
      // would be a fourth control nobody has drawn, and a stored value the
      // three chips could not display.
      expect(
        ReminderTime.values.map((ReminderTime time) => time.label).toList(),
        <String>['07:00', '19:30', '21:00'],
      );
    });

    test('a label round-trips to its member, and an unknown one does not', () {
      for (final ReminderTime time in ReminderTime.values) {
        expect(reminderTimeNamed(time.label), time);
      }
      expect(reminderTimeNamed('03:00'), isNull);
      expect(reminderTimeNamed(''), isNull);
    });
  });

  group('4.4 NotificationSettings', () {
    test('the defaults are the state the design draws', () {
      const NotificationSettings drawn = NotificationSettings.defaults;

      expect(drawn.dailyReminder, isTrue);
      expect(drawn.reminderTime, ReminderTime.evening);
      expect(drawn.streakAtRisk, isTrue);
      expect(drawn.newPuzzle, isFalse);
    });

    test('copyWith changes one field and leaves the rest', () {
      const NotificationSettings before = NotificationSettings.defaults;
      final NotificationSettings after = before.copyWith(newPuzzle: true);

      expect(after.newPuzzle, isTrue);
      expect(after.dailyReminder, before.dailyReminder);
      expect(after.reminderTime, before.reminderTime);
      expect(after.streakAtRisk, before.streakAtRisk);
    });

    test('copyWith with nothing named returns an equal value', () {
      expect(
        NotificationSettings.defaults.copyWith(),
        NotificationSettings.defaults,
      );
    });

    test('two values with different fields are not equal', () {
      // PROC-11: an equality that ignored a field would pass the test above and
      // silently make the store think a write changed nothing.
      const NotificationSettings base = NotificationSettings.defaults;
      expect(base.copyWith(dailyReminder: false), isNot(base));
      expect(base.copyWith(reminderTime: ReminderTime.morning), isNot(base));
      expect(base.copyWith(streakAtRisk: false), isNot(base));
      expect(base.copyWith(newPuzzle: true), isNot(base));
    });
  });
}
