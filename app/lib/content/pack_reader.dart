import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'model/pack.dart';

/// Reads a pack out of the app bundle.
///
/// **The one adapter in `content/`.** It does the two things the model cannot:
/// touches an `AssetBundle`, and decodes a string. Every decision about what a
/// pack *is* lives in `Pack.fromJson`, which is pure — so this class has
/// nothing to test beyond "it read the right file and handed the bytes on".
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
  Future<Pack> load([String path = starterPath]) async {
    final String source = await _assets.loadString(path);
    final Object? decoded = json.decode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('a pack must be a JSON object');
    }
    return Pack.fromJson(decoded);
  }
}
