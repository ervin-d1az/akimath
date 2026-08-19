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
  _Server(this._socket, this.requests);

  static Future<_Server> answering(
    Future<void> Function(HttpRequest request) respond,
  ) async {
    final HttpServer socket = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final List<HttpRequest> requests = <HttpRequest>[];
    socket.listen((HttpRequest request) async {
      requests.add(request);
      await respond(request);
      await request.response.close();
    });
    return _Server(socket, requests);
  }

  final HttpServer _socket;
  final List<HttpRequest> requests;

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
}
