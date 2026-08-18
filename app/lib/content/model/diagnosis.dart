import 'package:meta/meta.dart';

/// What `04 Error` has to say about a particular wrong answer.
///
/// **PURE** — copy and nothing else. Which diagnosis applies is
/// `features/round/policy/diagnose.dart`'s; this is what it returns.
///
/// The es-MX is the player's; the misconception id it was filed under is the
/// pack's map key rather than a field here, so the id is read by construction
/// instead of carried unused.
@immutable
class Diagnosis {
  const Diagnosis({required this.steps, required this.explain});

  /// One to four short lines, in the order a player should try them.
  final List<String> steps;

  /// The same advice as a paragraph.
  ///
  /// **Carried and not shown** (design D4). `content/misconceptions.json`
  /// already holds it and copying the map is free; omitting it means
  /// re-authoring when a parent-facing surface arrives. Showing it as well
  /// would ask a player to read the same thing twice.
  final String explain;

  @override
  bool operator ==(Object other) =>
      other is Diagnosis &&
      other.explain == explain &&
      other.steps.length == steps.length &&
      _sameLines(other.steps);

  bool _sameLines(List<String> other) {
    for (int at = 0; at < steps.length; at += 1) {
      if (other[at] != steps[at]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(explain, Object.hashAll(steps));

  @override
  String toString() => 'Diagnosis(${steps.length} steps)';
}
