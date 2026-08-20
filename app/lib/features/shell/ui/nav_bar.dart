import 'package:flutter/widgets.dart';

import '../../../design/brand/brand_drawing_painter.dart';
import '../../../design/brand/spec/brand_shapes.dart';
import '../../../design/icons/spec/nav_glyph_spec.dart';
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
/// **An icon over a label, and the icon is ours.** This bar carried labels
/// alone for a reason worth restating: `BrandIcon` renders stand-in characters
/// until the transcribed artwork lands, and the two nearest marks were a tick —
/// which means *correct* everywhere else in this app — and a gear the system
/// paints as a colour emoji. A wrong mark does read worse than a word.
///
/// So the two marks are drawn rather than borrowed, in
/// `design/icons/spec/nav_glyph_spec.dart`, which says plainly that it is a
/// fork of a design nobody has transcribed and is counted by a test. **The
/// label stays under the icon**: a mark this app invented is not one anyone has
/// learned yet, and an unlabelled bottom bar assumes they have.
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
              ? _content(visual)
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
                  child: _content(visual),
                ),
        ),
      ),
    );
  }

  /// The mark over the word.
  ///
  /// `mainAxisSize.min` and no spacer: the chip is a fixed 52 tall and the two
  /// children have to fit inside it at any text scale the app supports, which
  /// `screen_overflow_test` checks at 1.3.
  Widget _content(NavTabVisual visual) => Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: _markSize,
            height: _markSize,
            child: CustomPaint(
              painter: BrandDrawingPainter(_markFor(tab, visual.mark)),
            ),
          ),
          const SizedBox(height: 2),
          _label(visual),
        ],
      );

  Widget _label(NavTabVisual visual) => Text(
        NavBar.labelOf(tab),
        maxLines: 1,
        style: BrandText.eyebrow(color: visual.mark, size: 10)
            .copyWith(fontWeight: visual.weight),
      );

  /// The drawn mark, tinted to whatever the tab's state says.
  ///
  /// `skills` and `progress` have no root yet, so they cannot be reached and
  /// have no mark; they fall back to the house rather than to nothing, because
  /// a bar that renders an empty box is worse than one that repeats itself —
  /// and `rootsPresentToday` means neither is ever built.
  static BrandDrawing _markFor(AppTab tab, Color ink) {
    final BrandDrawing drawing = switch (tab) {
      AppTab.profile => NavGlyphSpec.settings,
      AppTab.progress => NavGlyphSpec.progress,
      // `skills` has no root and no mark of its own yet; it never reaches here
      // because `visibleTabs` does not hand it over. Sharing the house until
      // F5 is a decision that costs nothing while nothing can see it — and
      // `nav_bar_test.dart` fails the moment two *drawn* tabs share a mark.
      AppTab.home || AppTab.skills => NavGlyphSpec.home,
    };
    return BrandDrawing(
      viewBox: drawing.viewBox,
      marks: drawing.marks.map((BrandMark mark) => _tinted(mark, ink)).toList(),
    );
  }

  /// Both nav marks are stroke-only, which is what makes them tintable — see
  /// `NavGlyphSpec`. Anything else passes through unchanged rather than being
  /// silently recoloured wrong.
  static BrandMark _tinted(BrandMark mark, Color ink) => switch (mark) {
    InkStroke(:final Offset start, :final List<PathStep> steps, :final double width) =>
      InkStroke(start: start, steps: steps, width: width, color: ink),
    _ => mark,
  };

  /// 20, so the mark and a 10 pt label together clear the 52 chip.
  static const double _markSize = 20;

  /// `64×52` in the design. The chip is what the selected tab sits on and the
  /// footprint every tab reserves, so the labels do not shift when one is
  /// chosen.
  static const double _chipWidth = 78;
  static const double _chipHeight = 52;
}
