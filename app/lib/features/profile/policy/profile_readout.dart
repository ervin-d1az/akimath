import 'package:meta/meta.dart';

import '../../../design/math/spec/es_mx_number.dart';

/// What `4.1 Perfil` prints, decided before anything is drawn.
///
/// **PURE** — figures in, strings out. No widget, no clock, no storage.
///
/// **It exists so a figure can be swapped at one point.** Three of the numbers
/// the design draws — a rating, an accuracy and a mean time — arrive invented
/// today; the two the device does know come from `DayLog` and the series
/// cursor. Only the **rating** is invented for want of a source: it is F4 and
/// `GET /me/standing` answers 501. Accuracy and mean time have one —
/// `features/stats/` records a verdict and an elapsed time per answer — and the
/// caller filling [ProfileFigures] has not been pointed at it yet, which is
/// exactly the one line this type exists to make the whole change.
///
/// **A figure with no source is null, and a null figure is not drawn.** That is
/// the whole degradation rule: the tile row loses a tile, and the headline
/// falls back to the honest figure rather than printing a hole where a rating
/// would be.
@immutable
final class ProfileFigures {
  const ProfileFigures({
    required this.daysPractised,
    required this.streakDays,
    required this.challenges,
    this.rating,
    this.ratingThisWeek,
    this.accuracyPercent,
    this.averageTenthsOfSecond,
  });

  /// Distinct days recorded on this device.
  final int daysPractised;

  /// Days in a row, from `streakLength`.
  final int streakDays;

  /// Items served across every session, from the persisted series cursor.
  final int challenges;

  /// Null until rating exists. Rating is F4 and `GET /me/standing` answers 501.
  final int? rating;

  /// How much the rating moved this week. Null when there is no rating, and
  /// null on its own when there is one and nobody can say how it moved.
  final int? ratingThisWeek;

  /// A whole percent, or null while nothing hands one over.
  ///
  /// **Null is no longer the same statement it was.** It used to mean the
  /// device could not know; `features/stats/` knows now, and null means the
  /// caller has not asked it.
  final int? accuracyPercent;

  /// Tenths of a second, so the screen formats it with a decimal comma rather
  /// than carrying a `double` a `toString` would print with a point. Null for
  /// the same reason [accuracyPercent] is.
  final int? averageTenthsOfSecond;
}

/// The hue the sign run in front of a note takes.
///
/// Two arms rather than a boolean, because the day a loss is drawn in its own
/// colour this becomes three and every call site is a compile error (FUN-2).
enum NoteTone {
  /// Ink. What a plain unit line and a week that lost ground both get.
  plain,

  /// The success hue. `4.1` draws the weekly gain's `+` in it, and BRD-1 allows
  /// it here for the same reason it allows it anywhere: this is a success.
  gain,
}

/// One of the two cards at the top of `4.1`: a label, a figure and a line under
/// it.
///
/// The two differ in their fill — the design draws the lead white and the run
/// yellow — and the fill is the screen's, because a policy that named a colour
/// would be naming a hue instead of asking for a role (BRD-1).
@immutable
final class HeadlineCard {
  const HeadlineCard({
    required this.label,
    required this.value,
    required this.note,
    this.sign = '',
    this.tone = NoteTone.plain,
  });

  /// The eyebrow over the figure: `RATING`, `DÍAS`, `RACHA`.
  final String label;

  /// The figure, already spelt in es-MX.
  final String value;

  /// The line under the figure, or null when there is nothing true to put
  /// there.
  final String? note;

  /// The run in front of [note], empty when there is none. Separate from the
  /// note because it is set in another face and another hue, and because
  /// `EsMxNumber` hands a sign back separately so that no screen concatenates a
  /// hyphen where the brand requires U+2212.
  final String sign;

  final NoteTone tone;
}

/// One of the small tiles in the row under the headline pair.
@immutable
final class ProfileTile {
  const ProfileTile({required this.value, required this.label});

  /// The figure, already spelt in es-MX.
  final String value;

  final String label;
}

/// The wide card, and the one figure the screen leads with.
///
/// **A rating when there is one, the days practised when there is not.** The
/// slot is the headline and it is 1.3 times the width of the card beside it;
/// leaving it empty says the screen is about something it cannot show, and
/// printing a dash there is a promise with no date on it.
HeadlineCard headlineLead(ProfileFigures figures) {
  final int? rating = figures.rating;
  if (rating == null) {
    return HeadlineCard(
      label: 'DÍAS',
      value: EsMxNumber.integer(figures.daysPractised),
      note: 'practicando',
    );
  }
  return HeadlineCard(
    label: 'RATING',
    value: EsMxNumber.integer(rating),
    note: _weeklyNote(figures.ratingThisWeek),
    sign: _weeklySign(figures.ratingThisWeek),
    tone: (figures.ratingThisWeek ?? 0) > 0 ? NoteTone.gain : NoteTone.plain,
  );
}

String? _weeklyNote(int? delta) =>
    delta == null ? null : '${EsMxNumber.deltaParts(delta).digits} esta semana';

String _weeklySign(int? delta) =>
    delta == null ? '' : EsMxNumber.deltaParts(delta).sign;

/// The filled card: how many days in a row.
HeadlineCard headlineRun(ProfileFigures figures) => HeadlineCard(
      label: 'RACHA',
      value: EsMxNumber.integer(figures.streakDays),
      note: figures.streakDays == 1 ? 'día seguido' : 'días seguidos',
    );

/// The tile row, holding only the figures that have a source.
///
/// **Never empty**, because the count of challenges is the device's own: a
/// phone that has never synced still knows how many items it served. The other
/// two drop out silently, which is the point — a tile that says `—` is a gap
/// the player is invited to wonder about.
List<ProfileTile> profileTiles(ProfileFigures figures) {
  final int? accuracy = figures.accuracyPercent;
  final int? tenths = figures.averageTenthsOfSecond;

  return <ProfileTile>[
    ProfileTile(value: EsMxNumber.integer(figures.challenges), label: 'RETOS'),
    if (accuracy != null)
      ProfileTile(value: EsMxNumber.percent(accuracy), label: 'ACIERTOS'),
    if (tenths != null)
      ProfileTile(
        value: EsMxNumber.seconds(tenths / 10, places: 1),
        label: 'PROMEDIO',
      ),
  ];
}
