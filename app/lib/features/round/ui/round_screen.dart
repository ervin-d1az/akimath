import 'package:flutter/material.dart';

import '../../../content/model/item.dart';
import '../../../design/math/math_view.dart';
import '../../../design/math/spec/math_node.dart';
import '../../../design/painting/spec/dash_spec.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/keypad.dart';
import '../../../design/widgets/spec/keypad_layout.dart';
import '../../../design/widgets/spec/verdict.dart';
import '../../../design/widgets/verdict_ring.dart';
import '../policy/answer_draft.dart';
import '../policy/grading.dart';

/// The round: an item, an answer slot, a keypad, a verdict.
///
/// Everything it decides comes from `policy/` — what the typed characters
/// become is `AnswerDraft`, and whether an answer is right is `grade`. This
/// widget holds the current index and the current draft and nothing else, which
/// is what keeps both of those testable without pumping a screen.
///
/// It takes its items rather than fetching them. `RoundRoute` is the adapter
/// that reads the bundled pack, so nothing here touches an `AssetBundle` — and
/// a test plays a round by handing over a one-item list.
class RoundScreen extends StatefulWidget {
  const RoundScreen({super.key, required this.items});

  final List<Item> items;

  @override
  State<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends State<RoundScreen> {
  int _index = 0;
  AnswerDraft _draft = AnswerDraft.empty;
  Verdict? _verdict;

  Item get _item => widget.items[_index];

  void _onKey(KeypadKey key) {
    // A verdict is showing: the next press moves on rather than editing an
    // answer that has already been judged.
    if (_verdict != null) {
      _next();
      return;
    }

    setState(() {
      switch (key.id) {
        case 'backspace':
          _draft = _draft.backspace();
        case 'submit':
          if (_draft.canSubmit) {
            _verdict = grade(_item, _draft.text);
          }
        default:
          final String? emits = key.emits;
          if (emits != null) {
            _draft = _draft.type(emits);
          }
      }
    });
  }

  void _next() {
    setState(() {
      _index = (_index + 1) % widget.items.length;
      _draft = AnswerDraft.empty;
      _verdict = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold, not a bare ColoredBox: without a Material ancestor Flutter
    // falls back to a DefaultTextStyle that paints a yellow double underline
    // under every run of text. It is a debug marker, it looks like a defect,
    // and `screen_text_style_test.dart` now fails on it.
    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
              BrandButton.text(label: 'Dejar la serie', onPressed: _next),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text('Reto ${_index + 1}', style: BrandText.eyebrow()),
        // No visible timer, ever — time is measured quietly (CLAUDE.md).
        Text('Nivel ${_item.ladderStep}', style: BrandText.eyebrow()),
      ],
    );
  }

  Widget _prompt() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: MathView(node: _nodeFor(_item)),
    );
  }

  /// Turns the item's rendered prompt into something the compositor can lay out.
  MathNode _nodeFor(Item item) {
    return RowNode(<MathNode>[
      for (final PromptToken token in item.prompt)
        switch (token) {
          TextToken(:final String value) => NumeralNode(value),
          OperatorToken(:final String glyph) => OperatorNode.of(glyph),
          FractionToken(:final String numerator, :final String denominator) =>
            FractionNode(
              numerator: NumeralNode(numerator),
              denominator: NumeralNode(denominator),
            ),
        },
    ]);
  }

  Widget _answerSlot() {
    final Verdict? verdict = _verdict;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        CandySurface(
          // Pink dashed while the player is typing — a focus affordance, never
          // a verdict (BrandColorRole.focus). Once judged, the outline carries
          // the verdict's own pattern.
          borderDash: verdict == null || verdict.outline == VerdictOutline.dashed
              ? DashSpec.locked
              : null,
          borderColor: switch (verdict) {
            null => BrandColorRole.focus.color,
            Verdict.correct => BrandColorRole.success.color,
            Verdict.wrong => BrandColorRole.error.color,
          },
          borderWidth: BrandShape.borderWidth,
          borderRadius: BrandShape.radiusSlot,
          shadowOffset: Offset.zero,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            width: 140,
            child: Center(
              child: Text(
                _draft.text.isEmpty ? ' ' : _draft.text,
                // Named so a test can read the answer without matching a
                // keypad key that happens to show the same digit.
                key: const ValueKey<String>('answer-draft'),
                textScaler: TextScaler.noScaling,
                style: BrandText.numeral(40),
              ),
            ),
          ),
        ),
        if (verdict != null) ...<Widget>[
          const SizedBox(width: BrandShape.space4),
          VerdictRing(verdict),
        ],
      ],
    );
  }
}
