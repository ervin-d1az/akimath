import 'package:flutter/widgets.dart';

import '../../../content/model/item.dart';
import '../../round/ui/round_screen.dart';

/// `0.3 Primer reto` — the item that teaches how an answer is typed.
///
/// It is the round, with one item and a different ending: answering it continues
/// the first run rather than offering another. That is why it composes
/// `RoundScreen` instead of reimplementing it — a second solve screen would be a
/// second place to keep the keypad, the answer slot and the verdict in agreement.
///
/// **Aki is absent**, because the learner is solving. She is on `0.2` for the
/// same rule.
///
/// **It measures nothing.** The item is fixed, drawn from no pack, and no
/// `DayLogStore` is passed — a streak that started before the player reached the
/// home would be counting the tutorial.
class FirstItemScreen extends StatelessWidget {
  const FirstItemScreen({
    super.key,
    required this.onFinished,
    required this.onBack,
  });

  /// Called when the teaching item has been answered and acknowledged.
  ///
  /// This is the only path that completes the first run.
  final VoidCallback onFinished;

  /// Called by the close control.
  ///
  /// **Leaving is not finishing.** Routing the close here rather than to
  /// [onFinished] means a mistaken tap costs a few seconds instead of
  /// permanently skipping the only screen that teaches the answer format — the
  /// flag is set by answering, not by escaping. And it is not a trap either: the
  /// welcome behind it is not a solve screen and carries the action that comes
  /// back.
  final VoidCallback onBack;

  /// The teaching item.
  ///
  /// Fixed rather than fetched: a tutorial that varied between installs would be
  /// a tutorial nobody could support, and drawing it from the pack would tempt
  /// someone to rate it. Single-digit operands are reachable for the youngest
  /// audience, and a two-digit answer is the point — it is what teaches that
  /// digits accumulate and that backspace takes one away.
  ///
  /// **It must not be an item the starter pack holds.** It was `7 + 6`, which is
  /// `add-1` — the pack's *first* item, so it is what the home previews as
  /// `RETO DEL DÍA` and what `Empezar la serie` opens with. A new player solved
  /// it in the tutorial and then met it twice more on the next screen. Nothing in
  /// the suite could see that: the tests hand this screen its item and the home
  /// tests hand the home a fixture. Two launches on a simulator showed it at once.
  static const Item teachingItem = Item(
    id: 'teaching',
    prompt: <PromptToken>[
      PromptToken.text('5'),
      PromptToken.operator('+'),
      PromptToken.text('8'),
      PromptToken.operator('='),
    ],
    expected: '13',
    ladderStep: 1,
  );

  @override
  Widget build(BuildContext context) {
    return RoundScreen(
      items: const <Item>[teachingItem],
      onFinished: onFinished,
      onClose: onBack,
      // No `dayLog`: the tutorial does not count towards a streak.
    );
  }
}
