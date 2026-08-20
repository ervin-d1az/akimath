import 'dart:convert';
import 'dart:io';

import 'package:akimath_app/api/history.dart';
import 'package:akimath_app/api/me.dart';
import 'package:flutter_test/flutter_test.dart';

/// The frozen contract, read rather than restated.
///
/// R2 in its client form: `contract/openapi.json` and `app/lib/api/` are two
/// descriptions of the same wire, and nothing else compares them. The server
/// has `test/contract-parity.test.ts` for its half; this is the other.
///
/// Thrown at load, the way `content/model/canon_test.dart` does it: this runs
/// while the file is being loaded, before any test body, where `expect` has
/// nowhere to report — and a parity test that silently covers nothing is worse
/// than none (PROC-10).
Map<String, Object?> _contract() {
  final File file = File('../contract/openapi.json');
  if (!file.existsSync()) {
    throw StateError(
      'the frozen contract is missing at ${file.absolute.path} — client parity '
      'cannot be checked, and a silently vacuous gate is worse than none',
    );
  }
  return json.decode(file.readAsStringSync()) as Map<String, Object?>;
}

Map<String, Object?> _schema(Map<String, Object?> contract, String name) {
  final Map<String, Object?> components =
      contract['components']! as Map<String, Object?>;
  final Map<String, Object?> schemas =
      components['schemas']! as Map<String, Object?>;
  return schemas[name]! as Map<String, Object?>;
}

/// Fields the model carries without checking their shape, and why.
///
/// **`playerId` is passed through, not validated.** The contract pins it to a
/// uuid pattern, and the asymmetry with `createdAt` is deliberate: parsing a
/// date *changes* the value, so an unvalidated one round-trips to different
/// bytes and the two sides stop agreeing about an instant. An id is carried
/// verbatim — an off-contract one is the server's bug, and refusing it here
/// would turn a cosmetic server defect into a client that cannot show a
/// profile.
///
/// Named rather than omitted, so a second entry has to be argued for.
const Map<String, String> _carriedNotValidated = <String, String>{
  'playerId': 'carried verbatim; validating it would refuse a profile over a server-side typo',
};

void main() {
  final Map<String, Object?> contract = _contract();
  final Map<String, Object?> me = _schema(contract, 'Me');
  final List<String> required =
      (me['required']! as List<Object?>).cast<String>();

  final Me sample = Me(
    playerId: '018f4e3c-0000-7000-8000-0000000000b1',
    ageBand: AgeBand.under13,
    createdAt: DateTime.utc(2026, 8, 19, 9, 15),
  );

  test('the gate read a real document', () {
    expect(required, isNotEmpty);
    // ignore: avoid_print
    print('  api parity · Me → ${required.length} required field(s), '
        '${_carriedNotValidated.length} carried without validation');
  });

  group('the Dart model is the frozen Me, both directions', () {
    test('it carries every field the schema requires', () {
      expect(sample.toJson().keys.toSet(), containsAll(required));
    });

    test('and no field the schema does not describe', () {
      // `additionalProperties: false` means the server will never send one, so
      // a field here that is not there is a field the client invented.
      final Map<String, Object?> properties =
          me['properties']! as Map<String, Object?>;
      expect(sample.toJson().keys.toSet(), properties.keys.toSet());
    });

    test('every band the schema names, in the order it names them', () {
      // Order too: `AgeBand.values` is what a `switch` is checked against, and
      // a set comparison would pass while the two drifted into different
      // orders — which is how an index-based serialisation silently rotates.
      final Map<String, Object?> properties =
          me['properties']! as Map<String, Object?>;
      final Map<String, Object?> band =
          properties['ageBand']! as Map<String, Object?>;
      final List<String> frozen = (band['enum']! as List<Object?>).cast<String>();

      expect(AgeBand.values.map((AgeBand b) => b.wireName).toList(), frozen);
    });
  });

  group('the Dart model is the frozen HistoryEntry, both directions', () {
    final Map<String, Object?> schema = _schema(contract, 'HistoryEntry');
    final List<String> entryRequired =
        (schema['required']! as List<Object?>).cast<String>();
    final Map<String, Object?> properties =
        schema['properties']! as Map<String, Object?>;

    final HistoryEntry sampleEntry = HistoryEntry(
      kind: HistoryKind.series,
      title: 'Restas',
      at: DateTime.utc(2026, 8, 19, 9, 15),
      score: '4/5',
      ratingDelta: null,
    );

    test('the gate read a real schema', () {
      expect(entryRequired, isNotEmpty);
      // ignore: avoid_print
      print('  api parity · HistoryEntry → ${entryRequired.length} required field(s)');
    });

    test('it carries every field the schema requires, and no other', () {
      expect(sampleEntry.toJson().keys.toSet(), containsAll(entryRequired));
      expect(sampleEntry.toJson().keys.toSet(), properties.keys.toSet());
    });

    test('every kind the schema names, in the order it names them', () {
      final Map<String, Object?> kind = properties['kind']! as Map<String, Object?>;
      final List<String> frozen = (kind['enum']! as List<Object?>).cast<String>();

      expect(HistoryKind.values.map((HistoryKind k) => k.wireName).toList(), frozen);
    });

    test('ratingDelta is nullable in the schema and nullable here', () {
      // Required *and* nullable is not the same as optional, and the difference
      // is what stops a client drawing "±0" where the truth is "not yet".
      final Map<String, Object?> delta =
          properties['ratingDelta']! as Map<String, Object?>;

      expect(entryRequired, contains('ratingDelta'));
      expect(delta['nullable'], isTrue);
      expect(sampleEntry.toJson()['ratingDelta'], isNull);
    });

    test('and its instant is read by the same reader Me uses', () {
      // One rule, one implementation. Two re-derivations of the contract's
      // `date-time` is exactly the drift R2 names.
      final Map<String, Object?> at = properties['at']! as Map<String, Object?>;
      final Map<String, Object?> meProperties =
          me['properties']! as Map<String, Object?>;
      final Map<String, Object?> createdAt =
          meProperties['createdAt']! as Map<String, Object?>;

      expect(at['pattern'], createdAt['pattern']);
    });
  });

  group("createdAt agrees with the contract's own pattern", () {
    // The model re-derives the rules rather than copying the frozen regular
    // expression — a copy is a second source of truth. This is what keeps the
    // re-derivation honest: both are run over the same probes and must agree
    // on every one.
    late final RegExp frozen;

    setUpAll(() {
      final Map<String, Object?> properties =
          me['properties']! as Map<String, Object?>;
      final Map<String, Object?> createdAt =
          properties['createdAt']! as Map<String, Object?>;
      frozen = RegExp(createdAt['pattern']! as String);
    });

    const List<String> probes = <String>[
      // Accepted by both.
      '2026-08-19T09:15:00.000Z',
      '2026-01-02T03:04:05.678Z',
      '2026-01-02T03:04:05Z',
      '2026-01-02T03:04Z',
      '2028-02-29T00:00:00.000Z',
      '2000-02-29T00:00:00.000Z',
      '2026-01-31T23:59:59.999Z',
      // Refused by both.
      '2026-01-02T03:04:05.678+00:00',
      '2026-01-02T03:04:05.678',
      '2026-01-02 03:04:05.678Z',
      '2026-02-30T00:00:00.000Z',
      '2025-02-29T00:00:00.000Z',
      '1900-02-29T00:00:00.000Z',
      '2026-04-31T00:00:00.000Z',
      '2026-13-01T00:00:00.000Z',
      '2026-01-02T24:00:00.000Z',
      '2026-01-02T03:60:00.000Z',
      'yesterday',
      '',
    ];

    test('on every probe, accepted or refused together', () {
      final List<String> disagreements = <String>[];
      for (final String probe in probes) {
        final bool byContract = frozen.hasMatch(probe);
        bool byModel;
        try {
          Me.fromJson(<String, Object?>{
            'playerId': '018f4e3c-0000-7000-8000-0000000000b1',
            'ageBand': 'adult',
            'createdAt': probe,
          });
          byModel = true;
        } on FormatException {
          byModel = false;
        }
        if (byContract != byModel) {
          disagreements.add(
            '"$probe": contract=${byContract ? 'accepts' : 'refuses'} '
            'model=${byModel ? 'accepts' : 'refuses'}',
          );
        }
      }

      expect(probes.length, greaterThan(10));
      expect(disagreements, isEmpty);
    });
  });

  group('what the client is allowed to expect back', () {
    test('GET /me is an operation the contract describes', () {
      final Map<String, Object?> paths = contract['paths']! as Map<String, Object?>;
      final Map<String, Object?> path = paths['/me']! as Map<String, Object?>;
      final Map<String, Object?> get = path['get']! as Map<String, Object?>;

      expect(get['operationId'], 'getMe');
    });

    test('every status the client maps is one the contract declares', () {
      // The client turns statuses into a sealed union. A status it handles that
      // the contract never declares is a branch written from memory.
      final Map<String, Object?> paths = contract['paths']! as Map<String, Object?>;
      final Map<String, Object?> path = paths['/me']! as Map<String, Object?>;
      final Map<String, Object?> get = path['get']! as Map<String, Object?>;
      final Set<String> declared =
          (get['responses']! as Map<String, Object?>).keys.toSet();

      // 500 is deliberately absent: the contract does not declare it and the
      // client must still survive one, so it falls into the catch-all rather
      // than a branch of its own.
      expect(declared, containsAll(<String>['200', '401', '404']));
    });

    test('every carried-not-validated field is really in the schema', () {
      // A stale exclusion silently excuses nothing.
      final Map<String, Object?> properties =
          me['properties']! as Map<String, Object?>;
      for (final MapEntry<String, String> entry in _carriedNotValidated.entries) {
        expect(properties.keys, contains(entry.key));
        expect(entry.value, isNotEmpty);
      }
    });
  });

  group('the link the client can now make', () {
    test('POST /players/link is an operation the contract describes', () {
      final Map<String, Object?> paths = contract['paths']! as Map<String, Object?>;
      final Map<String, Object?> post =
          (paths['/players/link']! as Map<String, Object?>)['post']! as Map<String, Object?>;
      expect(post['operationId'], 'linkPlayer');
    });

    test('every status the client maps is one the contract declares', () {
      final Map<String, Object?> paths = contract['paths']! as Map<String, Object?>;
      final Map<String, Object?> post =
          (paths['/players/link']! as Map<String, Object?>)['post']! as Map<String, Object?>;
      final Set<String> declared =
          (post['responses']! as Map<String, Object?>).keys.toSet();

      // One branch per status the client has a result type for. 409 is the one
      // this operation added, and a client that mapped it without the contract
      // declaring it would be reading a status from memory.
      expect(declared, containsAll(<String>['200', '400', '401', '409']));
    });

    test('the request carries what the schema requires and nothing more', () {
      final Map<String, Object?> link = _schema(contract, 'PlayerLink');
      final Set<String> required =
          (link['required']! as List<Object?>).cast<String>().toSet();
      final Set<String> properties =
          (link['properties']! as Map<String, Object?>).keys.toSet();

      // What `linkPlayer` sends, spelled here so a field added to the schema
      // without a parameter fails rather than silently going unsent.
      expect(required, <String>{'playerId', 'ageBand'});
      expect(properties, required);
      expect(link['additionalProperties'], isFalse);
    });

    test('the header the contract marks required is one the client sends', () {
      final Map<String, Object?> paths = contract['paths']! as Map<String, Object?>;
      final Map<String, Object?> post =
          (paths['/players/link']! as Map<String, Object?>)['post']! as Map<String, Object?>;
      final List<Object?> parameters = post['parameters']! as List<Object?>;
      final List<String> requiredHeaders = <String>[
        for (final Object? p in parameters)
          if ((p! as Map<String, Object?>)['in'] == 'header' &&
              (p as Map<String, Object?>)['required'] == true)
            (p)['name']! as String,
      ];
      expect(requiredHeaders, <String>['Idempotency-Key']);
    });
  });
}
