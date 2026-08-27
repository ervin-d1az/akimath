# An item response can address the item it hands back

## Why

**F3.** `GET /items/next` is the ninth contracted operation and the only one still answering 501.
`packages/server/test/an-item-response-cannot-address-a-pack-item.test.ts` holds the reason as a
gate rather than as a comment, and the reason is a fact of the frozen document:

- `AttemptSubmission` names an answered item in one of two ways — `itemId` for something this
  server issued, `packRef` for `(packId, index)` in an offline pack — mirroring the
  `attempts_one_source` CHECK. Six properties: `answer`, `clientTs`, `elapsedMs`, `itemId`,
  `packRef`, `sessionId`.
- `ItemResponse` carries three — `itemId`, `prompt`, `keypad` — and all three are **required**.

So an item handed back by `GET /items/next` can be addressed as an issued item and in no other
way. That settles the endpoint, because **the only items this server has to offer are pack
items**. `POST /packs` issues a copy of the shipped pack — eighty authored items whose every
manifest entry is a digest — and an `itemId` resolves against `issued_items`, a table that records
`(template_id, template_version, seed, ladder_step)` and nothing else. A digest item has no
template, so nothing writes `issued_items` at all; `src/adapters/retention-job.ts:82` already says
so in as many words. An item served here today could be shown and never answered, for **every one
of the eighty**, in either direction.

This is the schema half of why the endpoint does not exist. It is not the whole of it — see
Non-goals, and `design.md` OQ1, which is a decision for Ervin rather than for this change.

## What changes

- **`ItemResponse` gains `packRef`, and `itemId` stops being required.** Both become optional, and
  the required set becomes `["prompt", "keypad"]`. This is not a new shape: `Verdict` already
  carries exactly this pair, for exactly this reason — *"a pack attempt has no `itemId` … so a
  required one was a field the server could not fill for half the paths it has to serve."*
- **The XOR is stated in the operation's `description`**, the way `POST /attempts` states it.
  `ARCHITECTURE.md` §2 forbids `oneOf` and `downconvert.ts` refuses one, so the rule goes where a
  caller will read it rather than being left to be discovered.
- **A new gate holds the two shapes together**: every spelling by which an item response can
  address an item is a spelling an attempt submission can address it by. That is the positive form
  of the invariant the deleted gate was guarding negatively, and unlike the deleted gate it does
  not expire.
- **`openapi.test.ts`'s item-response enumeration widens** from three properties and three
  required to four and two. It stays an enumeration — `packRef` is admitted by name, not by
  relaxing the assertion.
- **The gate deletes itself, as it instructs**, and `CLAUDE.md`'s `GET /items/next` line takes over
  the reason: after this change the endpoint is unbuilt for two remaining reasons, neither of them
  addressing.
- **This is a breaking change to the contract and asks to be labelled.** `design.md` D2 works out
  which half breaks and why; the pull request carries `allow-breaking-contract`.

## What this builds on

- `packages/contract/src/openapi/api-schemas.ts` — `ItemResponseSchema`, `OfflinePackRefSchema`,
  `AttemptSubmissionSchema`, `VerdictSchema`. The last is the precedent, on the same page.
- `packages/contract/src/openapi/document.ts:128` — `/items/next`, and at `:145` the description
  where `POST /attempts` states the same rule.
- `contract/openapi.json` — the emitted artifact, byte-diffed and `oasdiff`'d by CI.
- `packages/contract/test/openapi.test.ts:150` — the enumeration that pins the shape.
- `packages/server/test/an-item-response-cannot-address-a-pack-item.test.ts` — the gate.
- `packages/server/src/routing.ts:94,113` — `CONTRACTED_OPERATIONS` and `IMPLEMENTED_OPERATIONS`.
  Neither moves here.
- `.github/workflows/ci.yml`, job `contract` — the `oasdiff` step and its label escape.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `api-contract`: what the committed specification admits. One requirement gains a way to address a
  pack item, one gains the breaking case this change is an instance of, and one is added for the
  addressing rule itself.

## Impact

**Modified** — `packages/contract/src/openapi/api-schemas.ts`,
`packages/contract/src/openapi/document.ts`, `packages/contract/test/openapi.test.ts`,
`contract/openapi.json` (emitted, never hand-edited), `CLAUDE.md`.

**Deleted** — `packages/server/test/an-item-response-cannot-address-a-pack-item.test.ts`.

**Untouched** — `packages/server/src/`. `getNextItem` stays out of `IMPLEMENTED_OPERATIONS`, the
contract keeps its `501` declaration for that one operation, and `contract-parity.test.ts` holds
the two to each other in both directions exactly as it does today.

**Untouched** — `app/lib/api/`. Seven of the nine operations live there and this is not one of
them; nothing in the app calls `GET /items/next` and no Dart type models `ItemResponse`.
`app/test/api/contract_parity_test.dart` reads the emitted document and checks `Me`, so it is run
as evidence rather than changed.

**Needs a human** — the `allow-breaking-contract` label on the pull request, and an answer to OQ1
before the endpoint can be built at all.

## Non-goals

- **Building `getNextItem`.** An endpoint that hands out an item has to decide *which* item, and
  nobody has decided. That is a product decision, not a schema one; it is `design.md` OQ1 and it is
  handed to Ervin unranked. `openspec/config.yaml`'s own rule settles the scope question: *"Every
  scenario must be verifiable by a test that will be committed. If you cannot name the test, the
  scenario is not a requirement yet."* No policy, no test, no scenario, no task. The endpoint keeps
  answering 501, honestly, for a reason that has changed.
- **The prompt shape.** `ItemResponse.prompt` is a flat `PromptToken[]` of `{kind, text}`, and
  `packages/contract/src/stimulus/index.ts` records design decision D1 rejecting exactly that shape
  for the pack format — *"a 3×3 matrix, a function machine, seven elastic tiles, two pair-cards and
  a figurate figure are not a flat list"* — so fifty of the shipped pack's eighty items cannot be
  rendered into it at all. That is a second, independent blocker and it is
  **`f3-an-item-travels-as-a-stimulus`**, a separate change. `design.md` D4 says why splitting is
  right rather than convenient.
- **A replacement gate for either remaining blocker.** The deleted test says why: a test asserting
  the prompt shape *"would be asserting the opinion rather than the obstacle"*. The reasons move to
  `CLAUDE.md`, which is where this project already keeps them, and to the follow-up change's own
  proposal.
- **Any change to `AttemptSubmission`, `Verdict` or the `attempts` table.** The submission side is
  already correct; this change makes the response side match it.
