## 1. The policy

- [x] 1.1 Red → green: one board per kind, kinds in pack order, boards in pack order.
- [x] 1.2 Red → green: the same day is the same board; consecutive days rotate through a kind.
- [x] 1.3 Red → green: the day number survives a daylight-saving transition.

## 2. The home

- [x] 2.1 Red → green: the route offers the day's board for each kind, and the reachability
      gate still opens every kind.

## 3. Content

- [x] 3.1 Generate three KenKens and three Killers and author them into the pack.
- [x] 3.2 Red → green: every board the pack carries is offered on some day, with a count.

## 4. A regression the content size exposed

**Added during build.** The pack crossed 50 KB when the generated boards landed, and Flutter
hands a UTF-8 decode above that to a background isolate — which never completes inside
`testWidgets`' fake-async zone. Every widget test that loads the shipped pack stopped failing
and started hanging for ten minutes.

- [x] 4.1 Red → green: the reader decodes the bytes itself, with a bundle that refuses
      `loadString` as the gate.

## 5. Evidence

- [x] 5.1 Tier 1 with counts, Tier 1b falsification matrix, Tier 2 on the simulator.
