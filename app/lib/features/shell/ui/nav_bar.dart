import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/spec/nav_tab_visual.dart';
import '../policy/visible_tabs.dart';

/// The bottom bar the shell has always accepted and never been given.
///
/// It draws whatever `visibleTabs` hands it and decides nothing: which tabs
/// exist is the policy's, and the policy returns nothing while one root exists.
/// So this widget never has to know that a one-tab bar would be wrong — it is
/// simply never built.
///
/// **It floats.** `pantallas-base.md` places it `left:20; right:20; bottom:20`
/// as a 344×72 white card with a 3 px border, a 26 radius and the app's most
/// common hard shadow — the same object every card and button on the screen
/// already is. It used to be a full-bleed strip with a hairline on top, which
/// is the one surface treatment the rest of the app never uses.
///
/// **Selection is marked by more than hue** (BRD-1): the current tab sits on a
/// green chip and its label is heavier, so it survives deuteranopia. Every
/// destination is at least `BrandShape.minTouchTarget` tall.
///
/// **Labels, not icons, and that is deliberate.** The design draws four
/// stroked glyphs; `BrandIcon` renders stand-in characters until the
/// transcribed artwork lands, and the two nearest "home" and "settings" are a
/// tick — which means *correct* everywhere else in this app — and a gear the
/// system paints as a colour emoji. A wrong mark reads worse than a word.
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.tabs,
    required this.current,
    required this.onSelect,
  });

  final List<AppTab> tabs;
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  /// es-MX, and short: two words in a tab label wrap on a narrow phone.
  static String labelOf(AppTab tab) => switch (tab) {
        AppTab.home => 'Inicio',
        AppTab.skills => 'Mapa',
        AppTab.progress => 'Avance',
        AppTab.profile => 'Ajustes',
      };

  /// The card's own height, from the design. The chip inside it is 52 and the
  /// remaining 20 is the padding above and below it.
  static const double _height = 72;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BrandShape.space5,
          0,
          BrandShape.space5,
          BrandShape.space5,
        ),
        child: CandySurface(
          height: _height,
          borderRadius: BrandShape.radiusCardMedium,
          shadowOffset: BrandShape.shadowButton,
          padding: const EdgeInsets.symmetric(horizontal: BrandShape.space2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              for (final AppTab tab in tabs)
                _Tab(
                  tab: tab,
                  selected: tab == current,
                  onTap: () => onSelect(tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NavTabVisual visual = resolveNavTab(selected);

    return GestureDetector(
      onTap: onTap,
      // Opaque, so the whole cell is tappable and not only the label — a tab
      // you have to hit precisely is a tab that feels broken.
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _chipWidth,
        height: BrandShape.minTouchTarget,
        child: Center(
          child: visual.chip == null
              ? _label(visual)
              : CandySurface(
                  background: visual.chip!,
                  // 18 in the design, which is `radiusPill` here.
                  borderRadius: BrandShape.radiusPill,
                  // No shadow: a nested surface does not cast one, the same
                  // rule the `5 retos` chip follows inside its card.
                  shadowOffset: Offset.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: BrandShape.space2,
                  ),
                  height: _chipHeight,
                  alignment: Alignment.center,
                  child: _label(visual),
                ),
        ),
      ),
    );
  }

  Widget _label(NavTabVisual visual) => Text(
        NavBar.labelOf(tab),
        maxLines: 1,
        style: BrandText.eyebrow(color: visual.mark, size: 11)
            .copyWith(fontWeight: visual.weight),
      );

  /// `64×52` in the design. The chip is what the selected tab sits on and the
  /// footprint every tab reserves, so the labels do not shift when one is
  /// chosen.
  static const double _chipWidth = 78;
  static const double _chipHeight = 52;
}
