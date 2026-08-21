import 'package:flutter/material.dart' show TextField, InputDecoration, InputBorder;
import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../policy/erasure.dart';

/// The one destructive act in the app, behind a question and a typed word.
///
/// **Two screens in one widget, keyed off `step == null`.** Before anything is
/// sent it asks; afterwards it reports. They are one file because the second is
/// only ever reached through the first, and splitting them would put the
/// question and its consequence in different places for a reader.
///
/// **The safe choice is the green one.** Green is action and success and
/// nothing else (BRD-1), and coral is error and nothing else — so a destructive
/// confirm cannot borrow either hue to signal danger. The design draws this
/// screen's field, eyebrow and confirm all in coral; none of the three may be.
/// What the screen can do instead is put the prominent button on the way out
/// and make the destructive one cost a word. Both are labelled plainly and both
/// are the same distance from a thumb; nothing is hidden, the default is simply
/// the one that does not lose data.
///
/// **The locked confirm is drawn and is not pressable.** A control the player
/// cannot see is a gate they cannot understand, and a control that answers a
/// press by doing nothing is the inert row DR-P2 rules out. `BrandColors.quiet`
/// is the one fill that reads as present but not as offered, and the surface
/// under it is not a [BrandButton] at all — there is no `onPressed` to reach.
///
/// **No spinner while it waits** — `test/design/no_spinner_test.dart` is the
/// rule, and here the honest thing is a sentence rather than a shape: the wait
/// is one request long.
class EraseAccountScreen extends StatelessWidget {
  const EraseAccountScreen({
    super.key,
    required this.step,
    required this.confirmWord,
    required this.onConfirm,
    required this.onCancel,
    required this.onDone,
    this.onRetry,
  });

  /// Where the attempt got to, or null while nothing has been sent.
  final ErasureStep? step;

  /// What the player has typed into the gate's field.
  ///
  /// **Owned by the caller, and it is the field's controller rather than a
  /// string beside it.** What the field shows and what the gate reads are then
  /// one value; two would be two places stating one fact, and the one that
  /// could be wrong is the one deciding whether data is lost.
  final TextEditingController confirmWord;

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// Leaves the flow. Offered once there is nothing left to wait for.
  final VoidCallback onDone;

  /// Offered only where [canRetryErasure] says trying again could answer
  /// differently — the screen does not decide that, it asks.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ErasureStep? current = step;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: current == null ? _asking() : _reporting(current),
      ),
    );
  }

  List<Widget> _asking() => <Widget>[
        _headline(erasureConfirmHeadline),
        const SizedBox(height: BrandShape.space3),
        _detail(erasureConfirmDetail),
        const SizedBox(height: BrandShape.space5),
        _gate(),
        const SizedBox(height: BrandShape.space5),
        BrandButton.primary(label: erasureConfirmNo, onPressed: onCancel),
        const SizedBox(height: BrandShape.space2),
        // Rebuilt from the controller itself, so the screen stays a function of
        // what it was handed and the caller owns no listener of its own.
        ListenableBuilder(
          listenable: confirmWord,
          builder: (BuildContext context, Widget? _) =>
              erasureGateOpen(confirmWord.text)
                  ? BrandButton.secondary(
                      label: erasureConfirmYes,
                      onPressed: onConfirm,
                    )
                  : _lockedConfirm(),
        ),
      ];

  List<Widget> _reporting(ErasureStep current) => <Widget>[
        _headline(erasureHeadline(current)),
        const SizedBox(height: BrandShape.space3),
        _detail(erasureDetail(current)),
        const SizedBox(height: BrandShape.space5),
        if (canRetryErasure(current) && onRetry != null) ...<Widget>[
          BrandButton.primary(label: 'Reintentar', onPressed: onRetry!),
          const SizedBox(height: BrandShape.space2),
        ],
        // **Not while it is still in flight.** A way out drawn next to
        // "Borrando…" invites a tap that leaves the request running with
        // nowhere to land.
        if (current != ErasureStep.erasing)
          BrandButton.secondary(label: 'Volver', onPressed: onDone),
      ];

  Widget _gate() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(erasureConfirmPrompt, style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space1),
          CandySurface(
            // A resting field is quieter than a control the player can press,
            // which is the whole reason `borderWidthField` exists.
            borderWidth: BrandShape.borderWidthField,
            borderRadius: BrandShape.radiusControl,
            shadowOffset: BrandShape.shadowTile,
            padding: const EdgeInsets.symmetric(
              horizontal: BrandShape.space3,
              vertical: BrandShape.space2,
            ),
            child: TextField(
              key: const Key('erase-confirm-word'),
              controller: confirmWord,
              autocorrect: false,
              enableSuggestions: false,
              style: BrandText.body(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      );

  Widget _lockedConfirm() => CandySurface(
        background: BrandColors.quiet,
        borderRadius: BrandShape.radiusButton,
        // No shadow: a surface resting on one reads as a control that will
        // travel into it, and this one does not move.
        shadowOffset: Offset.zero,
        // The height a `BrandButton` occupies, so the column does not jump when
        // the word lands.
        minHeight: BrandShape.minTouchTarget,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: BrandShape.space5,
          vertical: BrandShape.space3,
        ),
        child: Text(
          erasureConfirmYes,
          style: BrandText.action(color: BrandColors.muted),
        ),
      );

  Widget _headline(String text) =>
      Text(text, textAlign: TextAlign.center, style: BrandText.sectionTitle());

  Widget _detail(String text) =>
      Text(text, textAlign: TextAlign.center, style: BrandText.body());
}
