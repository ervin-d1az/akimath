import 'package:flutter/widgets.dart';

import '../../../design/brand/aki.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';

/// Where a band below the threshold goes, and it is not the account form.
///
/// **`req-age-gate` says no path reaches `1.2` from here** — not back, not
/// resubmit, not relaunch. So this screen offers exactly one way on, and it is
/// backwards.
///
/// What a tutor-consent flow *collects* is Gate A's question and is not decided
/// (DR-7). Until it is, the honest screen is the one that says play continues
/// and nothing is sent — which is true, and is the whole of ADR 0002's position
/// for an unlinked player.
class TutorConsentScreen extends StatelessWidget {
  const TutorConsentScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Spacer(),
          Center(child: Aki(width: 150, semanticLabel: 'Aki')),
          const SizedBox(height: BrandShape.space4),
          Text(
            'Sigue jugando',
            textAlign: TextAlign.center,
            style: BrandText.sectionTitle(),
          ),
          const SizedBox(height: BrandShape.space3),
          Text(
            'Para crear una cuenta necesitamos el permiso de tu mamá, tu papá o '
            'tu tutor. Mientras tanto tus retos se guardan en este teléfono y '
            'nada se envía.',
            textAlign: TextAlign.center,
            style: BrandText.body(),
          ),
          const Spacer(),
          BrandButton.primary(label: 'Volver a los retos', onPressed: onBack),
        ],
      ),
    );
  }
}
