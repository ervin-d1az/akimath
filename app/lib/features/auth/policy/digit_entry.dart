/// Accumulating typed digits, for the two screens that take them.
///
/// **PURE.** Both the verification code and the birth date are a fixed-length
/// run of digits typed on the same 3×4 pad (D14), and the rules — a full buffer
/// ignores further presses, a backspace on an empty one does nothing — are the
/// same in both places. Written once so the two cannot disagree.
abstract final class DigitEntry {
  /// The buffer with `digit` appended, or unchanged if it is already full.
  ///
  /// A full buffer *ignoring* the press rather than rolling over is deliberate:
  /// on a code screen a silent rotation means the digits on screen are no
  /// longer the ones typed.
  static String push(String current, String digit, {required int max}) =>
      current.length >= max ? current : '$current$digit';

  /// The buffer with its last digit removed, or unchanged if it is empty.
  static String pop(String current) =>
      current.isEmpty ? current : current.substring(0, current.length - 1);

  /// A `ddmmyyyy` run as a date, or null if it is short or not a real day.
  ///
  /// Null rather than an exception: an incomplete date is the ordinary state of
  /// a field being typed into, not an error to report.
  static DateTime? dateFrom(String ddmmyyyy) {
    if (ddmmyyyy.length != 8) {
      return null;
    }
    final int day = int.parse(ddmmyyyy.substring(0, 2));
    final int month = int.parse(ddmmyyyy.substring(2, 4));
    final int year = int.parse(ddmmyyyy.substring(4, 8));
    if (month < 1 || month > 12 || day < 1) {
      return null;
    }
    final DateTime candidate = DateTime.utc(year, month, day);
    // `DateTime.utc(2026, 2, 30)` rolls forward to 2 March rather than failing,
    // so the only way to know the day was real is to read it back.
    if (candidate.day != day || candidate.month != month || candidate.year != year) {
      return null;
    }
    return candidate;
  }

  /// `ddmmyyyy` shown as `DD / MM / AAAA`, with the untyped part as placeholder.
  static String maskedDate(String typed) {
    String at(int from, int to, String placeholder) {
      final String slice = typed.length <= from
          ? ''
          : typed.substring(from, typed.length < to ? typed.length : to);
      return slice.padRight(to - from, placeholder);
    }

    return '${at(0, 2, 'D')} / ${at(2, 4, 'M')} / ${at(4, 8, 'A')}';
  }
}
