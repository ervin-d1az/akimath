import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// Every glyph the app names.
///
/// The set comes from the design corpus's inventory, so a call site can already
/// ask for the right thing by name even though the artwork is not here yet.
enum BrandGlyph {
  backspace,
  submit,
  check,
  alert,
  close,
  back,
  forward,
  pause,
  undo,
  hint,
  pencil,
  gear,
  flame,
  wifiOff,
  padlock,
}

/// A brand glyph, at a size and a colour the caller chooses.
///
/// **The artwork is not here yet, and this file is the seam that admits it.**
/// `f0-brand-icons` calls for ~21 glyphs transcribed *verbatim* from the design
/// digests — its own design rule (D2) forbids redrawing one by eye, because an
/// icon drawn from memory is a fork of the design that nobody knows exists. The
/// digests are not reachable from this session.
///
/// So each glyph renders a **stand-in character** today. That is a deliberate,
/// visible placeholder and not an approximation of the real mark: nothing here
/// claims to be the design. When the digests arrive, `BrandIconSpec` path data
/// replaces the map below and **no call site changes** — which is the whole
/// reason the seam exists rather than screens reaching for `Text('⌫')`
/// directly.
///
/// The stroke weights the real specs carry (submit 3.2, backspace 2.6) are a
/// property of the transcribed geometry and arrive with it.
class BrandIcon extends StatelessWidget {
  const BrandIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color = BrandColors.ink,
  });

  final BrandGlyph glyph;
  final double size;
  final Color color;

  /// Placeholder faces. Replaced wholesale by transcribed path data.
  static const Map<BrandGlyph, String> _standIn = <BrandGlyph, String>{
    BrandGlyph.backspace: '⌫',
    BrandGlyph.submit: '↵',
    BrandGlyph.check: '✓',
    BrandGlyph.alert: '!',
    BrandGlyph.close: '✕',
    BrandGlyph.back: '‹',
    BrandGlyph.forward: '›',
    BrandGlyph.pause: '‖',
    BrandGlyph.undo: '↺',
    BrandGlyph.hint: '?',
    BrandGlyph.pencil: '✎',
    BrandGlyph.gear: '⚙',
    BrandGlyph.flame: '▲',
    BrandGlyph.wifiOff: '⌁',
    BrandGlyph.padlock: '⚿',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          _standIn[glyph]!,
          textScaler: TextScaler.noScaling,
          style: BrandText.numeral(size * 0.8).copyWith(color: color),
        ),
      ),
    );
  }
}
