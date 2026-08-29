import 'package:meta/meta.dart';

/// When the daily reminder would arrive.
///
/// **A closed set, because the design draws three chips and no keyboard.** A
/// free `TimeOfDay` would need a picker nobody has drawn, and it could hold a
/// value none of the three chips can display — a stored preference the screen
/// showing it would have to lie about.
enum ReminderTime {
  morning('07', '00'),
  evening('19', '30'),
  night('21', '00');

  const ReminderTime(this.hour, this.minute);

  /// The two halves, kept apart because `4.4` draws them in **two boxes**.
  /// Splitting a joined string at the screen would be parsing what nobody had
  /// to join.
  final String hour;
  final String minute;

  /// What the chip reads, and what the store keeps. Twenty-four-hour, which is
  /// how es-MX writes a time in a settings list.
  String get label => '$hour:$minute';
}

/// The member [label] names, or null when nothing does.
///
/// Null rather than a fallback: the caller decides what an unreadable stored
/// value means, and the one caller today answers with the defaults.
ReminderTime? reminderTimeNamed(String label) {
  for (final ReminderTime time in ReminderTime.values) {
    if (time.label == label) {
      return time;
    }
  }
  return null;
}

/// What `Notificaciones` holds.
///
/// **PURE** — four values and no IO. The store beside it decides where they
/// live; this decides what they are.
///
/// **Nothing sends any of these yet.** There is no notification plugin in
/// `pubspec.yaml`, and adding one is a DEP-1 decision rather than a session's.
/// So the screen records the choice and says in words that it is recorded and
/// not yet acted on — which is the honest half of DR-P2: the row is absent when
/// the *destination* does not exist, and a control that stores a real answer is
/// not the same thing as a control that does nothing.
@immutable
class NotificationSettings {
  const NotificationSettings({
    required this.dailyReminder,
    required this.reminderTime,
    required this.streakAtRisk,
    required this.newPuzzle,
  });

  /// The state `4.4` is drawn in: the two the player asked for on, the one the
  /// app pushes at them off.
  static const NotificationSettings defaults = NotificationSettings(
    dailyReminder: true,
    reminderTime: ReminderTime.evening,
    streakAtRisk: true,
    newPuzzle: false,
  );

  /// *Recordatorio diario* — one a day, nothing more.
  final bool dailyReminder;

  /// The hour that reminder would land on.
  final ReminderTime reminderTime;

  /// *Racha en riesgo* — only on a day already played through without playing.
  final bool streakAtRisk;

  /// *Puzzle nuevo* — when the day's board arrives.
  final bool newPuzzle;

  NotificationSettings copyWith({
    bool? dailyReminder,
    ReminderTime? reminderTime,
    bool? streakAtRisk,
    bool? newPuzzle,
  }) {
    return NotificationSettings(
      dailyReminder: dailyReminder ?? this.dailyReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      streakAtRisk: streakAtRisk ?? this.streakAtRisk,
      newPuzzle: newPuzzle ?? this.newPuzzle,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.dailyReminder == dailyReminder &&
      other.reminderTime == reminderTime &&
      other.streakAtRisk == streakAtRisk &&
      other.newPuzzle == newPuzzle;

  @override
  int get hashCode =>
      Object.hash(dailyReminder, reminderTime, streakAtRisk, newPuzzle);
}

/// What the screen says under the controls.
///
/// A player who turns something on and never hears from the app again would
/// otherwise conclude the app is broken. Saying it plainly costs one line.
const String notificationsNotYetSentNotice =
    'Todavía no mandamos avisos. Guardamos tu elección para cuando lleguen.';
