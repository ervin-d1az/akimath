import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The runtime packages `app/` is allowed to ship.
///
/// This list is the contract. Adding a package means editing this line **and**
/// carrying the `CLAUDE.md`:9 phones-home audit in the same change — which is
/// the point: the test cannot judge whether a dependency collects data, so it
/// fails on *any* addition and summons a human who can.
///
/// R5's early signal is a pull request touching `pubspec.yaml` when the task did
/// not ask for it. This turns that from a review habit into a red build.
const Set<String> allowedRuntimeDependencies = <String>{
  'flutter',
  'cupertino_icons',
  'meta',
};

/// Reads the `dependencies:` block of `app/pubspec.yaml`.
///
/// A hand parse rather than a YAML package, because adding a YAML package to
/// read the dependency list would be its own punchline. The block is flat and
/// two levels deep; anything more elaborate belongs in a real parser and would
/// be a reason to revisit this.
Set<String> _declaredRuntimeDependencies(String yaml) {
  final List<String> lines = yaml.split('\n');
  final Set<String> found = <String>{};

  bool inDependencies = false;
  for (final String line in lines) {
    if (line.startsWith('dependencies:')) {
      inDependencies = true;
      continue;
    }
    if (inDependencies) {
      // Any other top-level key ends the block.
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
        break;
      }
      final RegExpMatch? match =
          RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
      if (match != null) {
        found.add(match.group(1)!);
      }
    }
  }
  return found;
}

void main() {
  group('the runtime dependency list is a committed allowlist', () {
    test('no icon dependency is added', () {
      final String yaml = File('pubspec.yaml').readAsStringSync();
      final Set<String> declared = _declaredRuntimeDependencies(yaml);

      expect(
        declared,
        allowedRuntimeDependencies,
        reason: 'app/pubspec.yaml declares a runtime dependency the allowlist '
            'does not. Adding one means editing the allowlist AND auditing '
            'whether the package phones home, in the same change (DEP-1).',
      );
    });

    test('it reports what it scanned, and scanning nothing is a failure', () {
      final String yaml = File('pubspec.yaml').readAsStringSync();
      final Set<String> declared = _declaredRuntimeDependencies(yaml);

      // A parser one typo away from matching nothing passes forever.
      expect(declared, isNotEmpty);
      // ignore: avoid_print
      print('  dependency allowlist · runtime → ${declared.length} packages');
    });

    test('an added dependency fails the build and names the package', () {
      // The parser, exercised against a manifest that is not on disk — so the
      // failure path is proven without editing the real one.
      const String withExtra = '''
name: akimath_app

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  meta: ^1.17.0
  some_analytics_sdk: ^2.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
''';

      final Set<String> declared = _declaredRuntimeDependencies(withExtra);
      expect(declared.difference(allowedRuntimeDependencies), <String>{
        'some_analytics_sdk',
      });
    });

    test('dev dependencies are out of scope', () {
      // They do not ship. Sweeping them in would make the gate fire on every
      // test-tooling bump and get disabled within a week.
      const String yaml = '''
dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_lints: ^6.0.0
  mocktail: ^1.0.0
''';

      expect(_declaredRuntimeDependencies(yaml), <String>{'flutter'});
    });
  });
}
