import 'package:akimath_app/features/preferences/policy/accessibility_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('4.5 the text size is a closed set with a proven ceiling', () {
    test('four steps, because the design draws four', () {
      expect(TextSizeStep.values, hasLength(4));
    });

    test('the steps climb, and none of them passes 1.3', () {
      // **The ceiling is the one the gates prove.** `screen_overflow_test`
      // pumps every registered screen at 1.0 and 1.3 and nothing above, so a
      // step of 1.5 would be a size the app has never been shown to survive.
      final List<double> scales =
          TextSizeStep.values.map((TextSizeStep step) => step.scale).toList();

      expect(scales.first, 1.0);
      expect(scales.last, largestProvenTextScale);
      for (int i = 1; i < scales.length; i++) {
        expect(scales[i], greaterThan(scales[i - 1]), reason: 'step $i');
      }
    });

    test('an index round-trips to its step, and an out-of-range one does not',
        () {
      for (final TextSizeStep step in TextSizeStep.values) {
        expect(textSizeStepAt(step.index), step);
      }
      expect(textSizeStepAt(-1), isNull);
      expect(textSizeStepAt(TextSizeStep.values.length), isNull);
    });
  });

  group('4.5 AccessibilitySettings', () {
    test('the defaults are the state the design draws', () {
      const AccessibilitySettings drawn = AccessibilitySettings.defaults;

      expect(drawn.textSize, TextSizeStep.regular);
      expect(drawn.reduceMotion, isTrue);
      expect(drawn.highContrast, isFalse);
    });

    test('copyWith changes one field and leaves the rest', () {
      const AccessibilitySettings before = AccessibilitySettings.defaults;
      final AccessibilitySettings after = before.copyWith(highContrast: true);

      expect(after.highContrast, isTrue);
      expect(after.textSize, before.textSize);
      expect(after.reduceMotion, before.reduceMotion);
    });

    test('two values with different fields are not equal', () {
      const AccessibilitySettings base = AccessibilitySettings.defaults;
      expect(base.copyWith(textSize: TextSizeStep.largest), isNot(base));
      expect(base.copyWith(reduceMotion: false), isNot(base));
      expect(base.copyWith(highContrast: true), isNot(base));
      expect(base.copyWith(), base);
    });
  });

  test('the copy says the preference is recorded and not yet applied', () {
    // Nothing reads these three yet — no screen scales its text off
    // `textSize`, nothing animates, nothing repaints darker. The screen has to
    // say that, so a player who moves a control and sees no change knows why.
    expect(accessibilityNotYetAppliedNotice, contains('Guardamos'));
  });
}
