import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../api/me_result.dart';
import '../policy/erasure.dart';
import 'erase_account_screen.dart';

/// Owns the one request the erasure flow makes, and nothing else.
///
/// **The socket arrives as a closure**, not as an `ApiClient`. The caller
/// already holds the token and the base URL and is the only place that should;
/// this widget's job is the sequence — ask, send, wait, report — and a seam
/// this narrow is one a widget test can drive without a loopback server, which
/// matters because `testWidgets` runs in a fake-async zone and a real socket
/// inside one hangs on `!timersPending`.
///
/// **Nothing closes on its own.** A success pops only when the player presses
/// `Volver`, because the screen it would skip is the one saying the address
/// still exists.
class EraseAccountRoute extends StatefulWidget {
  const EraseAccountRoute({
    super.key,
    required this.erase,
    required this.onClose,
  });

  /// Sends the request. Called once per attempt, never before the player says
  /// yes.
  final Future<EraseResult> Function() erase;

  /// Leaves the flow, saying whether anything was actually erased — the caller
  /// needs to know whether to forget the account it is holding.
  final void Function(bool erased) onClose;

  @override
  State<EraseAccountRoute> createState() => _EraseAccountRouteState();
}

class _EraseAccountRouteState extends State<EraseAccountRoute> {
  /// Null until the player says yes; then the step the attempt reached.
  ErasureStep? _step;

  /// The typed gate's field, owned here because this widget outlives the
  /// question — the screen is rebuilt into its reporting half and a controller
  /// created down there would go with it.
  final TextEditingController _confirmWord = TextEditingController();

  @override
  void dispose() {
    _confirmWord.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _step = ErasureStep.erasing);
    final EraseResult result = await widget.erase();
    if (!mounted) {
      // The request outlives the screen whenever a player backs out of a slow
      // erasure. Answering into a disposed widget is the one crash this route
      // has, and it is reachable.
      return;
    }
    setState(() => _step = erasureStepFor(result));
  }

  @override
  Widget build(BuildContext context) {
    final ErasureStep? step = _step;
    return EraseAccountScreen(
      step: step,
      confirmWord: _confirmWord,
      onConfirm: () => unawaited(_send()),
      onCancel: () => widget.onClose(false),
      onDone: () => widget.onClose(step == ErasureStep.gone),
      onRetry: step != null && canRetryErasure(step) ? () => unawaited(_send()) : null,
    );
  }
}
