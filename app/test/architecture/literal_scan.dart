/// Pure scanning of source text for the literals the token scale replaces.
///
/// This module is handed a map of lib-relative path to source text and returns
/// findings. It opens no file: the filesystem walk that produces the map is
/// `source_tree.dart`, the adapter beside it (PURE-1, PURE-2). Keeping the
/// matching on this side is what lets a file that violates BRD-2b be a map
/// entry in a test rather than a literal written under `app/lib/`.
///
/// Comment stripping is borrowed from `import_graph.dart` rather than written
/// again. Every one of these gates' false-positive stories depends on that one
/// behaviour, and three copies of it would drift apart on exactly the thing
/// that must not drift (design D11).
///
/// **Two stated limits, so they are read as limits and not found as bugs.**
/// `stripComments` copies string literals through verbatim, so a Dart string
/// whose text happens to contain `Colors.` or `Offset(` reports; nothing in
/// `app/lib/` does today. And a text scan cannot see a colour assembled at
/// runtime from ints. The gate raises the floor; it does not replace the
/// reviewer.
library;

import 'package:meta/meta.dart';

import 'import_graph.dart' show stripComments;

/// A directory the gates scan, together with what it does not govern.
@immutable
final class ScanRoot {
  const ScanRoot({required this.prefix, this.excluding = const <String>[]});

  /// A lib-relative directory prefix. The empty prefix is all of `app/lib/`.
  final String prefix;

  /// Prefixes inside [prefix] that this root does not govern.
  final List<String> excluding;

  /// How the root is named in the gate's report.
  String get label {
    final String scope = prefix.isEmpty ? 'lib/' : prefix;
    return excluding.isEmpty ? scope : '$scope minus ${excluding.join(' and ')}';
  }

  /// Whether a lib-relative file path lies inside this root.
  bool contains(String libPath) =>
      libPath.startsWith(prefix) &&
      !excluding.any((String excluded) => libPath.startsWith(excluded));

  /// The files of [libPaths] this root governs, in a stable order.
  List<String> selectFiles(Iterable<String> libPaths) =>
      libPaths.where(contains).toList()..sort();
}

/// The files [roots] govern between them, deduplicated and in a stable order.
List<String> selectFilesIn(Iterable<ScanRoot> roots, Iterable<String> libPaths) {
  final Set<String> selected = <String>{
    for (final ScanRoot root in roots) ...root.selectFiles(libPaths),
  };
  return selected.toList()..sort();
}

/// One line per root, naming what the gate actually looked at.
///
/// The count is printed rather than inferred from a green run: a gate whose
/// root is one typo away from matching nothing passes forever, and that is the
/// failure mode `dart_code_linter` already demonstrates in this repository
/// (PROC-5 — a check that can only ever be green is not evidence).
List<String> scanCoverageReport({
  required Iterable<String> libPaths,
  required Iterable<ScanRoot> roots,
}) {
  return <String>[
    for (final ScanRoot root in roots)
      '${root.label} → ${root.selectFiles(libPaths).length} files',
  ];
}

/// One textual form a literal is written in, named as the gate reports it.
@immutable
final class LiteralPattern {
  LiteralPattern(this.label, String expression)
      : _expression = RegExp(expression);

  /// How the form is written in a failure message.
  final String label;

  final RegExp _expression;

  Iterable<RegExpMatch> matchesIn(String source) =>
      _expression.allMatches(source);
}

/// One literal found, with enough to name it in a failure.
@immutable
final class LiteralHit {
  const LiteralHit({
    required this.file,
    required this.line,
    required this.text,
  });

  final String file;
  final int line;

  /// The matched source, with internal whitespace collapsed so a construction
  /// broken across lines still reads as what it is.
  final String text;

  String get message => '$file:$line writes $text';

  @override
  String toString() => message;
}

/// Material's palette — the arm that has to be matched on a word boundary.
///
/// `Colors.` is a **substring of `BrandColors.`**, the mandated way every
/// widget here names a hue, so a substring match reports ~94 correct lines
/// across 12 files. The negative lookbehind is the difference between a gate
/// and a gate somebody had to disable (design D8).
final LiteralPattern materialPalette = LiteralPattern(
  'Colors.',
  r'(?<![A-Za-z0-9_$])Colors\s*\.\s*[A-Za-z_][A-Za-z0-9_]*',
);

/// Every way a colour is written literally in Dart.
///
/// Deliberately not `#RRGGBB`: the character sheet prints four brand hexes as
/// swatch labels and is correct code (design D8). Derived colours are out of
/// scope by construction — `withValues(alpha:)` takes a token and adjusts it,
/// which is what tokens are for.
final List<LiteralPattern> colorLiteralPatterns = <LiteralPattern>[
  LiteralPattern('Color(0x…)', r'(?<![A-Za-z0-9_$])Color\s*\(\s*0x[0-9A-Fa-f]+'),
  LiteralPattern(
    'Color.fromARGB(',
    r'(?<![A-Za-z0-9_$])Color\s*\.\s*fromARGB\s*\(',
  ),
  LiteralPattern(
    'Color.fromRGBO(',
    r'(?<![A-Za-z0-9_$])Color\s*\.\s*fromRGBO\s*\(',
  ),
  materialPalette,
];

/// The hard-shadow offsets a widget surface must take from `BrandShape`.
///
/// Radii and border widths are **not** scanned: a bare `24` is not greppable
/// without parsing, and a gate that pretended to cover them would be a false
/// claim in the rulebook. BRD-2c stays a reviewer's read on those two.
final List<LiteralPattern> geometryLiteralPatterns = <LiteralPattern>[
  LiteralPattern('Offset(', r'(?<![A-Za-z0-9_$])Offset\s*\('),
];

/// All of `app/lib/` except the tokens, which are where the literals live.
const ScanRoot colorGateRoot = ScanRoot(
  prefix: '',
  excluding: <String>['design/tokens/'],
);

/// The widget surfaces `BrandShape` governs.
///
/// `design/brand/` is out of scope: 95 offsets in `aki_spec.dart` and one
/// proportional expression in `app_icon.dart` are the artwork layer, where
/// geometry *is* the content (design D9).
///
/// `design/math/` **is** in scope, and the distinction is worth stating because
/// it looks like the artwork case and is not. The compositor composes tokens
/// the way `design/widgets/` does; its geometry comes from `FractionMetrics`
/// and an injected x-height, never from a number typed while reading a mock.
/// Its `spec/` half is covered too and stays clean by having nothing to say
/// about offsets — it returns a `Rect` it computed.
const List<ScanRoot> geometryGateRoots = <ScanRoot>[
  ScanRoot(prefix: 'design/widgets/'),
  ScanRoot(prefix: 'design/math/'),
  ScanRoot(prefix: 'features/'),
];

/// The colour literal BRD-2b carves out by name.
///
/// `Colors.transparent` switches Material's surface tinting off and names no
/// hue. It is the one exception on disk, verbatim in `CLAUDE.md`.
const String permittedColorLiteral = 'Colors.transparent';

/// [hits] minus the one carve-out.
///
/// Kept apart from [findLiterals] so a gate can assert what its pattern matched
/// *before* anything was subtracted. A wrong pattern behind a long exclusion
/// list is green for the wrong reason.
List<LiteralHit> withoutPermitted(Iterable<LiteralHit> hits) => hits
    .where((LiteralHit hit) => hit.text != permittedColorLiteral)
    .toList();

/// Every literal of [patterns] in the files [roots] govern, comments stripped.
///
/// The match runs over the whole stripped source rather than line by line, so a
/// constructor broken across lines is still found; the line reported is the one
/// it starts on.
List<LiteralHit> findLiterals({
  required Map<String, String> sources,
  required Iterable<ScanRoot> roots,
  required Iterable<LiteralPattern> patterns,
}) {
  final List<LiteralHit> hits = <LiteralHit>[];
  for (final String file in selectFilesIn(roots, sources.keys)) {
    final String source = stripComments(sources[file]!);
    for (final LiteralPattern pattern in patterns) {
      for (final RegExpMatch match in pattern.matchesIn(source)) {
        hits.add(
          LiteralHit(
            file: file,
            line: _lineAt(source, match.start),
            text: _collapseWhitespace(match[0]!),
          ),
        );
      }
    }
  }
  hits.sort(_byFileThenLine);
  return hits;
}

int _byFileThenLine(LiteralHit a, LiteralHit b) {
  final int byFile = a.file.compareTo(b.file);
  return byFile != 0 ? byFile : a.line.compareTo(b.line);
}

int _lineAt(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

String _collapseWhitespace(String matched) =>
    matched.replaceAll(RegExp(r'\s+'), '');
