import 'package:akimath_app/design/widgets/detail_header.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/spec/verdict_copy.dart';
import 'package:akimath_app/design/widgets/verdict_ring.dart';
import 'package:akimath_app/features/preferences/data/settings_store.dart';
import 'package:akimath_app/features/preferences/policy/accessibility_settings.dart';
import 'package:akimath_app/features/preferences/ui/accessibility_screen.dart';
import 'package:akimath_app/features/preferences/ui/brand_switch.dart';
import 'package:akimath_app/features/preferences/ui/settings_choice_row.dart';
import 'package:akimath_app/features/preferences/ui/settings_toggle_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SettingsStore<AccessibilitySettings>> pump(
  WidgetTester tester, {
  AccessibilitySettings initial = AccessibilitySettings.defaults,
  VoidCallback? onBack,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final SettingsStore<AccessibilitySettings> store =
      InMemorySettingsStore<AccessibilitySettings>(initial);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AccessibilityScreen(onBack: onBack ?? () {}, store: store),
    ),
  ));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('Accesibilidad', () {
    testWidgets('has the header the design gives it, and a way back',
        (WidgetTester tester) async {
      int backs = 0;
      await pump(tester, onBack: () => backs++);

      expect(find.byType(DetailHeader), findsOneWidget);
      expect(find.text('ACCESIBILIDAD'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('the text size is one chip per step, previewed at its own size',
        (WidgetTester tester) async {
      await pump(tester);

      expect(find.text('TAMAÑO DE TEXTO'), findsOneWidget);

      final SettingsChoiceRow row =
          tester.widget(find.byType(SettingsChoiceRow));
      expect(row.options, hasLength(TextSizeStep.values.length));
      // The chip *is* the preview: four A's at climbing sizes, which is the
      // one thing a size chooser can show before it is applied.
      final List<double?> sizes = row.options
          .map((SettingsChoiceOption option) => option.labelSize)
          .toList();
      for (int i = 1; i < sizes.length; i++) {
        expect(sizes[i], greaterThan(sizes[i - 1]!), reason: 'chip $i');
      }
    });

    testWidgets('choosing a size records it', (WidgetTester tester) async {
      final SettingsStore<AccessibilitySettings> store = await pump(tester);
      expect((await store.read()).textSize, TextSizeStep.regular);

      final SettingsChoiceRow row =
          tester.widget(find.byType(SettingsChoiceRow));
      row.onSelected(TextSizeStep.largest.index);
      await tester.pumpAndSettle();

      expect((await store.read()).textSize, TextSizeStep.largest);
    });

    testWidgets('two switches, with the note the design gives the first',
        (WidgetTester tester) async {
      await pump(tester);

      expect(find.text('Reducir movimiento'), findsOneWidget);
      expect(
          find.text('Aki deja de rebotar y la cola no se mueve'), findsOneWidget);
      expect(find.text('Alto contraste'), findsOneWidget);

      final int rows = tester
          .widgetList<SettingsToggleRow>(find.byType(SettingsToggleRow))
          .length;
      expect(rows, greaterThan(0), reason: 'toggle rows -> $rows');
      expect(rows, AccessibilityScreen.toggleCount);
    });

    testWidgets('a switch records what it was moved to',
        (WidgetTester tester) async {
      final SettingsStore<AccessibilitySettings> store = await pump(tester);
      expect((await store.read()).highContrast, isFalse);

      await tester.tap(find.text('Alto contraste'));
      await tester.pumpAndSettle();

      expect((await store.read()).highContrast, isTrue);
    });

    testWidgets('it opens at what was stored, not at the defaults',
        (WidgetTester tester) async {
      await pump(
        tester,
        initial: AccessibilitySettings.defaults.copyWith(reduceMotion: false),
      );

      final Iterable<SettingsToggleRow> rows =
          tester.widgetList<SettingsToggleRow>(find.byType(SettingsToggleRow));
      expect(
        rows
            .firstWhere(
                (SettingsToggleRow row) => row.label == 'Reducir movimiento')
            .isOn,
        isFalse,
      );
    });

    testWidgets('it says plainly that nothing changes yet',
        (WidgetTester tester) async {
      await pump(tester);

      expect(find.text(accessibilityNotYetAppliedNotice), findsOneWidget);
    });
  });

  group('4.5 the colour-blind card', () {
    testWidgets('draws no switch, because the encoding cannot be turned off',
        (WidgetTester tester) async {
      // BRD-1 and design D6: the outline and the glyph are always on. The
      // design draws a switch that is on and can never move; DR-P2 says a
      // control that cannot act is worse than none, so the card says so in
      // words instead. Two switches on this screen, not three.
      await pump(tester);

      expect(find.text('Modo daltonismo'), findsOneWidget);
      expect(find.text(verdictEncodingAlwaysOnNotice), findsOneWidget);
      expect(
        tester.widgetList<BrandSwitch>(find.byType(BrandSwitch)),
        hasLength(AccessibilityScreen.toggleCount),
      );
    });

    testWidgets('shows the two marks together, named the way the app names them',
        (WidgetTester tester) async {
      // Legible as a *difference*, which one mark at a time never is -- and the
      // words are `verdict_copy`'s, so the card cannot teach a term no screen
      // shows.
      await pump(tester);

      expect(find.byType(VerdictRing), findsNWidgets(2));
      for (final Verdict verdict in Verdict.values) {
        expect(find.text(verdictHeadline(verdict)), findsOneWidget);
        expect(find.text(verdictMarkDescription(verdict)), findsOneWidget);
      }
    });
  });
}
