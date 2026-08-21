import 'package:flutter/widgets.dart';

import '../../../design/painting/spec/dash_spec.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/spec/mastery_level.dart';
import '../policy/map_layout.dart';
import '../policy/skill_copy.dart';
import '../policy/skill_map.dart';
import 'map_connectors.dart';
import 'mastery_skin.dart';
import 'skill_node_tile.dart';

/// `05 Mapa de habilidades` — the topics the pack carries, as a graph.
///
/// **It takes a [SkillMap] and reads nothing.** The pack and the series cursor
/// are `MapRoute`'s to fetch; every figure here arrived as data, which is what
/// lets the whole screen be pumped with four hand-written nodes.
///
/// **The map scrolls and the header does not.** The design draws the graph in a
/// fixed 358 × 576 well under a fixed header, on a viewport with no notch and
/// no text setting. This app is gated at `textScaler` 1.3 on a 402 × 874 phone
/// with 96 px of hardware in the way, where a fixed well overflows — so the
/// graph and the legend scroll together and the title stays.
///
/// **The counter is yellow and counts topics under way**, not topics finished.
/// The design's green `3 / 9` counts what its legend calls *Dominado*, and
/// mastering a family here means reaching the hardest ladder step the pack
/// offers for it — true, reachable, and reached by nobody in their first
/// session. A green pill reading `0 / 6` for the first month would be a figure
/// that is accurate and says nothing. Yellow is the legend's *En curso*, which
/// is what the number actually reports.
class SkillMapScreen extends StatelessWidget {
  const SkillMapScreen({super.key, required this.map, required this.onOpen});

  final SkillMap map;

  /// Opens a topic. Never called for a locked one — see [MasterySkin.opens].
  final void Function(SkillNode node) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              BrandShape.space4,
              0,
              BrandShape.space4,
              BrandShape.space5,
            ),
            child: map.nodes.isEmpty ? _nothingToMap() : _mapped(),
          ),
        ),
      ],
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(
          BrandShape.space4,
          BrandShape.space1,
          BrandShape.space4,
          BrandShape.space3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'MAPA DE TEMAS',
                  maxLines: 1,
                  style: BrandText.sectionTitle(),
                ),
              ),
            ),
            const SizedBox(width: BrandShape.space2),
            _counter(),
          ],
        ),
      );

  Widget _counter() => Semantics(
        label: '${map.startedCount} de ${map.nodes.length} temas empezados',
        child: CandySurface.pill(
          background: BrandColorRole.highlight.color,
          child: Text(
            '${map.startedCount} / ${map.nodes.length}',
            style: BrandText.eyebrow(color: BrandColors.ink),
          ),
        ),
      );

  Widget _mapped() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                _graph(constraints.maxWidth),
          ),
          const SizedBox(height: BrandShape.space4),
          _legend(),
        ],
      );

  Widget _graph(double width) {
    final MapLayout layout = MapLayout.of(
      nodeCount: map.nodes.length,
      width: width,
      focusIndex: map.focusIndex,
    );

    return SizedBox(
      width: layout.canvasSize.width,
      height: layout.canvasSize.height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: MapConnectors(
                boxes: layout.boxes,
                edges: layout.edges,
                lockedNodes: <int>{
                  for (int index = 0; index < map.nodes.length; index++)
                    if (!MasterySkin.of(map.nodes[index].level).opens) index,
                },
              ),
            ),
          ),
          for (int index = 0; index < map.nodes.length; index++)
            Positioned(
              left: layout.boxes[index].left,
              top: layout.boxes[index].top,
              child: SkillNodeTile(
                node: map.nodes[index],
                size: index == map.focusIndex
                    ? SkillNodeSize.hero
                    : SkillNodeSize.standard,
                onOpen: () => onOpen(map.nodes[index]),
              ),
            ),
        ],
      ),
    );
  }

  /// The key, with the fourth entry the design draws and never names.
  Widget _legend() => Wrap(
        spacing: BrandShape.space3,
        runSpacing: BrandShape.space2,
        children: <Widget>[
          for (final MasteryLevel level in MasteryLevel.values.reversed)
            _legendEntry(level),
        ],
      );

  Widget _legendEntry(MasteryLevel level) {
    final MasterySkin skin = MasterySkin.of(level);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CandySurface(
          width: _swatch,
          height: _swatch,
          background: skin.fill,
          borderRadius: _swatchRadius,
          borderWidth: BrandShape.borderWidthSmallSurface,
          borderColor: skin.ink,
          borderDash:
              skin.outline == MasteryOutline.dashed ? DashSpec.locked : null,
          shadowOffset: Offset.zero,
          child: const SizedBox.shrink(),
        ),
        const SizedBox(width: BrandShape.space1),
        Text(masteryName(level), style: BrandText.caption(color: skin.ink)),
      ],
    );
  }

  /// The design's 14 px legend swatch, at its own 5 px radius — smaller than
  /// anything `BrandShape` names, because nothing else in the app is a 14 px
  /// square (BRD-2c).
  static const double _swatch = 14;
  static const double _swatchRadius = 5;

  Widget _nothingToMap() => Padding(
        padding: const EdgeInsets.only(top: BrandShape.space6),
        child: Text(
          'Tu paquete de retos todavía no trae temas que dibujar.',
          style: BrandText.body(color: BrandColors.muted),
        ),
      );
}
