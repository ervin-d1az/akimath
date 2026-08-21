import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../shell/policy/banner_visual.dart';
import '../../shell/ui/app_shell.dart';
import '../../shell/ui/inline_banner.dart';
import '../../shell/ui/skeleton_block.dart';
import '../policy/account_state.dart';
import '../policy/server_error_note.dart';
import 'server_error_screen.dart';

/// The chip on a banner: a label and what pressing it does, or neither.
typedef _BannerAction = ({String label, VoidCallback press});

/// What the account section shows, for every state it can be in.
///
/// **One widget for seven states**, because the alternative is a `switch` on a
/// screen that grows a branch each time and never grows the one nobody
/// remembers.
///
/// `4.11 Cargando` is **skeletons and no spinner**. The plan says
/// *"esqueletos, sin ruedita"* and forbids repurposing `LoadingDots`;
/// `test/design/no_spinner_test.dart` keeps that true.
///
/// `4.9 Sin conexión` is a **notice**, not an error — yellow, not coral:
/// *"Sin conexión no es un error del usuario: va en amarillo."*
///
/// **A server error opens `4.10`, and offline does not open `4.9`.** The two
/// are drawn as full states and both survive as banners, because the design
/// itself draws `4.9` with its notice band *inside* the full state — they are
/// two surfaces, not two renderings of one. A banner belongs where the screen
/// around it is still true, and Perfil's días and racha are true with no
/// signal; the full state is what you get when the thing you asked for is the
/// whole screen.
///
/// The asymmetry is not an oversight. `4.10` needs nothing this section does
/// not have, so the banner is a door to it. `4.9` is *about a count* — its
/// headline is *"TRAES 40 RETOS EN LA BOLSA"* — and the profile holds no pack:
/// the bundled one is not necessarily the one in play, since a linked device
/// plays an issued pack instead. Opening it from here would put a guessed
/// figure in a headline, so it is reached from the home, which holds the real
/// pack.
class AccountStateView extends StatelessWidget {
  const AccountStateView({
    super.key,
    required this.state,
    this.email,
    this.onRetry,
    this.now = DateTime.now,
  });

  final AccountState state;
  final String? email;
  final VoidCallback? onRetry;

  /// Reads the wall clock for `4.10`'s note. Injected rather than called
  /// directly so the pushed screen is the same screen on every run.
  final DateTime Function() now;

  /// The chip the door asks for, when the caller supplied something to run.
  ///
  /// **A door with no callback draws nothing** — that is DR-P2, and it is why
  /// each arm checks: a chip that opens onto a dead end teaches the player the
  /// button is decoration.
  _BannerAction? _actionFor(AccountDoor door, BuildContext context) {
    final VoidCallback? retry = onRetry;

    return switch (door) {
      // `4.10` carries the retry itself, so the chip opens it rather than
      // running the retry twice over.
      AccountDoor.detail when retry != null =>
        (label: 'Detalle', press: () => _openServerError(context)),
      AccountDoor.retry when retry != null =>
        (label: 'Reintentar', press: retry),
      // **Not a chip.** A banner action cannot wrap, and at textScaler 1.3
      // this label overflowed the row by 65 px and fell under the 48 px floor.
      // `ProfileScreen` draws it as a full-width door instead, which is the
      // idiom the refused session already uses.
      AccountDoor.signOut ||
      AccountDoor.none ||
      AccountDoor.detail ||
      AccountDoor.retry => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (state == AccountState.loading) {
      return const _Loading();
    }

    final String? message = switch (state) {
      AccountState.linked => 'Tus retos se guardan en esta cuenta.',
      AccountState.noPlayer => 'Cuenta lista. Falta vincular un jugador.',
      AccountState.rejected => 'Tu sesión caducó. Vuelve a entrar.',
      AccountState.serverError => 'No pudimos consultar tu cuenta.',
      AccountState.offline => 'Sin conexión. Tus retos siguen aquí.',
      // One account, one player (migration 0003). Which phone the account
      // belongs to is a choice nobody has designed, so this says what is true
      // and offers nothing it cannot do. **It names a phone because there is
      // one**: the account holds a player this device did not mint.
      AccountState.otherDevice => 'Esta cuenta ya se está usando en otro teléfono.',
      // The mirror case, and the one a real device hit. It names no phone,
      // because there need not be a second one — the same handset can hold one
      // account's progress and be signed in to another.
      AccountState.otherAccount =>
        'Lo que llevas en este teléfono es de otra cuenta. Entra con esa para verlo.',
      // Both facts are true of both conflicts, and neither guesses which.
      AccountState.mismatch =>
        'Esta cuenta y lo que llevas en este teléfono no van juntos.',
      AccountState.none || AccountState.loading => null,
    };

    // Only the states somebody has to act on get a banner. `linked` and
    // `noPlayer` are ordinary and read as plain text; a banner on every state
    // is a banner nobody reads.
    final bool banner = state == AccountState.serverError ||
        state == AccountState.offline ||
        state == AccountState.otherDevice ||
        state == AccountState.otherAccount ||
        state == AccountState.mismatch;

    // **What to press comes from the policy, not from three booleans here.**
    // `otherDevice` was drawn with no action for as long as it existed because
    // nothing in this build method mentioned it; `accountDoorFor` is the one
    // place a new state has to be answered for.
    final _BannerAction? action = _actionFor(accountDoorFor(state), context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (email != null)
          Text(
            email!,
            key: const Key('account-email'),
            style: BrandText.body(),
          ),
        if (message != null) ...<Widget>[
          const SizedBox(height: BrandShape.space2),
          if (banner)
            InlineBanner(
              key: const Key('account-banner'),
              // Ours to apologise for, or nobody's — which is the whole of
              // what the hue encodes.
              kind: isOurFault(state) ? BannerKind.error : BannerKind.notice,
              message: message,
              onAction: action?.press,
              actionLabel: action?.label,
            )
          else
            Text(
              message,
              key: const Key('account-status'),
              style: BrandText.caption(),
            ),
        ],
      ],
    );
  }
}

/// Opens `4.10` over the profile, carrying the retry the banner was offering.
///
/// **Pushed from the view rather than handed down as a callback.** Every other
/// push in this app is owned by a route, and that is the shape to prefer; this
/// one is here because the profile route is the caller and the alternative is
/// a parameter it does not pass — an unreachable screen. A `ProfileRoute` that
/// grows an `onOpenServerError` should take this over and this method should
/// go.
extension on AccountStateView {
  void _openServerError(BuildContext context) {
    pushSession<void>(
      context,
      (BuildContext pushed) => ServerErrorScreen(
        // The state carries no status code — `accountStateFor` collapses every
        // unusable answer into one member — so the note names only the time.
        note: serverErrorNote(status: null, at: now()),
        onRetry: () {
          Navigator.of(pushed).pop();
          onRetry!();
        },
        // Nothing here can start a series: the round lives on the other tab.
      ),
    );
  }
}

/// `4.11 Cargando` — content-shaped placeholders, never a spinner.
///
/// A skeleton says *"something this shape is coming"*; a spinner says
/// *"wait"* and nothing else. The shapes here are the address and the line
/// under it, which is exactly what replaces them.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('account-loading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        SkeletonBlock(width: 220, height: 18),
        SizedBox(height: BrandShape.space2),
        SkeletonBlock(width: 150, height: 13),
      ],
    );
  }
}

/// The section's own frame, so the caller does not repeat the card.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CandySurface(
    padding: const EdgeInsets.all(BrandShape.space3),
    child: child,
  );
}
