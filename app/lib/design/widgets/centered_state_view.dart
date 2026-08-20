import 'package:flutter/widgets.dart';

import '../brand/aki.dart';
import '../tokens/tokens.dart';
import 'brand_button.dart';

/// The frame eleven screens share: something to look at, a headline, a line of
/// explanation, and a way out.
///
/// **The headline is a list, not a string** (`headlineLines`). The design draws
/// its own line breaks and they carry meaning — where a phrase turns is a
/// typographic decision, and letting the layout engine choose re-wraps it on
/// every screen width. A caller that does not care passes one element.
///
/// **Aki is optional and defaults to absent.** She may greet and she may
/// celebrate; she never appears while the learner is solving, and she has no
/// business on a server error either — an apology from the dog reads as the dog
/// being at fault.
///
/// Serves `4.8 Vacío`, `4.9 Sin conexión`, `4.10 Error de servidor`,
/// `4.12`–`4.15`, and four onboarding screens.
class CenteredStateView extends StatelessWidget {
  const CenteredStateView({
    super.key,
    required this.headlineLines,
    this.body,
    this.aki = false,
    this.content,
    this.primary,
    this.secondary,
  }) : assert(headlineLines.length > 0, 'a state with no headline says nothing');

  /// The headline, one entry per drawn line.
  final List<String> headlineLines;

  /// One sentence under the headline. Optional: some states are self-evident.
  final String? body;

  /// Whether Aki frames the state.
  final bool aki;

  /// Anything between the copy and the buttons — a stat row, a skeleton.
  final Widget? content;

  /// The way out. A state with no action is a dead end, so this is where the
  /// pressure to provide one lives; it is still optional, because
  /// `4.11 Cargando` genuinely has nothing to offer yet.
  final Widget? primary;
  final Widget? secondary;

  static const double _akiWidth = 150;

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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (aki) ...<Widget>[
                    Center(child: Aki(width: _akiWidth, semanticLabel: 'Aki')),
                    const SizedBox(height: BrandShape.space4),
                  ],
                  for (final String line in headlineLines)
                    Text(
                      line,
                      textAlign: TextAlign.center,
                      style: BrandText.sectionTitle(),
                    ),
                  if (body != null) ...<Widget>[
                    const SizedBox(height: BrandShape.space3),
                    Text(body!, textAlign: TextAlign.center, style: BrandText.body()),
                  ],
                  if (content != null) ...<Widget>[
                    const SizedBox(height: BrandShape.space5),
                    content!,
                  ],
                ],
              ),
            ),
          ),
          if (primary != null) ...<Widget>[
            const SizedBox(height: BrandShape.space4),
            primary!,
          ],
          if (secondary != null) ...<Widget>[
            const SizedBox(height: BrandShape.space3),
            secondary!,
          ],
        ],
      ),
    );
  }
}

/// A convenience for the common footer: one green button.
BrandButton stateAction(String label, VoidCallback onPressed) =>
    BrandButton.primary(label: label, onPressed: onPressed);
