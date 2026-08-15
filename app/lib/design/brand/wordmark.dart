import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// Which background the wordmark is sitting on.
///
/// The rule from the brand doc: "Math" is pink on light backgrounds and white
/// on the brand green. Never two accent colors at once.
enum WordmarkTone {
  /// Cream, sand, or white background.
  onLight(BrandColors.pink),

  /// The brand green.
  onBrandGreen(BrandColors.surface);

  const WordmarkTone(this.accent);

  /// The color of the "Math" half.
  final Color accent;
}

/// The AmbysMath wordmark.
///
/// One word, no apostrophe, no space. The capital M is what separates the two
/// halves. The wordmark carries no outline and no shadow — the hard shadow
/// belongs to objects with a body: cards, buttons, the icon tile.
class AmbysMathWordmark extends StatelessWidget {
  const AmbysMathWordmark({
    super.key,
    this.fontSize = 44,
    this.tone = WordmarkTone.onLight,
  }) : assert(
          fontSize >= BrandShape.minWordmarkFontSize,
          'Below 28px Darumadrop loses its rounded terminal and the mark stops '
          'reading. Use a different lockup instead of shrinking the wordmark.',
        );

  /// The cap height of the mark. Never below
  /// [BrandShape.minWordmarkFontSize].
  final double fontSize;

  final WordmarkTone tone;

  /// The first half, set in ink.
  static const String stem = 'Ambys';

  /// The second half, set in the accent.
  static const String accentedHalf = 'Math';

  /// How the mark is written, everywhere, always.
  static const String plainText = '$stem$accentedHalf';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: plainText,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: stem,
                style: BrandText.wordmark(fontSize, BrandColors.ink),
              ),
              TextSpan(
                text: accentedHalf,
                style: BrandText.wordmark(fontSize, tone.accent),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// The descriptor that sits under the wordmark.
///
/// Always Plus Jakarta with heavy tracking, never Darumadrop.
class BrandDescriptor extends StatelessWidget {
  const BrandDescriptor({
    super.key,
    this.color = BrandColors.muted,
    this.fontSize = 12,
  });

  final Color color;
  final double fontSize;

  /// The descriptor copy. User-facing, so it stays in Spanish.
  static const String text = 'RETOS MATEMÁTICOS';

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: BrandText.descriptor(size: fontSize, color: color),
    );
  }
}
