## Purpose

How the Flutter app reaches the server, and what it is allowed to believe about the band.

## MODIFIED Requirements

### Requirement: req-the-model-is-the-frozen-schema · Both directions

`Me` SHALL carry exactly the fields the frozen schema describes.

#### Scenario: Every required field, and no invented one

- **WHEN** the Dart model's serialised keys are compared to `Me`'s `properties` and `required`
- **THEN** they match in both directions — `additionalProperties: false` means a field here that is
  not there is one the client invented
  → `app/test/api/contract_parity_test.dart`

#### Scenario: The bands, in order

- **WHEN** `AgeBand.values` is compared to the schema's enum
- **THEN** they hold the same strings in the same order, and the count is reported — an enum of one
  is where a comparison of two empty lists passes without comparing anything
  → `app/test/api/contract_parity_test.dart`

#### Scenario: A band nobody decided

- **WHEN** a body carries a band the contract does not name — including `under_13` and `13_17`,
  which a server running an older build could still send
- **THEN** it is refused rather than coerced. The old reasoning was that defaulting either way
  misroutes a child; the reasoning now is narrower and still holds — a band the client cannot
  express is a disagreement about who the product is for, and swallowing it hides that
  → `app/test/api/me_test.dart`

## ADDED Requirements

### Requirement: req-a-stored-band-is-read-as-strictly-as-a-received-one · An older build's leftovers

A band read back from the device's own storage SHALL be validated exactly as one arriving from the
server is.

A device that ran a build from before this change can hold `13_17` in `shared_preferences`. That
value is not hostile and it is not hypothetical, and the sentence in the session policy asserting a
stored band *"can only ever be `13_17` or `adult`"* is the kind of comment that stops being true
without anything going red.

#### Scenario: A band this build does not know, on disk

- **WHEN** the session store reads a persisted band outside the contract's set
- **THEN** the stored session is refused rather than coerced to `adult`
  → `app/test/features/account/data/session_store_test.dart`
