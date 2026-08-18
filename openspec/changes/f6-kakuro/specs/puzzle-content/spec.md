## MODIFIED Requirements

### Requirement: req-puzzle-reader-sees-what-a-reader-can-see · The gate says which faults belong to whom

The parity gate SHALL require the reader to refuse every rejection row whose fault is structural or
arithmetic, and SHALL record, per kind, any fault that can only be found by searching — which is the
builder's and never the device's.

#### Scenario: A structural fault

- **WHEN** a rejection row carries a fault visible without solving — runs that leave a cell
  uncovered, a solution of the wrong shape, a target no arrangement could reach
- **THEN** the reader refuses it
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: A fault only a search can find

- **WHEN** a rejection row's fault is that the board has more than one solution
- **THEN** the reader is **not** required to refuse it, the gate says so with its reason, and the
  builder is what keeps such a board out of a pack
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: The exception cannot spread quietly

- **WHEN** a kind is excused from the rejection check
- **THEN** the gate names it and its reason, and every kind not named is still required to refuse —
  so excusing a second one is a visible edit and not an omission
  → `app/test/content/model/puzzle_fixture_test.dart`

### Requirement: req-puzzle-kakuro-domain · A Kakuro holds one to nine, whatever its size

The reader SHALL give a Kakuro board a domain of nine regardless of the board's size.

#### Scenario: A three-square Kakuro

- **WHEN** a 3×3 Kakuro is read
- **THEN** its cells accept 1 to 9, unlike a 3×3 KenKen which accepts 1 to 3
  → `app/test/content/model/puzzle_fixture_test.dart`
