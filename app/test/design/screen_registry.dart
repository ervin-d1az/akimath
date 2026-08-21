import 'package:akimath_app/api/me.dart';
import 'package:akimath_app/features/auth/policy/age_gate.dart';
import 'package:akimath_app/features/auth/ui/age_gate_screen.dart';
import 'package:akimath_app/features/auth/ui/create_account_screen.dart';
import 'package:akimath_app/features/auth/ui/new_password_screen.dart';
import 'package:akimath_app/features/auth/ui/recover_password_screen.dart';
import 'package:akimath_app/features/auth/ui/sign_in_screen.dart';
import 'package:akimath_app/features/auth/ui/tutor_consent_screen.dart';
import 'package:akimath_app/features/auth/ui/verify_email_screen.dart';
import 'package:akimath_app/features/character_sheet/character_sheet_screen.dart';
import 'package:akimath_app/features/states/policy/account_state.dart';
import 'package:akimath_app/features/states/ui/account_state_view.dart';
import 'package:akimath_app/features/states/ui/empty_state_screen.dart';
import 'package:akimath_app/features/states/ui/offline_screen.dart';
import 'package:akimath_app/features/states/ui/server_error_screen.dart';
import 'package:akimath_app/features/states/policy/topic_suggestion.dart';
import 'package:akimath_app/features/states/ui/skill_mastered_screen.dart';
import 'package:akimath_app/features/states/ui/topic_exhausted_screen.dart';
import 'package:akimath_app/features/splash/splash_screen.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/features/home/ui/home_screen.dart';
import 'package:akimath_app/features/onboarding/ui/first_item_screen.dart';
import 'package:akimath_app/content/model/diagnosis.dart';
import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/features/preferences/policy/erasure.dart';
import 'package:akimath_app/features/preferences/ui/erase_account_screen.dart';
import 'package:akimath_app/features/preferences/ui/account_screen.dart';
import 'package:akimath_app/features/preferences/ui/change_password_screen.dart';
import 'package:akimath_app/features/preferences/ui/legend_screen.dart';
import 'package:akimath_app/features/preferences/ui/settings_list_screen.dart';
import 'package:akimath_app/features/preferences/data/settings_store.dart';
import 'package:akimath_app/features/preferences/policy/accessibility_settings.dart';
import 'package:akimath_app/features/preferences/policy/notification_settings.dart';
import 'package:akimath_app/features/preferences/policy/sound_settings.dart';
import 'package:akimath_app/features/preferences/ui/accessibility_screen.dart';
import 'package:akimath_app/features/preferences/ui/data_privacy_screen.dart';
import 'package:akimath_app/features/preferences/ui/notifications_screen.dart';
import 'package:akimath_app/features/preferences/ui/sound_screen.dart';
import 'package:akimath_app/features/profile/ui/profile_screen.dart';
import 'package:akimath_app/api/history.dart';
import 'package:akimath_app/features/profile/policy/history_view.dart';
import 'package:akimath_app/features/profile/policy/profile_readout.dart';
import 'package:akimath_app/features/puzzle/policy/pause.dart';
import 'package:akimath_app/features/puzzle/ui/paused_board.dart';
import 'package:akimath_app/features/puzzle/ui/reference_card.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_screen.dart';
import 'package:akimath_app/features/puzzle/ui/puzzle_solved_screen.dart';
import 'package:akimath_app/features/puzzle/ui/word_search_screen.dart';
import 'package:akimath_app/features/onboarding/ui/welcome_screen.dart';
import 'package:akimath_app/features/shell/ui/app_shell.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/round/ui/summary/series_summary_screen.dart';
import 'package:akimath_app/features/round/ui/verdict/verdict_screen.dart';
import 'package:akimath_app/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
// f5-skill-map — the two screens of the topic map.
import 'package:akimath_app/design/widgets/spec/mastery_level.dart';
import 'package:akimath_app/features/map/policy/skill_map.dart';
import 'package:akimath_app/features/map/ui/node_detail_screen.dart';
import 'package:akimath_app/features/map/ui/skill_map_screen.dart';

/// A surface the design gates pump a screen at.
///
/// One entry per viewport the app promises to survive. The set is short on
/// purpose: 390×844 is the design viewport every document is drawn against, and
/// 1.3 is the text size a child's device arrives with more often than not.
enum ScreenViewport {
  designPhone('390×844', Size(390, 844), 1),
  designPhoneLargeText('390×844 · textScaler 1.3', Size(390, 844), 1.3),

  /// The same phone with the hardware in the way.
  ///
  /// **Added because a device found an overflow this gate could not.** Both
  /// viewports above are flat 390×844 rectangles with `padding` zero, so
  /// `SafeArea` takes nothing and a screen gets every pixel. No phone this app
  /// ships to is like that. Measured on the iPhone 17 the app is developed
  /// against: **402×874, padding 62 top and 34 bottom**, so a screen has 778 —
  /// and the difference is where a 24-pixel overflow hid.
  ///
  /// The numbers are the measured ones rather than a guess: a probe printed
  /// `MediaQuery.of(context)` on the device, because the design's 390×844 is a
  /// drawing convention and not a phone.
  notchedPhone(
    '402×874 · con muescas',
    Size(402, 874),
    1,
    padding: EdgeInsets.only(top: 62, bottom: 34),
  ),

  /// The same phone, the same hardware, and the text setting the app is gated
  /// for. The genuine worst case, and the one the design never drew.
  notchedPhoneLargeText(
    '402×874 · con muescas · textScaler 1.3',
    Size(402, 874),
    1.3,
    padding: EdgeInsets.only(top: 62, bottom: 34),
  );

  const ScreenViewport(
    this.label,
    this.physicalSize,
    this.textScale, {
    this.padding = EdgeInsets.zero,
  });

  /// What the hardware takes before a screen gets any of it.
  final EdgeInsets padding;

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
    answer: PlainAnswer('5/4'),
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
    answer: PlainAnswer('162'),
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
    answer: PlainAnswer('900'),
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
    answer: PlainAnswer('750'),
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
    answer: PlainAnswer('400'),
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
    answer: PlainAnswer('21'),
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
  RegisteredScreen(label: 'splash · cream', build: () => const SplashScreen()),
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
    label: 'age gate',
    build: () => AppShell(
      child: AgeGateScreen(
        today: DateTime.utc(2026, 8, 19),
        onResolved: (AgeBand band, AgeGateRoute route) {},
        onBack: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'tutor consent',
    build: () => AppShell(child: TutorConsentScreen(onBack: () {})),
  ),
  RegisteredScreen(
    label: 'create account',
    build: () => AppShell(
      child: CreateAccountScreen(
        onSubmit: (String email, String password) {},
        busy: false,
        onBack: () {},
        onSignInInstead: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'create account · rechazada',
    build: () => AppShell(
      child: CreateAccountScreen(
        onSubmit: (String email, String password) {},
        busy: false,
        onBack: () {},
        onSignInInstead: () {},
        problem: 'Ese correo ya tiene una cuenta.',
      ),
    ),
  ),
  RegisteredScreen(
    label: 'sign in',
    build: () => AppShell(
      child: SignInScreen(
        onSubmit: (String email, String password) {},
        busy: false,
        onBack: () {},
        onForgotPassword: (String email) {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'sign in · rechazada',
    // `1.7`: the refusal is a coral band with a glyph, never a hue alone.
    build: () => AppShell(
      child: SignInScreen(
        onSubmit: (String email, String password) {},
        busy: false,
        onBack: () {},
        onForgotPassword: (String email) {},
        initialEmail: 'alguien@ejemplo.com',
        problem:
            'Ese correo y esa contraseña no coinciden. Puedes intentar de '
            'nuevo o cambiarla.',
      ),
    ),
  ),
  RegisteredScreen(
    label: 'recuperar contraseña',
    build: () => AppShell(
      child: RecoverPasswordScreen(
        onSubmit: (String email) {},
        busy: false,
        sent: false,
        onBack: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'recuperar contraseña · enviada',
    build: () => AppShell(
      child: RecoverPasswordScreen(
        onSubmit: (String email) {},
        busy: false,
        sent: true,
        onBack: () {},
        initialEmail: 'alguien@ejemplo.com',
      ),
    ),
  ),
  RegisteredScreen(
    label: 'contraseña nueva',
    build: () => AppShell(
      child: NewPasswordScreen(
        onSubmit: (String password) {},
        busy: false,
        saved: false,
        onBack: () {},
        onSignIn: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'contraseña nueva · guardada',
    build: () => AppShell(
      child: NewPasswordScreen(
        onSubmit: (String password) {},
        busy: false,
        saved: true,
        onBack: () {},
        onSignIn: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'verify email',
    build: () => AppShell(
      child: VerifyEmailScreen(
        email: 'alguien@ejemplo.com',
        codeIssuedAt: DateTime.now(),
        onSubmit: (String _) {},
        onResend: () {},
        busy: false,
        onBack: () {},
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
        referenceSheet: const <String>[
          'Se usan los números del 1 al 9, uno por celda.',
        ],
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
          Run(
            cells: <Cell>[Cell(row: 0, col: 1), Cell(row: 0, col: 2)],
            sum: 4,
          ),
          Run(
            cells: <Cell>[
              Cell(row: 1, col: 0),
              Cell(row: 1, col: 1),
              Cell(row: 1, col: 2),
            ],
            sum: 15,
          ),
          Run(
            cells: <Cell>[
              Cell(row: 2, col: 0),
              Cell(row: 2, col: 1),
              Cell(row: 2, col: 2),
            ],
            sum: 19,
          ),
          Run(
            cells: <Cell>[Cell(row: 1, col: 0), Cell(row: 2, col: 0)],
            sum: 10,
          ),
          Run(
            cells: <Cell>[
              Cell(row: 0, col: 1),
              Cell(row: 1, col: 1),
              Cell(row: 2, col: 1),
            ],
            sum: 11,
          ),
          Run(
            cells: <Cell>[
              Cell(row: 0, col: 2),
              Cell(row: 1, col: 2),
              Cell(row: 2, col: 2),
            ],
            sum: 17,
          ),
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
  // **Labelled under `puzzle · kenken`, and that prefix is load-bearing.**
  // `quiet_while_you_solve_test.dart` decides what counts as a solving surface
  // with `startsWith` over a list of prefixes; both screens below are mid-solve
  // — one is the board's rules, the other is the board paused — so naming them
  // this way puts them under the Aki-absence and no-clock gates with no edit to
  // that file. Renaming either to `pausa · kenken` drops it silently out of
  // both, which is the PROC-10 failure this repository keeps rediscovering.
  RegisteredScreen(
    label: 'puzzle · kenken · hoja de referencia',
    // **This entry measures the card, not the screen around it.** The rules
    // live behind a tap and a registry builder cannot tap, so what is pumped
    // is the card in the board screen's own padding — with the 48px header
    // above it left out. The real surface gives the card that much less, and
    // the board screen itself is registered above at both viewports. Its rules
    // band scrolls, so the shortfall costs scroll extent rather than an
    // overflow, but the gate below is not measuring the shipping height and
    // should not be read as if it were.
    build: () => Scaffold(
      backgroundColor: BrandColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BrandShape.space4,
            vertical: BrandShape.space3,
          ),
          child: ReferenceCard(
            // The shipped copy, not a stub: these are the longest lines the
            // pack carries, which is the case the card has to survive.
            // **A deliberate long sample, not a fourth source of truth.**
            // `packages/core/test/reference-sheet.test.ts` is what holds the
            // generator and the pack together; this is a fixture that has to
            // stay roughly this long, and nothing goes red if the wording
            // moves — which is correct, because what is being measured here is
            // height, not words.
            puzzle: KenKenPuzzle(
              board: registryKenKen(6).board,
              cages: registryKenKen(6).cages,
              tutorialSteps: const <String>[],
              referenceSheet: const <String>[
                'Llena todas las casillas con números del 1 al 6.',
                'Las jaulas son los grupos de casillas con borde punteado: en '
                    'su esquina traen el resultado y el signo (+ suma, - resta, '
                    '× multiplica, ÷ divide).',
                'Las casillas de cada jaula dan ese resultado en el orden que '
                    'sea, y ningún número se repite en su fila ni en su columna.',
              ],
            ),
            onClose: () {},
          ),
        ),
      ),
    ),
  ),
  RegisteredScreen(
    label: 'puzzle · kenken · pausa',
    // The longest format name and the largest board, so nothing wider can
    // arrive: `CUADRO MÁGICO` beside a count in the tens.
    build: () => PausedBoardView(
      summary: const PauseSummary(
        filled: 11,
        total: 36,
        formatName: 'CUADRO MÁGICO',
        sizeLabel: '6 × 6',
      ),
      onResume: () {},
      onLeave: () {},
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
    label: 'perfil · cuenta cargando',
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.loading,
        onRetryAccount: null,
        onOpenSettings: () {},
        figures: registryProfileFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · cuenta sin jugador',
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.noPlayer,
        onRetryAccount: null,
        onOpenSettings: () {},
        figures: registryProfileFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · cuenta sin conexión',
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.offline,
        onRetryAccount: () {},
        onOpenSettings: () {},
        figures: registryProfileFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · cuenta error de servidor',
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.serverError,
        onRetryAccount: () {},
        onOpenSettings: () {},
        figures: registryProfileFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · cuenta sesión caducada',
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.rejected,
        onRetryAccount: null,
        onOpenSettings: () {},
        figures: registryProfileFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'estado · vista suelta',
    build: () => const AppShell(
      child: AccountSection(
        child: AccountStateView(state: AccountState.offline, email: 'a@b.co'),
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil',
    // The third root, and the one declared rule 1 actually names. In the
    // shell, because that is the only way it renders.
    build: () => AppShell(
      child: ProfileScreen(
        accountState: AccountState.none,
        onOpenSettings: () {},
        onCreateAccount: () {},
        figures: registryProfileFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · sin cuenta ni endpoints',
    // A build given no auth URL. It offers nothing it cannot do and still says
    // what is true, which are two different things (DR-P2).
    build: () => AppShell(
      child: ProfileScreen(
        accountState: AccountState.none,
        onOpenSettings: () {},
        figures: registryProfileFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'ajustes',
    build: () => AppShell(
      child: SettingsListScreen(
        onBack: () {},
        onOpenAccount: () {},
        onOpenLegend: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'ajustes · cuenta',
    build: () => AppShell(
      child: AccountScreen(
        onBack: () {},
        email: 'alguien@ejemplo.com',
        onErase: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'ajustes · cómo se leen los retos',
    build: () => AppShell(child: LegendScreen(onBack: () {})),
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
    label: 'verdict · error · con diagnóstico',
    // **The most the format admits**, at the longest lines in
    // `misconceptions.json`: four steps is the schema's ceiling. Registered
    // separately because `verdict · error` builds no diagnosis, so without this
    // the gate would stay green while the shipped screen overflowed — the same
    // shape as the home once registered with no puzzle cards.
    build: () => VerdictScreen(
      summary: const VerdictSummary(
        verdict: Verdict.wrong,
        elapsed: Duration(milliseconds: 9800),
        streakDays: 12,
        diagnosis: Diagnosis(
          steps: <String>[
            'Comprueba el resultado antes de enviarlo.',
            'Quita el segundo al primero, en ese orden.',
            'Mira el signo que hay entre los dos números.',
            'Rehaz la cuenta paso por paso, sin prisa.',
          ],
          explain:
              'Repasa el reto con calma: vuelve a leer los números, rehaz '
              'la cuenta paso por paso y compara lo que te salió con lo que '
              'pedía el reto.',
        ),
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
        outcomes: <Verdict>[
          Verdict.correct,
          Verdict.correct,
          Verdict.correct,
          Verdict.wrong,
          Verdict.correct,
        ],
      ),
      onDone: () {},
    ),
  ),
  RegisteredScreen(
    // The tallest state the screen has: the ring, the three tiles, both
    // invented blocks *and* the coral one, which only a slip with copy behind
    // it draws. Registered separately because the entry above never renders
    // it, and an overflow gate can only see what it is handed.
    label: 'series summary · con diagnostico',
    build: () => SeriesSummaryScreen(
      result: const SeriesResult(
        correct: 2,
        total: 5,
        elapsed: Duration(milliseconds: 128400),
        streakDays: 13,
        outcomes: <Verdict>[
          Verdict.wrong,
          Verdict.correct,
          Verdict.wrong,
          Verdict.wrong,
          Verdict.correct,
        ],
        stumble: Diagnosis(
          steps: <String>[
            'Fijate en cuanto crece la serie entre un numero y el otro.',
            'Suma esa diferencia al ultimo numero que ves.',
          ],
          explain: 'La diferencia crece; no es la misma cada vez.',
        ),
        stumbleIndex: 2,
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
  RegisteredScreen(
    label: 'ajustes · cuenta sin puerta de borrado',
    // No session the request could travel on, so the door is absent rather
    // than dead — `erasureOffered` is the judgement and the token is the fact.
    build: () => AppShell(
      child: AccountScreen(onBack: () {}, email: 'alguien@ejemplo.com'),
    ),
  ),
  RegisteredScreen(
    label: 'borrar datos · la pregunta',
    build: () => AppShell(
      child: EraseAccountScreen(
        step: null,
        confirmWord: TextEditingController(),
        onConfirm: () {},
        onCancel: () {},
        onDone: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'borrar datos · sin conexión',
    build: () => AppShell(
      child: EraseAccountScreen(
        step: ErasureStep.offline,
        confirmWord: TextEditingController(),
        onConfirm: () {},
        onCancel: () {},
        onDone: () {},
        onRetry: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'borrar datos · listo',
    build: () => AppShell(
      child: EraseAccountScreen(
        step: ErasureStep.gone,
        confirmWord: TextEditingController(),
        onConfirm: () {},
        onCancel: () {},
        onDone: () {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · sin cuenta',
    build: () => AppShell(
      child: ProfileScreen(
        accountState: AccountState.none,
        onOpenSettings: _nothing,
        onCreateAccount: _nothing,
        figures: registryProfileFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · historial cargando',
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.linked,
        onOpenSettings: _nothing,
        figures: registryProfileFigures,
        historyState: HistoryState.loading,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · con historial',
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.linked,
        onOpenSettings: _nothing,
        figures: registryProfileFigures,
        historyState: HistoryState.ready,
        entries: <HistoryEntry>[
          HistoryEntry(
            kind: HistoryKind.series,
            title: 'Restas',
            at: DateTime.utc(2026, 8, 19, 15),
            score: '4/5',
            ratingDelta: null,
          ),
          HistoryEntry(
            kind: HistoryKind.series,
            title: 'Serie de retos',
            at: DateTime.utc(2026, 8, 18, 15),
            score: '5/5',
            ratingDelta: null,
          ),
        ],
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · historial sin conexión',
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.linked,
        onOpenSettings: _nothing,
        figures: registryProfileFigures,
        historyState: HistoryState.offline,
        onRetryHistory: _nothing,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · cuenta en otro teléfono',
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.otherDevice,
        onOpenSettings: () {},
        figures: registryProfileFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  // ── 4.1 Perfil · the two shapes the figures give it ───────────────────────
  RegisteredScreen(
    label: 'perfil · solo lo comprobable',
    // The build that ships: no rating, no accuracy, no mean time. The headline
    // pair falls back to the days practised and the tile row is one tile wide,
    // so the gates walk the degraded layout as well as the full one.
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'alguien@ejemplo.com',
        accountState: AccountState.linked,
        onOpenSettings: _nothing,
        figures: registryProvableFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'perfil · cifras al máximo',
    // The widest every figure can be. Three tiles at their longest values with
    // the longest labels is the row that overflows first, and it is the row
    // 390 px at `textScaler` 1.3 has the least room for.
    build: () => AppShell(
      child: ProfileScreen(
        accountEmail: 'unnombremuylargo@correo-largo.com.mx',
        accountState: AccountState.linked,
        onOpenSettings: _nothing,
        figures: registryWidestFigures,
        historyState: HistoryState.noAccount,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'ajustes · cuenta · con las cuatro filas',
    // The state a linked account is actually in: every row the design draws,
    // and the widest this screen ever gets.
    build: () => AppShell(
      child: AccountScreen(
        onBack: _nothing,
        email: 'alguien@ejemplo.com',
        onErase: _nothing,
        onChangePassword: _nothing,
        onSignOut: _nothing,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'ajustes · contraseña · todavía no',
    build: () => AppShell(child: ChangePasswordScreen(onBack: _nothing)),
  ),
  RegisteredScreen(
    label: 'borrar datos · la pregunta · con la palabra escrita',
    // **Registered separately because the confirm only exists here.** With an
    // empty field every entry above draws the locked surface instead, so a
    // gate walking registered screens would never measure the one control that
    // loses data — the hole `verdict · error · con diagnóstico` was added for.
    build: () => AppShell(
      child: EraseAccountScreen(
        step: null,
        confirmWord: TextEditingController(text: erasureConfirmWord),
        onConfirm: _nothing,
        onCancel: _nothing,
        onDone: _nothing,
      ),
    ),
  ),
  // --- cross-cutting states 4.8-4.10, 4.14-4.15 (f7-estados-transversales) ---
  RegisteredScreen(
    label: 'estado · 4.8 vacío',
    build: () => AppShell(child: EmptyStateScreen(onStart: _nothing)),
  ),
  RegisteredScreen(
    label: 'estado · 4.9 sin conexión',
    build: () => AppShell(
      child: OfflineScreen(
        challenges: 40,
        puzzles: 2,
        onSolveOffline: _nothing,
      ),
    ),
  ),
  RegisteredScreen(
    // The tallest of the five: a note and both buttons, which is the case the
    // overflow gate has to survive at textScaler 1.3.
    label: 'estado · 4.10 error de servidor',
    build: () => AppShell(
      child: ServerErrorScreen(
        note: 'error 503 · 18:42',
        onRetry: _nothing,
        onSolveOffline: _nothing,
      ),
    ),
  ),
  RegisteredScreen(
    // Renders only — no skill can be completed, so nothing routes here. Every
    // figure is supplied from this test file rather than from `lib/`.
    label: 'estado · 4.14 habilidad dominada',
    build: () => AppShell(
      child: SkillMasteredScreen(
        skillName: 'Fracciones',
        weekAgoPercent: 88,
        unlockedTopics: const <String>['Porcentajes', 'Decimales'],
        onOpenMap: _nothing,
        onContinue: _nothing,
      ),
    ),
  ),
  RegisteredScreen(
    // Renders only — a topic cannot run out, because there are no topics.
    label: 'estado · 4.15 tema agotado',
    build: () => AppShell(
      child: TopicExhaustedScreen(
        skillName: 'Fracciones',
        nextTopic: const NextTopic(
          name: 'Decimales',
          percent: 38,
          readyCount: 5,
        ),
        puzzleSubtitle: 'KenKen · 15 min, sin prisa',
        onOpenTopic: _nothing,
        onOpenPuzzle: _nothing,
        onSwitch: _nothing,
      ),
    ),
  ),
  // ── f5-skill-map ─────────────────────────────────────────────────────────
  // `05 Mapa de habilidades` and `2.7 Detalle de nodo`. The map is registered
  // with **all four states on it**, which is what makes the locked arm
  // load-bearing: `readSkillMap` never produces one from the shipped pack —
  // nothing gates anything — so this entry is the only thing that draws the
  // dashed node and the dashed connector, and the only thing that would go red
  // if either stopped working.
  RegisteredScreen(
    label: 'mapa',
    build: () => AppShell(
      child: SkillMapScreen(map: registrySkillMap, onOpen: (int _) {}),
    ),
  ),
  RegisteredScreen(
    label: 'mapa · sin temas',
    build: () => AppShell(
      child: SkillMapScreen(
        map: const SkillMap(nodes: <SkillNode>[], focusIndex: null),
        onOpen: (int _) {},
      ),
    ),
  ),
  RegisteredScreen(
    label: 'nodo · en curso',
    // The most a detail screen can hold: a topic under way, the topic before it
    // finished, and the practice door open.
    build: () => AppShell(
      child: NodeDetailScreen(
        node: registrySkillMap.nodes[1],
        previous: registrySkillMap.nodes.first,
        onBack: _nothing,
        onPractise: _nothing,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'nodo · dominado',
    build: () => AppShell(
      child: NodeDetailScreen(
        node: registrySkillMap.nodes.first,
        onBack: _nothing,
        onPractise: _nothing,
      ),
    ),
  ),
  RegisteredScreen(
    label: 'nodo · bloqueado',
    // No practice door, because there is nothing to practise — and the longest
    // family name in the set, which is the one that tests the 52 px title.
    build: () => AppShell(
      child: NodeDetailScreen(
        node: registrySkillMap.nodes.last,
        previous: registrySkillMap.nodes[4],
        onBack: _nothing,
        onPractise: _nothing,
      ),
    ),
  ),
  // ── end f5-skill-map ─────────────────────────────────────────────────────
  // ── f7-ajustes: 4.4-4.7, the four screens behind 4.2's rows ──────────────
  RegisteredScreen(
    label: 'ajustes · 4.4 notificaciones',
    // The stores are handed in so the gates pump a screen in a known state
    // rather than whatever the device happens to hold.
    build: () => AppShell(
      child: NotificationsScreen(
        onBack: _nothing,
        store: InMemorySettingsStore<NotificationSettings>(
          NotificationSettings.defaults,
        ),
      ),
    ),
  ),
  RegisteredScreen(
    label: 'ajustes · 4.5 accesibilidad',
    build: () => AppShell(
      child: AccessibilityScreen(
        onBack: _nothing,
        store: InMemorySettingsStore<AccessibilitySettings>(
          AccessibilitySettings.defaults,
        ),
      ),
    ),
  ),
  RegisteredScreen(
    label: 'ajustes · 4.5 accesibilidad · en el paso más grande',
    // **Registered separately because the chip's label is its own preview.**
    // The largest step draws its `A` at 30, which at textScaler 1.3 is the
    // widest this card ever gets — the same hole `verdict · error · con
    // diagnóstico` was added for.
    build: () => AppShell(
      child: AccessibilityScreen(
        onBack: _nothing,
        store: InMemorySettingsStore<AccessibilitySettings>(
          AccessibilitySettings.defaults.copyWith(
            textSize: TextSizeStep.largest,
          ),
        ),
      ),
    ),
  ),
  RegisteredScreen(
    label: 'ajustes · 4.6 sonido y vibración',
    build: () => AppShell(
      child: SoundScreen(
        onBack: _nothing,
        store: InMemorySettingsStore<SoundSettings>(SoundSettings.defaults),
      ),
    ),
  ),
  RegisteredScreen(
    label: 'ajustes · 4.7 datos y privacidad',
    build: () => AppShell(child: DataPrivacyScreen(onBack: _nothing)),
  ),
  // ── end f7-ajustes ───────────────────────────────────────────────────────
];

/// What `4.1` draws when every figure has a value, invented ones included.
///
/// The design's own numbers, so the registry pumps the screen the demo shows.
const ProfileFigures registryProfileFigures = ProfileFigures(
  daysPractised: 12,
  streakDays: 5,
  challenges: 312,
  rating: 1248,
  ratingThisWeek: 36,
  accuracyPercent: 78,
  averageTenthsOfSecond: 68,
);

/// Only the figures the device can prove: a day log and a series cursor.
const ProfileFigures registryProvableFigures = ProfileFigures(
  daysPractised: 41,
  streakDays: 7,
  challenges: 312,
);

/// The widest each figure gets: a four-digit rating, a three-digit week, a
/// five-figure count, a full percent and a mean time in the tens of seconds.
const ProfileFigures registryWidestFigures = ProfileFigures(
  daysPractised: 9999,
  streakDays: 9999,
  challenges: 99999,
  rating: 9999,
  ratingThisWeek: 999,
  accuracyPercent: 100,
  averageTenthsOfSecond: 999,
);

/// A callback for a registry entry, so a screen can be drawn with its control
/// live without every entry declaring its own closure.
void _nothing() {}

/// Six topics, because the shipped pack carries six families; the four states
/// are spread across them on purpose, so a gate walking this screen sees the
/// dashed node and the dashed connector that no real pack produces today.
const SkillMap registrySkillMap = SkillMap(
  nodes: <SkillNode>[
    SkillNode(
      label: 'Cuentas',
      blurb: 'Sumar, restar y comparar: cuentas con enteros y con fracciones.',
      level: MasteryLevel.mastered,
      reachedStep: 5,
      topStep: 5,
    ),
    SkillNode(
      label: 'Parejas',
      blurb:
          'Dos parejas con la misma relación: si entiendes una, tienes la otra.',
      level: MasteryLevel.inProgress,
      reachedStep: 4,
      topStep: 6,
    ),
    SkillNode(
      label: 'Figuras',
      blurb:
          'Figuras de puntos que crecen con un patrón. ¿Cuántos trae la que sigue?',
      level: MasteryLevel.inProgress,
      reachedStep: 4,
      topStep: 5,
    ),
    SkillNode(
      label: 'Máquina',
      blurb:
          'Una máquina que transforma números. Averigua qué les hace por dentro.',
      level: MasteryLevel.inProgress,
      reachedStep: 3,
      topStep: 5,
    ),
    SkillNode(
      label: 'Cuadros',
      blurb:
          'Cuadros de números donde cada fila y cada columna esconden una regla.',
      level: MasteryLevel.available,
      reachedStep: 0,
      topStep: 6,
    ),
    SkillNode(
      label: 'Series',
      blurb: 'Encontrar la regla de una fila de números y decir cuál sigue.',
      level: MasteryLevel.locked,
      reachedStep: 0,
      topStep: 4,
    ),
  ],
  focusIndex: 1,
);
