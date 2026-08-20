import 'dart:convert';
import 'dart:io';


import 'me.dart';
import 'me_result.dart';

// Re-exported so a caller that fetches and a caller that only reads the result
// both need one import.
export 'me_result.dart';

/// The one place in the app that opens a socket.
///
/// **A PURE-2 adapter, holding no decisions** (ADR 0001). No retry, no backoff,
/// no caching, no token storage: it is handed a token and a base URL, and it
/// turns one request into one typed result. Whether to retry is the caller's
/// question, and putting it here would answer it identically for every screen.
///
/// `dart:io`'s `HttpClient` rather than a package, because AkiMath is a mobile
/// app and that keeps the runtime dependency list where it is — `flutter`,
/// `cupertino_icons`, `meta`, `shared_preferences`. On the web this would not
/// compile; there is no web build.
///
/// **The base URL carries whatever prefix the deployment uses.** The contract
/// declares `servers: [{ url: "/v1" }]`, so a deployed server is reached at
/// `https://host/v1`; the server does not mount there yet, so against a local
/// one the base URL is just `http://localhost:PORT`. The client takes the whole
/// thing rather than assuming either.
class ApiClient {
  ApiClient({
    required Uri baseUrl,
    HttpClient? transport,
    this.timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl,
       _transport = transport ?? HttpClient();

  final Uri _baseUrl;
  final HttpClient _transport;

  /// How long one request may take, end to end.
  ///
  /// A timeout is not a retry policy — it is the difference between a screen
  /// that reports a failure and one that spins forever on a network that went
  /// away mid-answer. It is a constructor parameter so the default is visible
  /// and a caller who knows better can say so.
  final Duration timeout;

  Future<MeResult> getMe(String accessToken) async {
    final Uri url = _baseUrl.resolve('me');
    try {
      final HttpClientRequest request = await _transport.getUrl(url);
      // **A blank token sends no header at all.** Sending `Bearer ` is a header
      // the server can only refuse, and it refuses it as `invalid_session` —
      // "you sent something broken" — when the truth is `unauthenticated`,
      // "you sent nothing". The server went to the trouble of separating those
      // two, and a client that garbles the distinction wastes it. Found by
      // running the real client against the real server, not by reading it.
      if (accessToken.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close().timeout(timeout);
      final String body = await response.transform(utf8.decoder).join();
      return _read(response.statusCode, body);
    } on Exception catch (cause) {
      // **Every transport failure, as a value.** `SocketException`,
      // `TimeoutException`, a malformed URL: a screen cannot `catch` what it
      // never called, and letting these escape would make the caller handle
      // errors in two shapes.
      return MeUnreachable(cause.toString());
    }
  }

  /// Attaches this device's player to the account the token names.
  ///
  /// **The band travels; the account does not.** The server takes the account
  /// from the verified token and refuses a body that so much as mentions it —
  /// so there is no parameter here for one, deliberately.
  ///
  /// `Idempotency-Key` is required by the contract. The caller supplies it, so
  /// a retry of *the same* attempt can carry the same key; generating one here
  /// would make every retry look like a new request.
  Future<LinkResult> linkPlayer({
    required String accessToken,
    required String playerId,
    required AgeBand ageBand,
    required String idempotencyKey,
  }) async {
    final Uri url = _baseUrl.resolve('players/link');
    try {
      final HttpClientRequest request = await _transport.postUrl(url);
      if (accessToken.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }
      request.headers.set('Idempotency-Key', idempotencyKey);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(json.encode(<String, Object?>{
        'playerId': playerId,
        'ageBand': ageBand.wireName,
      }));
      final HttpClientResponse response = await request.close().timeout(timeout);
      final String body = await response.transform(utf8.decoder).join();
      return _readLink(response.statusCode, body);
    } on Exception catch (cause) {
      return LinkUnreachable(cause.toString());
    }
  }

  LinkResult _readLink(int status, String body) {
    final Map<String, Object?> error = _errorOr(body);
    final String message = error['message'] as String? ?? '';
    switch (status) {
      case 200:
        try {
          return LinkDone(Me.fromJson(_object(body)));
        } on FormatException catch (cause) {
          return LinkFailed(status: status, reason: cause.message);
        }
      case 400:
        return LinkMalformed(message);
      case 401:
        return LinkRejected(
          tag: error['error'] as String? ?? 'unauthenticated',
          message: message,
        );
      case 409:
        return LinkConflict(message);
      default:
        return LinkFailed(status: status, reason: message.isEmpty ? body : message);
    }
  }

  MeResult _read(int status, String body) {
    switch (status) {
      case 200:
        try {
          return MeFound(Me.fromJson(_object(body)));
        } on FormatException catch (cause) {
          // A 200 whose body is not a `Me` is a server that broke the contract.
          // It is not a profile, so it cannot be `MeFound`, and it is not the
          // caller's fault, so it is not `MeRejected`.
          return MeFailed(status: status, reason: cause.message);
        }
      case 401:
        final Map<String, Object?> error = _errorOr(body);
        return MeRejected(
          tag: error['error'] as String? ?? 'unauthenticated',
          message: error['message'] as String? ?? '',
        );
      case 404:
        return const MeNoPlayer();
      default:
        return MeFailed(status: status, reason: _errorOr(body)['message'] as String? ?? body);
    }
  }

  Map<String, Object?> _object(String body) {
    final Object? decoded = json.decode(body);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('the body is not a JSON object', body);
    }
    return decoded;
  }

  /// The frozen `Error` shape if the body is one, and an empty map otherwise.
  ///
  /// A failing server is exactly the server most likely to answer with an HTML
  /// error page from something in front of it, so this never throws.
  Map<String, Object?> _errorOr(String body) {
    try {
      return _object(body);
    } on FormatException {
      return const <String, Object?>{};
    }
  }

  /// Releases the underlying connections. Call it when the app is done.
  void close() => _transport.close();
}
