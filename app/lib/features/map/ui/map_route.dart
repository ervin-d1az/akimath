import 'package:flutter/material.dart';

import '../../../content/model/item.dart';
import '../../../content/model/pack.dart';
import '../../../content/pack_reader.dart';
import '../../../design/tokens/tokens.dart';
import '../../home/data/day_log_store.dart';
import '../../home/data/series_cursor_store.dart';
import '../../round/ui/round_screen.dart';
import '../../shell/ui/app_shell.dart';
import '../../shell/ui/skeleton_block.dart';
import '../policy/practice_series.dart';
import '../policy/skill_map.dart';
import 'node_detail_screen.dart';
import 'skill_map_screen.dart';

/// Loads the pack and the cursor, draws the map, and opens what is tapped.
///
/// **The IO and the navigation live here so neither screen has either.**
/// `SkillMapScreen` takes a [SkillMap] and `NodeDetailScreen` takes one node;
/// this is what reads an `AssetBundle` and a preference and turns the two into
/// the first. The same split `HomeRoute` has, for the same reason — a widget
/// test drives both screens with hand-written nodes and touches no plugin.
class MapRoute extends StatefulWidget {
  const MapRoute({
    super.key,
    this.reader = const PackReader(),
    this.seriesCursor = const SeriesCursorStore(),
    this.dayLog,
  });

  final PackReader reader;

  /// How many items the player has been served. The map's only measure of
  /// progress, and the reason it is a real screen rather than a drawing.
  final SeriesCursorStore seriesCursor;

  /// Where a practice run records the day.
  ///
  /// Injected and optional, so a widget test never reaches a plugin. A day
  /// practised is a day practised whichever screen it was started from, so this
  /// is the same store the home hands its own rounds.
  final DayLogStore? dayLog;

  @override
  State<MapRoute> createState() => _MapRouteState();
}

class _MapRouteState extends State<MapRoute> {
  /// Read once, in the field initialiser, so a rebuild does not re-read the
  /// bundle — the same shape `HomeRoute` uses.
  late final Future<_MapContents> _contents = _read();

  Future<_MapContents> _read() async {
    final Pack pack = await widget.reader.load();
    return _MapContents(pack: pack, itemsServed: await widget.seriesCursor.read());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MapContents>(
      future: _contents,
      builder: (BuildContext context, AsyncSnapshot<_MapContents> snapshot) {
        if (snapshot.hasError) {
          return _unreadable();
        }
        final _MapContents? contents = snapshot.data;
        return contents == null
            ? _loading()
            : SkillMapScreen(
                map: contents.map,
                onOpen: (SkillNode node) => _open(context, contents, node),
              );
      },
    );
  }

  /// A block the size of the graph that is coming.
  ///
  /// **A skeleton and never a spinner** — `4.11 Cargando` is annotated
  /// *esqueletos, sin ruedita*, and a block says what is coming and where.
  Widget _loading() => Padding(
        padding: const EdgeInsets.all(BrandShape.space4),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              SkeletonBlock(
            width: constraints.maxWidth,
            height: _loadingHeight,
            radius: BrandShape.radiusPanel,
          ),
        ),
      );

  /// A pack that will not parse is refused where it is read, and this is where
  /// a player finds out — the map is one of two places that reads content, and
  /// a blank graph would read as "you have done nothing" rather than as a
  /// broken file.
  Widget _unreadable() => Padding(
        padding: const EdgeInsets.all(BrandShape.space5),
        child: Text(
          'El paquete de retos no se pudo leer, así que todavía no hay mapa.',
          style: BrandText.body(color: BrandColors.muted),
        ),
      );

  void _open(BuildContext context, _MapContents contents, SkillNode node) {
    final int index = contents.map.nodes.indexOf(node);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext detailContext) => NodeDetailScreen(
          node: node,
          previous: index > 0 ? contents.map.nodes[index - 1] : null,
          onBack: () => Navigator.of(detailContext).pop(),
          onPractise: () => _practise(detailContext, contents, node),
        ),
      ),
    );
  }

  /// Plays a short run inside one topic.
  ///
  /// Over the bar rather than under it (`pushSession`), because declared rule 1
  /// says a session has exactly one way out and a bottom bar is a second one.
  /// **`onFinished` is wired**: without it `RoundScreen` cycles its items for
  /// ever, which is an exercise rather than a run of five.
  void _practise(BuildContext context, _MapContents contents, SkillNode node) {
    final List<Item> items = practiceSeries(
      items: contents.pack.items,
      label: node.label,
      itemsServed: contents.itemsServed,
    );
    if (items.isEmpty) {
      return;
    }

    pushSession<void>(
      context,
      (BuildContext roundContext) => RoundScreen(
        items: items,
        fallbackDiagnosis: contents.pack.fallbackDiagnosis,
        attemptDays: const <DateTime>[],
        dayLog: widget.dayLog,
        onClose: () => Navigator.of(roundContext).pop(),
        // Wired, or the round cycles its five items for ever. What it reports
        // is not read: a practice run is not a series, so it opens no summary
        // and moves no cursor — it just ends.
        onFinished: (RoundOutcome _) => Navigator.of(roundContext).pop(),
      ),
    );
  }

  /// Roughly the graph's own height, so the screen does not jump when the pack
  /// lands.
  static const double _loadingHeight = 360;
}

/// The two things the map is read from, kept together so one `FutureBuilder`
/// resolves both and the screen cannot be drawn from half of them.
@immutable
class _MapContents {
  const _MapContents({required this.pack, required this.itemsServed});

  final Pack pack;
  final int itemsServed;

  SkillMap get map =>
      readSkillMap(items: pack.items, itemsServed: itemsServed);
}
