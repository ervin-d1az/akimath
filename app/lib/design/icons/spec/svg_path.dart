/// The `d` attribute of an SVG path, turned into geometry.
///
/// **PURE** — a string in, a `Path` out. `dart:ui` only, which the pure
/// boundary allows and `aki_spec.dart` already relies on for `Offset`, `Radius`
/// and `Rect`.
///
/// **Why a parser rather than hand-written `Path` calls.** The icon change's
/// own rule is that path data is transcribed *verbatim* from the design and
/// never redrawn by eye — an icon drawn from memory is a fork of the design
/// that nobody knows exists. Keeping the `d` string as the stored form is the
/// only way that rule can be checked by reading: the spec file and the design
/// document hold the same characters. Hand-translating twenty-one paths into
/// `lineTo`/`cubicTo` calls would be twenty-one chances to transcribe a curve
/// slightly wrong, and every one of them would render plausibly.
///
/// It supports exactly the commands the transcribed glyphs use — `M L H V C S
/// A Z` in both cases — and **throws on anything else**. A quiet skip would
/// draw two thirds of a glyph on a screen; a `FormatException` fails the spec's
/// own test.
library;

import 'dart:ui';

/// The geometry of [d], in the coordinate space its `viewBox` declares.
///
/// Throws [FormatException] on a command this does not support, on a path that
/// does not open with a move, and on a command missing arguments.
Path parseSvgPath(String d) {
  final _Scanner scanner = _Scanner(d);
  final Path path = Path();

  Offset current = Offset.zero;
  Offset subpathStart = Offset.zero;
  // The previous cubic's second control point, for `S`. Null when the last
  // command was not a cubic, which is the case SVG says uses the current point.
  Offset? lastCubicControl;
  String? command;
  bool opened = false;

  while (true) {
    final String? letter = scanner.commandOrNull();
    if (letter != null) {
      command = letter;
    } else if (scanner.atEnd) {
      break;
    } else if (!scanner.hasNumber) {
      // **Not a break.** An unrecognised letter used to end the walk quietly,
      // so `M0 0Q5 5 10 0` returned the move and dropped the curve — a glyph
      // two thirds drawn, on a screen, with a green suite. It is a typo in a
      // transcription and it fails here.
      throw FormatException('unsupported path command "${scanner.peek}"');
    } else if (command == null) {
      throw const FormatException('a path must begin with a move');
    } else if (command == 'M') {
      // **An implicit repeat after a move is a line, not another move.** The
      // SVG rule, and `pencil` would otherwise draw nothing.
      command = 'L';
    } else if (command == 'm') {
      command = 'l';
    }

    final bool relative = command == command.toLowerCase();
    final Offset origin = relative ? current : Offset.zero;

    switch (command.toUpperCase()) {
      case 'M':
        if (!opened && relative) {
          throw const FormatException('a path must begin with an absolute move');
        }
        current = origin + scanner.point();
        subpathStart = current;
        path.moveTo(current.dx, current.dy);
        opened = true;
        lastCubicControl = null;
      case 'L':
        _needOpen(opened);
        current = origin + scanner.point();
        path.lineTo(current.dx, current.dy);
        lastCubicControl = null;
      case 'H':
        _needOpen(opened);
        current = Offset(origin.dx + scanner.number(), current.dy);
        path.lineTo(current.dx, current.dy);
        lastCubicControl = null;
      case 'V':
        _needOpen(opened);
        current = Offset(current.dx, origin.dy + scanner.number());
        path.lineTo(current.dx, current.dy);
        lastCubicControl = null;
      case 'C':
        _needOpen(opened);
        final Offset c1 = origin + scanner.point();
        final Offset c2 = origin + scanner.point();
        current = origin + scanner.point();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
        lastCubicControl = c2;
      case 'S':
        _needOpen(opened);
        // **The reflection, and the one mistake that stays invisible.** An `S`
        // that used the current point as its first control draws a curve — a
        // different, smooth, entirely plausible one. `navProfile`'s second hump
        // is exactly this command.
        final Offset previous = lastCubicControl ?? current;
        final Offset c1 = current * 2 - previous;
        final Offset c2 = origin + scanner.point();
        current = origin + scanner.point();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
        lastCubicControl = c2;
      case 'A':
        _needOpen(opened);
        final double rx = scanner.number();
        final double ry = scanner.number();
        final double rotation = scanner.number();
        // **Flags are single characters.** `a6 6 0 0 1-12 0` packs the sweep
        // flag against a negative number with no separator, and a tokenizer
        // reading a full number here consumes `1-12`.
        final bool largeArc = scanner.flag();
        final bool clockwise = scanner.flag();
        current = origin + scanner.point();
        path.arcToPoint(
          current,
          radius: Radius.elliptical(rx, ry),
          // Both SVG's `x-axis-rotation` and Flutter's are in degrees, so
          // this passes straight through. Nothing transcribed is non-zero.
          rotation: rotation,
          largeArc: largeArc,
          clockwise: clockwise,
        );
        lastCubicControl = null;
      case 'Z':
        _needOpen(opened);
        path.close();
        current = subpathStart;
        lastCubicControl = null;
      default:
        throw FormatException('unsupported path command "$command"');
    }
  }

  if (!opened) {
    throw const FormatException('a path with no move draws nothing');
  }
  return path;
}

void _needOpen(bool opened) {
  if (!opened) {
    throw const FormatException('a path must begin with a move');
  }
}

/// Reads commands, numbers and arc flags out of a `d` string.
class _Scanner {
  _Scanner(this._source);

  final String _source;
  int _at = 0;

  static const int _zero = 0x30;
  static const int _nine = 0x39;

  void _skipSeparators() {
    while (_at < _source.length) {
      final int code = _source.codeUnitAt(_at);
      // Whitespace and commas, which SVG treats identically.
      if (code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D || code == 0x2C) {
        _at++;
      } else {
        break;
      }
    }
  }

  /// The next command letter, or null if the next token is a number.
  String? commandOrNull() {
    _skipSeparators();
    if (_at >= _source.length) {
      return null;
    }
    final String char = _source[_at];
    if ('MmLlHhVvCcSsAaZz'.contains(char)) {
      _at++;
      return char;
    }
    return null;
  }

  bool get atEnd {
    _skipSeparators();
    return _at >= _source.length;
  }

  /// The character the walk is stuck on, for the message.
  String get peek => _at < _source.length ? _source[_at] : '';

  bool get hasNumber {
    _skipSeparators();
    if (_at >= _source.length) {
      return false;
    }
    final int code = _source.codeUnitAt(_at);
    return (code >= _zero && code <= _nine) ||
        code == 0x2D || // -
        code == 0x2B || // +
        code == 0x2E; //  .
  }

  double number() {
    _skipSeparators();
    final int start = _at;
    if (_at < _source.length &&
        (_source[_at] == '-' || _source[_at] == '+')) {
      _at++;
    }
    while (_at < _source.length) {
      final int code = _source.codeUnitAt(_at);
      if ((code >= _zero && code <= _nine) || code == 0x2E) {
        _at++;
      } else if (code == 0x65 || code == 0x45) {
        // An exponent, and its own sign.
        _at++;
        if (_at < _source.length &&
            (_source[_at] == '-' || _source[_at] == '+')) {
          _at++;
        }
      } else {
        break;
      }
    }
    if (_at == start) {
      throw FormatException('expected a number at $start in "$_source"');
    }
    final double? value = double.tryParse(_source.substring(start, _at));
    if (value == null) {
      throw FormatException('"${_source.substring(start, _at)}" is not a number');
    }
    return value;
  }

  Offset point() => Offset(number(), number());

  /// One character, `0` or `1`.
  bool flag() {
    _skipSeparators();
    if (_at >= _source.length) {
      throw const FormatException('expected an arc flag');
    }
    final String char = _source[_at];
    if (char != '0' && char != '1') {
      throw FormatException('"$char" is not an arc flag');
    }
    _at++;
    return char == '1';
  }
}
