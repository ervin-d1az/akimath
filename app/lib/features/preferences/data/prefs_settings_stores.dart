import '../policy/accessibility_settings.dart';
import '../policy/notification_settings.dart';
import '../policy/sound_settings.dart';
import 'preference_values.dart';
import 'settings_store.dart';

/// `Notificaciones`, kept on the device.
///
/// **One key per field, not one encoded blob.** A blob would need a codec, and
/// a codec that cannot parse loses four answers to one bad character; a field
/// that cannot be read loses one and the other three still open the screen at
/// what the player chose.
///
/// Each key is named for what it holds rather than for the screen, so a later
/// reader of the device's storage can tell what it is.
class PrefsNotificationSettingsStore
    implements SettingsStore<NotificationSettings> {
  const PrefsNotificationSettingsStore({
    PreferenceValues values = const PreferenceValues(),
  }) : _values = values;

  static const String dailyReminderKey = 'akimath.notify.daily_reminder.v1';
  static const String reminderTimeKey = 'akimath.notify.reminder_time.v1';
  static const String streakAtRiskKey = 'akimath.notify.streak_at_risk.v1';
  static const String newPuzzleKey = 'akimath.notify.new_puzzle.v1';

  final PreferenceValues _values;

  @override
  Future<NotificationSettings> read() async {
    const NotificationSettings fallback = NotificationSettings.defaults;
    final String? hour = await _values.stringAt(reminderTimeKey);

    return NotificationSettings(
      dailyReminder: await _values.boolAt(dailyReminderKey) ??
          fallback.dailyReminder,
      // A stored hour naming no chip is the same as no stored hour: the screen
      // can only draw the three, so a fourth would be a selection with nothing
      // selected.
      reminderTime: (hour == null ? null : reminderTimeNamed(hour)) ??
          fallback.reminderTime,
      streakAtRisk:
          await _values.boolAt(streakAtRiskKey) ?? fallback.streakAtRisk,
      newPuzzle: await _values.boolAt(newPuzzleKey) ?? fallback.newPuzzle,
    );
  }

  @override
  Future<void> write(NotificationSettings settings) async {
    await _values.putBool(dailyReminderKey, value: settings.dailyReminder);
    await _values.putString(reminderTimeKey, settings.reminderTime.label);
    await _values.putBool(streakAtRiskKey, value: settings.streakAtRisk);
    await _values.putBool(newPuzzleKey, value: settings.newPuzzle);
  }
}

/// `Accesibilidad`, kept on the device.
class PrefsAccessibilitySettingsStore
    implements SettingsStore<AccessibilitySettings> {
  const PrefsAccessibilitySettingsStore({
    PreferenceValues values = const PreferenceValues(),
  }) : _values = values;

  static const String textSizeKey = 'akimath.a11y.text_size.v1';
  static const String reduceMotionKey = 'akimath.a11y.reduce_motion.v1';
  static const String highContrastKey = 'akimath.a11y.high_contrast.v1';

  final PreferenceValues _values;

  @override
  Future<AccessibilitySettings> read() async {
    const AccessibilitySettings fallback = AccessibilitySettings.defaults;
    final int? step = await _values.intAt(textSizeKey);

    return AccessibilitySettings(
      textSize: (step == null ? null : textSizeStepAt(step)) ??
          fallback.textSize,
      reduceMotion:
          await _values.boolAt(reduceMotionKey) ?? fallback.reduceMotion,
      highContrast:
          await _values.boolAt(highContrastKey) ?? fallback.highContrast,
    );
  }

  @override
  Future<void> write(AccessibilitySettings settings) async {
    await _values.putInt(textSizeKey, settings.textSize.index);
    await _values.putBool(reduceMotionKey, value: settings.reduceMotion);
    await _values.putBool(highContrastKey, value: settings.highContrast);
  }
}

/// `Sonido y vibración`, kept on the device.
class PrefsSoundSettingsStore implements SettingsStore<SoundSettings> {
  const PrefsSoundSettingsStore({
    PreferenceValues values = const PreferenceValues(),
  }) : _values = values;

  static const String volumeKey = 'akimath.sound.volume.v1';
  static const String keyPressesKey = 'akimath.sound.key_presses.v1';
  static const String correctAnswerKey = 'akimath.sound.correct_answer.v1';
  static const String vibrationKey = 'akimath.sound.vibration.v1';

  final PreferenceValues _values;

  @override
  Future<SoundSettings> read() async {
    const SoundSettings fallback = SoundSettings.defaults;
    final int? level = await _values.intAt(volumeKey);

    return SoundSettings(
      volume: (level == null ? null : volumeStepAtLevel(level)) ??
          fallback.volume,
      keyPresses: await _values.boolAt(keyPressesKey) ?? fallback.keyPresses,
      correctAnswer:
          await _values.boolAt(correctAnswerKey) ?? fallback.correctAnswer,
      vibration: await _values.boolAt(vibrationKey) ?? fallback.vibration,
    );
  }

  @override
  Future<void> write(SoundSettings settings) async {
    await _values.putInt(volumeKey, settings.volume.level);
    await _values.putBool(keyPressesKey, value: settings.keyPresses);
    await _values.putBool(correctAnswerKey, value: settings.correctAnswer);
    await _values.putBool(vibrationKey, value: settings.vibration);
  }
}
