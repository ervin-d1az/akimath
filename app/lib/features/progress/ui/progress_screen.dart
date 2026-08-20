import 'package:flutter/widgets.dart';

import '../../../api/history.dart';
import '../../../design/brand/aki.dart';
import '../../../design/math/spec/es_mx_number.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/speech_bubble.dart';
import '../../../design/widgets/stat_tile.dart';
import '../../shell/policy/banner_visual.dart';
import '../../shell/ui/inline_banner.dart';
import '../../shell/ui/skeleton_block.dart';
import '../policy/progress_view.dart';

/// `Avance` — what the player has done, from both places that know.
///
/// **Two halves that fail independently.** The figures on the left are the
/// device's and are always true: a phone that has never synced still knows what
/// it did. The history under them is the server's, and it has every state a
/// request has plus the one that is not a request — there is no account, so
/// there is nothing to ask, and that is an invitation rather than an error.
///
/// **No rating and no accuracy.** Both are `4.1 Perfil`'s and both are F4's:
/// `ratingDelta` comes back null from a server that has no rating, and a screen
/// printing "±0" would be inventing a figure. The same reason the verdict
/// screens show none.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
    super.key,
    required this.daysPractised,
    required this.streakDays,
    required this.historyState,
    this.entries = const <HistoryEntry>[],
    this.onRetryHistory,
  });

  /// Distinct days recorded on this device.
  final int daysPractised;

  /// From `StreakPolicy` — the same local fact the home shows.
  final int streakDays;

  final HistoryState historyState;

  /// Newest first, exactly as the server ordered them.
  final List<HistoryEntry> entries;

  /// Offered only where [canRetryHistory] says asking again could answer
  /// differently — the screen does not decide that, it asks.
  final VoidCallback? onRetryHistory;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('TU PROGRESO', style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space3),
          Row(
            children: <Widget>[
              Expanded(child: _tile('DÍAS', daysPractised)),
              const SizedBox(width: BrandShape.space2),
              Expanded(child: _tile('RACHA', streakDays)),
            ],
          ),
          const SizedBox(height: BrandShape.space5),
          Text('HISTORIAL', style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space3),
          _history(),
          const SizedBox(height: BrandShape.space5),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Aki(width: 110, semanticLabel: 'Aki'),
                const SizedBox(height: BrandShape.space3),
                const SpeechBubble(
                  text: 'Cada día que juegas cuenta, aunque falles.',
                  maxWidth: 300,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _history() {
    if (historyState == HistoryState.loading) {
      // `4.11 Cargando` — content-shaped placeholders, never a spinner. A
      // skeleton says "something this shape is coming"; a spinner says "wait".
      return const Column(
        key: Key('history-loading'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBlock(width: 260, height: 20),
          SizedBox(height: BrandShape.space2),
          SkeletonBlock(width: 200, height: 20),
        ],
      );
    }

    if (historyState == HistoryState.ready) {
      return Column(
        key: const Key('history-list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final HistoryEntry entry in entries) ...<Widget>[
            _row(entry),
            const SizedBox(height: BrandShape.space2),
          ],
        ],
      );
    }

    final String message = historyMessage(historyState)!;
    // Only the two somebody has to act on get a banner. An invitation and an
    // empty list are ordinary and read as plain text; a banner on every state
    // is a banner nobody reads.
    final bool banner = historyState == HistoryState.serverError ||
        historyState == HistoryState.offline ||
        historyState == HistoryState.rejected;

    // **The policy decides, not the banner.** A refused session earns a banner
    // and no retry: asking again with the same dead token gets the same
    // refusal, and a button that cannot work teaches the player the app is
    // broken rather than that their session is.
    final VoidCallback? retry =
        canRetryHistory(historyState) ? onRetryHistory : null;

    return banner
        ? InlineBanner(
            key: const Key('history-banner'),
            kind: isOurProblem(historyState) ? BannerKind.error : BannerKind.notice,
            message: message,
            onAction: retry,
            actionLabel: retry == null ? null : 'Reintentar',
          )
        : Text(message, key: const Key('history-note'), style: BrandText.caption());
  }

  /// One session: what it was, how it went, and when.
  ///
  /// **No rating column.** `ratingDelta` is null for every entry a server
  /// without rating can produce, and a dash where a number will go is a promise
  /// this screen cannot keep yet.
  Widget _row(HistoryEntry entry) => CandySurface(
        borderRadius: BrandShape.radiusCardMedium,
        padding: const EdgeInsets.all(BrandShape.space3),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(entry.title, style: BrandText.cardTitle()),
                  const SizedBox(height: 2),
                  // Local, not UTC: a player who practised at nine in the
                  // evening should not read tomorrow's date.
                  Text(entryDate(entry.at.toLocal()), style: BrandText.caption()),
                ],
              ),
            ),
            const SizedBox(width: BrandShape.space3),
            Text(entry.score, style: BrandText.cardTitle()),
          ],
        ),
      );

  Widget _tile(String label, int value) => StatTile(
        label: label,
        value: FittedBox(
          fit: BoxFit.scaleDown,
          child: StatValue(
            EsMxNumber.integer(value),
            size: StatTileVariant.compact.valueSize,
          ),
        ),
        variant: StatTileVariant.compact,
      );
}
