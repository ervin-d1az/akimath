import 'package:akimath_app/content/model/item.dart';
import 'package:akimath_app/design/widgets/spec/mastery_level.dart';
import 'package:akimath_app/features/map/policy/skill_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// One item of a family at a named ladder step.
///
/// The map reads two things off an item and nothing else — which family it
/// belongs to and how hard it is — so a fixture states exactly those two.
Item _item(Stimulus stimulus, int ladderStep) => Item(
      id: 'fixture',
      stimulus: stimulus,
      answer: const PlainAnswer('1'),
      ladderStep: ladderStep,
    );

Item _sum(int ladderStep) => _item(
      const ArithmeticStimulus(<PromptToken>[PromptToken.text('1')]),
      ladderStep,
    );

Item _series(int ladderStep) => _item(
      const NumberSeriesStimulus(terms: <int>[1, 2, 3], unknownIndex: 2),
      ladderStep,
    );

Item _figurate(int ladderStep) => _item(
      const FigurateStimulus(dotCounts: <int>[1, 3, 6], unknownIndex: 2),
      ladderStep,
    );

void main() {
  group('the nodes', () {
    test('are the families the pack carries, in the order they arrive', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_series(1), _sum(1), _series(2)],
        itemsServed: 0,
      );

      expect(
        map.nodes.map((SkillNode node) => node.label),
        <String>['Series', 'Cuentas'],
      );
    });

    test('a family the pack does not carry gets no node', () {
      final SkillMap map =
          readSkillMap(items: <Item>[_sum(1)], itemsServed: 0);

      expect(map.nodes, hasLength(1));
      expect(map.nodes.single.label, 'Cuentas');
    });

    test('an empty pack draws an empty map rather than throwing', () {
      final SkillMap map = readSkillMap(items: <Item>[], itemsServed: 4);

      expect(map.nodes, isEmpty);
      expect(map.focusIndex, isNull);
    });

    test('every node carries the sentence its detail screen opens with', () {
      final SkillMap map =
          readSkillMap(items: <Item>[_sum(1)], itemsServed: 0);

      expect(map.nodes.single.blurb, isNotEmpty);
    });
  });

  group('how far a family has been taken', () {
    test('nothing served is available, and it is not locked', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _sum(3)],
        itemsServed: 0,
      );

      expect(map.nodes.single.level, MasteryLevel.available);
      expect(map.nodes.single.reachedStep, 0);
      expect(map.nodes.single.progress, 0);
    });

    test('part of the way up the ladder is in progress', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(2), _sum(5)],
        itemsServed: 1,
      );

      expect(map.nodes.single.level, MasteryLevel.inProgress);
      expect(map.nodes.single.reachedStep, 2);
      expect(map.nodes.single.topStep, 5);
      expect(map.nodes.single.progress, closeTo(0.4, 1e-9));
    });

    test('the hardest step the pack offers is mastered', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _sum(4), _sum(2)],
        itemsServed: 2,
      );

      expect(map.nodes.single.level, MasteryLevel.mastered);
      expect(map.nodes.single.progress, 1);
    });

    test('the step reached is the hardest served, not the last served', () {
      // Otherwise an easy item after a hard one would take progress away, and
      // a player would watch a topic go backwards for answering.
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(4), _sum(1)],
        itemsServed: 2,
      );

      expect(map.nodes.single.reachedStep, 4);
    });

    test('this pack locks nothing, because nothing gates anything', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1), _figurate(1)],
        itemsServed: 0,
      );

      expect(
        map.nodes.map((SkillNode node) => node.level),
        everyElement(isNot(MasteryLevel.locked)),
      );
    });
  });

  group('the cursor', () {
    test('a cursor past the pack means every item has been served', () {
      // `seriesStart` wraps, so the stored total outgrows the pack and a naive
      // `items.take(served)` would be a range error on the second pass.
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _sum(2)],
        itemsServed: 9,
      );

      expect(map.nodes.single.level, MasteryLevel.mastered);
    });

    test('a negative cursor is read as nothing served', () {
      final SkillMap map =
          readSkillMap(items: <Item>[_sum(1)], itemsServed: -3);

      expect(map.nodes.single.level, MasteryLevel.available);
    });
  });

  group('the focus', () {
    test('is the family of the item the player meets next', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1), _figurate(1)],
        itemsServed: 1,
      );

      expect(map.nodes[map.focusIndex!].label, 'Series');
    });

    test('wraps with the series, so a finished pack points at its start', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1)],
        itemsServed: 2,
      );

      expect(map.nodes[map.focusIndex!].label, 'Cuentas');
    });
  });

  group('how many topics are under way', () {
    test('counts the families the player has actually met', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1), _figurate(1)],
        itemsServed: 2,
      );

      expect(map.startedCount, 2);
      expect(map.nodes, hasLength(3));
    });
  });
}
