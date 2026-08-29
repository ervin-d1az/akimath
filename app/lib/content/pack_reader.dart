import 'dart:convert';
import 'dart:typed_data' show ByteData;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'model/pack.dart';

/// Reads a pack out of the app bundle.
///
/// **The one file in `content/` that performs IO.** It does the two things the
/// model cannot: touches an `AssetBundle`, and decodes a string. Nothing else
/// under `content/` reads a file, a socket, a clock or an environment. It is
/// not the only file outside the `content/model/` pure root — `answer_digest`
/// is out there too, and labels itself an adapter for its import alone, which
/// is why the claim here is about IO and is checkable by grep. Every decision
/// about what a pack *is* lives in `Pack.fromJson`, which is pure — so this
/// class has nothing to test beyond "it read the right file and handed the
/// bytes on".
///
/// It makes **no network request**, and cannot: an `AssetBundle` serves what was
/// compiled into the app. That is `req-offline-pack-play` satisfied by
/// construction rather than by discipline.
class PackReader {
  const PackReader({AssetBundle? bundle}) : _bundle = bundle;

  /// The pack that ships with the app.
  static const String starterPath = 'assets/packs/starter.json';

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  /// Loads and parses the pack at [path].
  ///
  /// Throws [FormatException] if the pack is malformed — content is validated
  /// where it is read, so a broken pack fails at load rather than showing a
  /// player a wrong verdict later.
  ///
  /// **It decodes the bytes itself rather than calling `loadString`.** Flutter
  /// hands a UTF-8 decode over 50 KB to a background isolate, and the shipped
  /// pack passed that mark the day it started carrying several boards per
  /// format. An isolate never completes inside `testWidgets`' fake-async zone,
  /// so every widget test that loads the real pack stopped failing and started
  /// *hanging* for ten minutes — which is a far worse thing for a suite to do.
  ///
  /// Decoding here also spares the app an isolate spawn at launch, for a file
  /// it compiled in itself and already knows is UTF-8.
  Future<Pack> load([String path = starterPath]) async {
    final ByteData bytes = await _assets.load(path);
    final String source = utf8.decode(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final Object? decoded = json.decode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('a pack must be a JSON object');
    }
    return Pack.fromJson(decoded);
  }
}
