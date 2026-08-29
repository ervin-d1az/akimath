import 'package:meta/meta.dart';

/// The largest text scale any screen in this app has been shown to survive.
///
/// `screen_overflow_test.dart` pumps every registered screen at 1.0 and at this
/// number and at nothing above, so a fifth step of 1.5 would be a size the app
/// has never been proven to fit. The ceiling moves when that gate's viewport
/// list moves, and not before.
const double largestProvenTextScale = 1.3;

/// The four text sizes `4.5` offers, drawn as four A's of climbing size.
enum TextSizeStep {
  compact(1.0),
  regular(1.1),
  large(1.2),
  largest(largestProvenTextScale);

  const TextSizeStep(this.scale);

  /// What a `textScaler` would be set to. Nothing reads it yet — applying it
  /// means the app's root `MediaQuery`, which is a decision above this screen.
  final double scale;
}

/// The step at [index], or null when the stored index names none.
TextSizeStep? textSizeStepAt(int index) =>
    index < 0 || index >= TextSizeStep.values.length
        ? null
        : TextSizeStep.values[index];

/// What `Accesibilidad` holds.
///
/// **Three values, and the design's fourth control is deliberately not one.**
/// *Modo daltonismo* is drawn as a switch whose own note says the mode *"no
/// cambia el diseño: solo lo hace obvio"* — the outline-and-glyph encoding is
/// always on (BRD-1, design D6), so a switch there has nothing to move. The
/// screen states that and draws the pair instead, which is DR-P2 applied to a
/// control rather than to a row.
@immutable
class AccessibilitySettings {
  const AccessibilitySettings({
    required this.textSize,
    required this.reduceMotion,
    required this.highContrast,
  });

  /// The state `4.5` is drawn in.
  static const AccessibilitySettings defaults = AccessibilitySettings(
    textSize: TextSizeStep.regular,
    reduceMotion: true,
    highContrast: false,
  );

  final TextSizeStep textSize;

  /// *Reducir movimiento* — Aki stops bouncing and the tail holds still.
  final bool reduceMotion;

  /// *Alto contraste*.
  final bool highContrast;

  AccessibilitySettings copyWith({
    TextSizeStep? textSize,
    bool? reduceMotion,
    bool? highContrast,
  }) {
    return AccessibilitySettings(
      textSize: textSize ?? this.textSize,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      highContrast: highContrast ?? this.highContrast,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AccessibilitySettings &&
      other.textSize == textSize &&
      other.reduceMotion == reduceMotion &&
      other.highContrast == highContrast;

  @override
  int get hashCode => Object.hash(textSize, reduceMotion, highContrast);
}

/// What the screen says under the three controls.
const String accessibilityNotYetAppliedNotice =
    'Guardamos tu elección. Todavía no cambia cómo se ve la app.';

/// Why there is no switch on the colour-blind card.
const String verdictEncodingAlwaysOnNotice =
    'Acierto y error nunca se distinguen solo por color: cada uno trae su '
    'forma y su ícono. Siempre está así, no hay nada que prender.';
