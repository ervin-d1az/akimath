import 'dart:convert';

import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/design/theme.dart';
import 'package:akimath_app/features/home/data/series_cursor_store.dart';
import 'package:akimath_app/features/home/policy/series_families.dart';
import 'package:akimath_app/features/map/ui/map_route.dart';
import 'package:akimath_app/features/map/ui/node_detail_screen.dart';
import 'package:akimath_app/features/map/ui/skill_map_screen.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:akimath_app/features/shell/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));
}

/// Two families and six items, which is the smallest pack that makes a map
/// worth drawing: more than one node, and more items in a family than one
/// practice run can hold.
String _pack() {
  String arithmetic(String id, int step) => '''
    {"id": "$id", "ladder_step": $step, "answer": "7",
     "prompt": [{"kind": "text", "value": "3"},
                {"kind": "operator", "glyph": "+"},
                {"kind": "text", "value": "4"},
                {"kind": "operator", "glyph": "="}]}''';
  String series(String id, int step) => '''
    {"id": "$id", "ladder_step": $step, "answer": "8",
     "stimulus": {"kind": "numberSeries",
                  "payload": {"terms": [2, 4, 6, 8], "unknown_index": 3}}}''';

  return '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "2099-01-01T00:00:00Z",
  "items": [
    ${arithmetic('a1', 1)},
    ${series('s1', 1)},
    ${arithmetic('a2', 2)},
    ${series('s2', 2)},
    ${arithmetic('a3', 3)},
    ${arithmetic('a4', 4)}
  ]
}
''';
}

Future<void> _pump(WidgetTester tester, {required String pack}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AkiMathTheme.build(),
      home: AppShell(child: MapRoute(reader: PackReader(bundle: _FakeBundle(pack)))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('reads the pack and maps the families it carries',
      (WidgetTester tester) async {
    await _pump(tester, pack: _pack());

    expect(find.byType(SkillMapScreen), findsOneWidget);
    expect(find.text('Cuentas'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
  });

  testWidgets('a pack it cannot read says so instead of drawing a blank map',
      (WidgetTester tester) async {
    await _pump(tester, pack: '{"items": []}');

    expect(find.byType(SkillMapScreen), findsNothing);
    expect(find.textContaining('no se pudo'), findsOneWidget);
  });

  testWidgets('the map reads the cursor, so a played series shows up on it',
      (WidgetTester tester) async {
    await const SeriesCursorStore().advance(2);
    await _pump(tester, pack: _pack());

    // Items 0 and 1 served: one arithmetic at step 1 of 4, one series at step
    // 1 of 2.
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('opening a topic pushes its detail, and it comes back',
      (WidgetTester tester) async {
    await _pump(tester, pack: _pack());

    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    expect(find.byType(NodeDetailScreen), findsOneWidget);
    expect(find.text('CUENTAS'), findsOneWidget);

    await tester.tap(find.text('Volver al mapa'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillMapScreen), findsOneWidget);
  });

  testWidgets('practice plays that topic and nothing else',
      (WidgetTester tester) async {
    await _pump(tester, pack: _pack());

    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practicar 5 retos'));
    await tester.pumpAndSettle();

    final RoundScreen round =
        tester.widget<RoundScreen>(find.byType(RoundScreen));
    expect(round.items, hasLength(4));
    expect(
      round.items.map((Item item) => familyLabel(item.stimulus)).toSet(),
      <String>{'Cuentas'},
    );
  });

  testWidgets('practice leaves the cursor alone, so the map reports the run '
      'and not the practising', (WidgetTester tester) async {
    await _pump(tester, pack: _pack());

    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practicar 5 retos'));
    await tester.pumpAndSettle();

    expect(await const SeriesCursorStore().read(), 0);
  });
}
