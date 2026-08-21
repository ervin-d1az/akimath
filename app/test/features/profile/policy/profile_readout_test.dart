import 'package:akimath_app/design/math/spec/es_mx_number.dart';
import 'package:akimath_app/features/profile/policy/profile_readout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The figures a device always has. Every test overrides only what it is about.
ProfileFigures figures({
  int daysPractised = 13,
  int streakDays = 5,
  int challenges = 312,
  int? rating,
  int? ratingThisWeek,
  int? accuracyPercent,
  int? averageTenthsOfSecond,
}) =>
    ProfileFigures(
      daysPractised: daysPractised,
      streakDays: streakDays,
      challenges: challenges,
      rating: rating,
      ratingThisWeek: ratingThisWeek,
      accuracyPercent: accuracyPercent,
      averageTenthsOfSecond: averageTenthsOfSecond,
    );

void main() {
  group('the lead card takes the best figure there is', () {
    test('a rating leads when there is one', () {
      final HeadlineCard card =
          headlineLead(figures(rating: 1248, ratingThisWeek: 36));

      expect(card.label, 'RATING');
      expect(card.value, EsMxNumber.integer(1248));
      expect(card.note, '36 esta semana');
      expect(card.sign, '+');
      expect(card.tone, NoteTone.gain);
    });

    test('the days lead when there is no rating', () {
      // The wide slot is the screen's headline, so it takes the honest figure
      // rather than a hole. This is the branch a build with the invented
      // figures switched off draws.
      final HeadlineCard card = headlineLead(figures(daysPractised: 13));

      expect(card.label, 'DÍAS');
      expect(card.value, EsMxNumber.integer(13));
      expect(card.note, 'practicando');
      expect(card.sign, isEmpty);
      expect(card.tone, NoteTone.plain);
    });

    test('a week that lost rating is not drawn as a gain', () {
      // Green means success and nothing else (BRD-1). A green minus would say
      // the opposite of what the number says.
      final HeadlineCard card =
          headlineLead(figures(rating: 1248, ratingThisWeek: -12));

      expect(card.sign, EsMxNumber.deltaParts(-12).sign);
      expect(card.tone, NoteTone.plain);
    });

    test('a week that moved nothing claims no direction', () {
      final HeadlineCard card =
          headlineLead(figures(rating: 1248, ratingThisWeek: 0));

      expect(card.sign, isEmpty);
      expect(card.tone, NoteTone.plain);
    });

    test('a rating with no week behind it draws no second line', () {
      final HeadlineCard card = headlineLead(figures(rating: 1248));

      expect(card.note, isNull);
    });
  });

  group('the run card is the filled one', () {
    test('it counts the days in a row', () {
      final HeadlineCard card = headlineRun(figures(streakDays: 13));

      expect(card.label, 'RACHA');
      expect(card.value, EsMxNumber.integer(13));
      expect(card.note, 'días seguidos');
    });

    test('one day is singular', () {
      expect(headlineRun(figures(streakDays: 1)).note, 'día seguido');
    });

    test('zero is a number, not a gap', () {
      expect(headlineRun(figures(streakDays: 0)).value, EsMxNumber.integer(0));
    });
  });

  group('the tile row holds what can be measured', () {
    test('all three when every figure has a source', () {
      final List<ProfileTile> tiles = profileTiles(figures(
        challenges: 312,
        accuracyPercent: 78,
        averageTenthsOfSecond: 68,
      ));

      expect(
        tiles.map((ProfileTile tile) => tile.label),
        <String>['RETOS', 'ACIERTOS', 'PROMEDIO'],
      );
      expect(tiles.first.value, EsMxNumber.integer(312));
      expect(tiles[1].value, EsMxNumber.percent(78));
      expect(tiles.last.value, EsMxNumber.seconds(6.8, places: 1));
    });

    test('the row never empties, because the count is this device own', () {
      // `RETOS` comes from the cursor the home advances, so it is true on a
      // phone that has never synced and the row is never a gap.
      final List<ProfileTile> tiles = profileTiles(figures());

      expect(tiles, isNotEmpty);
      expect(tiles.map((ProfileTile tile) => tile.label), <String>['RETOS']);
    });

    test('a figure with no source leaves no tile behind', () {
      final List<ProfileTile> tiles =
          profileTiles(figures(accuracyPercent: 78));

      expect(
        tiles.map((ProfileTile tile) => tile.label),
        <String>['RETOS', 'ACIERTOS'],
      );
    });
  });
}
