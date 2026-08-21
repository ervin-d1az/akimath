import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/features/preferences/ui/brand_switch.dart';
import 'package:akimath_app/features/preferences/ui/settings_choice_row.dart';
import 'package:akimath_app/features/preferences/ui/settings_toggle_row.dart';
import 'package:akimath_app/features/preferences/ui/volume_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

/// Every tappable rectangle on the pumped tree.
///
/// The same measurement `touch_target_test.dart` makes, made here so a control
/// is held to 48 px in its own test rather than only once it is on a screen.
List<Size> pressSizes(WidgetTester tester) => tester
    .widgetList<GestureDetector>(find.byWidgetPredicate(
      (Widget w) => w is GestureDetector && w.onTap != null,
    ))
    .map((GestureDetector detector) =>
        tester.getSize(find.byWidget(detector).first))
    .toList();

void main() {
  group('the switch is paint, not a control', () {
    testWidgets('it draws in both states and answers no tap of its own',
        (WidgetTester tester) async {
      // **One press per row, and the switch is not it.** A 60×34 switch with
      // its own detector is a 48 px failure and the classic way a settings
      // list fails `touch_target_test`. The row owns the press; this draws.
      await pump(tester, const BrandSwitch(isOn: true));
      expect(pressSizes(tester), isEmpty);

      await pump(tester, const BrandSwitch(isOn: false));
      expect(pressSizes(tester), isEmpty);
    });

    testWidgets('the knob is on the side that says which state it is in',
        (WidgetTester tester) async {
      // Position, not only hue: the two states have to be legible to a reader
      // who cannot separate the track colours (BRD-1's reasoning, applied to a
      // control rather than to a verdict).
      await pump(tester, const BrandSwitch(isOn: true));
      final double onKnob = tester.getCenter(find.byKey(BrandSwitch.knobKey)).dx;

      await pump(tester, const BrandSwitch(isOn: false));
      final double offKnob =
          tester.getCenter(find.byKey(BrandSwitch.knobKey)).dx;

      expect(onKnob, greaterThan(offKnob));
    });
  });

  group('a toggle row', () {
    testWidgets('shows its label, its note, and clears 48 px',
        (WidgetTester tester) async {
      await pump(
        tester,
        SettingsToggleRow(
          label: 'Recordatorio diario',
          note: 'Una vez al día, nada más',
          isOn: true,
          onChanged: (bool _) {},
        ),
      );

      expect(find.text('Recordatorio diario'), findsOneWidget);
      expect(find.text('Una vez al día, nada más'), findsOneWidget);

      final List<Size> presses = pressSizes(tester);
      expect(presses, hasLength(1), reason: 'presses → ${presses.length}');
      expect(presses.single.height,
          greaterThanOrEqualTo(BrandShape.minTouchTarget));
      expect(
          presses.single.width, greaterThanOrEqualTo(BrandShape.minTouchTarget));
    });

    testWidgets('pressing anywhere on it reports the opposite of what it shows',
        (WidgetTester tester) async {
      final List<bool> reported = <bool>[];
      await pump(
        tester,
        SettingsToggleRow(
          label: 'Vibración',
          isOn: false,
          onChanged: reported.add,
        ),
      );

      await tester.tap(find.text('Vibración'));
      expect(reported, <bool>[true]);
    });

    testWidgets('a row with no note draws no second line',
        (WidgetTester tester) async {
      await pump(
        tester,
        SettingsToggleRow(
          label: 'Alto contraste',
          isOn: false,
          onChanged: (bool _) {},
        ),
      );

      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('a choice row', () {
    List<SettingsChoiceOption> hours() => const <SettingsChoiceOption>[
          SettingsChoiceOption(label: '07:00'),
          SettingsChoiceOption(label: '19:30'),
          SettingsChoiceOption(label: '21:00'),
        ];

    testWidgets('draws one press per option, each clearing 48 px',
        (WidgetTester tester) async {
      await pump(
        tester,
        SettingsChoiceRow(
          options: hours(),
          selected: 1,
          onSelected: (int _) {},
        ),
      );

      final List<Size> presses = pressSizes(tester);
      expect(presses, hasLength(3), reason: 'presses → ${presses.length}');
      for (final Size press in presses) {
        expect(press.height, greaterThanOrEqualTo(BrandShape.minTouchTarget));
        expect(press.width, greaterThanOrEqualTo(BrandShape.minTouchTarget));
      }
    });

    testWidgets('pressing an option reports its index',
        (WidgetTester tester) async {
      final List<int> chosen = <int>[];
      await pump(
        tester,
        SettingsChoiceRow(
          options: hours(),
          selected: 1,
          onSelected: chosen.add,
        ),
      );

      await tester.tap(find.text('21:00'));
      expect(chosen, <int>[2]);
    });

    testWidgets('exactly one option is filled with the highlight',
        (WidgetTester tester) async {
      await pump(
        tester,
        SettingsChoiceRow(
          options: hours(),
          selected: 1,
          onSelected: (int _) {},
        ),
      );

      final Iterable<Color?> fills = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(SettingsChoiceRow),
            matching: find.byType(Container),
          ))
          .map((Container box) => (box.decoration as BoxDecoration?)?.color);

      expect(
        fills.where((Color? fill) => fill == BrandColorRole.highlight.color),
        hasLength(1),
      );
    });
  });

  group('the volume bars', () {
    testWidgets('one press per step, each clearing 48 px',
        (WidgetTester tester) async {
      await pump(
        tester,
        SizedBox(
          width: 300,
          child: VolumeBars(level: 3, onSelected: (int _) {}),
        ),
      );

      final List<Size> presses = pressSizes(tester);
      expect(presses, hasLength(VolumeBars.steps),
          reason: 'presses → ${presses.length}');
      for (final Size press in presses) {
        expect(press.height, greaterThanOrEqualTo(BrandShape.minTouchTarget));
        expect(press.width, greaterThanOrEqualTo(BrandShape.minTouchTarget));
      }
    });

    testWidgets('the bars climb, so the row reads as a scale even unfilled',
        (WidgetTester tester) async {
      await pump(
        tester,
        SizedBox(
          width: 300,
          child: VolumeBars(level: 3, onSelected: (int _) {}),
        ),
      );

      final List<double> heights = tester
          .widgetList<VolumeBar>(find.byType(VolumeBar))
          .map((VolumeBar bar) => bar.height)
          .toList();

      expect(heights, hasLength(VolumeBars.steps));
      for (int i = 1; i < heights.length; i++) {
        expect(heights[i], greaterThan(heights[i - 1]), reason: 'bar $i');
      }
    });

    testWidgets('as many bars are filled as the level says',
        (WidgetTester tester) async {
      await pump(
        tester,
        SizedBox(
          width: 300,
          child: VolumeBars(level: 3, onSelected: (int _) {}),
        ),
      );

      final Iterable<VolumeBar> bars =
          tester.widgetList<VolumeBar>(find.byType(VolumeBar));

      expect(bars.where((VolumeBar bar) => bar.filled), hasLength(3));
      // The bar is filled with the highlight and nothing else, so a screen
      // cannot read the row as a verdict.
      final Iterable<Color?> fills = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(VolumeBar),
            matching: find.byType(Container),
          ))
          .map((Container box) => (box.decoration as BoxDecoration?)?.color);
      expect(
        fills.where((Color? fill) => fill == BrandColorRole.highlight.color),
        hasLength(3),
      );
    });

    testWidgets('pressing a bar reports its level, counting from one',
        (WidgetTester tester) async {
      final List<int> chosen = <int>[];
      await pump(
        tester,
        SizedBox(
          width: 300,
          child: VolumeBars(level: 3, onSelected: chosen.add),
        ),
      );

      await tester.tap(find.byType(VolumeBar).last);
      expect(chosen, <int>[VolumeBars.steps]);
    });
  });
}
