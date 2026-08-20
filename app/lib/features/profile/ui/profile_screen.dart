import 'package:flutter/widgets.dart';

import '../../../api/history.dart';
import '../../../design/brand/aki.dart';
import '../../../design/icons/brand_icon.dart';
import '../../../design/math/spec/es_mx_number.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/icon_button_tile.dart';
import '../../shell/policy/banner_visual.dart';
import '../../shell/ui/inline_banner.dart';
import '../../shell/ui/skeleton_block.dart';
import '../../states/policy/account_state.dart';
import '../../states/ui/account_state_view.dart';
import '../policy/history_view.dart';

/// `4.1 Perfil` — the identity, the figures the device knows and the history
/// the server reports, in the order the design draws them.
///
/// **It absorbed `Avance`, which no document ever drew.** That root existed
/// because the shell needed a second one and the two device figures needed a
/// home; every line on it is a line `4.1` puts under the identity. Splitting
/// them left two half-empty screens where the design has one full one.
///
/// **Two halves that fail independently.** The figures come from storage and
/// are always available — a phone that has never synced still knows what it
/// did. The history needs a session and a network, and it has every state a
/// request has plus the one that is not a request: there is no account, so
/// there is nothing to ask, and that is an invitation rather than an error.
///
/// **No rating, no accuracy, no mean time.** Each is F4 or needs an aggregate
/// no endpoint answers; `GET /me/standing` is still 501 and `GET /me/history`
/// reports sessions rather than totals. The same reading that keeps a rating
/// off the verdict screens.
///
/// **Aki appears once, inside the avatar tile.** Declared rule 5 names her
/// homes — *inicio, resultados, estados de racha y tutorial* — and the profile
/// is not one. `Avance` drew her loose at 110 px with a line of encouragement;
/// a warm line is a poor reason to break a rule the same document states.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.accountState,
    required this.onOpenSettings,
    required this.daysPractised,
    required this.streakDays,
    required this.historyState,
    this.accountEmail,
    this.entries = const <HistoryEntry>[],
    this.onCreateAccount,
    this.onRetryAccount,
    this.onRetryHistory,
  });

  /// The linked account's address, once there is one.
  ///
  /// `4.1` greets a name. A player has none — the app never asks for one — so
  /// the address stands in, which is the reading Q5 already settled.
  final String? accountEmail;

  /// Where the account stands with our own server.
  final AccountState accountState;

  /// Opens the settings stack. The one thing on this screen that navigates,
  /// and the design's own: `4.1` puts a 48×48 gear at the end of the identity
  /// row and nothing else on it goes anywhere.
  final VoidCallback onOpenSettings;

  /// Distinct days recorded on this device.
  final int daysPractised;

  /// From `StreakPolicy` — the same local fact the home shows.
  final int streakDays;

  final HistoryState historyState;

  /// Newest first, exactly as the server ordered them.
  final List<HistoryEntry> entries;

  /// Offered only where the build has endpoints to reach (DR-P2).
  final VoidCallback? onCreateAccount;

  /// Offered only where retrying could change the answer.
  final VoidCallback? onRetryAccount;

  /// Offered only where [canRetryHistory] says asking again could answer
  /// differently — the screen does not decide that, it asks.
  final VoidCallback? onRetryHistory;

  /// The avatar tile: `4.1` clips a 66 px full-body Aki inside a 78 px tile.
  static const double _tile = 78;
  static const double _aki = 66;

  @override
  Widget build(BuildContext context) {
    final String? email = accountEmail;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _identity(email),
          if (email != null) ...<Widget>[
            const SizedBox(height: BrandShape.space3),
            // **No `email:`.** The identity row above owns the address, and
            // handing it to the state view too drew it twice.
            AccountSection(
              child: AccountStateView(
                state: accountState,
                onRetry: onRetryAccount,
              ),
            ),
          ] else if (onCreateAccount != null) ...<Widget>[
            const SizedBox(height: BrandShape.space3),
            BrandButton.primary(
              label: 'Crear cuenta',
              onPressed: onCreateAccount!,
            ),
          ],
          const SizedBox(height: BrandShape.space4),
          _headlineStats(),
          // **No heading over nothing.** Two states have no section at all —
          // see `historyWorthDrawing`. A `HISTORIAL` that is always empty is a
          // promise the product cannot keep yet.
          if (historyWorthDrawing(historyState)) ...<Widget>[
            const SizedBox(height: BrandShape.space5),
            Text('HISTORIAL', style: BrandText.eyebrow()),
            const SizedBox(height: BrandShape.space3),
            _history(),
          ],
        ],
      ),
    );
  }

  Widget _identity(String? email) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      CandySurface.tile(
        size: _tile,
        // **Not `pinkSoft` by conviction.** The design fills this tile
        // `#FFC9DC`, seven, six and four off the token — a near miss nobody
        // has decided is the same colour (Q2). Until somebody does, the
        // tile takes the accent the app already has rather than a
        // seventeenth pink.
        background: BrandColors.pinkSoft,
        borderRadius: BrandShape.radiusCardMedium,
        child: Aki(width: _aki, semanticLabel: 'Aki'),
      ),
      const SizedBox(width: BrandShape.space3),
      Expanded(
        child: Text(
          email ?? 'Sin cuenta en este teléfono',
          style: email == null
              ? BrandText.caption()
              : BrandText.cardTitle(size: 16),
        ),
      ),
      const SizedBox(width: BrandShape.space2),
      Semantics(
        button: true,
        label: 'Ajustes',
        child: IconButtonTile(
          onPressed: onOpenSettings,
          child: const BrandIcon(BrandGlyph.gear, size: 20),
        ),
      ),
    ],
  );

  /// The headline pair, with the hierarchy `4.1` draws between its two.
  ///
  /// The design puts a white `RATING` card at `flex 1.3` beside a **yellow**
  /// `RACHA` card at `flex 1`. Rating is absent, so the wider slot takes the
  /// honest figure we have and the run keeps the fill — because the filled card
  /// is the one the screen is about, and two identical tiles say the two rank
  /// equally.
  Widget _headlineStats() => IntrinsicHeight(
    // **The two cards match heights.** `stretch` alone asks for infinite
    // height inside a scroll view; `IntrinsicHeight` is what gives the row
    // a height to stretch to. With two children the cost is a second
    // layout pass, which is what the design's matched pair is worth.
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          flex: 13,
          child: _statCard(
            label: 'DÍAS',
            value: daysPractised,
            unit: 'practicando',
            background: BrandColors.surface,
          ),
        ),
        const SizedBox(width: BrandShape.space2),
        Expanded(
          flex: 10,
          child: _statCard(
            label: 'RACHA',
            value: streakDays,
            unit: streakDays == 1 ? 'día seguido' : 'días seguidos',
            background: BrandColors.yellow,
          ),
        ),
      ],
    ),
  );

  Widget _statCard({
    required String label,
    required int value,
    required String unit,
    required Color background,
  }) => CandySurface(
    background: background,
    borderRadius: BrandShape.radiusCardSmall,
    shadowOffset: BrandShape.shadowButton,
    padding: const EdgeInsets.symmetric(
      horizontal: BrandShape.space3,
      vertical: BrandShape.space3,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: BrandText.eyebrow(
            // On the filled card the muted eyebrow loses its contrast, so
            // it takes the ink the design gives it there.
            color: background == BrandColors.surface
                ? BrandColors.muted
                : BrandColors.ink,
            size: 11,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(EsMxNumber.integer(value), style: BrandText.numeral(38)),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: BrandText.caption(
            color: background == BrandColors.surface
                ? BrandColors.muted
                : BrandColors.ink,
            size: 12,
            height: 1.2,
          ),
        ),
      ],
    ),
  );

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

    // Every remaining state is a failure to fetch, so every one gets a banner.
    final String message = historyMessage(historyState)!;

    // **The policy decides, not the banner.** A refused session earns a banner
    // and no retry: asking again with the same dead token gets the same
    // refusal, and a button that cannot work teaches the player the app is
    // broken rather than that their session is.
    final VoidCallback? retry = canRetryHistory(historyState)
        ? onRetryHistory
        : null;

    return InlineBanner(
      key: const Key('history-banner'),
      kind: isOurProblem(historyState) ? BannerKind.error : BannerKind.notice,
      message: message,
      onAction: retry,
      actionLabel: retry == null ? null : 'Reintentar',
    );
  }

  /// One session: what it was, how it went, and when.
  ///
  /// **No rating column.** `ratingDelta` is null for every entry a server
  /// without rating can produce, and a dash where a number will go is a promise
  /// this screen cannot keep yet.
  Widget _row(HistoryEntry entry) => CandySurface(
    borderRadius: BrandShape.radiusPill,
    shadowOffset: BrandShape.shadowPill,
    padding: const EdgeInsets.all(BrandShape.space3),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(entry.title, style: BrandText.cardTitle(size: 15)),
              const SizedBox(height: 2),
              // Local, not UTC: a player who practised at nine in the
              // evening should not read tomorrow's date.
              Text(entryDate(entry.at.toLocal()), style: BrandText.caption()),
            ],
          ),
        ),
        const SizedBox(width: BrandShape.space3),
        Text(entry.score, style: BrandText.cardTitle(size: 15)),
      ],
    ),
  );
}
