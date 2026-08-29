import 'package:akimath_app/features/preferences/policy/sound_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('4.6 the volume is a closed set of steps', () {
    test('five, because the design draws five bars', () {
      expect(VolumeStep.values, hasLength(5));
    });

    test('the steps are numbered from one, and there is no silent step', () {
      // Silence is `Sonido de teclas` and `Sonido al acertar`, which are their
      // own switches. A zero step would be a second way to say the same thing
      // and the two could disagree.
      expect(
        VolumeStep.values.map((VolumeStep step) => step.level).toList(),
        <int>[1, 2, 3, 4, 5],
      );
    });

    test('a level round-trips to its step, and an unknown one does not', () {
      for (final VolumeStep step in VolumeStep.values) {
        expect(volumeStepAtLevel(step.level), step);
      }
      expect(volumeStepAtLevel(0), isNull);
      expect(volumeStepAtLevel(6), isNull);
    });
  });

  group('SoundSettings', () {
    test('the defaults are the state the design draws', () {
      const SoundSettings drawn = SoundSettings.defaults;

      expect(drawn.volume, VolumeStep.three);
      expect(drawn.keyPresses, isTrue);
      expect(drawn.correctAnswer, isTrue);
      expect(drawn.vibration, isFalse);
    });

    test('nothing sounds on a wrong answer, and it is not a setting', () {
      // The design's own footer: *"Nada suena al fallar. El error no se anuncia
      // con ruido."* A switch for it would make that a preference, which is the
      // opposite of what the line says.
      expect(
        nothingSoundsOnAWrongAnswerNotice,
        contains('Nada suena al fallar'),
      );
    });

    test('copyWith changes one field and leaves the rest', () {
      const SoundSettings before = SoundSettings.defaults;
      final SoundSettings after = before.copyWith(vibration: true);

      expect(after.vibration, isTrue);
      expect(after.volume, before.volume);
      expect(after.keyPresses, before.keyPresses);
      expect(after.correctAnswer, before.correctAnswer);
    });

    test('two values with different fields are not equal', () {
      const SoundSettings base = SoundSettings.defaults;
      expect(base.copyWith(volume: VolumeStep.one), isNot(base));
      expect(base.copyWith(keyPresses: false), isNot(base));
      expect(base.copyWith(correctAnswer: false), isNot(base));
      expect(base.copyWith(vibration: true), isNot(base));
      expect(base.copyWith(), base);
    });
  });
}
