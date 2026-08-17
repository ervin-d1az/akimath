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
