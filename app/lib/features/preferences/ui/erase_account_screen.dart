import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../policy/erasure.dart';

/// The one destructive act in the app, behind a question.
///
/// **Two screens in one widget, keyed off `step == null`.** Before anything is
/// sent it asks; afterwards it reports. They are one file because the second is
/// only ever reached through the first, and splitting them would put the
/// question and its consequence in different places for a reader.
///
/// **The safe choice is the green one.** Green is action and success and
/// nothing else (BRD-1), and coral is error and nothing else — so a destructive
/// confirm cannot borrow either hue to signal danger. What it can do is put the
/// prominent button on the way out. Both are labelled plainly and both are the
/// same distance from a thumb; nothing is hidden, the default is simply the one
/// that does not lose data.
///
/// **No spinner while it waits** — `test/design/no_spinner_test.dart` is the
/// rule, and here the honest thing is a sentence rather than a shape: the wait
/// is one request long.
class EraseAccountScreen extends StatelessWidget {
  const EraseAccountScreen({
    super.key,
    required this.step,
    required this.onConfirm,
    required this.onCancel,
    required this.onDone,
    this.onRetry,
  });

  /// Where the attempt got to, or null while nothing has been sent.
  final ErasureStep? step;

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
        BrandButton.primary(label: erasureConfirmNo, onPressed: onCancel),
        const SizedBox(height: BrandShape.space2),
        BrandButton.secondary(label: erasureConfirmYes, onPressed: onConfirm),
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

  Widget _headline(String text) =>
      Text(text, textAlign: TextAlign.center, style: BrandText.sectionTitle());

  Widget _detail(String text) =>
      Text(text, textAlign: TextAlign.center, style: BrandText.body());
}
