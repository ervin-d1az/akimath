# Design

## Context

The frozen contract describes nine operations. Eight are built. The ninth, `GET /items/next`, has
answered 501 since the router landed, and `packages/server/test/an-item-response-cannot-address-a-pack-item.test.ts`
is the record of why: `AttemptSubmission` can name a pack item and `ItemResponse` cannot, so the
only items this server owns are items it could hand out and never accept back.

Two things make this a contract change rather than a server change. The asymmetry is in
`contract/openapi.json`, which is emitted from `packages/contract` and byte-diffed by CI; and the
document is frozen, so widening it is a deliberate act with a gate in front of it.

## Goals / Non-Goals

**Goals.** Make the response side of the wire able to name the items this server actually has.
Keep the record of *why* the endpoint is unbuilt truthful as the reasons change. Say plainly which
half of the change breaks and get it approved rather than smuggled.

**Non-Goals.** Building the endpoint, correcting the prompt shape, or choosing an issuance policy.
The first two are in `proposal.md`; the third is OQ1 below and it is not mine to answer.

## Decisions

### D1 · Mirror `Verdict`, do not invent a shape

`VerdictSchema` already carries `itemId` and `packRef` as two optionals with `required: ["ok",
"payload"]`, and its doc comment gives the reason verbatim: *"A pack attempt has no `itemId` —
identity for a pack item is `(packId, index)` — so a required one was a field the server could not
fill for half the paths it has to serve."* That is this problem, one hop downstream, already
solved. `ItemResponse` takes the same pair, `OfflinePackRefSchema` and all.

The alternatives were worse in the same way they were worse for `Verdict`:

| | Shape | Why not |
|---|---|---|
| Keep `itemId` required, add `packRef` | `itemId` is a uuid the server has to invent for a digest item | An id that resolves to nothing is worse than no id. It would also make the gate go green while the blocker stood — the gate lying in the opposite direction. |
| A `oneOf` over two addressing shapes | The rule stated properly | `ARCHITECTURE.md` §2 forbids response polymorphism outright and `downconvert.ts` refuses `oneOf`; 3.0.3 has no general union. |
| A single opaque `itemRef` string, `"packId#index"` | One field, always present | It is the Dart client's spelling (`Item.id` is `packId#index`), not the wire's. `AttemptSubmission` would then have three ways to name an item, and the server would parse a string where it currently reads two typed fields. |

The XOR cannot be expressed in the schema, exactly as it cannot on the submission side, so it goes
in the operation's `description` — the same place, in the same words, for the same reason.

### D2 · The change is breaking, and the added property is not the breaking half

Two edits, and `oasdiff` sees them differently.

- **Adding `packRef` to `ItemResponse` is additive.** A property appearing in a response is
  information a client may ignore; oasdiff reports it at INFO and the gate stays green. If this
  were the whole change it would need no label.
- **Removing `itemId` from `required` is breaking.** A required response property is a guarantee:
  every client written against the document may read `itemId` without checking for it. Making it
  optional withdraws that guarantee, and oasdiff classifies a response property that was required
  becoming optional at **ERR** — the level `--fail-on ERR` fails on. The expected checker is
  `response-property-became-optional`; the exact id is recorded from the tool's own output in task
  2.1 rather than trusted from memory here.

So the change is **breaking**, on account of the required set, and the pull request carries
`allow-breaking-contract`. That is the label doing the job it was built for: `.github/workflows/ci.yml`
records that *"a breaking change before v1 ships is ordinary and will happen again; what must not
happen is one nobody decided on"*.

**The break cannot be dodged by renaming.** Pointing `/items/next`'s `200` at a fresh
`NextItemResponse` schema does not help — oasdiff resolves refs and diffs the response, so the
comparison still sees a `200` whose required set lost `itemId`, which is
`response-required-property-removed` and is worse, not better. Ruling it out here so it is not
proposed in review.

Worth stating plainly and not as an excuse: nothing consumes this response. The operation answers
501, `app/lib/api/` never modelled it, and no deployment exists. "Breaking" is a true statement
about the document, not about a client — which is why the honest move is to label it rather than to
argue it is not breaking.

### D3 · The endpoint is not built here

`CLAUDE.md` names two reasons `GET /items/next` does not exist: the addressing gap, and *"needs an
issuance policy"*. This change removes the first. The second is OQ1 and it is a product decision —
an endpoint that hands out an item has to decide which item, and there is no defensible way to
infer that from the code. Writing scenarios for a policy nobody has chosen would put an invented
ladder into a spec that a reviewer would then have to argue against.

`openspec/config.yaml` settles it: *"If you cannot name the test, the scenario is not a requirement
yet."*

So `getNextItem` stays out of `IMPLEMENTED_OPERATIONS`, the contract keeps its `501`, and
`contract-parity.test.ts` keeps holding the two to each other. Nothing in `packages/server/src/`
moves.

### D4 · The prompt shape splits out, and that is not a convenience

`ItemResponse.prompt` is `PromptToken[]` where a token is `{kind: number|operator|blank|text, text:
string}` and nothing else — `additionalProperties: false`, no payload, no structure. The frozen
pack format made the opposite decision for the same content: `StimulusEnvelope` is `{kind,
payload}` over six kinds, and `packages/contract/src/stimulus/index.ts` states D1 as the reason.
Fifty of the shipped pack's eighty items are one of the five non-arithmetic kinds.

Four reasons to keep it out of this change:

1. **The blockers are independent.** The deleted gate says so and declines to assert the second one
   for a stated reason: *"a test asserting it would be asserting the opinion rather than the
   obstacle"*. The addressing gap is a fact of two property lists; "a 3×3 matrix is not a flat
   list" is a judgement about a design. One is gateable and one is arguable.
2. **They are different sizes.** This change edits one schema and one enumeration. The other
   redesigns the shape in which every item reaches the client, and reopens `ARCHITECTURE.md` §4's
   `{itemId, prompt: PromptToken[], keypad}` resolution.
3. **Both are breaking, and bundling puts two arguments behind one label.** The label is an
   approval of a specific break. Two unrelated breaks under one label is the failure mode this
   repository keeps writing down: a gate that fires on everything gets switched off.
4. **The second one has no client.** Nothing renders a `PromptToken[]` today — the app renders a
   `StimulusEnvelope` through `content/model/stimulus_reader.dart`. The follow-up change gets to
   ask whether the wire should simply adopt the shape the app and the pack format already agree on,
   which is a much better question than "how do we flatten a matrix".

The follow-up is **`f3-an-item-travels-as-a-stimulus`**.

### D5 · The gate is deleted and nothing replaces it in kind

The file says to delete itself the day `ItemResponse` gains a `packRef`, and its second assertion
goes red at that moment, so keeping it is not an option: it would fail for the good reason and read
as a regression. Deleting it is a task in the same commit as the schema edit.

What must not go with it is the record. Two things carry it:

- **`CLAUDE.md`'s `GET /items/next` line** is rewritten in the same commit. Today it says the
  endpoint *"needs an issuance policy"*; afterwards it says the two reasons that remain and names
  the follow-up change for the first. That is where this project already keeps the reasons an
  endpoint does not exist, and it is read by every session.
- **A new gate in `packages/contract/test/openapi.test.ts`** holds the positive invariant: every
  spelling by which an item response addresses an item is a spelling an attempt submission accepts.
  It is not a replacement blocker gate — it expires never, because it is true after this change and
  must stay true. It is what stops the asymmetry coming back through a later edit to either schema.

There is deliberately **no** gate asserting the prompt-shape blocker or the missing issuance
policy. Neither is a fact of a document, and a gate that asserts a design opinion is a gate the
next person argues with instead of reading.

## Risks / Trade-offs

- **The label is a one-time human act, and a re-run needs it present.** CI reads labels live from
  the API precisely so a label added after a red run is seen; that path exists and is documented in
  the workflow.
- **`ItemResponse` becomes a shape with no required identity.** A response carrying neither
  `itemId` nor `packRef` validates. That is the same hole `AttemptSubmission` and `Verdict` already
  have, closed the same way — by the server, when a handler exists. Until then nothing emits an
  `ItemResponse` at all, so the hole is unreachable rather than unguarded, and the follow-up that
  builds the endpoint owns closing it.
- **The frozen document moves twice.** This change and `f3-an-item-travels-as-a-stimulus` will each
  break the contract. That is the cost of splitting, and it is cheaper than one label covering two
  arguments.

## Open Questions

### OQ1 · Which item does `GET /items/next` hand out?

**This is Ervin's to answer, not the change's.** The endpoint is unbuildable until it is answered,
and the answer decides whether it is built at all.

Two facts narrow it before anyone starts:

1. **The operation declares no parameters.** No skill selector, no session id, no cursor —
   `contract/openapi.json`'s `/items/next` has a `get` with `responses` and nothing else. Whatever
   the policy is, it derives entirely from the bearer token and what the database already knows
   about that player. Any answer that needs the client to say what it wants is a different
   operation and a second breaking change.
2. **The client half was never written.** `app/lib/api/` holds seven of the nine operations and
   this is not one of them; nothing in the app calls it, and `AttemptSync` already closes the loop
   through packs. So there is no client to break, whichever way this goes.

Three answers, stated without a recommendation:

- **The next unanswered item of the player's live pack, in pack order.** Cheapest, and it reuses a
  product decision already made and already under test — `seriesPlan` takes five items in pack
  order and `pack_variety_test.dart` holds that order to six families in the first ten items. Needs
  the pack's `(packId, index)`, which is what this change makes expressible. Raises one question of
  its own: what it answers when the player has no live pack, or has answered all eighty.
- **Rating-driven, from `user_skills` and a ladder step.** The adaptive answer, and the one
  `ARCHITECTURE.md` §4 was written around. It needs template generation, which was deleted with the
  generator in `f1-5-pack-builder`'s wake — every item in the shipped pack is authored and graded
  by digest, and `issued_items` has no writer. This is the largest of the three by a long way.
- **Delete the operation.** The offline pack loop is the product: the device issues a pack, plays
  it offline, and syncs. An online one-item-at-a-time endpoint may simply be a leftover of the
  pre-pack design, and ADR 0001's spike is where its shape came from. Removing an operation is
  breaking and needs a label, and it is the only one of the three that makes the contract smaller.

Whichever it is, `f3-an-item-travels-as-a-stimulus` is a prerequisite for the first two: an
endpoint that can only serve the thirty arithmetic items is not the endpoint.
