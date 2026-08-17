import 'package:akimath_app/features/character_sheet/character_sheet_screen.dart';
import 'package:akimath_app/features/splash/splash_screen.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/onboarding/ui/first_item_screen.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:akimath_app/features/shell/ui/app_shell.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/round/ui/summary/series_summary_screen.dart';
import 'package:akimath_app/features/round/ui/verdict/verdict_screen.dart';
import 'package:flutter/widgets.dart';

/// A surface the design gates pump a screen at.
///
/// One entry per viewport the app promises to survive. The set is short on
/// purpose: 390×844 is the design viewport every document is drawn against, and
/// 1.3 is the text size a child's device arrives with more often than not.
enum ScreenViewport {
  designPhone('390×844', Size(390, 844), 1),
  designPhoneLargeText('390×844 · textScaler 1.3', Size(390, 844), 1.3);

  const ScreenViewport(this.label, this.physicalSize, this.textScale);

  /// How the viewport is named in a test title and in a failure.
  final String label;

  final Size physicalSize;

  final double textScale;
}

/// One screen the design gates walk.
@immutable
final class RegisteredScreen {
  const RegisteredScreen({
    required this.label,
    required this.build,
    this.excused = const <ScreenViewport, String>{},
  });

  /// The name the gates use in their test titles.
  final String label;

  /// Builds a fresh instance, so two gates pumping the same screen cannot share
  /// element state.
  final Widget Function() build;

  /// The viewports this screen is excused from, each mapped to the overflow
  /// message that earned the excuse.
  ///
  /// Nothing is excused in advance. An entry appears here only after the gate
  /// actually went red, carries the message it reported, and is deleted in the
  /// change that fixes the screen (design D-6). The gate asserts the reason is
  /// not empty, so a viewport cannot leave the required set in silence.
  final Map<ScreenViewport, String> excused;

  /// The viewports this screen must survive.
  List<ScreenViewport> get requiredViewports => ScreenViewport.values
      .where((ScreenViewport viewport) => !excused.containsKey(viewport))
      .toList();
}

/// Every screen under the design gates.
///
/// One list, read by `no_blurred_shadow_test.dart` and by
/// `screen_overflow_test.dart`, so a new screen is registered once and inherits
/// both. Two hand-maintained lists of the same ~50 screens would rot at
/// different rates (design D-5).
/// A fixed item for the gates to pump.
///
/// The screen takes its items rather than loading them, so the registry supplies
/// one — which also keeps the design gates independent of whatever the shipped
/// pack happens to contain today.
const List<Item> registryRoundItems = <Item>[
  Item(
    id: 'registry',
    stimulus: ArithmeticStimulus(<PromptToken>[
      PromptToken.fraction(numerator: '3', denominator: '4'),
      PromptToken.operator('+'),
      PromptToken.fraction(numerator: '2', denominator: '4'),
      PromptToken.operator('='),
    ]),
    expected: '5/4',
    ladderStep: 3,
  ),
];

/// A number-series item for the gates. Six terms and a three-digit one, which
/// is the widest a series in the shipped pack gets — the widest case is the one
/// worth registering, because it is the one that overflows first.
const List<Item> registrySeriesItems = <Item>[
  Item(
    id: 'registry-series',
    stimulus: NumberSeriesStimulus(
      terms: <int>[2, 6, 18, 54, 162, 486],
      unknownIndex: 4,
    ),
    expected: '162',
    ladderStep: 3,
  ),
];

final List<RegisteredScreen> registeredScreens = <RegisteredScreen>[
  RegisteredScreen(
    label: 'character sheet',
    build: () => const CharacterSheetScreen(),
  ),
  RegisteredScreen(
    label: 'splash · cream',
    build: () => const SplashScreen(),
  ),
  RegisteredScreen(
    label: 'splash · green',
    build: () => const SplashScreen(variant: SplashVariant.brandGreen),
  ),
  RegisteredScreen(
    label: 'home',
    // Inside the shell, because that is the only way it ever renders. Pumped
    // bare it has no Material ancestor and `screen_text_style_test` fails —
    // correctly: a screen registered in a shape the app never builds is a gate
    // checking something nobody ships.
    build: () => AppShell(
      child: HomeScreen(
        preview: registryRoundItems.single,
        streakDays: 7,
        onStart: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'welcome',
    // In the shell, which is how `OnboardingFlow` builds it — the screen is a
    // bare `Padding` and has no Material ancestor of its own.
    build: () => AppShell(child: WelcomeScreen(onStart: () {})),
  ),
  RegisteredScreen(
    label: 'first item',
    // Not in the shell: it composes `RoundScreen`, which brings its own
    // `Scaffold` — the same shape `OnboardingFlow` builds.
    build: () => FirstItemScreen(onFinished: () {}, onBack: () {}),
  ),
  RegisteredScreen(
    label: 'round',
    build: () => const RoundScreen(items: registryRoundItems),
  ),
  RegisteredScreen(
    label: 'round · number series',
    // The second stimulus family, registered so it inherits the shadow,
    // overflow and text-style gates the arithmetic one already has. A family
    // that draws itself but is not registered is a family whose first overflow
    // report comes from a player.
    build: () => const RoundScreen(items: registrySeriesItems),
  ),
  RegisteredScreen(
    label: 'verdict · acierto',
    build: () => VerdictScreen(
      summary: const VerdictSummary(
        verdict: Verdict.correct,
        elapsed: Duration(milliseconds: 4200),
        streakDays: 7,
      ),
      onContinue: () {},
      onClose: () {},
    ),
  ),
  RegisteredScreen(
    label: 'series summary',
    // Bare, like the round and the verdicts: it brings its own `Scaffold`,
    // which is the shape `_SeriesSession` builds it in.
    build: () => SeriesSummaryScreen(
      result: const SeriesResult(
        correct: 4,
        total: 5,
        elapsed: Duration(seconds: 47),
        streakDays: 3,
      ),
      onDone: () {},
    ),
  ),
  RegisteredScreen(
    label: 'verdict · error',
    build: () => VerdictScreen(
      summary: const VerdictSummary(
        verdict: Verdict.wrong,
        elapsed: Duration(milliseconds: 12800),
        streakDays: 1,
      ),
      onContinue: () {},
      onClose: () {},
    ),
  ),
];
