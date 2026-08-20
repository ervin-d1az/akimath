/// Every glyph the app names.
///
/// **A name is data; drawing one is an adapter's job.** The two used to live in
/// the same file, and the pure-boundary gate caught it the moment `Verdict`
/// reached for a glyph name: `design/widgets/spec/verdict.dart` →
/// `design/icons/brand_icon.dart` → `package:flutter/widgets.dart`. A pure type
/// cannot name a glyph if naming one means importing Flutter.
///
/// So the enum lives here, importing nothing, and `BrandIcon` renders it.
library;

enum BrandGlyph {
  backspace,
  submit,
  check,
  alert,
  close,
  back,

  /// The chevron on a card that opens something. **Not an arrow between two
  /// numbers** — see [mapsTo].
  forward,

  /// "becomes", between an input and an output.
  ///
  /// **A separate glyph because `forward` reads as a comparison.** The stand-in
  /// for `forward` is `›`, and `2 › 4` set between two numerals is
  /// indistinguishable from `2 > 4` — a false statement, printed by a maths
  /// app, in the one place a player is being asked to work out a rule.
  mapsTo,
  pause,
  undo,
  hint,
  pencil,
  gear,
  flame,
  wifiOff,
  padlock,

  /// The four bottom-bar marks.
  ///
  /// **Transcribed, which retires a named fork.** They were hand-drawn in
  /// `nav_glyph_spec.dart` because the bar needed marks and the design digests
  /// could not be opened; its own doc comment said so and a counter held the
  /// exception to three. The digests opened, the real `0 0 26 26` paths are in
  /// hand, and drawing a fourth by eye when the data exists would be the
  /// mistake that file apologises for.
  navHome,
  navSkills,
  navProgress,
  navProfile,
}
