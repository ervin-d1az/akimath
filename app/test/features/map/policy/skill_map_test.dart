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
        practisedSteps: const <String, int>{},
      );

      expect(
        map.nodes.map((SkillNode node) => node.label),
        <String>['Series', 'Cuentas'],
      );
    });

    test('a family the pack does not carry gets no node', () {
      final SkillMap map =
          readSkillMap(items: <Item>[_sum(1)], itemsServed: 0, practisedSteps: const <String, int>{});

      expect(map.nodes, hasLength(1));
      expect(map.nodes.single.label, 'Cuentas');
    });

    test('an empty pack draws an empty map rather than throwing', () {
      final SkillMap map = readSkillMap(items: <Item>[], itemsServed: 4, practisedSteps: const <String, int>{});

      expect(map.nodes, isEmpty);
      expect(map.focusIndex, isNull);
    });

    test('every node carries the sentence its detail screen opens with', () {
      final SkillMap map =
          readSkillMap(items: <Item>[_sum(1)], itemsServed: 0, practisedSteps: const <String, int>{});

      expect(map.nodes.single.blurb, isNotEmpty);
    });
  });

  group('how far a family has been taken', () {
    test('nothing served is available, and it is not locked', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _sum(3)],
        itemsServed: 0,
        practisedSteps: const <String, int>{},
      );

      expect(map.nodes.single.level, MasteryLevel.available);
      expect(map.nodes.single.reachedStep, 0);
      expect(map.nodes.single.progress, 0);
    });

    test('part of the way up the ladder is in progress', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(2), _sum(5)],
        itemsServed: 1,
        practisedSteps: const <String, int>{},
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
        practisedSteps: const <String, int>{},
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
        practisedSteps: const <String, int>{},
      );

      expect(map.nodes.single.reachedStep, 4);
    });

    test('this pack locks nothing, because nothing gates anything', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1), _figurate(1)],
        itemsServed: 0,
        practisedSteps: const <String, int>{},
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
        practisedSteps: const <String, int>{},
      );

      expect(map.nodes.single.level, MasteryLevel.mastered);
    });

    test('a negative cursor is read as nothing served', () {
      final SkillMap map =
          readSkillMap(items: <Item>[_sum(1)], itemsServed: -3, practisedSteps: const <String, int>{});

      expect(map.nodes.single.level, MasteryLevel.available);
    });
  });

  group('the focus', () {
    test('is the family of the item the player meets next', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1), _figurate(1)],
        itemsServed: 1,
        practisedSteps: const <String, int>{},
      );

      expect(map.nodes[map.focusIndex!].label, 'Series');
    });

    test('wraps with the series, so a finished pack points at its start', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1)],
        itemsServed: 2,
        practisedSteps: const <String, int>{},
      );

      expect(map.nodes[map.focusIndex!].label, 'Cuentas');
    });
  });

  group('how many topics are under way', () {
    test('counts the families the player has actually met', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1), _figurate(1)],
        itemsServed: 2,
        practisedSteps: const <String, int>{},
      );

      expect(map.startedCount, 2);
      expect(map.nodes, hasLength(3));
    });
  });

  group('what a practice run left behind', () {
    // The map's question is "how far up this topic's ladder has the player been
    // taken", and two things take them up it: the daily series, which the
    // cursor counts because it walks the pack in order, and a practice run,
    // which walks one family and cannot be counted by a pack position. Both are
    // lower bounds on the same fact, so the map takes the higher.

    test('a practised step the cursor never reached moves the node', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_series(1), _series(2), _series(4)],
        itemsServed: 1,
        practisedSteps: const <String, int>{'numberSeries': 2},
      );

      expect(map.nodes.single.reachedStep, 2);
      expect(map.nodes.single.progress, closeTo(0.5, 1e-9));
    });

    test('a cursor ahead of what practice reached keeps what the cursor read',
        () {
      final SkillMap map = readSkillMap(
        items: <Item>[_series(1), _series(3), _series(4)],
        itemsServed: 2,
        practisedSteps: const <String, int>{'numberSeries': 1},
      );

      expect(map.nodes.single.reachedStep, 3);
    });

    test('each family reads its own entry, and the two can disagree in '
        'opposite directions', () {
      // PROC-11: with both families pulling the same way, the merge, "cursor
      // only" and "practised only" would all pass this. Cuentas is ahead on the
      // cursor and Series is ahead on practice, so only the merge is green.
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1), _sum(3), _series(4)],
        itemsServed: 3,
        practisedSteps: const <String, int>{
          'arithmetic': 1,
          'numberSeries': 4,
        },
      );

      expect(
        <String, int>{
          for (final SkillNode node in map.nodes) node.label: node.reachedStep,
        },
        <String, int>{'Cuentas': 3, 'Series': 4},
      );
    });

    test('an empty record leaves the map reading the cursor alone', () {
      // The other half of the same gate: a store that always answered empty
      // would be invisible without this, and a merge that always answered from
      // the record would be invisible with only the cases above.
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _sum(3)],
        itemsServed: 2,
        practisedSteps: const <String, int>{},
      );

      expect(map.nodes.single.reachedStep, 3);
    });

    test('a family the pack does not carry draws no node of its own', () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1)],
        itemsServed: 0,
        practisedSteps: const <String, int>{'figurate': 4},
      );

      expect(map.nodes, hasLength(1));
      expect(map.nodes.single.label, 'Cuentas');
    });

    test('a step past the ladder this pack offers is read as its top', () {
      // A record outlives a pack: it is keyed by family and step, not by item,
      // so a lighter pack must read as mastered rather than as 450%.
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _sum(2)],
        itemsServed: 0,
        practisedSteps: const <String, int>{'arithmetic': 9},
      );

      expect(map.nodes.single.reachedStep, 2);
      expect(map.nodes.single.progress, 1);
      expect(map.nodes.single.level, MasteryLevel.mastered);
    });

    test('practice alone starts a topic, so the count of started topics moves',
        () {
      final SkillMap map = readSkillMap(
        items: <Item>[_sum(1), _series(1)],
        itemsServed: 0,
        practisedSteps: const <String, int>{'numberSeries': 1},
      );

      expect(map.startedCount, 1);
    });
  });
}
