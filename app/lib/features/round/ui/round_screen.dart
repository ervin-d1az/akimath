import 'dart:async';

import 'package:flutter/material.dart';

import '../../../content/model/item.dart';
import '../../../design/math/math_view.dart';
import '../../../design/painting/spec/dash_spec.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/icons/brand_icon.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/icon_button_tile.dart';
import '../../../design/widgets/keypad.dart';
import '../../../design/widgets/spec/keypad_layout.dart';
import '../../home/data/day_log_store.dart';
import '../policy/answer_draft.dart';
import '../policy/grading.dart';
import '../policy/prompt_layout.dart';
import '../policy/streak_policy.dart';
import 'verdict/verdict_screen.dart';

/// The round: an item, an answer slot, a keypad, a verdict.
///
/// Everything it decides comes from `policy/` — what the typed characters
/// become is `AnswerDraft`, and whether an answer is right is `grade`. This
/// widget holds the current index and the current draft and nothing else, which
/// is what keeps all three testable without pumping a screen. Turning a prompt
/// into a node tree is `nodeFor`, and it lives in `policy/` for the same reason
/// the other two do.
///
/// It takes its items rather than fetching them. `HomeRoute` is the adapter
/// that reads the bundled pack and pushes this screen, so nothing here touches
/// an `AssetBundle` — and a test plays a round by handing over a one-item list.
class RoundScreen extends StatefulWidget {
  const RoundScreen({
    super.key,
    required this.items,
    this.now = DateTime.now,
    this.attemptDays = const <DateTime>[],
    this.dayLog,
    this.onClose,
    this.onFinished,
  });

  final List<Item> items;

  /// The clock, injected.
  ///
  /// Time is measured here and shown only on the verdict screen — never while
  /// an item is on screen (`req-quiet-timing`, and `CLAUDE.md`'s "no visible
  /// timer"). Taking the clock as a parameter is what lets that be tested by
  /// handing it two instants rather than by waiting.
  final DateTime Function() now;

  /// The days the player has practised, for the streak.
  final List<DateTime> attemptDays;

  /// Where today gets recorded when an answer is submitted.
  ///
  /// Optional so a test can play a round without one. When present, submitting
  /// records the day — **right or wrong**, because the streak counts days
  /// practised and not days won.
  final DayLogStore? dayLog;

  /// Leaves the series.
  ///
  /// **The only way out, and it has to exist.** A series is pushed as a
  /// full-screen route, which on iOS means no system back button and — because
  /// `fullscreenDialog` routes get no `_CupertinoBackGestureDetector` — no
  /// edge-swipe either. The round itself never ends: it cycles items forever.
  /// So without this control an iPhone player who started a series could not
  /// reach the home again without killing the app. Android hid it, because the
  /// hardware back pops the route.
  ///
  /// Defaults to `Navigator.maybePop`, so a pushed round always has an exit
  /// even if a caller forgets to wire one.
  final VoidCallback? onClose;

  /// Called instead of advancing, once every item has been answered.
  ///
  /// When null the round cycles — which is what a practice series does. The
  /// teaching item on `0.3` is the opposite: exactly one item, and finishing it
  /// continues the first run rather than offering another.
  final VoidCallback? onFinished;

  @override
  State<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends State<RoundScreen> {
  @override
  void initState() {
    super.initState();
    // Not a constructor assert: `items.length` is not a constant expression, so
    // a const constructor cannot check it. Unreachable through `RoundRoute` —
    // `Pack.fromJson` refuses an empty pack — but the constructor is public and
    // `required` does not mean non-empty. Without this, `_item` is a RangeError
    // and `_next` a modulo by zero.
    assert(
      widget.items.isNotEmpty,
      'a round needs at least one item to play',
    );
  }

  int _index = 0;
  AnswerDraft _draft = AnswerDraft.empty;
  VerdictSummary? _summary;
  late DateTime _startedAt = widget.now();

  Item get _item => widget.items[_index];

  void _onKey(KeypadKey key) {
    setState(() {
      switch (key.id) {
        case 'backspace':
          _draft = _draft.backspace();
        case 'submit':
          if (_draft.canSubmit) {
            _submit();
          }
        default:
          final String? emits = key.emits;
          if (emits != null) {
            _draft = _draft.type(emits);
          }
      }
    });
  }

  /// Judges the answer and builds what the verdict screen shows.
  ///
  /// The streak counts today as played the moment an answer is submitted —
  /// right or wrong. A wrong answer never decrements it (Q7), and it does not
  /// fail to increment it either: the streak counts days practised.
  void _submit() {
    final DateTime finishedAt = widget.now();
    // Recorded before the verdict is built, and regardless of what it says.
    unawaited(widget.dayLog?.record(finishedAt) ?? Future<void>.value());
    _summary = VerdictSummary(
      verdict: grade(_item, _draft.text),
      elapsed: finishedAt.difference(_startedAt),
      streakDays: streakLength(
        attemptDays: <DateTime>[...widget.attemptDays, finishedAt],
        today: finishedAt,
      ),
    );
  }

  void _next() {
    final VoidCallback? finished = widget.onFinished;
    if (finished != null && _index == widget.items.length - 1) {
      finished();
      return;
    }

    setState(() {
      _index = (_index + 1) % widget.items.length;
      _draft = AnswerDraft.empty;
      _summary = null;
      _startedAt = widget.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final VerdictSummary? summary = _summary;
    if (summary != null) {
      return VerdictScreen(
        summary: summary,
        onContinue: _next,
        onClose: _close,
      );
    }

    // Scaffold, not a bare ColoredBox: without a Material ancestor Flutter
    // falls back to a DefaultTextStyle that paints a yellow double underline
    // under every run of text. It is a debug marker, it looks like a defect,
    // and `screen_text_style_test.dart` now fails on it.
    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BrandShape.space4,
            vertical: BrandShape.space3,
          ),
          child: Column(
            children: <Widget>[
              _header(),
              const Spacer(),
              _prompt(),
              const SizedBox(height: BrandShape.space5),
              _answerSlot(),
              const Spacer(),
              Keypad(layout: KeypadLayout.item, onKeyPressed: _onKey),
              const SizedBox(height: BrandShape.space3),
              BrandButton.text(label: 'Saltar este reto', onPressed: _next),
            ],
          ),
        ),
      ),
    );
  }

  /// `close · progress · …` — the shell's first element, per the item-shell
  /// design. It was specified and never built, and its absence trapped an iOS
  /// player inside the session.
  void _close() {
    final VoidCallback? handler = widget.onClose;
    if (handler != null) {
      handler();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        IconButtonTile(
          onPressed: _close,
          child: const BrandIcon(BrandGlyph.close, size: 22),
        ),
        Text('Reto ${_index + 1}', style: BrandText.eyebrow()),
        // No visible timer, ever — time is measured quietly (CLAUDE.md).
        Text('Nivel ${_item.ladderStep}', style: BrandText.eyebrow()),
      ],
    );
  }

  Widget _prompt() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: MathView(node: nodeFor(_item)),
    );
  }


  Widget _answerSlot() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        CandySurface(
          // Pink dashed throughout: a focus affordance, never a verdict
          // (BrandColorRole.focus). A judged answer leaves this screen
          // entirely, so the slot has no verdict state to carry.
          borderDash: DashSpec.locked,
          borderColor: BrandColorRole.focus.color,
          borderWidth: BrandShape.borderWidth,
          borderRadius: BrandShape.radiusSlot,
          shadowOffset: Offset.zero,
          // No token at these two values; the slot's inner padding is set to
          // keep a 40px numeral clear of the 3px outline at textScaler 1.3.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            // Fixed so the slot does not resize as the player types.
            width: 140,
            child: Center(
              // **Scaled to fit, never clipped.** At 40 px a Darumadrop `0`
              // advances about 27 px, so 140 px holds five or six digits while
              // `AnswerDraft.maxLength` permits twelve. Clipping the overflow
              // meant the answer shown and the answer graded could differ — and
              // worse, backspacing a hidden character read as a keypress that
              // did nothing.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _draft.text.isEmpty ? ' ' : _draft.text,
                  // Named so a test can read the answer without matching a
                  // keypad key that happens to show the same digit.
                  key: const ValueKey<String>('answer-draft'),
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  // Half the prompt's 76: the answer is read, not solved, so it
                  // sits below the challenge in the visual hierarchy.
                  style: BrandText.numeral(40),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
