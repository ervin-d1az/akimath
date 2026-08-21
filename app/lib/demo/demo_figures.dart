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
/// Values are taken from the design documents so the screens match what was
/// drawn, rather than from anyone's imagination.
abstract final class DemoFigures {
  /// `4.1` draws `1 248`.
  static const int rating = 1248;

  /// `4.1` draws `+ 36 esta semana`.
  static const int ratingThisWeek = 36;

  /// `4.1` draws `312 RETOS`.
  static const int challenges = 312;

  /// `4.1` draws `78% ACIERTOS`, as a whole percent.
  ///
  /// **Superseded — there is a real source now.** The belief that put this here
  /// was that the device has none, and it was wrong:
  /// `features/round/policy/grading.dart` decides every verdict locally, which
  /// is how a wrong answer draws `04 Error` with no network. What the device
  /// does not do is *send* it. `features/stats/` remembers it instead, and
  /// `LocalStats.accuracyPercent` is the same figure computed from what the
  /// player actually did — **absent rather than `0` over no answers**, which is
  /// the one thing a constant cannot be. This goes when `4.1` is wired to it.
  static const int accuracyPercent = 78;

  /// `4.1` draws `6,8 s PROMEDIO`. Tenths of a second, so the screen formats it
  /// in es-MX with a decimal comma rather than carrying a `double` that a
  /// `toString` would print with a point.
  ///
  /// **Superseded by `LocalStats.meanTime`, and that is the only source there
  /// will be.** Time on task has no wire representation in either direction:
  /// the frozen `Standing` is `{playerId, skills: […]}` with
  /// `additionalProperties: false` and `GET /me/history` carries a score and no
  /// timing, so no endpoint can ever answer this. The device measures it or
  /// nobody does.
  static const int averageTenthsOfSecond = 68;


  /// `2.5` draws `+12 RATING`.
  ///
  /// **A series delta, not [ratingThisWeek].** One is what a sitting was worth
  /// and the other is what a week was; a screen reading the wrong one would be
  /// wrong in a way nobody would notice. Rating never runs in Dart, so neither
  /// can ever become real on this side — `GET /me/standing` is where the real
  /// one will come from, and it answers 501 today.
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
