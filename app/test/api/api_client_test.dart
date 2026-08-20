import 'dart:convert';
import 'dart:io';

import 'package:akimath_app/api/api_client.dart';
import 'package:akimath_app/api/me.dart';
import 'package:flutter_test/flutter_test.dart';

const String _playerId = '018f4e3c-0000-7000-8000-0000000000b1';
const String _token = 'a.bearer.token';

/// A real HTTP server on loopback, answering however the test says.
///
/// **No mocking library, and no fake transport.** `dart:io` gives a server for
/// free, so the client under test is the production one talking over a real
/// socket — real headers, real status line, real body. A fake `HttpClient`
/// would have proved that the client calls the fake correctly.
class _Server {
  _Server(this._socket, this.requests, this.bodies);

  static Future<_Server> answering(
    Future<void> Function(HttpRequest request) respond,
  ) async {
    final HttpServer socket = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final List<HttpRequest> requests = <HttpRequest>[];
    final List<String> bodies = <String>[];
    socket.listen((HttpRequest request) async {
      requests.add(request);
      bodies.add(await utf8.decodeStream(request));
      await respond(request);
      await request.response.close();
    });
    return _Server(socket, requests, bodies);
  }

  final HttpServer _socket;
  final List<HttpRequest> requests;
  final List<String> bodies;

  Uri get baseUrl => Uri.parse('http://${_socket.address.host}:${_socket.port}/');

  Future<void> close() => _socket.close(force: true);
}

Future<void> _json(HttpRequest request, int status, Object? body) async {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(json.encode(body));
}

void main() {
  late _Server server;
  late ApiClient client;

  Future<void> serving(Future<void> Function(HttpRequest) respond) async {
    server = await _Server.answering(respond);
    client = ApiClient(baseUrl: server.baseUrl);
  }

  tearDown(() async {
    client.close();
    await server.close();
  });

  group('GET /me over a real socket', () {
    test('a 200 becomes the profile it carried', () async {
      await serving((HttpRequest request) => _json(request, 200, <String, Object?>{
        'playerId': _playerId,
        'ageBand': 'under_13',
        'createdAt': '2026-08-19T09:15:00.000Z',
      }));

      final MeResult result = await client.getMe(_token);

      expect(result, isA<MeFound>());
      final Me me = (result as MeFound).me;
      expect(me.playerId, _playerId);
      expect(me.ageBand, AgeBand.under13);
      expect(me.createdAt, DateTime.utc(2026, 8, 19, 9, 15));
    });

    test('it asks the right path and sends the token as a bearer', () async {
      await serving((HttpRequest request) => _json(request, 404, <String, Object?>{
        'error': 'no_player',
        'message': 'This account has no player yet.',
      }));

      await client.getMe(_token);

      final HttpRequest asked = server.requests.single;
      expect(asked.method, 'GET');
      expect(asked.uri.path, '/me');
      expect(asked.headers.value(HttpHeaders.authorizationHeader), 'Bearer $_token');
      expect(asked.headers.value(HttpHeaders.acceptHeader), 'application/json');
    });

    test('a blank token sends no header, so the refusal says what is true', () async {
      // `Bearer ` is a header the server can only refuse, and it refuses it as
      // `invalid_session` when the truth is `unauthenticated`. Sending nothing
      // is what "I have no token" means on the wire.
      await serving((HttpRequest request) => _json(request, 401, <String, Object?>{
        'error': 'unauthenticated',
        'message': 'This operation needs a session.',
      }));

      for (final String blank in <String>['', '   ']) {
        await client.getMe(blank);
      }

      expect(server.requests, hasLength(2));
      for (final HttpRequest asked in server.requests) {
        expect(asked.headers.value(HttpHeaders.authorizationHeader), isNull);
      }
    });

    test('a 404 is no player, which is not an error', () async {
      await serving((HttpRequest request) => _json(request, 404, <String, Object?>{
        'error': 'no_player',
        'message': 'This account has no player yet.',
      }));

      expect(await client.getMe(_token), isA<MeNoPlayer>());
    });

    test('a 401 carries the tag, so the two reasons stay distinguishable', () async {
      // `unauthenticated` and `invalid_session` are different bugs — nothing
      // sent versus something broken — and the server went to the trouble of
      // separating them.
      await serving((HttpRequest request) => _json(request, 401, <String, Object?>{
        'error': 'invalid_session',
        'message': '"exp" claim timestamp check failed',
      }));

      final MeResult result = await client.getMe(_token);

      expect(result, isA<MeRejected>());
      expect((result as MeRejected).tag, 'invalid_session');
      expect(result.message, contains('exp'));
    });

    test('a 500 is a failure and never a profile', () async {
      await serving((HttpRequest request) => _json(request, 500, <String, Object?>{
        'error': 'internal',
        'message': 'That went wrong on our side.',
      }));

      final MeResult result = await client.getMe(_token);
      expect(result, isA<MeFailed>());
      expect((result as MeFailed).status, 500);
    });

    test('a 501 is a failure too, because this operation is meant to exist', () async {
      await serving((HttpRequest request) => _json(request, 501, <String, Object?>{
        'error': 'not_implemented',
        'message': 'The server has not built it yet.',
      }));

      expect(await client.getMe(_token), isA<MeFailed>());
    });
  });

  group('what a server can do wrong', () {
    test('a 200 whose body is not a profile is a failure, not a crash', () async {
      // The case that would otherwise reach a screen as an exception from a
      // constructor: a 200 the contract promises is a `Me` and is not one.
      await serving((HttpRequest request) => _json(request, 200, <String, Object?>{
        'playerId': _playerId,
      }));

      final MeResult result = await client.getMe(_token);
      expect(result, isA<MeFailed>());
      expect((result as MeFailed).status, 200);
    });

    test('a 200 that is not JSON at all is a failure, not a crash', () async {
      await serving((HttpRequest request) async {
        request.response.statusCode = 200;
        request.response.write('<html>a proxy said no</html>');
      });

      expect(await client.getMe(_token), isA<MeFailed>());
    });

    test('an error page in place of the frozen Error shape still reports', () async {
      // A failing server is the one most likely to answer with HTML from
      // something in front of it. Reading the tag must not throw.
      await serving((HttpRequest request) async {
        request.response.statusCode = 502;
        request.response.write('<html>bad gateway</html>');
      });

      final MeResult result = await client.getMe(_token);
      expect(result, isA<MeFailed>());
      expect((result as MeFailed).status, 502);
    });
  });

  group('when no answer arrives', () {
    test('a refused socket is unreachable, not an exception', () async {
      // Bound and immediately closed, so the port is real and nothing listens.
      final HttpServer dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final Uri gone = Uri.parse('http://${dead.address.host}:${dead.port}/');
      await dead.close(force: true);

      final ApiClient orphan = ApiClient(baseUrl: gone);
      addTearDown(orphan.close);

      expect(await orphan.getMe(_token), isA<MeUnreachable>());
    });

    test('a server that never answers times out as unreachable', () async {
      // The timeout is a constructor parameter precisely so this test does not
      // take ten seconds.
      server = await _Server.answering((HttpRequest request) =>
          Future<void>.delayed(const Duration(seconds: 30)));
      client = ApiClient(
        baseUrl: server.baseUrl,
        timeout: const Duration(milliseconds: 150),
      );

      expect(await client.getMe(_token), isA<MeUnreachable>());
    });
  });

  group('GET /me/history over a real socket', () {
    Map<String, Object?> entry() => <String, Object?>{
      'kind': 'series',
      'title': 'Restas',
      'at': '2026-08-19T09:15:00.000Z',
      'score': '4/5',
      'ratingDelta': null,
    };

    test('a 200 becomes the sessions it carried', () async {
      await serving((HttpRequest request) => _json(request, 200, <String, Object?>{
        'entries': <Object?>[entry()],
      }));

      final HistoryResult result = await client.getHistory(_token);

      expect(result, isA<HistoryFound>());
      expect((result as HistoryFound).history.entries.single.title, 'Restas');
      expect(server.requests.single.uri.path, '/me/history');
      expect(server.requests.single.method, 'GET');
    });

    test('an empty list is a success, not a failure', () async {
      await serving((HttpRequest request) => _json(request, 200, <String, Object?>{
        'entries': <Object?>[],
      }));

      final HistoryResult result = await client.getHistory(_token);

      expect(result, isA<HistoryFound>());
      expect((result as HistoryFound).history.isEmpty, isTrue);
    });

    test('a 404 is no player, which is not an error either', () async {
      await serving((HttpRequest request) => _json(request, 404, <String, Object?>{
        'error': 'no_player',
        'message': 'This account has no player yet.',
      }));

      expect(await client.getHistory(_token), isA<HistoryNoPlayer>());
    });

    test('a 401 keeps its tag', () async {
      await serving((HttpRequest request) => _json(request, 401, <String, Object?>{
        'error': 'invalid_session',
        'message': 'that token expired',
      }));

      final HistoryResult result = await client.getHistory(_token);

      expect(result, isA<HistoryRejected>());
      expect((result as HistoryRejected).tag, 'invalid_session');
    });

    test('a 200 that is not a history is a failure, not a crash', () async {
      // A server that broke the contract. It is not a history, so it cannot be
      // `HistoryFound`, and it is not the caller's fault.
      await serving((HttpRequest request) => _json(request, 200, <String, Object?>{
        'entries': <Object?>[<String, Object?>{'kind': 'series'}],
      }));

      expect(await client.getHistory(_token), isA<HistoryFailed>());
    });

    test('a blank token sends no header at all', () async {
      await serving((HttpRequest request) => _json(request, 401, <String, Object?>{
        'error': 'unauthenticated',
        'message': 'no session',
      }));

      await client.getHistory('  ');

      expect(
        server.requests.single.headers.value(HttpHeaders.authorizationHeader),
        isNull,
      );
    });

    test('no answer at all is unreachable', () async {
      await serving((HttpRequest request) async {});
      await server.close();

      expect(await client.getHistory(_token), isA<HistoryUnreachable>());
    });
  });

  group('DELETE /me over a real socket', () {
    test('a 204 with no body is an erasure', () async {
      await serving((HttpRequest request) async {
        request.response.statusCode = 204;
      });

      final EraseResult result = await client.eraseMe(_token);

      expect(result, isA<EraseDone>());
      expect(server.requests.single.method, 'DELETE');
      expect(server.requests.single.uri.path, '/me');
      expect(
        server.requests.single.headers.value(HttpHeaders.authorizationHeader),
        'Bearer $_token',
      );
    });

    test('and it does not try to read a body that is not there', () async {
      // A 204 carries none by definition. A client that parses one anyway turns
      // a successful erasure into a `FormatException` the player sees as a
      // failure — and then does not retry, because the row really is gone.
      await serving((HttpRequest request) async {
        request.response.statusCode = 204;
      });

      expect(await client.eraseMe(_token), isA<EraseDone>());
    });

    test('a 404 is nothing left to erase, not a failure', () async {
      await serving((HttpRequest request) => _json(request, 404, <String, Object?>{
        'error': 'no_player',
        'message': 'This account has no player, so there is nothing to erase.',
      }));

      expect(await client.eraseMe(_token), isA<EraseNothingThere>());
    });

    test('a 401 keeps its tag', () async {
      await serving((HttpRequest request) => _json(request, 401, <String, Object?>{
        'error': 'invalid_session',
        'message': 'that token expired',
      }));

      final EraseResult result = await client.eraseMe(_token);

      expect(result, isA<EraseRejected>());
      expect((result as EraseRejected).tag, 'invalid_session');
      expect(result.message, 'that token expired');
    });

    test('a blank token sends no header at all', () async {
      await serving((HttpRequest request) => _json(request, 401, <String, Object?>{
        'error': 'unauthenticated',
        'message': 'no session',
      }));

      await client.eraseMe('   ');

      expect(
        server.requests.single.headers.value(HttpHeaders.authorizationHeader),
        isNull,
      );
    });

    test('anything else is a failure carrying its status', () async {
      await serving((HttpRequest request) => _json(request, 500, <String, Object?>{
        'error': 'internal',
        'message': 'That went wrong on our side.',
      }));

      final EraseResult result = await client.eraseMe(_token);

      expect(result, isA<EraseFailed>());
      expect((result as EraseFailed).status, 500);
    });

    test('no answer at all is unreachable', () async {
      await serving((HttpRequest request) async {});
      await server.close();

      expect(await client.eraseMe(_token), isA<EraseUnreachable>());
    });
  });

  group('POST /players/link over a real socket', () {
    Future<LinkResult> link({String token = _token, String key = 'k-1'}) => client.linkPlayer(
      accessToken: token,
      playerId: _playerId,
      ageBand: AgeBand.under13,
      idempotencyKey: key,
    );

    test('a 200 becomes the profile the link created', () async {
      await serving((HttpRequest request) => _json(request, 200, <String, Object?>{
        'playerId': _playerId,
        'ageBand': 'under_13',
        'createdAt': '2026-08-19T09:15:00.000Z',
      }));

      final LinkResult result = await link();
      expect(result, isA<LinkDone>());
      expect((result as LinkDone).me.playerId, _playerId);
    });

    test('it posts the band and the key, and never the account', () async {
      // The server takes the account from the token and refuses a body that
      // mentions it. There is no parameter for one here, so there is nothing
      // to send by mistake.
      await serving((HttpRequest request) => _json(request, 200, <String, Object?>{
        'playerId': _playerId,
        'ageBand': 'under_13',
        'createdAt': '2026-08-19T09:15:00.000Z',
      }));

      await link(key: 'the-key');

      final HttpRequest asked = server.requests.single;
      expect(asked.method, 'POST');
      expect(asked.uri.path, '/players/link');
      expect(asked.headers.value('Idempotency-Key'), 'the-key');
      expect(asked.headers.value(HttpHeaders.authorizationHeader), 'Bearer $_token');
      expect(server.bodies.single, contains('"ageBand":"under_13"'));
      expect(server.bodies.single, isNot(contains('authUserId')));
    });

    test('a 409 is a conflict a person can read, not a failure', () async {
      await serving((HttpRequest request) => _json(request, 409, <String, Object?>{
        'error': 'already_linked',
        'message': 'This account already has a player.',
      }));

      final LinkResult result = await link();
      expect(result, isA<LinkConflict>());
      expect((result as LinkConflict).message, contains('already has a player'));
    });

    test('a 400 says what was wrong with the request', () async {
      await serving((HttpRequest request) => _json(request, 400, <String, Object?>{
        'error': 'malformed',
        'message': 'ageBand must be one of under_13, 13_17, adult.',
      }));

      expect(await link(), isA<LinkMalformed>());
    });

    test('a 401 keeps its tag', () async {
      await serving((HttpRequest request) => _json(request, 401, <String, Object?>{
        'error': 'invalid_session',
        'message': 'expired',
      }));

      final LinkResult result = await link();
      expect((result as LinkRejected).tag, 'invalid_session');
    });

    test('a 500 and an unreadable 200 are both failures', () async {
      await serving((HttpRequest request) => _json(request, 500, <String, Object?>{}));
      expect(await link(), isA<LinkFailed>());
    });

    test('no answer at all is unreachable', () async {
      final HttpServer dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final Uri gone = Uri.parse('http://${dead.address.host}:${dead.port}/');
      await dead.close(force: true);
      final ApiClient orphan = ApiClient(baseUrl: gone);
      addTearDown(orphan.close);

      expect(
        await orphan.linkPlayer(
          accessToken: _token,
          playerId: _playerId,
          ageBand: AgeBand.adult,
          idempotencyKey: 'k',
        ),
        isA<LinkUnreachable>(),
      );
    });
  });
}
