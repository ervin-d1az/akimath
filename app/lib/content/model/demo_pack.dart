import 'item.dart';

/// A hand-written set of items, so the round is playable before the pack
/// builder exists.
///
/// **This is a fixture, not the content pipeline.** `f1b-content-reader` reads
/// the same [Item] type out of a bundled JSON pack, and `f1-5-pack-builder`
/// generates that pack; when they land, the *source* changes and the screen
/// does not. Nothing here computes difficulty — `ladderStep` travels with the
/// item, per the invariant that rating never runs in Dart.
const List<Item> demoPack = <Item>[
  Item(
    id: 'demo-1',
    prompt: <PromptToken>[
      PromptToken.fraction(numerator: '3', denominator: '4'),
      PromptToken.operator('+'),
      PromptToken.fraction(numerator: '2', denominator: '4'),
      PromptToken.operator('='),
    ],
    expected: '5/4',
    ladderStep: 3,
  ),
  Item(
    id: 'demo-2',
    prompt: <PromptToken>[
      PromptToken.text('14'),
      PromptToken.operator('×'),
      PromptToken.text('3'),
      PromptToken.operator('='),
    ],
    expected: '42',
    ladderStep: 2,
  ),
  Item(
    id: 'demo-3',
    prompt: <PromptToken>[
      PromptToken.fraction(numerator: '1', denominator: '2'),
      PromptToken.operator('+'),
      PromptToken.fraction(numerator: '1', denominator: '3'),
      PromptToken.operator('='),
    ],
    expected: '5/6',
    ladderStep: 4,
  ),
  Item(
    id: 'demo-4',
    prompt: <PromptToken>[
      PromptToken.text('8'),
      PromptToken.operator('−'),
      PromptToken.text('15'),
      PromptToken.operator('='),
    ],
    expected: '−7',
    ladderStep: 3,
  ),
  Item(
    id: 'demo-5',
    prompt: <PromptToken>[
      PromptToken.text('96'),
      PromptToken.operator('÷'),
      PromptToken.text('4'),
      PromptToken.operator('='),
    ],
    expected: '24',
    ladderStep: 2,
  ),
];
