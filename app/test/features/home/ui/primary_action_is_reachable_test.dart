import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:akimath_app/design/widgets/brand_button.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/shell/policy/visible_tabs.dart';
import 'package:akimath_app/features/shell/ui/app_shell.dart';
import 'package:akimath_app/features/shell/ui/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../design/screen_registry.dart';

/// The thing the screen is asking for is on the screen before anything moves.
///
/// **The gap this closes.** `screen_overflow_test.dart` pumps the same home at
/// the same four viewports and cannot see this: the bands scroll, so a widget
/// pushed past the fold overflows nothing and the gate stays green. The first
/// playthrough against a deployed server found it on a 402×874 device
/// (`docs/qa/2026-09-02-first-production-playthrough.md`, finding 5) — the home
/// opened with no visible way to start the series it was asking about, and a
/// swipe was needed to find `Empezar la serie`.
///
/// **Measured, not asserted about the widget tree.** `findsOneWidget` is true
/// of a button a mile below the fold, because a `SingleChildScrollView` lays
/// its child out at full height and simply paints the part that fits. So this
/// reads the rectangle the button actually occupies and compares it against the
/// rectangle the hardware leaves the app, the way `touch_target_test.dart`
/// measures a press rather than trusting a `SizedBox`.
///
/// **Pack length is a variable, never five.** How many puzzle cards the home
/// draws is whatever the pack carries — `puzzleMenu` decides, and it answers
/// five today. A layout that is correct only for today's pack is the defect
/// this file is named after, one content edit later, so every case below runs
/// at three lengths and one of them is longer than anything shipped.
void main() {
  group('the harness', () {
    testWidgets('sees an action that sits below the fold',
        (WidgetTester tester) async {
      // The control. Without it every sweep below passes for a measurement that
      // silently reads the wrong box, which is how a gate looks green for a
      // year (TEST-1).
      await _pump(
        tester,
        screen: const _ActionAtTheBottomOfATallScroll(),
        viewport: ScreenViewport.notchedPhone,
      );

      expect(_actionIsOnScreen(tester, ScreenViewport.notchedPhone), isFalse);
    });

    testWidgets('and reports an action that does not scroll away',
        (WidgetTester tester) async {
      await _pump(
        tester,
        screen: const _ActionBelowATallScroll(),
        viewport: ScreenViewport.notchedPhone,
      );

      expect(_actionIsOnScreen(tester, ScreenViewport.notchedPhone), isTrue);
    });

    testWidgets('the hardware in the way reaches the measurement',
        (WidgetTester tester) async {
      // The second control, and the one `touch_target_test.dart` had to add
      // later: without `padding` on the `MediaQuery` the two `con muescas`
      // entries are flat rectangles and this gate cannot see an action hidden
      // under the home indicator. 874 less the 34 the hardware takes is 840, so
      // an action whose top is at 850 is off the usable screen and on the raw
      // one.
      await _pump(
        tester,
        screen: const _ActionUnderTheHomeIndicator(),
        viewport: ScreenViewport.notchedPhone,
      );

      expect(_actionIsOnScreen(tester, ScreenViewport.notchedPhone), isFalse);
    });
  });

  group('the home offers a visible way to start', () {
    for (final ScreenViewport viewport in ScreenViewport.values) {
      for (final int puzzles in _packLengths) {
        testWidgets(
            '`Empezar la serie` is on screen at ${viewport.label} with '
            '$puzzles ${puzzles == 1 ? 'puzzle' : 'puzzles'}',
            (WidgetTester tester) async {
          await _pump(
            tester,
            screen: _home(puzzles: puzzles),
            viewport: viewport,
          );

          expect(
            _actionIsOnScreen(tester, viewport),
            isTrue,
            reason: 'the home opened at ${viewport.label} carrying $puzzles '
                'puzzle cards and `$_action` was at '
                '${_actionRect(tester)}, outside the '
                '${_usableRect(viewport)} the hardware leaves — so a player '
                'has to scroll to find the only thing the screen is asking '
                'them to do.',
          );
        });
      }
    }

    testWidgets('and it stays where it is when the bands are scrolled',
        (WidgetTester tester) async {
      // The other half of the claim. An action that happens to be on screen at
      // rest but rides the scroll is one a player loses the moment they look at
      // the puzzles — which is the same defect reached from the other side.
      await _pump(
        tester,
        screen: _home(puzzles: _longerThanAnythingShipped),
        viewport: ScreenViewport.notchedPhone,
      );
      final Rect atRest = _actionRect(tester);

      await tester.drag(find.byType(SingleChildScrollView), _aFirmSwipeUp);
      await tester.pumpAndSettle();

      expect(_actionRect(tester), atRest);
      expect(_actionIsOnScreen(tester, ScreenViewport.notchedPhone), isTrue);
    });
  });
}

/// What the primary action reads.
const String _action = 'Empezar la serie';

/// The pack lengths every case runs at.
///
/// Zero because a pack may carry no puzzle at all and the section is then
/// absent; five because that is what ships today; and one longer than anything
/// shipped, because the section grew from one card to five without this screen
/// being re-measured and there is no rule that says it stops at five.
const List<int> _packLengths = <int>[0, 5, _longerThanAnythingShipped];

const int _longerThanAnythingShipped = 12;

/// Far enough to reach the end of the tallest band stack.
const Offset _aFirmSwipeUp = Offset(0, -600);

/// Rounding on a rectangle read back off the render tree.
const double _tolerance = 0.01;

/// The home as the shell builds it, with [puzzles] cards in the section.
Widget _home({required int puzzles}) {
  return AppShell(
    // **The bar the app actually draws**, which `screen_registry.dart` does not
    // pass — the registry's entry is `AppShell(child: HomeScreen(…))` with no
    // `navBar`, so the home is measured there with the whole height the shell
    // never gives it. Three roots exist today, so `visibleTabs` returns three
    // and the bar is 72 tall plus its own padding and the bottom inset. Leaving
    // it out here would hand the screen room a player does not have.
    navBar: (List<AppTab> tabs) => NavBar(
      tabs: tabs,
      current: AppTab.home,
      onSelect: (AppTab tab) {},
    ),
    child: HomeScreen(
      preview: _preview,
      streakDays: 7,
      weekMarks: const <bool>[true, true, false, true, true, true, true],
      todaysFamilies: const <String>[
        'Cuentas',
        'Series',
        'Cuadros',
        'Parejas',
        'Máquina',
      ],
      puzzles: <PuzzleOption>[
        for (int i = 0; i < puzzles; i++)
          PuzzleOption(label: 'Rompecabezas ${i + 1}', onOpen: () {}),
      ],
      onStart: () {},
    ),
  );
}

const Item _preview = Item(
  id: 'preview',
  stimulus: ArithmeticStimulus(<PromptToken>[
    PromptToken.fraction(numerator: '3', denominator: '4'),
    PromptToken.operator('+'),
    PromptToken.fraction(numerator: '2', denominator: '4'),
    PromptToken.operator('='),
  ]),
  answer: PlainAnswer('5/4'),
  ladderStep: 3,
);

Future<void> _pump(
  WidgetTester tester, {
  required Widget screen,
  required ScreenViewport viewport,
}) async {
  tester.view
    ..physicalSize = viewport.physicalSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AkiMathTheme.build(),
      // Applied below `MaterialApp` for the reason `screen_overflow_test.dart`
      // records: `WidgetsApp` builds its own `MediaQuery` from the view, so a
      // wrapper above it is overridden and every screen silently passes at 1.0
      // with no hardware in the way.
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(viewport.textScale),
            padding: viewport.padding,
            viewPadding: viewport.padding,
          ),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The rectangle the primary action occupies on the pumped screen.
Rect _actionRect(WidgetTester tester) {
  final RenderBox box = tester.renderObject<RenderBox>(
    find.widgetWithText(BrandButton, _action),
  );
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The rectangle the hardware leaves the app.
Rect _usableRect(ScreenViewport viewport) => Rect.fromLTRB(
      viewport.padding.left,
      viewport.padding.top,
      viewport.physicalSize.width - viewport.padding.right,
      viewport.physicalSize.height - viewport.padding.bottom,
    );

/// Whether the whole action is inside the room the hardware leaves.
///
/// The whole of it, not its top edge: half a button under the home indicator is
/// a control a player can see and cannot reliably press.
bool _actionIsOnScreen(WidgetTester tester, ScreenViewport viewport) {
  final Rect action = _actionRect(tester);
  final Rect usable = _usableRect(viewport);
  return action.top >= usable.top - _tolerance &&
      action.bottom <= usable.bottom + _tolerance &&
      action.left >= usable.left - _tolerance &&
      action.right <= usable.right + _tolerance;
}

/// A screen whose action is the last child of a scroll view taller than the
/// viewport — the shape the home had until 2026-09-02.
class _ActionAtTheBottomOfATallScroll extends StatelessWidget {
  const _ActionAtTheBottomOfATallScroll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 1200),
              BrandButton.primary(label: _action, onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same bands, with the action outside the scroll view.
class _ActionBelowATallScroll extends StatelessWidget {
  const _ActionBelowATallScroll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Expanded(
              child: SingleChildScrollView(child: SizedBox(height: 1200)),
            ),
            BrandButton.primary(label: _action, onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

/// An action drawn where the hardware is, on a screen that takes no inset.
class _ActionUnderTheHomeIndicator extends StatelessWidget {
  const _ActionUnderTheHomeIndicator();

  static const double _belowTheUsableBottom = 850;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned(
            top: _belowTheUsableBottom,
            left: BrandShape.space4,
            right: BrandShape.space4,
            child: BrandButton.primary(label: _action, onPressed: () {}),
          ),
        ],
      ),
    );
  }
}
