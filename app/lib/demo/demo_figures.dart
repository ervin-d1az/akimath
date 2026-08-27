import 'package:meta/meta.dart';

import '../design/widgets/spec/mastery_level.dart';

/// Figures the product cannot compute yet, for the demo.
///
/// **PURE, and deliberately quarantined.** Every number here is invented. They
/// exist so the screens the design draws can be shown before the systems behind
/// them are built — rating is F4, and no rating runs in Dart at all.
///
/// **One file, so deleting them is one commit and not a hunt.** Nothing here
/// may be read by a policy that decides anything; it is display-only, and the
/// day a real figure arrives its caller stops reading this and the constant
/// goes.
///
/// **Four of them went that way.** `4.1 Perfil` used to print `RATING 1 248`,
/// `+ 36 esta semana`, `78 % ACIERTOS` and `6,8 s PROMEDIO` **beside a real
/// `0 RETOS` and `RACHA 0`** — invented figures contradicting real ones on the
/// same screen. Accuracy and mean time now come from the record
/// `features/stats/` keeps, `RETOS` was already the series cursor's, and the
/// two rating figures are drawn by nothing: `GET /me/standing` answers a rating
/// per skill rather than one number, and `HistoryEntry.ratingDelta` is a real
/// figure now but a *session's* movement — null for a session that spanned two
/// skills and for one that only calibrated — and never a week's.
/// The constants went with the callers, which is what this file is for.
///
/// Values are taken from the design documents so the screens match what was
/// drawn, rather than from anyone's imagination.
abstract final class DemoFigures {
  /// `0.5 Calibración` and `1.3 Guardar tu avance` each draw `1 248`.
  ///
  /// **Named for its readers, because `4.1` stopped being one.** Rating never
  /// runs in Dart, and the server's own answer is a rating *per skill* — so a
  /// single number is invented on the onboarding screens whether or not a
  /// player has ever synced. They are the last two readers; when a rating can
  /// be stated, this goes the way the profile's four did.
  static const int rating = 1248;

  /// `2.5` draws `+12 RATING`.
  ///
  /// **What a sitting was worth**, which was never the same fact as what a week
  /// was — `4.1`'s `+ 36 esta semana` was the other one, and a screen reading
  /// the wrong one would have been wrong in a way nobody would notice. That one
  /// is deleted; this one is not, because `2.5` still draws it.
  ///
  /// It has no source and is not merely waiting for one. Rating never runs in
  /// Dart, and the server's per-session `ratingDelta` in `GET /me/history` is a
  /// real movement now but the wrong one to reach for here: it is read back
  /// from a session the server already holds, and `2.5` draws the instant a
  /// series ends on a device that played it offline. `GET /me/history` is
  /// asked by the profile route and by nobody else. Even after a sync the
  /// answer can be nothing — a session that spanned two skills, or one that
  /// only calibrated, reports null — and `GET /me/standing` answers a standing
  /// per skill and never a move.
  static const int seriesRatingDelta = 12;

  /// `2.5`'s `QUÉ MEJORÓ` bars.
  ///
  /// Nothing tracks mastery per skill. `attempts.skill_id` is a `smallint` the
  /// device never sees, the local record `features/stats/` keeps carries no
  /// skill, and `GET /me/history` reports a session at a time. So both the
  /// names and both the numbers are invented, together.
  static const List<DemoSkillBar> seriesSkills = <DemoSkillBar>[
    DemoSkillBar(skill: 'Fracciones', percent: 68, before: 62),
    DemoSkillBar(skill: 'Multiplicar', percent: 96, before: 94),
  ];

  /// `2.5`'s `QUÉ SIGUE · UNA SOLA COSA`.
  ///
  /// A recommendation needs something that decides what to practise next, and
  /// there is no such thing — `GET /items/next` is the endpoint that would, and
  /// it answers 501.
  static const String seriesNext = 'Tres series numéricas mañana';

  /// The line under [seriesNext].
  static const String seriesNextNote =
      'Es lo único pendiente. Nada más se recomienda hoy.';

  /// Whether the invented figures are drawn at all.
  ///
  /// **The one switch.** A build that flips this to false shows only what the
  /// product can prove, which is what shipping looks like.
  static const bool enabled = true;
}

/// One invented mastery bar on `2.5`.
///
/// It carries a [MasteryLevel] rather than a colour for the same reason
/// `BaselineMeter` takes one: with no hue to pass, an invented figure cannot
/// invent a meaning for it too.
@immutable
class DemoSkillBar {
  const DemoSkillBar({
    required this.skill,
    required this.percent,
    required this.before,
  });

  /// es-MX, because it is drawn.
  final String skill;

  /// Where the bar fills to, as a whole percent.
  final int percent;

  /// Where the ink marker sits — where the player supposedly started.
  final int before;

  /// `available` is the design's pink and `mastered` its green, at the
  /// threshold the two bars it draws sit either side of.
  MasteryLevel get level =>
      percent >= 90 ? MasteryLevel.mastered : MasteryLevel.available;
}
