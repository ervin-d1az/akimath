import 'package:akimath_app/design/widgets/detail_header.dart';
import 'package:akimath_app/features/preferences/data/settings_store.dart';
import 'package:akimath_app/features/preferences/policy/sound_settings.dart';
import 'package:akimath_app/features/preferences/ui/settings_toggle_row.dart';
import 'package:akimath_app/features/preferences/ui/sound_screen.dart';
import 'package:akimath_app/features/preferences/ui/volume_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SettingsStore<SoundSettings>> pump(
  WidgetTester tester, {
  SoundSettings initial = SoundSettings.defaults,
  VoidCallback? onBack,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final SettingsStore<SoundSettings> store =
      InMemorySettingsStore<SoundSettings>(initial);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SoundScreen(onBack: onBack ?? () {}, store: store)),
  ));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('Sonido y vibración', () {
    testWidgets('has the header the design gives it, and a way back',
        (WidgetTester tester) async {
      int backs = 0;
      await pump(tester, onBack: () => backs++);

      expect(find.byType(DetailHeader), findsOneWidget);
      expect(find.text('SONIDO Y VIBRACIÓN'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('the volume row shows the level that is set',
        (WidgetTester tester) async {
      await pump(tester);

      expect(find.text('VOLUMEN'), findsOneWidget);
      expect(
        tester.widgetList<VolumeBar>(find.byType(VolumeBar)).where(
              (VolumeBar bar) => bar.filled,
            ),
        hasLength(SoundSettings.defaults.volume.level),
      );
    });

    testWidgets('pressing a bar records that level',
        (WidgetTester tester) async {
      final SettingsStore<SoundSettings> store = await pump(tester);

      await tester.tap(find.byType(VolumeBar).first);
      await tester.pumpAndSettle();

      expect((await store.read()).volume, VolumeStep.one);
      expect(
        tester
            .widgetList<VolumeBar>(find.byType(VolumeBar))
            .where((VolumeBar bar) => bar.filled),
        hasLength(1),
      );
    });

    testWidgets('draws the three switches the design draws, with their notes',
        (WidgetTester tester) async {
      await pump(tester);

      expect(find.text('Sonido de teclas'), findsOneWidget);
      expect(find.text('Un toque seco, corto'), findsOneWidget);
      expect(find.text('Sonido al acertar'), findsOneWidget);
      expect(find.text('Vibración'), findsOneWidget);
      expect(find.text('Al presionar y al enviar'), findsOneWidget);

      final int rows = tester
          .widgetList<SettingsToggleRow>(find.byType(SettingsToggleRow))
          .length;
      expect(rows, greaterThan(0), reason: 'toggle rows -> $rows');
      expect(rows, SoundScreen.toggleCount);
    });

    testWidgets('there is no switch for a sound on a wrong answer, and the '
        'screen says why', (WidgetTester tester) async {
      // The design's own footer. A fourth switch would turn a product rule
      // into a preference, which is the opposite of what the line says.
      await pump(tester);

      expect(find.text(nothingSoundsOnAWrongAnswerNotice), findsOneWidget);
      expect(find.text('Sonido al fallar'), findsNothing);
    });

    testWidgets('a switch records what it was moved to',
        (WidgetTester tester) async {
      final SettingsStore<SoundSettings> store = await pump(tester);
      expect((await store.read()).vibration, isFalse);

      await tester.tap(find.text('Vibración'));
      await tester.pumpAndSettle();

      expect((await store.read()).vibration, isTrue);
    });

    testWidgets('it opens at what was stored, not at the defaults',
        (WidgetTester tester) async {
      await pump(
        tester,
        initial: SoundSettings.defaults.copyWith(volume: VolumeStep.five),
      );

      expect(
        tester
            .widgetList<VolumeBar>(find.byType(VolumeBar))
            .where((VolumeBar bar) => bar.filled),
        hasLength(VolumeStep.five.level),
      );
    });

    testWidgets('it says plainly that nothing sounds yet',
        (WidgetTester tester) async {
      await pump(tester);

      expect(find.text(soundNotYetPlayedNotice), findsOneWidget);
    });
  });
}
