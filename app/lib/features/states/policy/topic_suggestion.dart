import 'package:meta/meta.dart';

/// A topic `4.15` can send a player to instead.
///
/// **PURE** — a value type with no IO. It exists so the screen takes one named
/// thing rather than three loose parameters that a call site could transpose:
/// a percentage and a count are both bare ints, and `38` in the slot meant for
/// `5` would draw a plausible, wrong screen.
@immutable
class NextTopic {
  const NextTopic({
    required this.name,
    required this.percent,
    required this.readyCount,
  });

  /// As a player reads it: `Decimales`.
  final String name;

  /// How far into it they already are.
  final int percent;

  /// How much is waiting there today.
  final int readyCount;

  @override
  bool operator ==(Object other) =>
      other is NextTopic &&
      other.name == name &&
      other.percent == percent &&
      other.readyCount == readyCount;

  @override
  int get hashCode => Object.hash(name, percent, readyCount);

  @override
  String toString() => 'NextTopic($name $percent% $readyCount)';
}
