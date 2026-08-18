## MODIFIED Requirements

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
