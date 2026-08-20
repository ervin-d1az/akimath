# Shell — one profile, and the bar that follows from it

## ADDED Requirements

### Requirement: The profile holds everything the device and the server can say about a player

`4.1 Perfil` SHALL draw the identity, the figures the device computes and the
history the server reports, in the order the design draws them.

#### Scenario: The identity comes first

- **WHEN** the profile is drawn for a linked account
- **THEN** the avatar tile, the address and the gear are above everything else

#### Scenario: The figures the device knows are drawn whether or not there is an account

- **WHEN** the profile is drawn with no account at all
- **THEN** the days practised and the current run are still shown, because a
  phone that has never synced still knows what it did

#### Scenario: The history section is absent when there is nothing true to say

- **WHEN** there is no account, or an account with no sessions
- **THEN** no `HISTORIAL` heading appears — a heading over nothing is a promise
  the product cannot keep

#### Scenario: The two halves fail independently

- **WHEN** the history request fails
- **THEN** the figures are still drawn, because they never needed the network

### Requirement: The stat pair is drawn as the design draws it

The two headline figures SHALL be cards, not equal tiles: an eyebrow over a
display numeral over a unit line, with the run carrying the highlight fill.

#### Scenario: The run is the one that is filled

- **WHEN** the pair is drawn
- **THEN** the streak card is yellow and the days card is white, which is the
  hierarchy `4.1` draws between its two headline figures

#### Scenario: Each card names its unit

- **WHEN** the pair is drawn
- **THEN** each carries a label above and a unit below, so a bare number is
  never left to be guessed at

### Requirement: The bar draws the roots that exist

The bar SHALL draw one tab per root that has a destination, and none for a
tab the design names but nobody has drawn.

#### Scenario: Two roots today

- **WHEN** the shell is drawn
- **THEN** the bar shows `Inicio` and `Perfil` and nothing else

#### Scenario: No tab is drawn for a root nobody has designed

- **WHEN** the bar is drawn
- **THEN** there is no `Avance` tab, because no document draws a progress screen
  and what ours showed is `4.1`'s

#### Scenario: The next root needs no change here

- **WHEN** a skills map is added to the roots that exist
- **THEN** the bar draws three, with no edit to the rule that decides them

### Requirement: Aki appears where the rules say she does

The profile SHALL draw Aki exactly where `4.1` draws her and nowhere else on
the screen.

#### Scenario: She is in the tile and nowhere else on the profile

- **WHEN** the profile is drawn
- **THEN** Aki appears once, inside the avatar tile, and there is no loose
  portrait or speech bubble — declared rule 5 names her homes as *inicio,
  resultados, estados de racha y tutorial*
