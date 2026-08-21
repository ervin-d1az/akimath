import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/detail_header.dart';

/// The frame `4.3` through `4.7` share: a header, a way back, and a scrolling
/// column of cards.
///
/// **The list scrolls, and that is a gate rather than a preference.** Every
/// registered screen is pumped at `textScaler` 1.3, where four cards of fixed
/// height do not fit 844 pixels. A `ListView` cannot overflow; a `Column` can,
/// and the screens that came before this one each wrote the same one by hand.
class SettingsDetailScaffold extends StatelessWidget {
  const SettingsDetailScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.children,
  });

  final String title;
  final VoidCallback onBack;

  /// The cards, in the order the design stacks them. Spacing is this widget's,
  /// so no screen restates it.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: title, onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BrandShape.space4,
              BrandShape.space5,
              BrandShape.space4,
              BrandShape.space4,
            ),
            children: <Widget>[
              for (int index = 0; index < children.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(height: BrandShape.space3),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A white card with an optional eyebrow over its content.
///
/// The shape the design gives every grouped control on `4.4` through `4.7`:
/// radius 22, the tile shadow, and the eyebrow in the muted caps the rest of
/// the app already uses.
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({super.key, required this.child, this.eyebrow});

  final Widget child;

  /// `¿A QUÉ HORA?`, `TAMAÑO DE TEXTO`, `VOLUMEN`. Absent where the card leads
  /// with a title of its own.
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final String? heading = eyebrow;

    return CandySurface(
      borderRadius: BrandShape.radiusCardSmall,
      shadowOffset: BrandShape.shadowTile,
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (heading != null) ...<Widget>[
            Text(heading, style: BrandText.eyebrow()),
            const SizedBox(height: BrandShape.space3),
          ],
          child,
        ],
      ),
    );
  }
}
