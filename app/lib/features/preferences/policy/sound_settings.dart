import 'package:meta/meta.dart';

/// The five volume steps `4.6` draws as a rising row of bars.
///
/// **No silent step.** Silence is what *Sonido de teclas* and *Sonido al
/// acertar* are for; a zeroth bar would be a second way to say the same thing,
/// and the two could then disagree about whether the app is quiet.
enum VolumeStep {
  one,
  two,
  three,
  four,
  five;

  /// The step's place in the row, counting from one — which is what the bars
  /// show and what the store keeps.
  int get level => index + 1;
}

/// The step at [level], or null when nothing is at that level.
VolumeStep? volumeStepAtLevel(int level) {
  for (final VolumeStep step in VolumeStep.values) {
    if (step.level == level) {
      return step;
    }
  }
  return null;
}

/// What `Sonido y vibración` holds.
///
/// **PURE.** Nothing plays any of it: there is no audio engine in
/// `pubspec.yaml`, and the keypad does not ask for a haptic. Both are DEP-1
/// and wiring decisions above this screen, so the choice is recorded and the
/// screen says so.
@immutable
class SoundSettings {
  const SoundSettings({
    required this.volume,
    required this.keyPresses,
    required this.correctAnswer,
    required this.vibration,
  });

  /// The state `4.6` is drawn in: three bars of five filled, the two sounds on,
  /// the vibration off.
  static const SoundSettings defaults = SoundSettings(
    volume: VolumeStep.three,
    keyPresses: true,
    correctAnswer: true,
    vibration: false,
  );

  final VolumeStep volume;

  /// *Sonido de teclas* — a dry, short tap.
  final bool keyPresses;

  /// *Sonido al acertar*. There is no counterpart for a wrong answer, and that
  /// is the design's decision rather than an omission — see
  /// [nothingSoundsOnAWrongAnswerNotice].
  final bool correctAnswer;

  /// *Vibración* — on press and on submit.
  final bool vibration;

  SoundSettings copyWith({
    VolumeStep? volume,
    bool? keyPresses,
    bool? correctAnswer,
    bool? vibration,
  }) {
    return SoundSettings(
      volume: volume ?? this.volume,
      keyPresses: keyPresses ?? this.keyPresses,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      vibration: vibration ?? this.vibration,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoundSettings &&
      other.volume == volume &&
      other.keyPresses == keyPresses &&
      other.correctAnswer == correctAnswer &&
      other.vibration == vibration;

  @override
  int get hashCode => Object.hash(volume, keyPresses, correctAnswer, vibration);
}

/// The design's own footer, kept verbatim because it is a product rule rather
/// than a caption: a wrong answer is never announced with a noise, so there is
/// no switch for one.
const String nothingSoundsOnAWrongAnswerNotice =
    'Nada suena al fallar. El error no se anuncia con ruido.';

/// What the screen says under the controls.
const String soundNotYetPlayedNotice =
    'Todavía no suena nada. Guardamos tu elección para cuando suene.';
