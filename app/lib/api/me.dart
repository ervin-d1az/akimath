import 'package:meta/meta.dart';

/// The band a player was routed into, as a closed union.
///
/// **An enum and not a string**, so a `switch` over it is exhaustive: a band
/// added server-side becomes a compile error here rather than falling through a
/// `default` nobody looked at. `CLAUDE.md` calls the band "the routing decision
/// that sends a player into child protections or not" — that is not a decision
/// to make with a `?? adult`.
enum AgeBand {
  under13('under_13'),
  thirteenToSeventeen('13_17'),
  adult('adult');

  const AgeBand(this.wireName);

  /// Exactly the string the frozen `Me` schema's enum carries.
  final String wireName;

  static AgeBand fromWire(String value) => AgeBand.values.firstWhere(
    (AgeBand band) => band.wireName == value,
    orElse: () => throw FormatException('not a band this contract names', value),
  );
}

/// The instants the frozen `Me.createdAt` pattern admits, and no others.
///
/// **Narrower than `DateTime.parse` on purpose.** The contract pins `date-time`
/// to a literal `Z` with optional seconds and fraction; `DateTime.parse` also
/// takes `+00:00`, a bare local time, and a space in place of the `T`. Each of
/// those round-trips to different bytes than it arrived as, which is how a
/// client and a server quietly stop agreeing about an instant.
///
/// The calendar arithmetic — 30-day months, and 29 February only in a leap
/// year — is the contract's too. Reproducing the frozen regular expression here
/// would be a second copy of it; re-deriving the same *rules* and then having
/// `test/api/contract_parity_test.dart` check both against the artifact is the
/// arrangement this repository uses everywhere else.
final RegExp _instant = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?Z$',
);

bool _isLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

const List<int> _daysInMonth = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

DateTime _readInstant(String value) {
  final RegExpMatch? match = _instant.firstMatch(value);
  if (match == null) {
    throw FormatException('not the date-time the contract pins', value);
  }

  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  if (month < 1 || month > 12) {
    throw FormatException('month out of range', value);
  }
  final int last =
      month == 2 && _isLeapYear(year) ? 29 : _daysInMonth[month - 1];
  if (day < 1 || day > last) {
    throw FormatException('day out of range for that month', value);
  }

  final int hour = int.parse(match.group(4)!);
  final int minute = int.parse(match.group(5)!);
  final int second = int.parse(match.group(6) ?? '0');
  if (hour > 23 || minute > 59 || second > 59) {
    throw FormatException('time out of range', value);
  }
  // Milliseconds only: `DateTime` on the web has no microseconds, and the
  // server emits three digits. A longer fraction is truncated rather than
  // refused, because the contract allows it and losing it changes no instant
  // this product can measure.
  final String fraction = (match.group(7) ?? '').padRight(3, '0').substring(0, 3);

  return DateTime.utc(year, month, day, hour, minute, second, int.parse(fraction));
}

T _read<T>(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  if (value is! T) {
    throw FormatException('$field is ${value.runtimeType}, not $T', json.toString());
  }
  return value;
}

/// The player behind the current session.
///
/// Immutable, with an explicit `fromJson` — ADR 0001's shape for every model in
/// `api/`. It holds no defaults: every field the frozen schema marks required
/// is required here, and a body missing one is a `FormatException` rather than
/// a `Me` with a hole in it.
@immutable
class Me {
  const Me({
    required this.playerId,
    required this.ageBand,
    required this.createdAt,
  });

  factory Me.fromJson(Map<String, Object?> json) => Me(
    playerId: _read<String>(json, 'playerId'),
    ageBand: AgeBand.fromWire(_read<String>(json, 'ageBand')),
    createdAt: _readInstant(_read<String>(json, 'createdAt')),
  );

  final String playerId;
  final AgeBand ageBand;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'playerId': playerId,
    'ageBand': ageBand.wireName,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is Me &&
      other.playerId == playerId &&
      other.ageBand == ageBand &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(playerId, ageBand, createdAt);

  @override
  String toString() => 'Me($playerId, ${ageBand.wireName}, $createdAt)';
}
