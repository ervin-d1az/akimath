import 'package:akimath_app/features/onboarding/data/onboarding_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the first run happens once', () {
    test('a fresh install has not completed it', () async {
      expect(await const OnboardingStore().isComplete(), isFalse);
    });

    test('completing it is remembered', () async {
      await const OnboardingStore().markComplete();
      expect(await const OnboardingStore().isComplete(), isTrue);
    });

    test('a new store over the same storage sees it', () async {
      // Two instances over one backend is what a relaunch looks like from the
      // adapter's side.
      await const OnboardingStore().markComplete();
      expect(await const OnboardingStore().isComplete(), isTrue);
    });

    test('it uses one key, named for what it holds', () async {
      await const OnboardingStore().markComplete();
      expect(
        await SharedPreferencesAsync().getKeys(),
        <String>{OnboardingStore.key},
      );
    });
  });

  group('storage that cannot be read shows the onboarding', () {
    test('an absent flag reads as not complete', () async {
      // The alternative — assume completed — skips the only screen that teaches
      // the answer format, for a player who may never have seen it. Showing it
      // twice costs seconds; skipping it costs the explanation.
      expect(await const OnboardingStore().isComplete(), isFalse);
    });

    test('a non-boolean under the key reads as not complete', () async {
      await SharedPreferencesAsync().setString(OnboardingStore.key, 'yes');
      expect(await const OnboardingStore().isComplete(), isFalse);
    });
  });

  group('what it stores', () {
    test('a boolean and nothing else', () async {
      await const OnboardingStore().markComplete();
      expect(await SharedPreferencesAsync().getBool(OnboardingStore.key), isTrue);
    });

    test('it stores no version, deliberately', () async {
      // A version whose semantics nobody has decided is a decision taken by
      // default. A key rename does the same job the day it is wanted.
      expect(OnboardingStore.key, isNot(contains('version')));
      await const OnboardingStore().markComplete();
      expect((await SharedPreferencesAsync().getKeys()), hasLength(1));
    });
  });
}
