import 'package:flutter/widgets.dart';

import '../../../api/history.dart';
import '../../../design/brand/aki.dart';
import '../../../design/icons/brand_icon.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/icon_button_tile.dart';
import '../../../design/widgets/stat_tile.dart';
import '../../shell/policy/banner_visual.dart';
import '../../shell/ui/inline_banner.dart';
import '../../shell/ui/skeleton_block.dart';
import '../../states/policy/account_state.dart';
import '../../states/ui/account_state_view.dart';
import '../policy/history_view.dart';
import '../policy/profile_readout.dart';

/// `Perfil` — the identity, the headline pair, the tile row and the history
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
/// **The screen draws what it is handed and decides nothing.** Which figures
/// exist, what each one is called and how each is spelt is [ProfileFigures] and
/// the three functions beside it.
///
/// **Nothing it is handed is invented any more.** Accuracy and mean time come
/// from the record `features/stats/` keeps of what was answered; the days, the
/// run and the count of challenges were always the device's. A rating is handed
/// over by nobody — `GET /me/standing` answers one *per skill* and there is no
/// single number to print — and a weekly move by nobody either, since
/// `ratingDelta` is one session's movement on one skill's scale and a week is
/// not the sum of them. Both are simply not drawn, the same rule that makes
/// `HISTORIAL` disappear when there is nothing true to say.
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
    required this.figures,
    required this.historyState,
    this.accountEmail,
    this.entries = const <HistoryEntry>[],
    this.onCreateAccount,
    this.onSignIn,
    this.onRetryAccount,
    this.onRetryHistory,
    this.onSignOut,
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

  /// Every number the screen prints, and the one seam an invented figure is
  /// swapped for a real one at.
  final ProfileFigures figures;

  final HistoryState historyState;

  /// Newest first, exactly as the server ordered them.
  final List<HistoryEntry> entries;

  /// Offered only where the build has endpoints to reach (DR-P2).
  final VoidCallback? onCreateAccount;

  /// The returning player's door, beside the new player's.
  ///
  /// **Two errands, two controls.** The only way into `Iniciar sesión` used
  /// to be a text link at the bottom of `Crear cuenta`, past the age gate —
  /// so coming back to an account meant being asked when you were born. Drawn
  /// as the secondary weight because exactly one control on a screen is *the*
  /// action, and for a signed-out profile that is still making an account.
  final VoidCallback? onSignIn;

  /// Offered only where retrying could change the answer.
  final VoidCallback? onRetryAccount;

  /// Leaves the account, where doing so is the way out.
  ///
  /// **Present only when [accountDoorFor] says so** — the caller asks the
  /// policy, this screen only draws what it was handed. Signing out is always
  /// *possible* with a session; it is the answer to exactly one state.
  final VoidCallback? onSignOut;

  /// Offered only where [canRetryHistory] says asking again could answer
  /// differently — the screen does not decide that, it asks.
  final VoidCallback? onRetryHistory;

  /// The avatar tile: `4.1` clips a 66 px full-body Aki inside a 78 px tile.
  static const double _tile = 78;
  static const double _aki = 66;

  /// The headline figure, at the size the design sets it.
  static const double _headlineNumeral = 42;

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
            // **The conflict this device can resolve, and it gets the same
            // shape the refused session gets.** A chip inside the banner was
            // tried and does not fit: at textScaler 1.3 the row overflowed by
            // 65 px and the chip fell under the 48 px floor, because a banner
            // action cannot wrap. A full-width door is also the more findable
            // of the two, and it is already this screen's idiom for *"a state
            // with a way out"*.
            if (onSignOut != null) ...<Widget>[
              const SizedBox(height: BrandShape.space3),
              BrandButton.secondary(
                label: signOutDoorLabel,
                onPressed: onSignOut!,
              ),
            ],
            // **A refused session is the one state with an address and a way
            // out.** The section above it says *"Vuelve a entrar"* and, until
            // this, offered nothing that could — the door required there to be
            // no session, and a refused one is still a session.
            if (onSignIn != null) ...<Widget>[
              const SizedBox(height: BrandShape.space3),
              BrandButton.secondary(
                label: signInDoorLabel(accountState),
                onPressed: onSignIn!,
              ),
            ],
          ] else
            ..._doors(),
          const SizedBox(height: BrandShape.space4),
          _headlinePair(),
          const SizedBox(height: BrandShape.space2),
          _tiles(),
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

  /// The two ways in, for a device with no session.
  ///
  /// Each is drawn only where its caller hands a callback, the same rule every
  /// other optional control on this screen follows: one that cannot act reads
  /// as broken rather than as unbuilt (DR-P2).
  List<Widget> _doors() {
    final VoidCallback? create = onCreateAccount;
    final VoidCallback? signIn = onSignIn;
    return <Widget>[
      if (create != null) ...<Widget>[
        const SizedBox(height: BrandShape.space3),
        BrandButton.primary(label: 'Crear cuenta', onPressed: create),
      ],
      if (signIn != null) ...<Widget>[
        SizedBox(height: create == null ? BrandShape.space3 : BrandShape.space2),
        BrandButton.secondary(
          label: signInDoorLabel(accountState),
          onPressed: signIn,
        ),
      ],
    ];
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
  /// The design puts the white card at `flex 1.3` beside the **yellow** one at
  /// `flex 1`, because the filled card is the one the screen is about and two
  /// identical tiles say the two rank equally.
  Widget _headlinePair() => IntrinsicHeight(
    // **The two cards match heights.** `stretch` alone asks for infinite
    // height inside a scroll view; `IntrinsicHeight` is what gives the row
    // a height to stretch to. With two children the cost is a second
    // layout pass, which is what the design's matched pair is worth.
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(flex: 13, child: _card(headlineLead(figures), _CardFill.plain)),
        const SizedBox(width: BrandShape.space2),
        Expanded(flex: 10, child: _card(headlineRun(figures), _CardFill.filled)),
      ],
    ),
  );

  Widget _card(HeadlineCard card, _CardFill fill) => CandySurface(
    background: fill.background,
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
          card.label,
          style: BrandText.eyebrow(
            color: fill.quiet,
            size: 11,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(card.value, style: BrandText.numeral(_headlineNumeral)),
        ),
        if (card.note != null) ...<Widget>[
          const SizedBox(height: 2),
          _note(card, fill),
        ],
      ],
    ),
  );

  /// The line under the figure: a sign run, then the words.
  ///
  /// Two runs and not one span, because the design sets the sign heavier and —
  /// when the week gained — in another hue, and because `EsMxNumber` hands a
  /// sign back separately so no screen concatenates a hyphen where the brand
  /// requires U+2212.
  Widget _note(HeadlineCard card, _CardFill fill) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: <Widget>[
      if (card.sign.isNotEmpty) ...<Widget>[
        Text(
          card.sign,
          style: BrandText.action(
            color: switch (card.tone) {
              NoteTone.gain => BrandColorRole.success.color,
              NoteTone.plain => fill.quiet,
            },
            size: 12,
          ),
        ),
        const SizedBox(width: 3),
      ],
      Flexible(
        child: Text(
          card.note!,
          style: BrandText.caption(color: fill.quiet, size: 12, height: 1.2),
        ),
      ),
    ],
  );

  /// The row of small tiles under the headline pair.
  ///
  /// **Each takes an equal share and each figure scales down inside it**, the
  /// shape `3.4`'s tiles already use: three natural-width tiles overflow 390 px,
  /// and `Expanded` plus a `FittedBox` keeps a long figure inside its own tile
  /// rather than pushing the next one off the edge at `textScaler` 1.3.
  ///
  /// The row is as long as `profileTiles` says. One tile is as legitimate as
  /// three — it is the shipping build — and the list is never empty, so this is
  /// never a gap between two cards.
  Widget _tiles() {
    final List<ProfileTile> tiles = profileTiles(figures);

    return Row(
      children: <Widget>[
        for (int index = 0; index < tiles.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: BrandShape.space2),
          Expanded(
            child: StatTile(
              // The design sets this label at 10 px against the token's 12.
              // `StatTile` is the widget three other screens use for exactly
              // this row and a second spelling of it would be the duplication
              // worth more than two pixels of tracking.
              label: tiles[index].label,
              value: FittedBox(
                fit: BoxFit.scaleDown,
                child: StatValue(
                  tiles[index].value,
                  size: StatTileVariant.compact.valueSize,
                ),
              ),
              variant: StatTileVariant.compact,
            ),
          ),
        ],
      ],
    );
  }

  Widget _history() {
    if (historyState == HistoryState.loading) {
      // `Cargando` — content-shaped placeholders, never a spinner. A
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
  /// **No rating column, whatever the headline says.** F4 made `ratingDelta` a
  /// real figure and a row still does not print it: it is null for a session
  /// that spanned two skills and for one that only calibrated, so a column
  /// would be blank on exactly the sessions a mixed pack produces, and nothing
  /// has decided what a row should read there. A headline figure the product
  /// cannot compute is a placeholder on a screen; a `± 0` printed against a
  /// session nothing measured would be a record of something that did not
  /// happen.
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

/// Which of the headline pair a card is.
///
/// Two arms rather than a colour compared at the point of use: the design fills
/// one of the two and leaves the other white, and the secondary ink follows the
/// fill — on the yellow card the muted violet loses its contrast.
enum _CardFill {
  plain(background: BrandColors.surface, quiet: BrandColors.muted),
  filled(background: BrandColors.yellow, quiet: BrandColors.ink);

  const _CardFill({required this.background, required this.quiet});

  final Color background;

  /// The eyebrow and the note's ink on this fill.
  final Color quiet;
}
