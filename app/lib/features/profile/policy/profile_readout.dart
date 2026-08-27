import 'package:meta/meta.dart';

import '../../../design/math/spec/es_mx_number.dart';
import '../../states/policy/account_state.dart';

/// What `4.1 Perfil` prints, decided before anything is drawn.
///
/// **PURE** — figures in, strings out. No widget, no clock, no storage.
///
/// **Nothing invented reaches it any more.** Every figure the caller fills in
/// is now the device's own: the days and the run from `DayLog`, the count from
/// the series cursor, and accuracy and mean time from the record
/// `features/stats/` keeps of what was actually answered. The screen used to
/// print `RATING 1 248` and `78 % ACIERTOS` beside a real `0 RETOS` — invented
/// figures contradicting real ones on the same screen.
///
/// **The rating slot stays and stays empty**, which is a different statement
/// from the slot not existing. `4.1` draws a rating and `GET /me/standing`
/// answers one **per skill**; there is no single number on the wire, and this
/// client cannot even name a skill (`skillId` is an integer and `skillName()`
/// lives server-side in `@akimath/core`). Until somebody decides what one
/// number means over a list of Glicko ratings, the honest figure is none —
/// `api/standing.dart` refuses to do arithmetic over them for the same reason.
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
    this.averageTime,
  });

  /// Distinct days recorded on this device.
  final int daysPractised;

  /// Days in a row, from `streakLength`.
  final int streakDays;

  /// Items served across every session, from the persisted series cursor.
  final int challenges;

  /// Null, and null from every caller there is.
  ///
  /// **The data exists and the number does not.** F4 landed and
  /// `GET /me/standing` reads `user_skills` truthfully, but it answers a rating
  /// **per skill** — and a player who has never synced has none at all, which
  /// is the ordinary state rather than a failure. Averaging six Glicko ratings
  /// is not a rating; it is a figure nobody could explain. The slot is kept
  /// because the design draws one and the day the product says what the single
  /// number means, this is the one line that changes.
  final int? rating;

  /// How much the rating moved this week. Null when there is no rating, and
  /// null on its own when there is one and nobody can say how it moved.
  ///
  /// Nothing can say it today. `HistoryEntry.ratingDelta` is a real figure
  /// since F4, but it is *one session's* movement on *one skill's* scale:
  /// adding a week of them together adds independent scales, and the two kinds
  /// that report null — a session that spanned two skills, a session that only
  /// calibrated — would silently drop out of the sum rather than be counted as
  /// nothing. `+ 36 esta semana` still has no source at all.
  final int? ratingThisWeek;

  /// A whole percent, or null over no answers at all.
  ///
  /// **Real, from `LocalStats.accuracyPercent`.** Null means the player has
  /// answered nothing, and it stays absent rather than becoming `0 %` — a new
  /// player is not 0 % accurate, and a screen that says so teaches them they
  /// are already failing.
  final int? accuracyPercent;

  /// How long an answer takes, or null over no answers at all.
  ///
  /// **A [Duration] rather than a number of tenths**, because it arrives as one
  /// from `LocalStats.meanTime` and the rounding to the tenth the screen prints
  /// is a decision — so it is made once, here in the pure layer, by
  /// [profileTiles] rather than by whichever caller happened to divide.
  final Duration? averageTime;
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
  final Duration? mean = figures.averageTime;

  return <ProfileTile>[
    ProfileTile(value: EsMxNumber.integer(figures.challenges), label: 'RETOS'),
    if (accuracy != null)
      ProfileTile(value: EsMxNumber.percent(accuracy), label: 'ACIERTOS'),
    if (mean != null)
      ProfileTile(
        // One tenth of a second, rounded rather than truncated: the record
        // stores milliseconds, and 6 950 ms is `7,0 s`. Cutting it to `6,9 s`
        // would print every player a twentieth of a second faster than they
        // were.
        value: EsMxNumber.seconds(mean.inMilliseconds / 1000, places: 1),
        label: 'PROMEDIO',
      ),
  ];
}

/// What the sign-in door on `4.1` says.
///
/// **Two labels for one act, and the second is a recovery.** Over a signed-out
/// profile the door stands beside *Crear cuenta* and reads as the alternative
/// to it. Over a session the server has refused it stands under the player's
/// own address, where *Ya tengo cuenta* would be answering a question nobody
/// asked — and the words it uses instead are the ones `4.1`'s own caption for
/// that state already uses: *"Tu sesión caducó. Vuelve a entrar."*
String signInDoorLabel(AccountState state) =>
    state == AccountState.rejected ? 'Volver a entrar' : 'Ya tengo cuenta';
