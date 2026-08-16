import 'dart:io';

import 'import_graph.dart';

/// The PURE-2 adapter beside `import_graph.dart`.
///
/// It owns the only filesystem access in the gate: it enumerates the Dart files
/// under `app/lib/`, reads their bytes, and answers which of the pure roots are
/// on disk. It decides nothing — what counts as a violation, what a URI
/// resolves to, and what belongs to which root all live on the pure side.
///
/// The sources are handed on **raw**. Comment stripping is lexical analysis of
/// Dart, which is a decision, so it belongs to `import_graph.dart`'s entry
/// points and not here.
final class SourceTree {
  const SourceTree._({
    required this.libRoot,
    required this.sources,
    required this.presentRoots,
  });

  /// Reads the tree of the package the test is running in.
  ///
  /// `flutter test` runs with `app/` as the working directory, so `lib` is the
  /// package's source root.
  factory SourceTree.readAppLib() => SourceTree.readFrom(Directory('lib'));

  factory SourceTree.readFrom(Directory libRoot) {
    if (!libRoot.existsSync()) {
      throw StateError(
        'No Dart source root at ${libRoot.absolute.path}. Every pure root '
        'would report absent and the gate would pass while scanning nothing.',
      );
    }
    final Map<String, String> sources = <String, String>{};
    final Set<PureRoot> presentRoots = <PureRoot>{};
    for (final FileSystemEntity entity
        in libRoot.listSync(recursive: true, followLinks: false)) {
      final String relativePath = _relativeTo(libRoot, entity);
      if (entity is Directory) {
        presentRoots.addAll(
          PureRoot.values.where(
            (PureRoot root) => root.containsDirectory(relativePath),
          ),
        );
        continue;
      }
      if (entity is File && relativePath.endsWith('.dart')) {
        sources[relativePath] = entity.readAsStringSync();
      }
    }
    return SourceTree._(
      libRoot: libRoot,
      sources: Map<String, String>.unmodifiable(sources),
      presentRoots: Set<PureRoot>.unmodifiable(presentRoots),
    );
  }

  static String _relativeTo(Directory libRoot, FileSystemEntity entity) {
    final String prefix = libRoot.path.endsWith(Platform.pathSeparator)
        ? libRoot.path
        : '${libRoot.path}${Platform.pathSeparator}';
    return entity.path
        .substring(prefix.length)
        .replaceAll(Platform.pathSeparator, '/');
  }

  /// The directory the sources were read from.
  final Directory libRoot;

  /// Lib-relative path to raw source text, for every `.dart` file found.
  final Map<String, String> sources;

  /// The pure roots that exist on disk. A root missing from this set is absent,
  /// which is not the same as present and empty.
  final Set<PureRoot> presentRoots;
}
