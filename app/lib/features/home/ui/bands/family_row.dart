import 'package:flutter/widgets.dart';

import '../../../../design/tokens/tokens.dart';
import '../../../../design/widgets/candy_surface.dart';

/// `HOY JUEGAS` over the kinds of question today's series holds.
///
/// The one thing the old home said nothing about: that this is not a
/// times-tables app. Six families exist and any series draws five of them, so
/// the row is the shortest honest way to show the breadth before a player has
/// met it.
///
/// **A `Wrap`, not a `Row`.** Five or six chips at `textScaler` 1.3 do not fit
/// 390 px on one line, and the overflow gate measures exactly that. A wrap
/// reflows; a row clips for precisely the readers who chose large text.
class FamilyRow extends StatelessWidget {
  const FamilyRow({super.key, required this.families});

  final List<String> families;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('HOY JUEGAS', style: BrandText.eyebrow()),
        const SizedBox(height: BrandShape.space2),
        Wrap(
          spacing: BrandShape.space2,
          runSpacing: BrandShape.space2,
          children: <Widget>[
            for (final String family in families)
              CandySurface(
                borderRadius: BrandShape.radiusChip,
                borderWidth: BrandShape.borderWidthSmallSurface,
                shadowOffset: BrandShape.shadowPill,
                padding: const EdgeInsets.symmetric(
                  horizontal: BrandShape.space3,
                  vertical: BrandShape.space2,
                ),
                child: Text(family, style: BrandText.caption()),
              ),
          ],
        ),
      ],
    );
  }
}
