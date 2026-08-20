# Shell — the bar's homes, and the stack above one of them

## ADDED Requirements

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
omit it rather than approximate it, and where another screen already draws it,
the profile SHALL NOT draw it a second time.

#### Scenario: No rating and no aggregate figures

- **WHEN** `Perfil` is drawn for a linked account
- **THEN** it shows no rating, no weekly delta, no accuracy and no mean time,
  because each is F4 or needs an aggregate no endpoint answers

#### Scenario: History is not drawn twice

- **WHEN** `Perfil` is drawn
- **THEN** it carries no history section, because `Avance` already reads
  `GET /me/history` and two screens over one feed can disagree

#### Scenario: The way out stays with the address

- **WHEN** the account has a session that could carry an erasure
- **THEN** the door is offered beside the address, so the sentence about what
  survives sits next to the thing it is about
