import 'package:flutter/widgets.dart';

import '../../../design/painting/spec/dash_spec.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/centered_state_view.dart';

/// `Vacío` — the skills list before there is a skill in it.
///
/// **Nothing routes to this screen, and that is deliberate.** The design fills
/// it with dashed rows reading *"Aquí irá tu primera habilidad"*, which promise
/// a skills feature that does not exist: `GET /me/standing` answers `skills: []`
/// for every player because nothing writes `user_skills`. Routing it would
/// therefore show it to every player for ever — which is the exact defect
/// `historyWorthDrawing` was written to prevent, one level up. Its doc comment
/// records the incident: a section told a player *"los de hoy aparecen aquí"*
/// and they did not.
///
/// So this is built and registered, not wired. The day a skill can be earned,
/// the trigger is a linked account whose standing is empty, and the call site
/// is the screen that would otherwise draw the list.
class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({super.key, required this.onStart});

  /// Into the first series. The state resolves itself by being acted on, the
  /// same shape `4.12` has: the way out and the remedy are one act.
  final VoidCallback onStart;

  /// The design draws these rows at 56, above the 48 floor without being a
  /// touch target — they are not pressable, so the floor does not apply.
  static const double _placeholderRow = 56;

  @override
  Widget build(BuildContext context) {
    return CenteredStateView(
      aki: true,
      headlineLines: const <String>['TODAVÍA NO HAY', 'NADA QUE VER'],
      body: 'Tus habilidades se dibujan solas con los primeros cinco retos.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _placeholder('Aquí irá tu primera habilidad'),
          const SizedBox(height: BrandShape.space2),
          _placeholder('Y aquí la siguiente'),
        ],
      ),
      primary: BrandButton.primary(
        label: 'Resolver los primeros 5',
        onPressed: onStart,
      ),
    );
  }

  /// A row that is not there yet, drawn as a row that is not there yet.
  ///
  /// **Dashed and not pressable.** The markup draws a `<span>`, not a
  /// `<button>`: there is no skill behind it, so a press would have nowhere to
  /// go, and an affordance that does nothing is worse than an absent one
  /// (DR-P2). `DashSpec.locked` already names the empty-state placeholder as
  /// one of its three uses.
  Widget _placeholder(String label) => CandySurface(
    // The design's 20, which is the radius its buttons carry (BRD-2c).
    borderRadius: BrandShape.radiusButton,
    borderColor: BrandColors.muted,
    borderDash: DashSpec.locked,
    shadowOffset: Offset.zero,
    minHeight: _placeholderRow,
    padding: const EdgeInsets.symmetric(horizontal: BrandShape.space3),
    alignment: Alignment.centerLeft,
    child: Text(
      label,
      style: BrandText.cardTitle(color: BrandColors.muted, size: 13),
    ),
  );
}
