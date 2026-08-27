# shell Specification

## Purpose
TBD - created by archiving change f7-perfil-es-la-raiz. Update Purpose after archive.

## Requirements

### Requirement: The bar names the homes the design names

The bottom bar SHALL label its roots `Inicio`, `Mapa`, `Avance` and `Perfil`,
which are declared rule 1's four homes. Ajustes SHALL NOT be one of them.

#### Scenario: The third root reads Perfil

- **WHEN** the bar is drawn with the roots that exist today
- **THEN** its third tab reads `Perfil` and carries the profile mark, not the
  settings mark

#### Scenario: No tab is labelled Ajustes

- **WHEN** every tab the bar can draw is enumerated
- **THEN** none of them is named after a settings screen, because a settings
  screen is reached from a home and is not one

### Requirement: Settings is pushed from the profile, not rooted

The app SHALL reach the settings list from a control on the profile root, and
that list SHALL carry a way back.

#### Scenario: The gear opens the list

- **WHEN** the player presses the gear on `Perfil`
- **THEN** the settings list is shown over the profile

#### Scenario: The list comes back

- **WHEN** the player presses the list's back control
- **THEN** the profile is shown again, with the bar still under it

#### Scenario: The bar survives the stack

- **WHEN** the settings list is open
- **THEN** the bar is still drawn, because the stack sits above a home rather
  than replacing it — *"Aquí sí va la barra inferior"*

### Requirement: The list draws only rows that lead somewhere

The settings list SHALL contain a row for each destination that exists and no
row for one that does not.

#### Scenario: A destination that exists gets a row

- **WHEN** the list is drawn
- **THEN** `Cuenta` is a row, and pressing it opens the account

#### Scenario: A destination that does not exist gets no row

- **WHEN** the list is drawn
- **THEN** there is no `Notificaciones`, no `Sonido y vibración` and no `Ayuda`
  — a row leading nowhere is worse than an absent one, the same reading that
  keeps every toggle off the screen

#### Scenario: The list reports what it drew

- **WHEN** a test enumerates the rows
- **THEN** the count is reported and is greater than zero, so a list that
  silently drew nothing cannot pass

### Requirement: The profile prints only what the device or the server can say

Every figure on the profile SHALL come from a device fact or an implemented
endpoint. Where the design draws one that neither can produce, the screen SHALL
omit it rather than approximate it.

#### Scenario: No rating and no weekly delta

- **WHEN** `Perfil` is drawn for a linked account
- **THEN** it shows no rating and no weekly delta. F4 landed and
  `GET /me/standing` is implemented, but it answers a rating **per skill** and no
  single number over a list of Glicko ratings is a fact about a player, so the
  slot stays empty rather than being averaged into existence; and
  `HistoryEntry.ratingDelta` comes back null, so nothing can say how one moved

#### Scenario: Accuracy and mean time are the device's own

- **WHEN** the player has answered something on this device
- **THEN** `ACIERTOS` and `PROMEDIO` are drawn from the record `features/stats/`
  keeps of what was actually answered, which needs no server at all — and both
  are absent rather than `0` over no answers at all

#### Scenario: One screen reads the history feed

- **WHEN** `Perfil` is drawn
- **THEN** it is the only screen over `GET /me/history` — `Avance` was absorbed
  into it, so the two screens that could disagree over one feed are now one

#### Scenario: The way out stays with the address

- **WHEN** the account has a session that could carry an erasure
- **THEN** the door is offered beside the address, so the sentence about what
  survives sits next to the thing it is about

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

#### Scenario: Three roots today

- **WHEN** the shell is drawn
- **THEN** the bar shows `Inicio`, `Mapa` and `Perfil` and nothing else

#### Scenario: No tab is drawn for a root nobody has designed

- **WHEN** the bar is drawn
- **THEN** there is no `Avance` tab, because no document draws a progress screen
  and what ours showed is `4.1`'s

#### Scenario: A new root needs no change here

- **WHEN** the skills map was added to the roots that exist
- **THEN** the bar drew three, with no edit to the rule that decides them —
  `visibleTabs` has still never been edited across none → two → three → two →
  three

### Requirement: Aki appears where the rules say she does

The profile SHALL draw Aki exactly where `4.1` draws her and nowhere else on
the screen.

#### Scenario: She is in the tile and nowhere else on the profile

- **WHEN** the profile is drawn
- **THEN** Aki appears once, inside the avatar tile, and there is no loose
  portrait or speech bubble — declared rule 5 names her homes as *inicio,
  resultados, estados de racha y tutorial*
