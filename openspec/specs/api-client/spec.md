# api-client Specification

## Purpose
How the Flutter app reaches the server, and what it is allowed to believe.

## Requirements

### Requirement: req-the-model-is-the-frozen-schema · Both directions

`Me` SHALL carry exactly the fields the frozen schema describes.

#### Scenario: Every required field, and no invented one

- **WHEN** the Dart model's serialised keys are compared to `Me`'s `properties` and `required`
- **THEN** they match in both directions — `additionalProperties: false` means a field here that is
  not there is one the client invented
  → `app/test/api/contract_parity_test.dart`

#### Scenario: The bands, in order

- **WHEN** `AgeBand.values` is compared to the schema's enum
- **THEN** they hold the same strings in the same order
  → `app/test/api/contract_parity_test.dart`

#### Scenario: A band nobody decided

- **WHEN** a body carries a band the contract does not name
- **THEN** it is refused — defaulting to `adult` would route a child out of their own protections,
  and defaulting to `under_13` would be a lie about who is playing
  → `app/test/api/me_test.dart`

### Requirement: req-createdat-is-the-contracts · Narrower than DateTime.parse

`createdAt` SHALL accept exactly the instants the frozen pattern admits.

#### Scenario: Agreement with the artifact

- **WHEN** the model and the contract's own regular expression are run over the same probes
- **THEN** they accept and refuse together on every one — the model re-derives the rules rather
  than copying the pattern, and this is what keeps the re-derivation honest
  → `app/test/api/contract_parity_test.dart`

#### Scenario: Parseable but off-contract

- **WHEN** a value carries a `+00:00` offset, no zone, or a space instead of the `T`
- **THEN** it is refused, though `DateTime.parse` would take it — each round-trips to different
  bytes than it arrived as
  → `app/test/api/me_test.dart`

### Requirement: req-every-answer-is-a-value · A screen never catches

`getMe` SHALL return a result for every outcome, including the ones that are not answers.

#### Scenario: Each status the contract declares

- **WHEN** the server answers 200, 401 or 404
- **THEN** the result is `MeFound`, `MeRejected` carrying the tag, or `MeNoPlayer` — 404 is not an
  error, it is an account with no player yet
  → `app/test/api/api_client_test.dart`

#### Scenario: A server that breaks its own contract

- **WHEN** a 200 carries something that is not a `Me`, or is not JSON at all
- **THEN** the result is `MeFailed` rather than an exception out of a constructor
  → `app/test/api/api_client_test.dart`

#### Scenario: No answer at all

- **WHEN** the socket is refused or the server never replies
- **THEN** the result is `MeUnreachable` — a screen cannot `catch` what it never called
  → `app/test/api/api_client_test.dart`

#### Scenario: A blank token

- **WHEN** `getMe` is given an empty token
- **THEN** no `Authorization` header is sent at all, so the server answers `unauthenticated` rather
  than `invalid_session` — the two are different bugs and the server separated them deliberately
  → `app/test/api/api_client_test.dart`
