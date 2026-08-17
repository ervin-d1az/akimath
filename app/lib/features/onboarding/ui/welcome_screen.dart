import 'package:flutter/widgets.dart';

import '../../../design/brand/aki.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/speech_bubble.dart';

/// `0.2 Bienvenida` — the first thing a new player sees.
///
/// **Aki belongs here.** The rule is that she never appears while the learner is
/// *solving*; this is a greeting, not a solve. She is absent from `0.3` for the
/// same rule that puts her on this screen.
///
/// **No account, and nothing that looks like one.** The first run reaches a
/// solved item with no registration and no network call — that is the
/// requirement, not an omission, and a test asserts no field asks for an email
/// or a password.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  /// Larger than the home's 150: this is the one screen where she is the
  /// subject rather than the company.
  static const double _akiWidth = 200;

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
          Center(child: Aki(width: _akiWidth, semanticLabel: 'Aki')),
          const SizedBox(height: BrandShape.space4),
          const Center(
            child: SpeechBubble(
              text: 'Soy Aki. Te acompaño con las mates.',
              maxWidth: 260,
            ),
          ),
          const SizedBox(height: BrandShape.space5),
          Text(
            'Resolvemos retos cortos, a tu ritmo.',
            textAlign: TextAlign.center,
            style: BrandText.body(),
          ),
          const Spacer(),
          BrandButton.primary(label: 'Resolver uno', onPressed: onStart),
        ],
      ),
    );
  }
}
