# puzzle-content Specification

## Purpose
How much the shipped pack carries, and what it may not carry.

## Requirements

### Requirement: req-a-week-of-every-format · Tomorrow is a different board

The pack SHALL carry enough boards of each format that a week passes before one repeats.

#### Scenario: Seven of each

- **WHEN** the shipped pack's boards are counted by kind
- **THEN** every kind has at least seven, because the rotation offers one per kind per day
  → `app/test/content/pack_variety_test.dart`

#### Scenario: And all of them are reachable

- **WHEN** a fortnight of days is asked for
- **THEN** every board the pack carries has been offered — seven per kind fits, and fifteen
  would not
  → `app/test/content/pack_variety_test.dart`

### Requirement: req-nothing-the-pad-cannot-enter · The contract permits more than the client can play

No board SHALL require a value the keypad cannot produce.

#### Scenario: A magic square above three

- **WHEN** a 4×4 magic square is offered to the pack
- **THEN** it is refused, because it draws from 1 to 16 and the pad has nine keys — a player
  could not enter seven of them
  → `app/test/content/pack_variety_test.dart`

#### Scenario: The rule is named, not only enforced

- **WHEN** a board exceeding the pad's ceiling reaches the pack
- **THEN** a test says so in a sentence, rather than leaving the reader's `FormatException` as
  the only explanation
  → `app/test/content/pack_variety_test.dart`

### Requirement: req-puzzle-authored-never-generated · Boards arrive, they are not made here

The system SHALL read puzzles from the pack and SHALL NOT construct or search for one on the device.

#### Scenario: The app is inspected for a solver

- **WHEN** the puzzle feature's sources are walked
- **THEN** nothing generates a board, places a cage or searches for a unique solution — that work is
  the builder's, and a uniqueness search running before a player can start is not something to ship
  → `app/test/architecture/no_puzzle_generation_test.dart`

### Requirement: req-puzzle-reader-answers-to-the-fixtures · The Dart parsers agree with the frozen format

The system SHALL parse each frozen puzzle payload it claims to support, SHALL refuse each rejection
row, and SHALL report how many kinds it reads.

#### Scenario: A golden payload is read

- **WHEN** the frozen golden for a supported kind is parsed
- **THEN** it yields the board, cages and solution the fixture declares
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: A rejection row is read

- **WHEN** the frozen rejection row for a supported kind is parsed
- **THEN** it is refused, so the two stacks cannot disagree about what is a valid board
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: A kind this build cannot draw

- **WHEN** a pack carries a puzzle kind the app has no renderer for
- **THEN** it is refused where the pack is read, not halfway into a board
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: Killer is read

- **WHEN** the frozen Killer golden is parsed
- **THEN** it yields a board and cages carrying targets and no operations
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: Killer's rejection row

- **WHEN** the frozen Killer rejection row is parsed
- **THEN** it is refused
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: A target no arrangement could reach

- **WHEN** a summing cage asks for a total outside the range its cell count and the board's size
  allow
- **THEN** it is refused — a bound in constant time, not a reachability proof, because whether a
  particular target is achievable under the Latin constraint is the builder's to decide and
  re-deriving it on the device is the solving this app does not do
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: The gate reports its coverage

- **WHEN** the parity gate runs
- **THEN** it reports two kinds readable and three pending, so the gap stays visible
  → `app/test/content/model/puzzle_fixture_test.dart`

### Requirement: req-puzzle-solution-stays-off-the-screen · The board never draws its own answer

The system SHALL NOT render any value from the solution into a cell the player is expected to fill.

#### Scenario: The rendered board is swept

- **WHEN** a board is drawn from a payload whose solution is known
- **THEN** no open cell shows its solution value before the player enters one, and the sweep reports
  how many cells it checked
  → `app/test/features/puzzle/ui/puzzle_board_test.dart`

### Requirement: req-puzzle-playable-on-the-pad · A board nobody can enter values into is refused

The system SHALL refuse a puzzle whose domain exceeds what the frozen pad can express.

#### Scenario: A magic square larger than three

- **WHEN** a 4×4 magic square arrives, needing sixteen distinct values
- **THEN** it is refused where the pack is read, because the pad offers nine digits and the other
  seven values cannot be entered at all — that board is not difficult, it is unplayable
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: A three-square magic square

- **WHEN** a 3×3 magic square arrives, needing nine
- **THEN** it is accepted, because nine is exactly what the pad offers
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: A caged board of any admitted size

- **WHEN** a 6×6 KenKen arrives, needing six
- **THEN** it is accepted — the limit is the domain, not the board
  → `app/test/content/model/puzzle_fixture_test.dart`

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

### Requirement: req-puzzle-words-must-be-present · A word that is not in the grid is refused

The reader SHALL refuse a word search whose list names a word its grid does not contain.

#### Scenario: A word that cannot be found

- **WHEN** a word appears in none of the eight directions
- **THEN** the puzzle is refused where the pack is read, because that word can never be claimed and
  the board can never be finished
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: This kind needs no exception

- **WHEN** the parity gate runs
- **THEN** word search is required to refuse its rejection row like the others, because
  `word_not_found` is a scan of a small grid and not a search for a solution
  → `app/test/content/model/puzzle_fixture_test.dart`

#### Scenario: Every frozen kind is readable

- **WHEN** the gate reports its coverage
- **THEN** it reports five kinds readable and none pending
  → `app/test/content/model/puzzle_fixture_test.dart`
