/// Pure analysis of the repository's import graph.
///
/// This module is handed a map of lib-relative path to source text and returns
/// findings. It opens no file and touches no `Canvas`: the filesystem walk that
/// produces the map is `source_tree.dart`, the adapter beside it (PURE-1,
/// PURE-2). Keeping the analysis on this side is what lets the scenarios that
/// describe a repository which would not compile — a `policy/` file importing
/// the token barrel, two feature barrels importing each other — be proven
/// against a synthetic graph instead of against files written to disk.
library;

import 'package:meta/meta.dart';

/// The directive forms the closure walks.
///
/// `part` is included because a part file's directives belong to its library:
/// leaving it out would let a `part` smuggle an import past the closure.
enum DirectiveKind { import, export, part }

/// One `import`, `export` or `part` directive, with the line it was read from.
@immutable
final class SourceDirective {
  const SourceDirective({
    required this.kind,
    required this.uri,
    required this.line,
  });

  final DirectiveKind kind;
  final String uri;
  final int line;

  @override
  String toString() => '$line: ${kind.name} $uri';
}

/// What a URI the closure cannot walk into means for a pure file.
enum LeafVerdict { allowed, forbidden }

/// The directories plan §2.2's import ceiling applies to.
///
/// Only [designSpec] exists today. The other two arrive with later changes, and
/// a root that is not on disk is reported as absent rather than counted as
/// zero — otherwise a gate scanning nothing is indistinguishable from a gate
/// finding nothing (design D-7).
enum PureRoot {
  featurePolicy('features/*/policy/'),
  designSpec('design/**/spec/'),
  contentModel('content/model/');

  const PureRoot(this.label);

  /// How the root is written in plan §2.2, used verbatim in the gate's report.
  final String label;

  /// Whether a directory path relative to `app/lib/` lies inside this root.
  bool containsDirectory(String libDirPath) {
    final List<String> segments = libDirPath.split('/');
    return switch (this) {
      PureRoot.featurePolicy => segments.length >= 3 &&
          segments.first == 'features' &&
          segments[2] == 'policy',
      PureRoot.designSpec =>
        segments.first == 'design' && segments.skip(1).contains('spec'),
      PureRoot.contentModel => segments.length >= 2 &&
          segments.first == 'content' &&
          segments[1] == 'model',
    };
  }

  /// Whether a file path relative to `app/lib/` lies inside this root.
  bool containsFile(String libFilePath) {
    final int lastSlash = libFilePath.lastIndexOf('/');
    return lastSlash > 0 &&
        containsDirectory(libFilePath.substring(0, lastSlash));
  }

  /// The files of [libPaths] that lie inside this root, in a stable order.
  List<String> selectFiles(Iterable<String> libPaths) =>
      libPaths.where(containsFile).toList()..sort();
}

/// One line per root, naming what the gate actually looked at.
///
/// The count is printed rather than inferred from a green run: a root that
/// exists and contributes nothing looks exactly like a root with nothing wrong
/// in it, and an absent root has to read as absent rather than as zero
/// (design D-7).
List<String> rootCoverageReport({
  required Iterable<String> libPaths,
  required Set<PureRoot> presentRoots,
}) {
  return <String>[
    for (final PureRoot root in PureRoot.values)
      presentRoots.contains(root)
          ? '${root.label} → ${root.selectFiles(libPaths).length} files'
          : '${root.label} → absent',
  ];
}

/// A forbidden URI a pure file can reach, and the chain it reaches it by.
@immutable
final class BoundaryViolation {
  const BoundaryViolation(this.path);

  /// From the pure file, through every repo-local file the closure walked, to
  /// the forbidden leaf. Both ends matter: the direct import at the call site
  /// is innocent-looking, and only the chain shows what it drags in.
  final List<String> path;

  String get file => path.first;

  String get forbiddenUri => path.last;

  String get message =>
      '$file must not reach $forbiddenUri\n      ${path.join('\n   → ')}';

  @override
  String toString() => message;
}

/// Every directive form, which is what the ceiling has to be checked against.
const Set<DirectiveKind> allDirectiveKinds = <DirectiveKind>{
  DirectiveKind.import,
  DirectiveKind.export,
  DirectiveKind.part,
};

/// Every forbidden URI reachable from [pureFiles] through repo-local
/// directives.
///
/// [follow] and [maxHops] exist so the gate's own test can prove the closure is
/// load-bearing: a walk restricted to `import`, and a walk stopped after one
/// hop, both report zero on the graph the full walk fails. Their defaults are
/// the ceiling plan §2.2 asks for.
///
/// A repo-local target that is not a key of [sources] is skipped. On the real
/// tree that cannot hide anything — a directive pointing at a file that does
/// not exist is a compile error, and `flutter analyze --fatal-infos` runs
/// beside this test.
List<BoundaryViolation> findBoundaryViolations({
  required Map<String, String> sources,
  required Iterable<String> pureFiles,
  Set<DirectiveKind> follow = allDirectiveKinds,
  int? maxHops,
}) {
  final List<BoundaryViolation> violations = <BoundaryViolation>[];
  for (final String start in pureFiles) {
    violations.addAll(
      _violationsFrom(
        start: start,
        sources: sources,
        follow: follow,
        maxHops: maxHops,
      ),
    );
  }
  return violations;
}

List<BoundaryViolation> _violationsFrom({
  required String start,
  required Map<String, String> sources,
  required Set<DirectiveKind> follow,
  required int? maxHops,
}) {
  final List<BoundaryViolation> violations = <BoundaryViolation>[];
  final Set<String> reportedLeaves = <String>{};
  final Set<String> visited = <String>{start};
  final List<List<String>> frontier = <List<String>>[
    <String>[start],
  ];
  while (frontier.isNotEmpty) {
    final List<String> pathHere = frontier.removeAt(0);
    final int hops = pathHere.length - 1;
    if (maxHops != null && hops >= maxHops) {
      continue;
    }
    final String? source = sources[pathHere.last];
    if (source == null) {
      continue;
    }
    for (final SourceDirective directive in readDirectives(source)) {
      if (!follow.contains(directive.kind)) {
        continue;
      }
      final String? target =
          canonicalLibPath(directive.uri, fromLibPath: pathHere.last);
      if (target == null) {
        if (leafVerdict(directive.uri) == LeafVerdict.forbidden &&
            reportedLeaves.add(directive.uri)) {
          violations.add(
            BoundaryViolation(<String>[...pathHere, directive.uri]),
          );
        }
        continue;
      }
      if (visited.add(target)) {
        frontier.add(<String>[...pathHere, target]);
      }
    }
  }
  return violations;
}

/// A read of ambient state from a file that is supposed to be a function of its
/// arguments.
@immutable
final class AmbientAccess {
  const AmbientAccess({
    required this.file,
    required this.line,
    required this.pattern,
  });

  final String file;
  final int line;
  final String pattern;

  String get message => '$file:$line reads $pattern';

  @override
  String toString() => message;
}

/// Every read of a clock, of randomness or of the platform in [pureFiles].
///
/// The scan is textual over comment-stripped source — plan §2.2's Ambient row,
/// nothing more — and three limits come with that, stated here so they are read
/// as limits rather than found as bugs (design D-4):
///
/// - It does not see `Random.secure()`, a `DateTime.now` tear-off, or a clock
///   reached through an alias or a wrapper.
/// - A `now` **parameter** is not a miss. `remainingCooldown(issuedAt, now)`
///   taking the clock as a value is exactly the shape §2.2 asks for; the widget
///   in `ui/` is what reads the clock.
/// - String literals are not stripped, so a string whose text happens to be
///   `DateTime.now()` reports. Accepted; PROC-6 says fix it in the session it
///   first bites.
List<AmbientAccess> findAmbientAccess({
  required Map<String, String> sources,
  required Iterable<String> pureFiles,
}) {
  final List<AmbientAccess> found = <AmbientAccess>[];
  for (final String file in pureFiles) {
    final String? source = sources[file];
    if (source == null) {
      continue;
    }
    final List<String> lines = stripComments(source).split('\n');
    for (int index = 0; index < lines.length; index += 1) {
      for (final MapEntry<String, RegExp> pattern in _ambientPatterns.entries) {
        if (pattern.value.hasMatch(lines[index])) {
          found.add(
            AmbientAccess(
              file: file,
              line: index + 1,
              pattern: pattern.key,
            ),
          );
        }
      }
    }
  }
  return found;
}

/// Plan §2.2's Ambient row, as the text that gives it away.
///
/// Each is anchored on a word boundary so `SeededRandom(` is not mistaken for
/// `Random(`.
final Map<String, RegExp> _ambientPatterns = <String, RegExp>{
  'DateTime.now()': RegExp(r'\bDateTime\s*\.\s*now\s*\('),
  'Random()': RegExp(r'\bRandom\s*\('),
  'Platform.': RegExp(r'\bPlatform\s*\.'),
};

/// Whether a lib-relative path is a feature barrel — `features/x/x.dart`.
bool isFeatureBarrel(String libPath) {
  final List<String> segments = libPath.split('/');
  return segments.length == 3 &&
      segments.first == 'features' &&
      segments[2] == '${segments[1]}.dart';
}

/// Every cycle among the feature barrels of [sources], each as the chain that
/// closes it.
///
/// Dart compiles an import cycle without complaint, so plan §2.5's acyclicity
/// rule has no other enforcement. The walk runs over the same repo-local edges
/// as the boundary closure, so a cycle that closes through a file which is not
/// itself a barrel is still reported.
List<List<String>> findFeatureBarrelCycles(
  Map<String, String> sources, {
  Set<DirectiveKind> follow = allDirectiveKinds,
}) {
  final List<String> barrels = sources.keys.where(isFeatureBarrel).toList()
    ..sort();
  final List<List<String>> cycles = <List<String>>[];
  final Set<String> alreadyReported = <String>{};
  for (final String barrel in barrels) {
    final List<String>? cycle = _shortestCycleFrom(barrel, sources, follow);
    if (cycle != null && alreadyReported.add(_cycleIdentity(cycle))) {
      cycles.add(cycle);
    }
  }
  return cycles;
}

/// The same cycle found from each of its barrels is one cycle, so it is
/// identified by the set of files it runs through rather than by where the walk
/// happened to enter it.
String _cycleIdentity(List<String> cycle) =>
    (cycle.toSet().toList()..sort()).join('|');

List<String>? _shortestCycleFrom(
  String barrel,
  Map<String, String> sources,
  Set<DirectiveKind> follow,
) {
  final Set<String> visited = <String>{barrel};
  final List<List<String>> frontier = <List<String>>[
    <String>[barrel],
  ];
  while (frontier.isNotEmpty) {
    final List<String> pathHere = frontier.removeAt(0);
    for (final String target
        in _repoLocalTargets(pathHere.last, sources, follow)) {
      if (target == barrel) {
        return <String>[...pathHere, barrel];
      }
      if (visited.add(target)) {
        frontier.add(<String>[...pathHere, target]);
      }
    }
  }
  return null;
}

Iterable<String> _repoLocalTargets(
  String libPath,
  Map<String, String> sources,
  Set<DirectiveKind> follow,
) sync* {
  final String? source = sources[libPath];
  if (source == null) {
    return;
  }
  for (final SourceDirective directive in readDirectives(source)) {
    if (!follow.contains(directive.kind)) {
      continue;
    }
    final String? target =
        canonicalLibPath(directive.uri, fromLibPath: libPath);
    if (target != null) {
      yield target;
    }
  }
}

/// The `name:` of `app/pubspec.yaml`, which is how a repo-local file may also
/// be spelled.
const String _packageName = 'akimath_app';

/// URIs the closure stops at and forgives. Everything else it stops at is a
/// violation, so an SDK library nobody listed fails closed rather than slipping
/// through unnoticed — plan §2.2 names only these.
const Set<String> _allowedLeaves = <String>{
  'dart:ui',
  'dart:math',
  'dart:core',
  'package:meta',
};

/// Resolves a directive URI to its path relative to `app/lib/`.
///
/// Returns `null` for a URI the closure cannot walk into — a `dart:` library or
/// a third-party package. Relative and `package:$_packageName/` spellings
/// collapse to the same key, so the two ways of naming the token barrel cannot
/// hide the same edge from each other.
String? canonicalLibPath(String uri, {required String fromLibPath}) {
  const String packagePrefix = 'package:$_packageName/';
  if (uri.startsWith(packagePrefix)) {
    return _normalizeSegments(uri.substring(packagePrefix.length).split('/'));
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) {
    return null;
  }
  final List<String> fromSegments = fromLibPath.split('/');
  return _normalizeSegments(<String>[
    ...fromSegments.take(fromSegments.length - 1),
    ...uri.split('/'),
  ]);
}

String _normalizeSegments(List<String> segments) {
  final List<String> resolved = <String>[];
  for (final String segment in segments) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (resolved.isNotEmpty) {
        resolved.removeLast();
      }
      continue;
    }
    resolved.add(segment);
  }
  return resolved.join('/');
}

/// The verdict plan §2.2 gives a URI the closure stops at.
LeafVerdict leafVerdict(String uri) {
  final String library = uri.startsWith('package:')
      ? 'package:${uri.substring('package:'.length).split('/').first}'
      : uri;
  return _allowedLeaves.contains(library)
      ? LeafVerdict.allowed
      : LeafVerdict.forbidden;
}

/// Replaces comment text with spaces, keeping every newline and every column.
///
/// Stripping has to come before any scan or `// import 'package:flutter/…';`
/// reads as a violation. Positions are preserved rather than deleted because
/// the ambient scan reports a line number, and a strip that removed lines would
/// cite the wrong one.
String stripComments(String source) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < source.length) {
    final int afterLiteral = _copyStringLiteral(source, i, out);
    if (afterLiteral > i) {
      i = afterLiteral;
      continue;
    }
    if (source.startsWith('//', i)) {
      i = _blankLineComment(source, i, out);
      continue;
    }
    if (source.startsWith('/*', i)) {
      i = _blankBlockComment(source, i, out);
      continue;
    }
    out.write(source[i]);
    i += 1;
  }
  return out.toString();
}

/// Copies a string literal verbatim so a `//` inside one is not read as a
/// comment. Returns the index after the literal, or [start] if none begins
/// there.
int _copyStringLiteral(String source, int start, StringBuffer out) {
  final String quote = source[start];
  if (quote != "'" && quote != '"') {
    return start;
  }
  final bool isRaw = start > 0 && source[start - 1] == 'r';
  final String triple = quote * 3;
  final String delimiter = source.startsWith(triple, start) ? triple : quote;
  out.write(delimiter);
  int i = start + delimiter.length;
  while (i < source.length) {
    if (!isRaw && source[i] == r'\' && i + 1 < source.length) {
      out.write(source.substring(i, i + 2));
      i += 2;
      continue;
    }
    if (source.startsWith(delimiter, i)) {
      out.write(delimiter);
      return i + delimiter.length;
    }
    out.write(source[i]);
    i += 1;
  }
  return i;
}

int _blankLineComment(String source, int start, StringBuffer out) {
  int i = start;
  while (i < source.length && source[i] != '\n') {
    out.write(' ');
    i += 1;
  }
  return i;
}

/// Dart block comments nest, so this counts depth rather than looking for the
/// first `*/`.
int _blankBlockComment(String source, int start, StringBuffer out) {
  int depth = 0;
  int i = start;
  while (i < source.length) {
    if (source.startsWith('/*', i)) {
      depth += 1;
      out.write('  ');
      i += 2;
      continue;
    }
    if (source.startsWith('*/', i)) {
      depth -= 1;
      out.write('  ');
      i += 2;
      if (depth == 0) {
        return i;
      }
      continue;
    }
    out.write(source[i] == '\n' ? '\n' : ' ');
    i += 1;
  }
  return i;
}

/// Matches a directive whose URI follows the keyword directly.
///
/// `part of` is deliberately unmatched: its edge runs from the part back to the
/// library, which would read as a cycle between two files that are one library.
final RegExp _directivePattern =
    RegExp('''^\\s*(import|export|part)\\s+r?(?:'([^']*)'|"([^"]*)")''');

/// Reads the directives of a Dart source, ignoring commented-out ones.
List<SourceDirective> readDirectives(String source) {
  final List<String> lines = stripComments(source).split('\n');
  final List<SourceDirective> directives = <SourceDirective>[];
  for (int index = 0; index < lines.length; index += 1) {
    final RegExpMatch? match = _directivePattern.firstMatch(lines[index]);
    if (match == null) {
      continue;
    }
    directives.add(
      SourceDirective(
        kind: DirectiveKind.values.byName(match.group(1)!),
        uri: match.group(2) ?? match.group(3)!,
        line: index + 1,
      ),
    );
  }
  return directives;
}
