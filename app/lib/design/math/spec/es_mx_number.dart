/// Every number the player reads, formatted in one place.
///
/// The name is not `NumberFormat`. That is `intl`'s class, and `intl` is a
/// plausible future dependency in a Spanish-language app — a collision that
/// only appears the day someone adds a package is the kind this project names
/// its way out of rather than discovers.
///
/// Two conventions hold across the whole surface, and both are stated here once
/// instead of at each call site:
///
/// * **The decimal separator is a comma** and the thousands separator is
///   U+202F NARROW NO-BREAK SPACE. A plain U+0020 renders almost identically
///   and wraps: `1 180` can break into `1` / `180` inside a 48px pill at
///   `textScaler` 1.3, which the app is gated to support.
/// * **Every other space this module emits is U+202F too.** The reasoning that
///   picked it for thousands is not specific to thousands — a unit, a ratio
///   slash and a dimensions cross all sit inside a pill or tile sized to its
///   content, and any of them breaking across two lines is the same defect.
///
/// **A negative is U+2212 MINUS SIGN, never U+002D HYPHEN-MINUS.** Callers do
/// not compose one: [deltaParts] hands back the sign and the digits as separate
/// runs precisely so that no screen concatenates a hyphen by hand.
///
/// Pure by construction — no Flutter import, no clock, no locale lookup. It
/// takes numbers and returns strings.
library;

/// U+202F NARROW NO-BREAK SPACE.
const String _thinSpace = ' ';

/// U+2212 MINUS SIGN.
const String _minus = '−';

/// A signed value split into the two runs a caller renders separately.
///
/// The split exists so that a delta's sign can be styled — or omitted — without
/// any call site building the string itself, which is how a hyphen gets in.
class DeltaParts {
  const DeltaParts({required this.sign, required this.digits});

  /// `+`, [_minus], or empty when the value is zero. A `+0` is a claim about
  /// direction that a zero does not support.
  final String sign;

  /// The magnitude, grouped. Never carries the sign.
  final String digits;
}

abstract final class EsMxNumber {
  /// What a screen prints where a measurement exists but has no value yet.
  ///
  /// An em dash rather than an empty string: a blank cell and an unmeasured one
  /// look the same and mean different things.
  static const String noValue = '—';

  /// The formatters that can emit a negative.
  ///
  /// Published so the test that forbids U+002D can assert it covers all of
  /// them. A formatter added here without a matching assertion fails that test,
  /// which is the point — the list is the contract, not documentation.
  static const Set<String> negatableEntryPoints = <String>{
    'integer',
    'decimal',
    'seconds',
    'percent',
    'delta',
  };

  /// A whole number, grouped in threes.
  static String integer(int value) {
    final bool negative = value < 0;
    final String digits = _group(value.abs().toString());
    return negative ? '$_minus$digits' : digits;
  }

  /// A number with a fixed number of decimal places and a comma separator.
  static String decimal(num value, {required int places}) {
    final bool negative = value < 0;
    final String fixed = value.abs().toStringAsFixed(places);
    final List<String> parts = fixed.split('.');
    final String whole = _group(parts.first);
    final String body =
        parts.length > 1 ? '$whole,${parts[1]}' : whole;
    return negative ? '$_minus$body' : body;
  }

  /// A duration in seconds, as the verdict screens print it: `4,2 s`.
  static String seconds(num value, {required int places}) =>
      '${decimal(value, places: places)}${_thinSpace}s';

  /// A percentage. es-MX sets a space before the sign.
  static String percent(num value) =>
      '${decimal(value, places: 0)}$_thinSpace%';

  /// A wall-clock time. The hour is not padded; the minute always is.
  static String clockTime({required int hour, required int minute}) =>
      '$hour:${minute.toString().padLeft(2, '0')}';

  /// Time taken, as minutes and seconds. Reads as a stopwatch, so the minute is
  /// unpadded and the second always padded.
  static String elapsed(Duration value) {
    final int totalSeconds = value.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int remainder = totalSeconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  /// A duration rounded to one unit, for a reader who wants the magnitude and
  /// not the measurement.
  static String durationCoarse(Duration value) {
    if (value.inMinutes < 1) {
      return '${value.inSeconds}${_thinSpace}s';
    }
    return '${value.inMinutes}${_thinSpace}min';
  }

  /// A board size: `6 × 6`, with U+00D7 rather than the letter x.
  static String dimensions(int width, int height) =>
      '$width$_thinSpace×$_thinSpace$height';

  /// A counter: `3 / 9`.
  static String ratio(int completed, int total) =>
      '$completed$_thinSpace/$_thinSpace$total';

  /// A signed change, split into the runs a caller styles separately.
  static DeltaParts deltaParts(int value) {
    if (value == 0) {
      return const DeltaParts(sign: '', digits: '0');
    }
    return DeltaParts(
      sign: value < 0 ? _minus : '+',
      digits: _group(value.abs().toString()),
    );
  }

  /// Groups a run of digits in threes from the right.
  static String _group(String digits) {
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        out.write(_thinSpace);
      }
      out.write(digits[i]);
    }
    return out.toString();
  }
}
