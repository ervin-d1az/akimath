import 'dart:async';

import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../api/endpoints.dart';
import '../../../content/model/issued_pack.dart';
import '../../../content/model/item.dart';
import '../../../content/model/pack.dart';
import '../../../content/pack_reader.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/spec/verdict.dart';
import '../../account/policy/session.dart';
import '../../home/data/day_log_store.dart';
import '../../home/data/prefs_day_log_store.dart';
import '../../home/data/series_cursor_store.dart';
import '../../home/policy/day_log.dart';
import '../../home/policy/series_families.dart';
import '../../round/ui/round_screen.dart';
import '../../shell/policy/visible_tabs.dart';
import '../../shell/ui/app_shell.dart';
import '../../shell/ui/skeleton_block.dart';
import '../../stats/data/answer_record_store.dart';
import '../../stats/policy/local_stats.dart';
import '../../sync/attempt_sync.dart';
import '../../sync/data/issued_pack_store.dart';
import '../data/practised_step_store.dart';
import '../policy/practice_series.dart';
import '../policy/skill_map.dart';
import 'node_detail_screen.dart';
import 'skill_map_screen.dart';

/// Loads the pack and what the player has done with it, draws the map, and
/// opens what is tapped.
///
/// **The IO and the navigation live here so neither screen has either.**
/// `SkillMapScreen` takes a [SkillMap] and `NodeDetailScreen` takes one node;
/// this is what reads an `AssetBundle` and two preferences and turns them into
/// the first. The same split `HomeRoute` has, for the same reason — a widget
/// test drives both screens with hand-written nodes and touches no plugin.
class MapRoute extends StatefulWidget {
  const MapRoute({
    super.key,
    this.reader = const PackReader(),
    this.seriesCursor = const SeriesCursorStore(),
    this.dayLog,
    this.practisedSteps,
    this.answerRecord,
    this.sync,
    this.session,
    this.issuedPacks,
    this.fetchPack,
    this.visibility = RootVisibility.showing,
  });

  /// Whether this root is the one on screen.
  ///
  /// Defaults to [RootVisibility.showing], the same default and for the same
  /// reason `ProfileRoute` gives it: every caller that is not the shell — a
  /// test, the screen registry — is looking at it.
  final RootVisibility visibility;

  final PackReader reader;

  /// How many items the player has been served by the **daily series**.
  ///
  /// One of the map's two measures of progress, and the only one a run in pack
  /// order needs: the series walks the pack from the front, so a single total
  /// says everything about it.
  final SeriesCursorStore seriesCursor;

  /// Where a practice run records the day.
  ///
  /// Injected and optional, so a widget test never reaches a plugin. A day
  /// practised is a day practised whichever screen it was started from, so this
  /// is the same store the home hands its own rounds.
  final DayLogStore? dayLog;

  /// Where a practice run records how far up a topic it took the player.
  ///
  /// The map's other measure of progress, and the reason `Practicar 5 retos`
  /// is now able to move the number above it. Injected for the reason [dayLog]
  /// is: a `testWidgets` must never reach a plugin.
  final PractisedStepStore? practisedSteps;

  /// Where the device's own record of answered items is kept — the one source
  /// of the accuracy and the mean time `Perfil` draws.
  ///
  /// **A practice run is a run.** The home wires this for a series; the map did
  /// not, so five items answered from a topic moved neither figure and the
  /// profile reported on a fraction of what the player had actually done.
  final AnswerRecordStore? answerRecord;

  /// What remembers an answered item until the server has it.
  ///
  /// The home wires this for a series and the map did not, so a topic run
  /// reached the server as nothing: no attempt row, no history entry, no
  /// rating. It records without touching the network — flushing is the home's,
  /// on the launch, on a session arriving, and on the way back from a series.
  final AttemptSync? sync;

  /// The account this device is signed in to, if it is.
  ///
  /// **The map needs it for one reason**: to play the pack the server issued,
  /// which is the only pack whose items carry the `(packId, index)` an attempt
  /// is addressed by. Without it the bundled pack keeps playing for ever and by
  /// design (ADR 0002), and nothing a practice run answers could ever be sent.
  final LinkedSession? session;

  /// Where the id of that pack is kept between launches.
  ///
  /// **Read here and written only by the home.** Issuing is the home's act —
  /// it is the root that opens the app and the one that knows whether a device
  /// has a pack at all — and a second minter would leave a row per tab.
  final IssuedPackStore? issuedPacks;

  /// Fetches the pack this device already has an id for. A closure, the same
  /// shape every other request in this app takes and for the same reason: a
  /// `testWidgets` runs in a fake-async zone and a real socket inside one hangs
  /// on `!timersPending`.
  final Future<FetchPackResult> Function({
    required String accessToken,
    required String packId,
  })? fetchPack;

  @override
  State<MapRoute> createState() => _MapRouteState();
}

class _MapRouteState extends State<MapRoute> {
  /// What the map is drawn from, or null until the first reading lands.
  ///
  /// **A notifier and not a plain field, because `2.7` is pushed.** The detail
  /// screen sits on a route above this one rather than inside it, so no
  /// `setState` here can rebuild it — and its `MaterialPageRoute` builder runs
  /// once, capturing whichever node the push handed it. That is PROC-13's named
  /// trap, and it is exactly where a player looks after practising: the map
  /// underneath had moved while the topic they had just practised still read
  /// its launch-time figure.
  final ValueNotifier<_MapContents?> _contents =
      ValueNotifier<_MapContents?>(null);

  /// Whether the last reading refused the pack.
  bool _packRefused = false;

  /// Where a practice run records the day.
  ///
  /// **Defaulted here, because nothing downstream defaults it.** `RoundScreen`
  /// takes a nullable store and writes through `store?.record(…)`, which is
  /// deliberate — the teaching item is a round that must record nothing — and
  /// `RootScaffold` hands this route no store, so a practice run started from
  /// Mapa wrote no day at all. `HomeRoute` has resolved its own the same way
  /// since it landed.
  late final DayLogStore _dayLog = widget.dayLog ?? const PrefsDayLogStore();

  /// Defaulted here for the reason [_dayLog] is: the shell hands this route
  /// nothing, and a store nobody supplies is a record nobody writes.
  late final PractisedStepStore _practisedSteps =
      widget.practisedSteps ?? const PrefsPractisedStepStore();

  late final AnswerRecordStore _answerRecord =
      widget.answerRecord ?? const PrefsAnswerRecordStore();

  late final AttemptSync _sync = widget.sync ?? AttemptSync();

  /// The days the player has practised, as the last reading found them.
  ///
  /// **Held here because the round has to be told.** `RoundScreen` prints the
  /// streak on its verdict, and it computes it from what it is handed plus
  /// today; handed an empty list it reported `RACHA 1` to a player on a run of
  /// twelve, one screen away from the home saying otherwise. Read with
  /// everything else so a run started after coming back to Mapa sees what the
  /// home wrote.
  DayLog _log = DayLog.empty;

  late final IssuedPackStore _issuedPacks =
      widget.issuedPacks ?? const PrefsIssuedPackStore();

  /// The pack the server issued, once this root has fetched it.
  ///
  /// **Null is the ordinary state**, and it is what an unlinked device draws
  /// and plays for ever. When it is not null it *replaces* the bundled pack —
  /// same six families, same ladder — and the difference is that every item
  /// carries an address the server can grade.
  Pack? _issued;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void dispose() {
    _contents.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapRoute old) {
    super.didUpdateWidget(old);
    _refreshOnComingToTheFront(old.visibility);
  }

  /// Re-reads what the player has done the moment this root becomes the one on
  /// screen.
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

  /// The pack and what the player has done with it, and the map the three of
  /// them make.
  ///
  /// **What it drew survives a re-read that has not landed yet.** Assigning
  /// only on success is what keeps the graph on screen while the second
  /// reading is in flight, instead of flashing the skeleton every time the
  /// player taps `Mapa`.
  Future<void> _read() async {
    try {
      await _fetchIssuedPack();
      final Pack pack = _issued ?? await widget.reader.load();
      final int served = await widget.seriesCursor.read();
      final Map<String, int> practised = await _practisedSteps.read();
      final DayLog log = await _dayLog.read();
      if (!mounted) {
        return;
      }
      _log = log;
      setState(() => _packRefused = false);
      _contents.value = _MapContents(
        pack: pack,
        itemsServed: served,
        map: readSkillMap(
          items: pack.items,
          itemsServed: served,
          practisedSteps: practised,
        ),
      );
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

  /// Fetches the pack the home was issued, once, when there is one to fetch.
  ///
  /// **It never issues, and never clears the id.** Minting is the home's — the
  /// root that opens the app, and the one that writes the id before it adopts
  /// the pack — so this asks for what is already recorded and takes silence for
  /// an answer. A blip on a request the player did not make is worth no screen
  /// and no second row; the app they already had works.
  ///
  /// It runs inside [_read], so a device that links on the profile tab picks
  /// the pack up the next time it comes to Mapa rather than only next launch.
  Future<void> _fetchIssuedPack() async {
    final LinkedSession? session = widget.session;
    if (session == null || _issued != null) {
      return;
    }
    final String? packId = await _issuedPacks.read();
    if (packId == null || !mounted) {
      return;
    }
    final FetchPackResult fetched = await (widget.fetchPack ?? _fetchOverASocket)(
      accessToken: session.accessToken,
      packId: packId,
    );
    if (fetched is! FetchPackDone || !mounted) {
      return;
    }
    try {
      _issued = readIssuedPack(
        Map<String, dynamic>.from(fetched.issued.pack),
        packId: fetched.issued.packId,
        issuedAt: fetched.issued.issuedAt,
        expiresAt: fetched.issued.expiresAt,
      );
      // **A pack this app cannot read is a pack it does not play**, which is
      // the rule `PackReader` already keeps. The bundled one is still there.
    } on FormatException {
      // Nothing to say to a player about a request they did not make.
    }
  }

  Future<FetchPackResult> _fetchOverASocket({
    required String accessToken,
    required String packId,
  }) async {
    final ApiClient api = ApiClient(baseUrl: Uri.parse(Endpoints.apiBaseUrl));
    try {
      return await api.fetchPack(accessToken: accessToken, packId: packId);
    } finally {
      api.close();
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
    return ValueListenableBuilder<_MapContents?>(
      valueListenable: _contents,
      builder: (BuildContext context, _MapContents? contents, Widget? _) =>
          contents == null
              ? _loading()
              : SkillMapScreen(
                  map: contents.map,
                  onOpen: (int index) => _open(context, contents, index),
                ),
    );
  }

  /// A block the size of the graph that is coming.
  ///
  /// **A skeleton and never a spinner** — `Cargando` is annotated
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

  /// Pushes `2.7` for the topic at [index], and keeps it current.
  ///
  /// **It listens rather than capturing.** A route's builder runs once, so a
  /// node handed to it here is the node it draws for ever — and the whole point
  /// of the practice button underneath is to change that node. The topic is
  /// found again on every reading **by label**, so a pack that arrives with a
  /// different set of families cannot turn a re-read into a range error.
  void _open(BuildContext context, _MapContents opened, int index) {
    final SkillNode openedNode = opened.map.nodes[index];
    final SkillNode? openedPrevious =
        index > 0 ? opened.map.nodes[index - 1] : null;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // **Its own `AppShell`, because a sibling route inherits none.** The
        // detail is pushed onto the tab's navigator, above the shell this route
        // built and not inside it, so the inset has to be taken a second time —
        // measured on an iPhone 17, where the back control sat at y=4, entirely
        // under the clock. `ProfileRoute` wraps each of its pushed screens for
        // the same reason.
        builder: (BuildContext detailContext) =>
            ValueListenableBuilder<_MapContents?>(
          valueListenable: _contents,
          builder: (BuildContext context, _MapContents? latest, Widget? _) {
            final _MapContents contents = latest ?? opened;
            final int at = contents.map.nodes
                .indexWhere((SkillNode node) => node.label == openedNode.label);
            final SkillNode node =
                at < 0 ? openedNode : contents.map.nodes[at];
            return AppShell(
              child: NodeDetailScreen(
                node: node,
                previous: at < 0
                    ? openedPrevious
                    : (at > 0 ? contents.map.nodes[at - 1] : null),
                onBack: () => Navigator.of(detailContext).pop(),
                onPractise: () =>
                    unawaited(_practise(detailContext, contents, node)),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Plays a short run inside one topic, and records what it took the player
  /// through.
  ///
  /// Over the bar rather than under it (`pushSession`), because declared rule 1
  /// says a session has exactly one way out and a bottom bar is a second one.
  /// **`onFinished` is wired**: without it `RoundScreen` cycles its items for
  /// ever, which is an exercise rather than a run of five.
  ///
  /// **It is awaited, and that is load-bearing.** The push used to be a bare
  /// call in a `void` method, so nothing here ran when the run ended: the map
  /// could not re-read, and a store written perfectly would still have left the
  /// screen showing the figure it opened with.
  ///
  /// **What it records is a ladder step and not a cursor.** `SeriesCursorStore`
  /// counts items served in pack order and decides which five the home serves
  /// next; advancing it for a run inside one family would mark five other
  /// topics as progressed and silently skip items the player has never seen.
  /// See `policy/practised_steps.dart` for the whole argument.
  Future<void> _practise(
    BuildContext context,
    _MapContents contents,
    SkillNode node,
  ) async {
    final List<Item> items = practiceSeries(
      items: contents.pack.items,
      label: node.label,
      itemsServed: contents.itemsServed,
    );
    if (items.isEmpty) {
      return;
    }

    // **The key comes from the items, not from the node.** A node carries a
    // label, which is copy a designer may rewrite; a stored record must not
    // change the day the copy does. Every item `practiceSeries` returns is of
    // the one family, so any of them names it.
    final String family = familyKey(items.first.stimulus);

    // **Accumulated here and written once, when the run ends.** Writing on each
    // answer would be five writes agreeing with one another, and the last of
    // them would be racing the re-read below — a store that lands a frame late
    // is a screen that shows the old number.
    int hardestStepServed = 0;

    // **One id per sitting**, minted before the push so every answer in this
    // run carries the same one, exactly as `_startSeries` does. `GET
    // /me/history` groups by it, and a history of one-item sessions is a
    // history nobody can read.
    final String sessionId = _sync.newSessionId();

    await pushSession<void>(
      context,
      (BuildContext roundContext) => RoundScreen(
        items: items,
        fallbackDiagnosis: contents.pack.fallbackDiagnosis,
        // **What the round prints as `RACHA`.** Empty said the player had
        // practised on no day at all, while the store below it recorded today —
        // so a practice verdict read `RACHA 1` however long the real run was.
        attemptDays: _log.days,
        dayLog: _dayLog,
        onClose: () => Navigator.of(roundContext).pop(),
        // **The item and never the verdict.** Two things want an answered item
        // here, and neither of them wants a verdict: how far up a topic the run
        // took the player is a fact about what was *served*, and what travels
        // to the server deliberately carries no verdict at all, because the
        // frozen schema has nowhere to put one.
        onAnswered: (Item item, String answer, Duration elapsed) {
          if (item.ladderStep > hardestStepServed) {
            hardestStepServed = item.ladderStep;
          }
          // Never touches the network — play is offline, and a submit that
          // waited on a socket would be a pause mid-round. An item the server
          // cannot address is dropped inside `record`, on purpose.
          unawaited(
            _sync.record(
              itemId: item.id,
              sessionId: sessionId,
              answer: answer,
              at: DateTime.now(),
              elapsed: elapsed,
            ),
          );
        },
        // **`onGraded` and never `onAnswered`.** That one carries what the
        // server needs and deliberately no verdict; reading a verdict off it
        // would mean calling `gradeItem` a second time, which is a second
        // decision about one answer — the defect `diagnose` was fixed for.
        onGraded: (Verdict verdict, Duration elapsed) => unawaited(
          _answerRecord.record(
            AnsweredItem(verdict: verdict, elapsed: elapsed),
          ),
        ),
        // Wired, or the round cycles its five items for ever.
        onFinished: (RoundOutcome _) => Navigator.of(roundContext).pop(),
      ),
    );

    // **A run left part-way still counts what it served.** Closing `03 Reto`
    // after two items is two items the player met, and the record is a claim
    // about difficulty met rather than a position to serve from.
    if (hardestStepServed > 0) {
      await _practisedSteps.record(family: family, step: hardestStepServed);
    }
    // **On the way back, finished or abandoned**, for `_startSeries`'s reason:
    // coming back from a run is exactly where `record` last ran, so it is the
    // best evidence this root ever gets that there is a network worth trying.
    // Never awaited — a player must not wait on a socket — and failure stays
    // the journal's business, since `journalAfter` decides what survives which
    // answer.
    unawaited(_flush());
    // The run recorded the day as well. Re-read rather than adjust what this
    // screen holds: the stores are the source of truth, and a screen that
    // increments locally is how it ends up showing a figure they would not
    // yield.
    await _read();
  }

  /// Sends what the journal is holding, if there is a session to send it on.
  ///
  /// Failure is the journal's business rather than this screen's, the same
  /// reading `HomeRoute._flush` takes: there is nothing useful to say to a
  /// player about a batch they never asked to send.
  Future<void> _flush() async {
    final LinkedSession? session = widget.session;
    if (session == null) {
      return;
    }
    await _sync.flush(session.accessToken);
  }

  /// Roughly the graph's own height, so the screen does not jump when the pack
  /// lands.
  static const double _loadingHeight = 360;
}

/// The three things the map is read from, kept together so one reading resolves
/// them all and the screen cannot be drawn from part of them.
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
