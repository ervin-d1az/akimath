import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../shell/policy/banner_visual.dart';
import '../../shell/ui/inline_banner.dart';
import '../../shell/ui/skeleton_block.dart';
import '../policy/account_state.dart';

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
class AccountStateView extends StatelessWidget {
  const AccountStateView({
    super.key,
    required this.state,
    this.email,
    this.onRetry,
  });

  final AccountState state;
  final String? email;
  final VoidCallback? onRetry;

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
      AccountState.none || AccountState.loading => null,
    };

    // Only the two states somebody has to act on get a banner. `linked` and
    // `noPlayer` are ordinary and read as plain text; a banner on every state
    // is a banner nobody reads.
    final bool banner =
        state == AccountState.serverError || state == AccountState.offline;

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
              onAction: onRetry,
              actionLabel: onRetry == null ? null : 'Reintentar',
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
