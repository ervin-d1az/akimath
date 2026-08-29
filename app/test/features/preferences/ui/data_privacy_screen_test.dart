import 'package:akimath_app/design/widgets/brand_button.dart';
import 'package:akimath_app/design/widgets/detail_header.dart';
import 'package:akimath_app/design/widgets/settings_row.dart';
import 'package:akimath_app/features/preferences/policy/data_privacy.dart';
import 'package:akimath_app/features/preferences/ui/data_privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, {VoidCallback? onBack}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: DataPrivacyScreen(onBack: onBack ?? () {})),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('Datos y privacidad', () {
    testWidgets('has the header the design gives it, and a way back',
        (WidgetTester tester) async {
      int backs = 0;
      await pump(tester, onBack: () => backs++);

      expect(find.byType(DetailHeader), findsOneWidget);
      expect(find.text('DATOS Y PRIVACIDAD'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('both cards are drawn, with the words the design gives them',
        (WidgetTester tester) async {
      await pump(tester);

      for (final DataRequest request in DataRequest.values) {
        expect(find.text(request.title), findsOneWidget, reason: request.name);
        expect(find.text(request.description), findsOneWidget,
            reason: request.name);
      }
    });

    testWidgets('neither card offers a button, and each says why',
        (WidgetTester tester) async {
      // **The design draws two.** `Pedir mi archivo` has no endpoint behind it
      // — export is not one of the nine contracted operations — and
      // `Borrar historial` has none either: `DELETE /me` erases the player and
      // everything under it, which is a different act with a different screen.
      // A button that produces nothing is exactly DR-P2's broken-looking
      // control, so the card keeps its words and loses its button.
      await pump(tester);

      expect(find.byType(BrandButton), findsNothing);
      for (final DataRequest request in DataRequest.values) {
        expect(find.text(request.unavailable), findsOneWidget,
            reason: request.name);
      }
    });

    testWidgets('there is no row to a document that does not exist',
        (WidgetTester tester) async {
      // `Aviso de privacidad` and `Términos` are rows to two documents nobody
      // has written. Absent rather than greyed out, and rather than a row that
      // opens an empty screen (DR-P2). This turns red the day either lands.
      await pump(tester);

      expect(find.byType(SettingsRow), findsNothing);
      expect(find.text('Aviso de privacidad'), findsNothing);
      expect(find.text('Términos'), findsNothing);
    });

    testWidgets('the screen reports what it drew, so it cannot go quietly empty',
        (WidgetTester tester) async {
      // PROC-10: a card list that reached zero would look like a screen with
      // nothing to say rather than a screen that lost its content.
      await pump(tester);

      expect(DataRequest.values, isNotEmpty);
      expect(DataRequest.values, hasLength(DataPrivacyScreen.cardCount));
    });
  });

  group('4.7 the copy', () {
    test('every request names what it is and what it would do', () {
      for (final DataRequest request in DataRequest.values) {
        expect(request.title, isNotEmpty, reason: request.name);
        expect(request.description, isNotEmpty, reason: request.name);
        expect(request.unavailable, contains('Todavía'), reason: request.name);
      }
    });

    test('the two are not the same card said twice', () {
      // PROC-11: a copy table whose entries were accidentally identical would
      // pass every "is not empty" check above.
      expect(
        DataRequest.values.map((DataRequest request) => request.title).toSet(),
        hasLength(DataRequest.values.length),
      );
      expect(
        DataRequest.values
            .map((DataRequest request) => request.description)
            .toSet(),
        hasLength(DataRequest.values.length),
      );
    });
  });
}
