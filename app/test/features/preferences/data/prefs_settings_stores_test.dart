import 'package:akimath_app/features/preferences/data/preference_values.dart';
import 'package:akimath_app/features/preferences/data/prefs_settings_stores.dart';
import 'package:akimath_app/features/preferences/data/settings_store.dart';
import 'package:akimath_app/features/preferences/policy/accessibility_settings.dart';
import 'package:akimath_app/features/preferences/policy/notification_settings.dart';
import 'package:akimath_app/features/preferences/policy/sound_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A backend whose every operation throws.
///
/// The same shape `series_cursor_store_test.dart` uses: a store that cannot
/// reach storage at all must still answer, because a settings screen that
/// throws on open is worse than one that shows the defaults.
base class _BrokenBackend extends SharedPreferencesAsyncPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _brokenStorageTests();
  _unregisteredPluginTests();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('4.4 notifications survive a relaunch', () {
    test('a fresh install reads the defaults', () async {
      expect(
        await const PrefsNotificationSettingsStore().read(),
        NotificationSettings.defaults,
      );
    });

    test('what one store writes, another reads', () async {
      // Two instances over one backend is what a relaunch looks like from here.
      const NotificationSettings chosen = NotificationSettings(
        dailyReminder: false,
        reminderTime: ReminderTime.morning,
        streakAtRisk: false,
        newPuzzle: true,
      );
      await const PrefsNotificationSettingsStore().write(chosen);

      expect(await const PrefsNotificationSettingsStore().read(), chosen);
    });

    test('an unreadable hour falls back to the default hour, not to null',
        () async {
      await SharedPreferencesAsync()
          .setString(PrefsNotificationSettingsStore.reminderTimeKey, '03:00');

      expect(
        (await const PrefsNotificationSettingsStore().read()).reminderTime,
        NotificationSettings.defaults.reminderTime,
      );
    });

    test('a wrongly-typed key costs the setting, never the screen', () async {
      await SharedPreferencesAsync()
          .setString(PrefsNotificationSettingsStore.dailyReminderKey, 'sí');

      expect(
        (await const PrefsNotificationSettingsStore().read()).dailyReminder,
        NotificationSettings.defaults.dailyReminder,
      );
    });
  });

  group('4.5 accessibility survives a relaunch', () {
    test('a fresh install reads the defaults', () async {
      expect(
        await const PrefsAccessibilitySettingsStore().read(),
        AccessibilitySettings.defaults,
      );
    });

    test('what one store writes, another reads', () async {
      const AccessibilitySettings chosen = AccessibilitySettings(
        textSize: TextSizeStep.largest,
        reduceMotion: false,
        highContrast: true,
      );
      await const PrefsAccessibilitySettingsStore().write(chosen);

      expect(await const PrefsAccessibilitySettingsStore().read(), chosen);
    });

    test('a text size outside the four steps falls back to the default',
        () async {
      await SharedPreferencesAsync()
          .setInt(PrefsAccessibilitySettingsStore.textSizeKey, 9);

      expect(
        (await const PrefsAccessibilitySettingsStore().read()).textSize,
        AccessibilitySettings.defaults.textSize,
      );
    });
  });

  group('4.6 sound survives a relaunch', () {
    test('a fresh install reads the defaults', () async {
      expect(
        await const PrefsSoundSettingsStore().read(),
        SoundSettings.defaults,
      );
    });

    test('what one store writes, another reads', () async {
      const SoundSettings chosen = SoundSettings(
        volume: VolumeStep.five,
        keyPresses: false,
        correctAnswer: false,
        vibration: true,
      );
      await const PrefsSoundSettingsStore().write(chosen);

      expect(await const PrefsSoundSettingsStore().read(), chosen);
    });

    test('a volume outside the five steps falls back to the default', () async {
      await SharedPreferencesAsync()
          .setInt(PrefsSoundSettingsStore.volumeKey, 42);

      expect(
        (await const PrefsSoundSettingsStore().read()).volume,
        SoundSettings.defaults.volume,
      );
    });
  });

  group('every key says what it holds, and no two share one', () {
    test('the keys are distinct and namespaced', () {
      // A shared key would make two screens overwrite each other, which no
      // round-trip test above could see: each one passes on its own.
      const List<String> keys = <String>[
        PrefsNotificationSettingsStore.dailyReminderKey,
        PrefsNotificationSettingsStore.reminderTimeKey,
        PrefsNotificationSettingsStore.streakAtRiskKey,
        PrefsNotificationSettingsStore.newPuzzleKey,
        PrefsAccessibilitySettingsStore.textSizeKey,
        PrefsAccessibilitySettingsStore.reduceMotionKey,
        PrefsAccessibilitySettingsStore.highContrastKey,
        PrefsSoundSettingsStore.volumeKey,
        PrefsSoundSettingsStore.keyPressesKey,
        PrefsSoundSettingsStore.correctAnswerKey,
        PrefsSoundSettingsStore.vibrationKey,
      ];

      expect(keys.toSet(), hasLength(keys.length));
      for (final String key in keys) {
        expect(key, startsWith('akimath.'), reason: key);
        expect(key, endsWith('.v1'), reason: key);
      }
    });

    test('one screen writing does not disturb another', () async {
      await const PrefsSoundSettingsStore()
          .write(SoundSettings.defaults.copyWith(vibration: true));

      expect(
        await const PrefsNotificationSettingsStore().read(),
        NotificationSettings.defaults,
      );
      expect(
        await const PrefsAccessibilitySettingsStore().read(),
        AccessibilitySettings.defaults,
      );
    });
  });

  group('the in-memory store is the seam a widget test hands in', () {
    test('it starts at what it was given and keeps what it was written',
        () async {
      final SettingsStore<SoundSettings> store =
          InMemorySettingsStore<SoundSettings>(SoundSettings.defaults);

      expect(await store.read(), SoundSettings.defaults);

      const SoundSettings louder = SoundSettings(
        volume: VolumeStep.five,
        keyPresses: true,
        correctAnswer: true,
        vibration: false,
      );
      await store.write(louder);
      expect(await store.read(), louder);
    });
  });
}

void _unregisteredPluginTests() {
  group('a plugin that never registered costs the setting, never the screen',
      () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance = null;
    });

    test('every read still answers with its defaults', () async {
      // **`SharedPreferencesAsync()` throws from its own constructor here**,
      // not from the call — so a handle resolved as an argument puts the throw
      // outside the catch and a settings screen dies on open instead of
      // showing the defaults it promised. That is not hypothetical: this app
      // has already shipped a build whose plugin did not link, because
      // CocoaPods was missing.
      expect(
        await const PrefsNotificationSettingsStore().read(),
        NotificationSettings.defaults,
      );
      expect(
        await const PrefsAccessibilitySettingsStore().read(),
        AccessibilitySettings.defaults,
      );
      expect(
        await const PrefsSoundSettingsStore().read(),
        SoundSettings.defaults,
      );
    });

    test('a write that has nowhere to go does not throw at the caller',
        () async {
      await expectLater(
        const PrefsNotificationSettingsStore()
            .write(NotificationSettings.defaults),
        completes,
      );
    });
  });
}

void _brokenStorageTests() {
  group('storage that fails outright costs the setting, never the screen', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance = _BrokenBackend();
    });

    test('every read answers with its defaults', () async {
      expect(
        await const PrefsNotificationSettingsStore().read(),
        NotificationSettings.defaults,
      );
      expect(
        await const PrefsAccessibilitySettingsStore().read(),
        AccessibilitySettings.defaults,
      );
      expect(
        await const PrefsSoundSettingsStore().read(),
        SoundSettings.defaults,
      );
    });

    test('a write that cannot land does not throw at the caller', () async {
      await expectLater(
        const PrefsSoundSettingsStore()
            .write(SoundSettings.defaults.copyWith(vibration: true)),
        completes,
      );
    });

    test('the raw adapter reports a failed read as absent', () async {
      const PreferenceValues values = PreferenceValues();

      expect(await values.boolAt('akimath.nothing.v1'), isNull);
      expect(await values.intAt('akimath.nothing.v1'), isNull);
      expect(await values.stringAt('akimath.nothing.v1'), isNull);
    });
  });
}
