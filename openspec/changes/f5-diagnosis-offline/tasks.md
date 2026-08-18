## 1. The pack carries it

- [x] 1.1 Red → green: a misconceptions map and a per-item distractor table are read.
- [x] 1.2 Red → green: an id with no copy behind it is refused where the pack is read.
- [x] 1.3 Red → green: a distractor keyed by the item's own answer is refused.

## 2. The policy

- [x] 2.1 Red → green: an anticipated wrong answer gets its steps.
- [x] 2.2 Red → green: anything else gets the fallback; a correct answer gets nothing.
- [x] 2.3 Red → green: both the typed answer and the authored key are canonicalised.

## 3. The screen

- [x] 3.1 Red → green: `04 Error` shows the steps and still does not scold.
- [x] 3.2 Register it at the most the schema admits, and let that entry decide the layout.

## 4. Content

- [x] 4.1 Author the misconceptions map and distractors for the arithmetic items where a wrong
      answer has an obvious cause.

## 5. What falsification changed

**Added during build.** Replacing the authored-side canonicalisation with a raw string
comparison changed no test — because storage mode rewrites nothing, so canonicalising a key
that survived the reader's check is an identity. The lookup is now a plain map read on the
canonical typed value, and the design says why.

- [x] 5.1 Red → green: the typed side is canonicalised in learner mode and the two modes are
      shown not to be interchangeable; the authored side is validated at load instead.
- [x] 5.2 Red → green: the whole path, end to end — a wrong answer in a real round reaches the
      screen with steps on it.

## 6. Evidence

- [x] 6.1 Tier 1 with counts, Tier 1b falsification matrix, Tier 2 on the simulator.
