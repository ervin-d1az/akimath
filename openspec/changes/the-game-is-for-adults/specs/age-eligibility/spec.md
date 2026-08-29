## Purpose

Who the product is for, and how the app behaves toward someone it is not for.

Written for `design.md` D3's options 1 and 2, which differ in *where* the refusal is reached and
agree on everything below. **Under option 3 — the store declares it and the app never asks — this
capability is wrong on purpose and is deleted rather than amended**, because a device that declares
`adult` without having asked is a worse position than the routing gate this change replaces.

**The scenarios below are written at option 1's position — the gate in front of the account form —
because that is where the gate stands today and a scenario has to name a test that exists.** Option
2 moves the position earlier, to the first playable screen, and moves the test files with it:
`auth_flow_test.dart` becomes the first-run suite. Task 0.1 decides which, and only the position
moves — every claim these requirements make is the same under both.

## ADDED Requirements

### Requirement: req-one-band-and-it-is-adult · Every layer names one band

No layer of the system SHALL be able to express a band other than `adult`.

The old gate *routed*: a band chose between child protections and none, so three values were three
destinations. With one destination the band stops being a router and becomes a declaration, and the
value set collapses with it. Four artifacts state that set — the schema's `CHECK`, the contract's
enum, the server's reader and the client's enum — and this requirement is what stops one of them
holding an opinion the others do not.

#### Scenario: The client cannot construct another

- **WHEN** `AgeBand.values` is enumerated
- **THEN** it holds exactly one member, matching the contract's enum by value and order
  → `app/test/api/contract_parity_test.dart`

#### Scenario: No path produces another

- **WHEN** every path in the app that reaches `linkPlayer` is exercised — the age gate, and the
  sign-in door that reads a band back off `GET /me` rather than off the gate
- **THEN** the band on the request is `adult` in each case
  → `app/test/features/auth/auth_flow_test.dart`,
  `app/test/features/profile/ui/sign_in_door_test.dart`

#### Scenario: The server refuses another

- **WHEN** a request names any other band
- **THEN** the pure reader refuses it 400 before a connection is borrowed
  → `packages/server/test/link.test.ts`

### Requirement: req-no-account-without-a-declaration · The account form is unreachable without one

No screen that submits personal data or obtains a session SHALL be reachable until eligibility has
been declared on the device — and under option 2, no playable screen either.

This is `req-age-gate` narrowed rather than deleted. What changes in *both* options is that the
branch below the threshold ends in a refusal rather than in a consolation, so the two arms stop
being two destinations and become an answer and its opposite. What 0.1 decides is only how early the
question is asked; the birth date never leaves the phone either way.

#### Scenario: The form is behind the question

- **WHEN** the flow the gate stands in front of is opened — the account flow under option 1, the
  app's own entry under option 2
- **THEN** the eligibility question is what is drawn, and no path from it reaches what it guards
  without an eligible answer
  → `app/test/features/auth/auth_flow_test.dart` under option 1; the first-run suite under
  option 2

#### Scenario: The birth date does not travel

- **WHEN** an eligible answer is given and the device links
- **THEN** the request carries the band alone — no day, no month, no year
  → `app/test/api/api_client_test.dart`

#### Scenario: The decision is a pure function of its inputs

- **WHEN** eligibility is decided from a birth date and a day
- **THEN** it is decided by a module that reads no clock, no store and no socket, and the boundary
  gate still counts `features/*/policy/` rather than losing the root
  → `app/test/features/auth/policy/age_gate_test.dart`,
  `app/test/architecture/pure_boundary_test.dart`

### Requirement: req-the-refusal-offers-only-what-it-can-do · A refusal is not a broken control

A player the product is not for SHALL be told so, and SHALL be offered nothing the app cannot
deliver.

The screen this replaces offered a way forward — a tutor's permission — that the product will no
longer honour. Leaving that offer in place, or greying it out, is the failure DR-P2 names: a control
that cannot act reads as broken rather than as closed, and a player cannot tell *not yet* from *not
for you*. The copy is the design owner's and es-MX; these scenarios pin the facts it must claim, not
the strings it spells.

#### Scenario: Nothing on it leads to an account

- **WHEN** the refusal is reached
- **THEN** no control on it reaches the account form, and none is drawn disabled
  → `app/test/features/auth/ui/`, plus the entry in `app/test/design/screen_registry.dart`

#### Scenario: It says what remains true

- **WHEN** the refusal is read
- **THEN** every claim it makes is one the build can satisfy — anything it says about what stays on
  the device, or about what was sent, is checked against what the code does rather than accepted as
  copy (LANG-2)
  → `app/test/features/auth/ui/`

#### Scenario: The offer that is gone is gone

- **WHEN** the app is swept for the consent path the old branch led to
- **THEN** nothing reaches it, and no screen registry entry keeps it drawable — nothing enumerates
  screen filenames, so a stale screen trips no other gate
  → `app/test/design/screen_registry.dart`
