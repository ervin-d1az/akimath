/// The Dart half of the frozen answer canonicaliser.
///
/// `packages/contract` froze what a canonical answer is, in TypeScript. This is
/// the same rule in Dart, and `canon_test.dart` checks it against
/// `contract/fixtures/canon.golden.json` — **the fixture, not a copy of it**.
/// R2 is the risk that two implementations of one rule drift apart, and a
/// shared oracle is the only thing that catches it.
///
/// Pure: a string in, a result out. No clock, no network, no storage.
library;

/// How strictly a value is read.
enum CanonMode {
  /// What a player typed. Normalises: folds spaces, the fraction slash and the
  /// minus sign, and strips leading zeros.
  learner,

  /// What a system stored. Must **already** be canonical; anything that would
  /// have to be normalised is rejected rather than quietly fixed, so a
  /// malformed record cannot masquerade as a valid one.
  stored,
}

/// The outcome of canonicalising a value.
class CanonResult {
  const CanonResult.ok(this.value)
      : tag = null,
        ok = true;

  const CanonResult.rejected(this.tag)
      : value = null,
        ok = false;

  final bool ok;

  /// The canonical form, when accepted.
  final String? value;

  /// Why it was refused. The tags are the contract's, shared with TypeScript.
  final String? tag;
}

/// U+200B..U+200D, U+2060, U+FEFF — characters that occupy no width and would
/// let two visually identical answers compare unequal.
bool _isInvisible(int rune) =>
    (rune >= 0x200B && rune <= 0x200D) || rune == 0x2060 || rune == 0xFEFF;

/// Combining diacriticals. `1` followed by U+0301 looks like `1`.
bool _isCombining(int rune) =>
    (rune >= 0x0300 && rune <= 0x036F) ||
    (rune >= 0x1AB0 && rune <= 0x1AFF) ||
    (rune >= 0x20D0 && rune <= 0x20FF) ||
    (rune >= 0xFE20 && rune <= 0xFE2F);

/// A digit that is not an ASCII digit — Arabic-Indic, Devanagari, and the rest.
///
/// Rejected rather than folded: `٠` and `0` are the same number and different
/// text, and silently equating them is a decision the contract does not make.
bool _isNonAsciiDigit(int rune) {
  if (rune >= 0x30 && rune <= 0x39) {
    return false;
  }
  const List<List<int>> digitBlocks = <List<int>>[
    <int>[0x0660, 0x0669], // Arabic-Indic
    <int>[0x06F0, 0x06F9], // Extended Arabic-Indic
    <int>[0x0966, 0x096F], // Devanagari
    <int>[0x09E6, 0x09EF], // Bengali
    <int>[0x0BE6, 0x0BEF], // Tamil
    <int>[0xFF10, 0xFF19], // Fullwidth
  ];
  return digitBlocks.any((List<int> b) => rune >= b[0] && rune <= b[1]);
}

/// The character map the fixture declares: space removed, U+2044 FRACTION
/// SLASH folded to `/`, U+2212 MINUS SIGN folded to `-`.
String _fold(String value) => value
    .replaceAll(' ', '')
    .replaceAll('⁄', '/')
    .replaceAll('−', '-');

/// `-?digits` optionally over `digits`.
final RegExp _shape = RegExp(r'^-?\d+(?:/\d+)?$');

/// Removes leading zeros, keeping a single zero.
String _stripLeadingZeros(String digits) {
  final String stripped = digits.replaceFirst(RegExp(r'^0+'), '');
  return stripped.isEmpty ? '0' : stripped;
}

/// Reduces [raw] to its canonical form, or says why it cannot.
///
/// Order matters and is the contract's: the character-class refusals come
/// before the shape check, so `٠` is reported as a non-ASCII digit rather than
/// as something non-numeric.
CanonResult canonicalise(String raw, {required CanonMode mode}) {
  final CanonResult learner = _asLearner(raw);

  if (mode == CanonMode.learner || !learner.ok) {
    return learner;
  }

  // Stored values must already be what the learner form produces. Anything
  // that had to be normalised was not canonical to begin with.
  return raw == learner.value
      ? learner
      : const CanonResult.rejected('not_canonical');
}

CanonResult _asLearner(String raw) {
  final String spaceless = raw.replaceAll(' ', '');
  if (spaceless.isEmpty) {
    return const CanonResult.rejected('empty');
  }

  for (final int rune in spaceless.runes) {
    if (_isNonAsciiDigit(rune)) {
      return const CanonResult.rejected('non_ascii_digit');
    }
    if (_isInvisible(rune)) {
      return const CanonResult.rejected('invisible_character');
    }
    if (_isCombining(rune)) {
      return const CanonResult.rejected('combining_mark');
    }
  }

  final String folded = _fold(spaceless);
  if (!_shape.hasMatch(folded)) {
    return const CanonResult.rejected('non_numeric');
  }

  final bool negative = folded.startsWith('-');
  final String body = negative ? folded.substring(1) : folded;
  final List<String> parts = body.split('/');

  final String numerator = _stripLeadingZeros(parts.first);
  if (parts.length == 1) {
    // `-0` is `0`: a signed zero is a sign with nothing to sign.
    final String signed =
        negative && numerator != '0' ? '-$numerator' : numerator;
    return CanonResult.ok(signed);
  }

  final String denominator = _stripLeadingZeros(parts[1]);
  if (denominator == '0') {
    return const CanonResult.rejected('zero_denominator');
  }

  // **A fraction is never reduced.** 2/4 and 1/2 are different answers, and
  // deciding they are the same is a pedagogical call this layer does not make.
  final String value = '$numerator/$denominator';
  return CanonResult.ok(negative ? '-$value' : value);
}
