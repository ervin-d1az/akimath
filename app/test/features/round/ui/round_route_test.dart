import 'dart:convert';

import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/features/round/ui/round_route.dart';
import 'package:akimath_app/features/round/ui/round_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(source));
}

String _pack({required String expiresAt}) => '''
{
  "pack_version": 1,
  "pack_id": "test",
  "issued_at": "2026-08-01T00:00:00Z",
  "expires_at": "$expiresAt",
  "items": [
    {
      "id": "a1",
      "ladder_step": 2,
      "answer": "42",
      "prompt": [
        {"kind": "text", "value": "6"},
        {"kind": "operator", "glyph": "×"},
        {"kind": "text", "value": "7"},
        {"kind": "operator", "glyph": "="}
      ]
    }
  ]
}
''';

Future<void> _pump(WidgetTester tester, String source) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: RoundRoute(reader: PackReader(bundle: _FakeBundle(source))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the route loads a pack and plays it', () {
    testWidgets('a valid pack reaches the screen', (WidgetTester tester) async {
      await _pump(tester, _pack(expiresAt: '2099-01-01T00:00:00Z'));

      expect(find.byType(RoundScreen), findsOneWidget);
    });

    testWidgets('an expired pack is refused rather than played',
        (WidgetTester tester) async {
      await _pump(tester, _pack(expiresAt: '2020-01-01T00:00:00Z'));

      expect(
        find.byType(RoundScreen),
        findsNothing,
        reason: 'an expired pack was served anyway',
      );
      expect(find.textContaining('vencieron'), findsOneWidget);
    });

    testWidgets('a broken pack shows a message rather than crashing',
        (WidgetTester tester) async {
      await _pump(tester, '{"nope": true}');

      expect(find.byType(RoundScreen), findsNothing);
      expect(find.textContaining('No se pudo'), findsOneWidget);
    });

    testWidgets('no spinner is used while loading',
        (WidgetTester tester) async {
      // `4.11` is annotated *esqueletos, sin ruedita*, and LoadingDots is
      // explicitly not to be repurposed for a product screen.
      await _pump(tester, _pack(expiresAt: '2099-01-01T00:00:00Z'));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
