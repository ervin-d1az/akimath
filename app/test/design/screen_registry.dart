import 'package:akimath_app/features/character_sheet/character_sheet_screen.dart';
import 'package:akimath_app/features/splash/splash_screen.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/onboarding/ui/first_item_screen.dart';
import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/features/preferences/ui/preferences_screen.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_screen.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_solved_screen.dart';
import 'package:akimath_app/features/puzzle/ui/word_search_screen.dart';
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

/// A matrix item for the gates: a 3×3 of three-digit cells, which is the most
/// a grid can be asked to fit across 390 px.
const List<Item> registryMatrixItems = <Item>[
  Item(
    id: 'registry-matrix',
    stimulus: MatrixStimulus(
      cells: <int>[100, 200, 300, 200, 400, 600, 300, 600, 900],
      size: 3,
      unknownIndex: 8,
    ),
    expected: '900',
    ladderStep: 5,
  ),
];

/// An analogy item for the gates: three-digit terms, which is the widest an
/// analogy gets before the bridge and four tiles stop fitting 390 px.
const List<Item> registryAnalogyItems = <Item>[
  Item(
    id: 'registry-analogy',
    stimulus: AnalogyStimulus(
      terms: <int>[100, 300, 250, 750],
      unknownIndex: 3,
    ),
    expected: '750',
    ladderStep: 4,
  ),
];

/// A function machine for the gates: three examples and three-digit outputs,
/// which is the tallest *and* widest this family gets.
const List<Item> registryMachineItems = <Item>[
  Item(
    id: 'registry-machine',
    stimulus: HiddenOperationStimulus(
      examples: <({int input, int output})>[
        (input: 10, output: 100),
        (input: 25, output: 250),
        (input: 32, output: 320),
      ],
      queryInput: 40,
    ),
    expected: '400',
    ladderStep: 4,
  ),
];

/// A figurate item for the gates: four boxes, the largest carrying 21 dots,
/// which is the densest figure the shipped pack draws.
const List<Item> registryFigurateItems = <Item>[
  Item(
    id: 'registry-figurate',
    stimulus: FigurateStimulus(
      dotCounts: <int>[6, 10, 15, 21],
      unknownIndex: 3,
    ),
    expected: '21',
    ladderStep: 5,
  ),
];

/// A KenKen of a given size, with one cage over the whole board.
///
/// The cage is deliberately the largest one possible: a single cage's outline
/// is the board's rim and its label sits in the corner, which is the cheapest
/// arrangement that still exercises every part of the renderer.
KenKenPuzzle registryKenKen(int size) => KenKenPuzzle(
      board: PuzzleBoard.caged(
        size: size,
        blocked: const <Cell>{},
        given: const <Cell>{},
        solution: <List<int>>[
          for (int row = 0; row < size; row++)
            <int>[for (int col = 0; col < size; col++) (row + col) % size + 1],
        ],
      ),
      cages: <Cage>[
        Cage(
          cells: <Cell>[
            for (int row = 0; row < size; row++)
              for (int col = 0; col < size; col++) Cell(row: row, col: col),
          ],
          operation: '+',
          target: size * size,
        ),
      ],
      tutorialSteps: const <String>['Cada fila y cada columna, una sola vez.'],
      referenceSheet: const <String>['Ningún número se repite en su fila.'],
    );

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
        weekMarks: const <bool>[true, true, false, true, true, true, true],
        todaysFamilies: const <String>[
          'Cuentas',
          'Series',
          'Cuadros',
          'Parejas',
          'Máquina',
        ],
        // All five, because all five ship. A home registered with none was
        // walking a screen the app stopped building the moment the pack
        // carried a puzzle, and the section is the tallest thing on it.
        puzzles: <PuzzleOption>[
          for (final String label in <String>[
            'KenKen',
            'Suma con jaulas',
            'Cuadro mágico',
            'Kakuro',
            'Sopa de letras',
          ])
            PuzzleOption(label: label, onOpen: () {}),
        ],
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
    label: 'round · analogy',
    // The fourth stimulus family, and the widest prompt the round draws: four
    // tiles and a bridge on one line.
    build: () => const RoundScreen(items: registryAnalogyItems),
  ),
  RegisteredScreen(
    label: 'round · function machine',
    // The fifth stimulus family, and the tallest prompt the round draws: four
    // rows and a rule between them.
    build: () => const RoundScreen(items: registryMachineItems),
  ),
  RegisteredScreen(
    label: 'round · figurate',
    // The sixth and last frozen family. Its dots are painted rather than laid
    // out as text, so it is the one registered screen whose prompt the overflow
    // gate measures as a fixed box.
    build: () => const RoundScreen(items: registryFigurateItems),
  ),
  RegisteredScreen(
    label: 'round · matrix',
    // The third stimulus family. A family that draws itself but is not
    // registered is a family whose first overflow report comes from a player —
    // and a grid is the tallest prompt the round has had to hold.
    build: () => const RoundScreen(items: registryMatrixItems),
  ),
  RegisteredScreen(
    label: 'puzzle · kenken 3x3',
    build: () => PuzzleScreen(puzzle: registryKenKen(3)),
  ),
  RegisteredScreen(
    label: 'puzzle · kenken 6x6',
    // The largest board the format admits — the tightest layout in the app, so
    // it is measured rather than assumed to fit.
    build: () => PuzzleScreen(puzzle: registryKenKen(6)),
  ),
  RegisteredScreen(
    label: 'puzzle · killer 3x3',
    // The second caged format on the same board, registered so the label rule
    // — a sum cage shows no operation — is measured and not merely tested.
    build: () => PuzzleScreen(
      puzzle: KillerPuzzle(
        board: registryKenKen(3).board,
        cages: <Cage>[
          Cage(
            cells: <Cell>[
              for (int row = 0; row < 3; row++)
                for (int col = 0; col < 3; col++) Cell(row: row, col: col),
            ],
            target: 18,
          ),
        ],
        tutorialSteps: const <String>['Cada jaula pide una suma.'],
        referenceSheet: const <String>['Las jaulas no traen signo.'],
      ),
    ),
  ),
  RegisteredScreen(
    label: 'puzzle · magic square 3x3',
    // The only format with a margin, and therefore the widest board on screen.
    build: () => PuzzleScreen(
      // Not `const`: `Cell` overrides `==`, so a constant set of them is a
      // compile error — the analyzer is right that constant set semantics and a
      // custom equality do not mix.
      puzzle: MagicSquarePuzzle(
        board: PuzzleBoard(
          size: 3,
          blocked: const <Cell>{},
          // The *set* cannot be const because `Cell` overrides `==`; the
          // element still can.
          given: <Cell>{const Cell(row: 0, col: 0)},
          solution: const <List<int>>[
            <int>[2, 7, 6],
            <int>[9, 5, 1],
            <int>[4, 3, 8],
          ],
          highestValue: 9,
        ),
        rowTargets: const <int>[15, 15, 15],
        columnTargets: const <int>[15, 15, 15],
        tutorialSteps: const <String>['Cada línea llega a su número.'],
        referenceSheet: const <String>['Se usan los números del 1 al 9, uno por celda.'],
      ),
    ),
  ),
  RegisteredScreen(
    label: 'puzzle · kakuro 3x3',
    // Clues inside the grid rather than in a margin, and a cell that carries
    // two of them — the densest a cell gets.
    build: () => PuzzleScreen(
      puzzle: KakuroPuzzle(
        board: PuzzleBoard(
          size: 3,
          blocked: <Cell>{const Cell(row: 0, col: 0)},
          given: <Cell>{const Cell(row: 1, col: 0)},
          solution: const <List<int>>[
            <int>[0, 1, 3],
            <int>[4, 2, 9],
            <int>[6, 8, 5],
          ],
          highestValue: 9,
        ),
        runs: const <Run>[
          Run(cells: <Cell>[Cell(row: 0, col: 1), Cell(row: 0, col: 2)], sum: 4),
          Run(cells: <Cell>[Cell(row: 1, col: 0), Cell(row: 1, col: 1), Cell(row: 1, col: 2)], sum: 15),
          Run(cells: <Cell>[Cell(row: 2, col: 0), Cell(row: 2, col: 1), Cell(row: 2, col: 2)], sum: 19),
          Run(cells: <Cell>[Cell(row: 1, col: 0), Cell(row: 2, col: 0)], sum: 10),
          Run(cells: <Cell>[Cell(row: 0, col: 1), Cell(row: 1, col: 1), Cell(row: 2, col: 1)], sum: 11),
          Run(cells: <Cell>[Cell(row: 0, col: 2), Cell(row: 1, col: 2), Cell(row: 2, col: 2)], sum: 17),
        ],
        tutorialSteps: const <String>['Cada tramo suma su pista.'],
        referenceSheet: const <String>['Solo se usan los dígitos del 1 al 9.'],
      ),
    ),
  ),
  RegisteredScreen(
    label: 'puzzle · word search 8x8',
    // The largest grid the format admits, with the most words it admits, each
    // of them running in a different one of the eight directions. Nothing
    // denser can arrive, so if this fits at 1.3 every word search fits.
    build: () => WordSearchScreen(
      puzzle: const WordSearchPuzzle(
        grid: <String>[
          'NUMERODG',
          'ANECEDAQ',
          'KIRKXDTX',
          'WDHEOHIZ',
          'FAOBSAMH',
          'LDLRMTHP',
          'JEVUEVAQ',
          'KXSRWCHP',
        ],
        words: <String>[
          'NUMERO',
          'DECENA',
          'UNIDAD',
          'MITAD',
          'RESTA',
          'DOBLE',
          'SUMA',
          'CERO',
        ],
        tutorialSteps: <String>['Encuentra las palabras escondidas.'],
        referenceSheet: <String>['Las palabras van en ocho direcciones.'],
      ),
    ),
  ),
  RegisteredScreen(
    label: 'puzzle · solved',
    // The longest format name and the largest figures it can show: a Kakuro
    // that took an hour, on a streak that has reached the ninety days `DayLog`
    // retains. Nothing wider can arrive.
    build: () => PuzzleSolvedScreen(
      format: 'Sopa de letras',
      elapsed: const Duration(hours: 1, minutes: 4, seconds: 9),
      streakDays: 90,
      onDone: () {},
    ),
  ),
  RegisteredScreen(
    label: 'preferences',
    // The second root, and the reason the app has a bar at all. In the shell,
    // because that is the only way it renders.
    build: () => const AppShell(
      child: PreferencesScreen(daysPractised: 12, streakDays: 5),
    ),
  ),
  RegisteredScreen(
    label: 'preferences · nothing played',
    // A player on their first launch. Zero rather than a dash or a gap, so the
    // screen has no state in which it says nothing.
    build: () => const AppShell(
      child: PreferencesScreen(daysPractised: 0, streakDays: 0),
    ),
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
