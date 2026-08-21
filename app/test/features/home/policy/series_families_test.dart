import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/features/home/policy/series_families.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Stimulus> _everyFamily = <Stimulus>[
  ArithmeticStimulus(<PromptToken>[PromptToken.text('1')]),
  NumberSeriesStimulus(terms: <int>[1, 2, 3], unknownIndex: 2),
  MatrixStimulus(cells: <int>[1, 2, 3, 4], size: 2, unknownIndex: 3),
  AnalogyStimulus(terms: <int>[2, 4, 5, 10], unknownIndex: 3),
  HiddenOperationStimulus(
    examples: <({int input, int output})>[
      (input: 1, output: 3),
      (input: 2, output: 4),
    ],
    queryInput: 5,
  ),
  FigurateStimulus(dotCounts: <int>[1, 3, 6], unknownIndex: 2),
];

void main() {
  group('familyKey', () {
    test('names every family with the kind the frozen contract froze', () {
      expect(
        _everyFamily.map(familyKey),
        <String>[
          'arithmetic',
          'numberSeries',
          'matrix',
          'analogy',
          'hiddenOperation',
          'figurate',
        ],
      );
    });

    test('is not the label, so renaming what a player reads keeps a record',
        () {
      // The two answer the same question for different audiences: one is
      // storage, the other is a screen. A key that happened to equal its label
      // would be a key that changes the day the copy does.
      for (final Stimulus stimulus in _everyFamily) {
        expect(familyKey(stimulus), isNot(familyLabel(stimulus)));
      }
    });

    test('tells the six families apart', () {
      expect(_everyFamily.map(familyKey).toSet(), hasLength(6));
    });
  });
}
