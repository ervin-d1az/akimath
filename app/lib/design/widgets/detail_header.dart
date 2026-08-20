import 'package:flutter/widgets.dart';

import '../icons/brand_icon.dart';
import '../tokens/tokens.dart';
import 'icon_button_tile.dart';

/// The header `4.2` through `4.7` share: a way back and a display title.
///
/// **The title fits rather than choosing from six sizes.** The design draws it
/// at 40, 38, 34, 34, 32 and 32 across those six screens, shrinking as the
/// words lengthen. Six constants would be six chances to pick the wrong one and
/// the seventh screen would have none — so this renders at the largest and
/// scales down only as far as it must, which reproduces every one of the six
/// and answers the seventh. It also survives a `textScaler` the design never
/// considered.
class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  /// The design's largest header, which a short title gets in full.
  static const double titleSize = 40;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrandShape.space4,
        BrandShape.space1,
        BrandShape.space4,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Semantics(
            button: true,
            label: 'Volver',
            child: IconButtonTile(
              onPressed: onBack,
              child: const BrandIcon(BrandGlyph.back, size: 20),
            ),
          ),
          const SizedBox(width: BrandShape.space3),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                style: BrandText.sectionTitle(size: titleSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
