import 'dart:async';

import 'package:flutter/material.dart';

import '../../../content/model/item.dart';
import '../../../content/model/pack.dart';
import '../../../content/pack_reader.dart';
import '../../../design/tokens/tokens.dart';
import '../../home/data/day_log_store.dart';
import '../../home/data/series_cursor_store.dart';
import '../../round/ui/round_screen.dart';
import '../../shell/policy/visible_tabs.dart';
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
    this.visibility = RootVisibility.showing,
  });

  /// Whether this root is the one on screen.
  ///
  /// Defaults to [RootVisibility.showing], the same default and for the same
  /// reason `ProfileRoute` gives it: every caller that is not the shell — a
  /// test, the screen registry — is looking at it.
  final RootVisibility visibility;

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
  /// What the map is drawn from, or null until the first reading lands.
  _MapContents? _contents;

  /// Whether the last reading refused the pack.
  bool _packRefused = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void didUpdateWidget(MapRoute old) {
    super.didUpdateWidget(old);
    _refreshOnComingToTheFront(old.visibility);
  }

  /// Re-reads the cursor the moment this root becomes the one on screen.
  ///
  /// **A rebuild is not a visit**, which is `ProfileRoute`'s wording because it
  /// is the same problem: `IndexedStack` keeps every root alive, so `initState`
  /// runs once per launch and there is no second one to hook. Reading on any
  /// rebuild would read storage for a screen nobody is looking at, and would
  /// hide the case this exists for.
  ///
  /// Measured on a device: the map showed launch-time percentages for ever —
  /// play a series on Inicio, come back to Mapa, and nothing had moved (PROC-13).
  void _refreshOnComingToTheFront(RootVisibility before) {
    if (widget.visibility == RootVisibility.showing &&
        before == RootVisibility.behind) {
      unawaited(_read());
    }
  }

  /// The pack and the cursor, and the map the two of them make.
  ///
  /// **What it drew survives a re-read that has not landed yet.** Assigning
  /// only on success is what keeps the graph on screen while the second
  /// reading is in flight, instead of flashing the skeleton every time the
  /// player taps `Mapa`.
  Future<void> _read() async {
    try {
      final Pack pack = await widget.reader.load();
      final int served = await widget.seriesCursor.read();
      if (!mounted) {
        return;
      }
      setState(() {
        _packRefused = false;
        _contents = _MapContents(
          pack: pack,
          itemsServed: served,
          map: readSkillMap(items: pack.items, itemsServed: served),
        );
      });
      // Anything at all, the way `FutureBuilder.hasError` took anything at all:
      // a pack is refused where it is read and this screen only reports that it
      // was, so narrowing the clause would turn one refusal into a crash.
    } on Object catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _packRefused = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // **The route insets, not the screen.** `RootScaffold` puts this straight
    // into an `IndexedStack` with no `SafeArea` of its own, so without this the
    // title is drawn under the Dynamic Island — measured on an iPhone 17, where
    // `MAPA DE TEMAS` sat at y=6 with the clock printed across it. `HomeRoute`
    // and `ProfileRoute` have both returned an `AppShell` since they landed.
    return AppShell(child: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_packRefused) {
      return _unreadable();
    }
    final _MapContents? contents = _contents;
    return contents == null
        ? _loading()
        : SkillMapScreen(
            map: contents.map,
            onOpen: (int index) => _open(context, contents, index),
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

  void _open(BuildContext context, _MapContents contents, int index) {
    final SkillNode node = contents.map.nodes[index];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // **Its own `AppShell`, because a sibling route inherits none.** The
        // detail is pushed onto the tab's navigator, above the shell this route
        // built and not inside it, so the inset has to be taken a second time —
        // measured on an iPhone 17, where the back control sat at y=4, entirely
        // under the clock. `ProfileRoute` wraps each of its pushed screens for
        // the same reason.
        builder: (BuildContext detailContext) => AppShell(
          child: NodeDetailScreen(
            node: node,
            previous: index > 0 ? contents.map.nodes[index - 1] : null,
            onBack: () => Navigator.of(detailContext).pop(),
            onPractise: () => _practise(detailContext, contents, node),
          ),
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
  const _MapContents({
    required this.pack,
    required this.itemsServed,
    required this.map,
  });

  final Pack pack;
  final int itemsServed;

  /// Read once, in [_MapRouteState._read], and **not a getter**. A getter
  /// re-derived the whole map on every rebuild, which cost nothing visible and
  /// handed out a new list of nodes each time.
  final SkillMap map;
}
