import 'package:flutter/widgets.dart';

import '../../../content/model/item.dart';
import '../../../design/brand/aki.dart';
import '../../../design/icons/brand_icon.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/speech_bubble.dart';
import 'bands/family_row.dart';
import 'bands/week_strip.dart';
import '../../round/ui/stimulus/stimulus_view.dart';

/// `Inicio actualizado`, reduced to what F2 can source.
///
/// **The subtractions each have a return phase, and none is a cut** (D5):
/// the rating pill comes back at **F3**, because the rating is the server's
/// exclusive authority and no server exists (Q3, D17); the `PUZZLE DEL DÍA`
/// card at **F6**; the bottom nav at **F5**, when a second root exists.
///
/// **The streak pill is not a subtraction** — it ships here and is the only
/// pill on the F2 home, because a streak is a *local calendar fact* computed on
/// device (D17). It was once listed among the deferrals with a return phase of
/// "F2", which is this change: the two statements were the same statement
/// written as though they disagreed.
///
/// The `TUS HABILIDADES` row is **not** deferred either. It is the structural
/// difference between the two home documents, and choosing `Inicio actualizado`
/// means dropping it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.preview,
    required this.streakDays,
    required this.onStart,
    this.weekMarks = const <bool>[false, false, false, false, false, false, false],
    this.todaysFamilies = const <String>[],
    this.puzzles = const <PuzzleOption>[],
  });

  /// The item whose expression the card previews.
  final Item preview;

  /// From `StreakPolicy` — a local fact, never the server's.
  final int streakDays;

  final VoidCallback onStart;

  /// Seven days, oldest first, ending today — from `weekMarks`.
  final List<bool> weekMarks;

  /// The families the next series will draw — from `seriesFamilies` over the
  /// same plan that will serve them.
  final List<String> todaysFamilies;

  /// Every puzzle the pack carries, named and openable, in pack order.
  ///
  /// **Empty means the section is absent, not disabled.** A card a player can
  /// see and cannot open is a promise the screen has no way to keep — the same
  /// reasoning that keeps the rating off this screen entirely.
  ///
  /// All of them rather than the first: the pack ships five formats and a home
  /// that opened one of them left the other four unreachable in a build that
  /// draws all five.
  final List<PuzzleOption> puzzles;

  /// Aki's band on the home is 150, against the verdict screens' 182.
  static const double _akiWidth = 150;

  @override
  Widget build(BuildContext context) {
    // **It scrolls** (design D2). Two bands, Aki, the card and the button do
    // not fit 844 px at `textScaler` 1.3, and shrinking them until they do
    // would be making the screen worse for exactly the readers who chose large
    // text. The order puts the button above the fold at 1.0, so nobody has to
    // scroll to start.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WeekStrip(marks: weekMarks, streakDays: streakDays),
          const SizedBox(height: BrandShape.space4),
          _band(),
          const SizedBox(height: BrandShape.space4),
          _challengeCard(),
          const SizedBox(height: BrandShape.space4),
          if (puzzles.isNotEmpty) ...<Widget>[
            ..._puzzleSection(),
            const SizedBox(height: BrandShape.space4),
          ],
          if (todaysFamilies.isNotEmpty) ...<Widget>[
            FamilyRow(families: todaysFamilies),
            const SizedBox(height: BrandShape.space4),
          ],
          // Last, so nothing sits below the thing the screen is asking for.
          BrandButton.primary(label: 'Empezar la serie', onPressed: onStart),
          const SizedBox(height: BrandShape.space3),
        ],
      ),
    );
  }

  /// `ROMPECABEZAS` — the section F2 deferred to F6.
  ///
  /// One card per puzzle, each naming its kind rather than only the word
  /// "rompecabezas", because a KenKen and a sopa de letras are different
  /// amounts of evening and a player deciding whether to start one should know
  /// which. The eyebrow is printed once above them, not on every card.
  List<Widget> _puzzleSection() {
    return <Widget>[
      Text('ROMPECABEZAS', style: BrandText.eyebrow()),
      const SizedBox(height: BrandShape.space2),
      for (final PuzzleOption option in puzzles) ...<Widget>[
        _puzzleCard(option),
        const SizedBox(height: BrandShape.space2),
      ],
    ];
  }

  Widget _puzzleCard(PuzzleOption option) {
    return GestureDetector(
      onTap: option.onOpen,
      behavior: HitTestBehavior.opaque,
      child: CandySurface(
        borderRadius: BrandShape.radiusCardMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: BrandShape.space4,
          vertical: BrandShape.space3,
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(option.label, style: BrandText.cardTitle())),
            const BrandIcon(BrandGlyph.forward, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _band() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Aki(width: _akiWidth, semanticLabel: 'Aki'),
        const SizedBox(width: BrandShape.space2),
        const Flexible(
          child: SpeechBubble(text: '¿Le entramos a los retos de hoy?'),
        ),
      ],
    );
  }

  /// `RETO DEL DÍA`, with the expression composed rather than described.
  Widget _challengeCard() {
    return CandySurface(
      borderRadius: BrandShape.radiusCardMedium,
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('RETO DEL DÍA', style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space3),
          // **The same renderer the round uses**, not a picture of one, so the
          // preview cannot drift from the item it shows — and so a day whose
          // first item is a series draws a series instead of throwing. It used
          // to call `nodeFor` directly, which throws on anything that is not an
          // expression.
          // Capped, because the compositor sizes an expression to fill what it
          // is given and a fraction is two lines tall — uncapped it made the
          // card half the screen and pushed everything else into a scroll
          // nobody should need on a phone at ordinary text size.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 116),
            child: StimulusView(stimulus: preview.stimulus),
          ),
        ],
      ),
    );
  }
}

/// One openable puzzle on the home.
///
/// The name comes from `puzzleMenu`, which is pure and tested on its own; this
/// carries it and the callback together so the screen never has to hold two
/// lists in step by index.
class PuzzleOption {
  const PuzzleOption({required this.label, required this.onOpen});

  /// What the card reads, from `puzzleName`.
  final String label;

  final VoidCallback onOpen;
}
