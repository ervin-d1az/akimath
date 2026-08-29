import 'package:akimath_app/content/model/arithmetic_glyphs.dart';
import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/content/model/pack.dart';
import 'package:akimath_app/content/pack_reader.dart';
import 'package:akimath_app/content/model/diagnosis.dart';
import 'package:akimath_app/content/model/puzzle.dart';
import 'package:akimath_app/content/model/puzzle_reader.dart';
import 'package:akimath_app/features/home/policy/puzzle_of_day.dart';
import 'package:akimath_app/features/round/policy/series_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// What kind of question an item asks, as a name a failure can print.
String _family(Item item) => switch (item.stimulus) {
      ArithmeticStimulus() => 'arithmetic',
      NumberSeriesStimulus() => 'numberSeries',
      MatrixStimulus() => 'matrix',
      AnalogyStimulus() => 'analogy',
      HiddenOperationStimulus() => 'hiddenOperation',
      FigurateStimulus() => 'figurate',
    };

/// A board's identity, for a test that has to say which one it means.
///
/// The kind and its solution: two KenKens of the same size differ by their
/// solution, and nothing in the pack format carries an id.
String _puzzleId(Puzzle puzzle) => switch (puzzle) {
      BoardPuzzle() => '${puzzleKindOf(puzzle)}:${puzzle.board.solution}',
      WordSearchPuzzle() => '${puzzleKindOf(puzzle)}:${puzzle.grid}',
    };

/// **The shipped pack's order is a product decision, and this is the gate.**
///
/// `seriesPlan` takes five items in pack order and is deliberately dull —
/// choosing *which* items a player should get is the adaptive question and it
/// belongs to `f4-calibration`. That means variety is not the policy's job; it
/// is the pack's, and a pack grouped by family would be a player answering
/// twenty sums before meeting anything else.
///
/// That is not hypothetical. It is what the pack did when the families were
/// added one after another, each appending its ten to the end, and the report
/// was *"I can only play the most basic ones"*.
void main() {
  late Pack pack;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    pack = await const PackReader().load();
  });

  group('the pack that ships offers more than one kind of question', () {
    test('it carries every family the app can draw', () {
      final Set<String> families = pack.items.map(_family).toSet();

      expect(families, hasLength(6), reason: 'families found: $families');
      // ignore: avoid_print
      print('  pack variety · ${pack.items.length} items → '
          '${families.length} families');
    });

    test('no family is a token presence', () {
      // Ten of each non-arithmetic family, twenty sums. A family with two items
      // would satisfy the count above and still never be seen twice.
      final Map<String, int> perFamily = <String, int>{};
      for (final Item item in pack.items) {
        perFamily[_family(item)] = (perFamily[_family(item)] ?? 0) + 1;
      }

      for (final MapEntry<String, int> entry in perFamily.entries) {
        expect(entry.value, greaterThanOrEqualTo(seriesLength * 2),
            reason: '${entry.key} has only ${entry.value} items');
      }
    });
  });

  group('every mark the shipped pack draws is one the vocabulary names', () {
    test('no expression in it draws a mark outside arithmeticGlyphs', () {
      // `Pack.fromJson` refuses one now, so this cannot fail while the reader
      // is intact — which is the point. It is the gate that says the *shipped
      // asset* is correct by construction rather than by author discipline,
      // and it turns red if the refusal is ever loosened. The asset was right
      // by discipline until this change: all five of its subtractions spell
      // U+2212, and nothing made them.
      final Map<String, int> marks = <String, int>{};
      for (final Item item in pack.items) {
        if (item.stimulus case ArithmeticStimulus(
              :final List<PromptToken> prompt
            )) {
          for (final PromptToken token in prompt) {
            if (token case OperatorToken(:final String glyph)) {
              marks[glyph] = (marks[glyph] ?? 0) + 1;
            }
          }
        }
      }

      expect(marks, isNotEmpty, reason: 'no operator was swept, so this gate '
          'asserted nothing');
      for (final MapEntry<String, int> mark in marks.entries) {
        expect(
          arithmeticGlyphs,
          contains(mark.key),
          reason: '"${mark.key}" (U+${mark.key.runes.first.toRadixString(16)}) '
              'is drawn ${mark.value} times and is not in the vocabulary',
        );
      }
      // ignore: avoid_print
      print('  pack operators · ${marks.values.reduce((int a, int b) => a + b)}'
          ' marks over ${marks.length} distinct → all in the vocabulary');
    });
  });

  group('a player meets the variety immediately, not eventually', () {
    test('the first series is a mix, not five of a kind', () {
      final Set<String> first =
          seriesPlan(pack.items).map(_family).toSet();

      expect(first.length, greaterThanOrEqualTo(3),
          reason: 'the opening series was all $first');
    });

    test('the first two series between them show every family', () {
      // Ten items — two sittings. Beyond that a player has formed a view of
      // what this app is, and "sums" would be the wrong one.
      final Set<String> seen = <String>{
        ...seriesPlan(pack.items).map(_family),
        ...seriesPlan(pack.items, from: seriesLength).map(_family),
      };

      expect(seen, hasLength(6), reason: 'after ten items a player had seen $seen');
    });

    test('no series repeats a family more than twice', () {
      // Arithmetic is twice as common as the rest, so twice in five is its fair
      // share and three would mean the interleave has clumped.
      for (int from = 0; from < pack.items.length; from += seriesLength) {
        final Map<String, int> perFamily = <String, int>{};
        for (final Item item in seriesPlan(pack.items, from: from)) {
          perFamily[_family(item)] = (perFamily[_family(item)] ?? 0) + 1;
        }

        for (final MapEntry<String, int> entry in perFamily.entries) {
          expect(entry.value, lessThanOrEqualTo(2),
              reason: 'the series from $from had ${entry.value} '
                  '${entry.key} items');
        }
      }
    });
  });

  group('the puzzles it carries are all reachable', () {
    test('a fortnight of days offers every board', () {
      // The home shows one card per format, so a board only reaches a player on
      // the days its kind's rotation lands on it. Content nothing ever offers
      // is content that may as well not be in the pack — and this is the gate
      // that notices when a fifth KenKen quietly outruns the rotation.
      final Set<String> offered = <String>{};
      for (int day = 0; day < 14; day += 1) {
        for (final Puzzle puzzle
            in puzzlesOfDay(pack.puzzles, today: DateTime(2026, 8, 1 + day))) {
          offered.add(_puzzleId(puzzle));
        }
      }

      final Set<String> carried = pack.puzzles.map(_puzzleId).toSet();
      expect(carried, isNotEmpty, reason: 'the pack carries no puzzle at all');
      expect(
        carried.difference(offered),
        isEmpty,
        reason: 'boards no fortnight reaches',
      );
      final int formats = pack.puzzles.map(puzzleKindOf).toSet().length;
      // ignore: avoid_print
      print('  puzzle rotation · ${carried.length} boards across $formats '
          'formats → all offered within a fortnight');
    });

    test('no board asks for a digit the pad cannot enter', () {
      // **The contract permits sizes this client cannot play.** A 4×4 magic
      // square draws from 1 to 16 and the keypad has nine keys, so
      // `readPuzzle` refuses one — which is how a batch of generated 4×4s was
      // caught before it shipped. The reader failing at load is the real gate;
      // this one names the rule so the next person meets a sentence rather
      // than a `FormatException`.
      for (final Puzzle puzzle in pack.puzzles) {
        if (puzzle case final BoardPuzzle board) {
          expect(
            board.board.highestValue,
            lessThanOrEqualTo(padHighestDigit),
            reason: '${puzzleKindOf(puzzle)} ${board.board.size}×'
                '${board.board.size} needs ${board.board.highestValue}',
          );
        }
      }
    });

    test('every format offers a week before it repeats', () {
      // The rotation is one board per kind per day, so however many boards a
      // kind carries is how many days it takes to come round again.
      final Map<String, int> perKind = <String, int>{};
      for (final Puzzle puzzle in pack.puzzles) {
        perKind.update(puzzleKindOf(puzzle), (int n) => n + 1, ifAbsent: () => 1);
      }

      expect(perKind.values, everyElement(greaterThanOrEqualTo(7)),
          reason: 'boards per kind: $perKind');
    });

    test('each day offers one board per format, never two of a kind', () {
      for (int day = 0; day < 14; day += 1) {
        final List<Puzzle> today =
            puzzlesOfDay(pack.puzzles, today: DateTime(2026, 8, 1 + day));
        final List<String> kinds = today.map(puzzleKindOf).toList();

        expect(kinds.toSet(), hasLength(kinds.length), reason: 'day $day: $kinds');
      }
    });
  });

  group('the pack can say something about a wrong answer', () {
    test('it carries the copy, including the fallback', () {
      // The screen degrades to a bare "Casi." without it, which is the state
      // `ARCHITECTURE.md` §9 names as F1.5 having failed.
      expect(pack.fallbackDiagnosis, isNotNull);
      expect(pack.fallbackDiagnosis!.steps, isNotEmpty);
    });

    test('some items anticipate a wrong answer, and the count is reported', () {
      // Most will not — the fallback is the common case by design — but zero
      // would mean the distractor half never ships and nothing would say so.
      final List<Item> anticipating =
          pack.items.where((Item i) => i.distractors.isNotEmpty).toList();
      final Set<String> named = <String>{
        for (final Item item in anticipating)
          for (final Diagnosis copy in item.distractors.values)
            copy.steps.first,
      };

      expect(anticipating, isNotEmpty);
      // ignore: avoid_print
      print('  pack diagnosis · ${anticipating.length} of ${pack.items.length} '
          'items anticipate a wrong answer, across ${named.length} misconceptions');
    });

    test('no item explains its own answer away', () {
      // The reader refuses one, so this is the shipped pack agreeing with it.
      for (final Item item in pack.items) {
        expect(item.distractors.keys, isNot(contains(item.expected)),
            reason: 'item ${item.id}');
      }
    });
  });
}