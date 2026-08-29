import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Waiting is drawn as the shape of what is coming, never as a wheel.
///
/// `Cargando` is annotated *"esqueletos, sin ruedita"*, and the plan is
/// blunt about the corollary: **"Do not invent a spinner anywhere."** It also
/// rules out repurposing `LoadingDots`, which belongs to `Splash` and to
/// no product screen.
///
/// The reason is not taste. A skeleton says *something this shape is coming*
/// and a spinner says *wait*; one of those tells the player what they are
/// getting and the other only tells them they are not getting it yet.
///
/// This is the cheapest possible gate on a decision that is otherwise one
/// hurried import away from being lost.
void main() {
  final Directory lib = Directory('lib');

  List<File> sources() => lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  /// The file with its comments removed.
  ///
  /// **Because a gate that fires on prose is a gate that gets deleted.** The
  /// first version of this matched the bare word and reported three files —
  /// two of them doc comments explaining why not to use it, one of them this
  /// rule's own explanation. What it must read is code.
  String code(File file) => file
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  /// Widgets whose whole job is an indeterminate wheel.
  const List<String> wheels = <String>[
    'CircularProgressIndicator',
    'RefreshProgressIndicator',
    'CupertinoActivityIndicator',
    'LinearProgressIndicator',
  ];

  /// `Splash` owns these dots and nothing else may.
  const String dotsOwner = 'lib/features/splash/splash_screen.dart';

  test('reports what it scanned, and scanning nothing is a failure', () {
    // PROC-10: a sweep whose input can silently reach zero cannot tell
    // "nothing is wrong" from "nothing was checked".
    final List<File> files = sources();
    expect(files, isNotEmpty);
    // ignore: avoid_print
    print('  no spinner · swept ${files.length} source files');
  });

  test('nothing in the app draws a spinner', () {
    final List<String> offenders = <String>[];
    for (final File file in sources()) {
      final String text = code(file);
      for (final String wheel in wheels) {
        if (text.contains('$wheel(')) {
          offenders.add('${file.path}: $wheel');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'waiting is skeletons — see Cargando, "esqueletos, sin ruedita"',
    );
  });

  test('LoadingDots stays on the splash it was drawn for', () {
    // Not forbidden, owned. Repurposing it onto a product screen is how the
    // rule above gets kept in letter and broken in spirit.
    // A construction, not a mention: `LoadingDots(` is a use and
    // `class LoadingDots` is the definition.
    final List<String> users = <String>[
      for (final File file in sources())
        if (code(file).contains('LoadingDots(')) file.path,
    ];
    expect(
      users..sort(),
      <String>['lib/design/widgets/loading_dots.dart', dotsOwner],
      reason: 'LoadingDots belongs to Splash',
    );
  });
}
