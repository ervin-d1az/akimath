import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/spec/nav_tab_visual.dart';
import '../policy/visible_tabs.dart';

/// The bottom bar the shell has always accepted and never been given.
///
/// It draws whatever `visibleTabs` hands it and decides nothing: which tabs
/// exist is the policy's, and the policy returns nothing while one root exists.
/// So this widget never has to know that a one-tab bar would be wrong — it is
/// simply never built.
///
/// **Selection is marked by more than hue** (BRD-1): the current tab is filled
/// and its label is heavier, so it survives deuteranopia. Every destination is
/// at least `BrandShape.minTouchTarget` tall, which is why the bar's height is
/// derived from that constant rather than chosen to look right.
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

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BrandColors.surface,
        border: Border(
          top: BorderSide(color: BrandColors.ink, width: BrandShape.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            for (final AppTab tab in tabs)
              Expanded(
                child: _Tab(
                  tab: tab,
                  selected: tab == current,
                  onTap: () => onSelect(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The mark above a selected tab.
///
/// Always occupies its space, so switching tabs does not shift the labels by a
/// few pixels — a bar that twitches under a thumb reads as a bug.
class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.shown});

  final bool shown;

  static const double _size = 7;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: shown
          ? const DecoratedBox(
              decoration: BoxDecoration(
                color: BrandColors.ink,
                shape: BoxShape.circle,
              ),
            )
          : null,
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
      // Opaque, so the whole cell is tappable and not only the glyph — a tab
      // you have to hit precisely is a tab that feels broken.
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BrandShape.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BrandShape.space2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // **A dot, not a glyph.** The icon layer is a deliberate
              // placeholder — `BrandIcon` renders stand-in characters until the
              // transcribed artwork lands, and the two nearest to "home" and
              // "settings" are a tick, which means *correct* everywhere else in
              // this app, and a gear the system draws as a colour emoji. A
              // wrong mark reads worse than none, and a dot is honest about
              // what has not been drawn yet.
              _SelectionDot(shown: visual.showsDot),
              const SizedBox(height: BrandShape.space2),
              Text(
                NavBar.labelOf(tab),
                style: BrandText.eyebrow(color: visual.mark, size: 11)
                    .copyWith(fontWeight: visual.weight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
