## 1. The gate

- [x] 1.1 Red: `POST /players/link` carries no `ageBand`, against the applied schema.
- [x] 1.2 Red: the offered band set is empty, so nothing can be inserted.

## 2. The contract

- [x] 2.1 `PlayerLink` gains `ageBand`; the band set is declared once and shared with `Me`.
- [x] 2.2 Green, with counts: 2 caller-supplied columns → 2 carried, 3 bands → 3 accepted.
- [x] 2.3 Emit; the tree does not move afterwards.

## 3. The escape

- [x] 3.1 The breaking gate can be answered with `allow-breaking-contract`.
- [x] 3.2 All four branches simulated against the pinned `oasdiff`.

- [x] 3.3 The gate is reachable at all: full history, and a base commit that is missing
      fails loudly instead of passing quietly.
