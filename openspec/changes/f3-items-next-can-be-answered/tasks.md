## 1. The item response can name a pack item

- [ ] 1.1 Red → green: widen the enumeration in `packages/contract/test/openapi.test.ts` to expect
      `["itemId", "keypad", "packRef", "prompt"]` and `required` of `["keypad", "prompt"]`, see it
      fail, then give `ItemResponseSchema` an optional `packRef: OfflinePackRefSchema` and make
      `itemId` optional. Check: `npm run verify` in `packages/contract`, with that test named in
      the run.
- [ ] 1.2 Red → green: a gate holding the two shapes together — every addressing property on
      `ItemResponse` is an addressing property on `AttemptSubmission`, compared over the emitted
      document rather than over the Zod source, and reporting the two property counts so a
      comparison that finds nothing cannot pass (PROC-10). Check:
      `packages/contract/test/openapi.test.ts`.
- [ ] 1.3 Red → green: the operation's `description` on `/items/next` names both spellings and says
      exactly one is present, the way `POST /attempts` already does. Check: a test in
      `packages/contract/test/openapi.test.ts` asserting the description mentions `itemId` and
      `packRef` — the rule the schema cannot state is not allowed to live only in a code comment.
- [ ] 1.4 Re-emit the artifact and prove it did not move on the second run: `npm run emit` in
      `packages/contract`, then `git add -A -- contract/` and `git diff --cached --exit-code --
      contract/` after a second `npm run emit`. Expected: no output, exit 0.

## 2. The break is measured, not recalled

- [ ] 2.1 Run the gate's own comparison locally before pushing: `git show
      main:contract/openapi.json > /tmp/openapi.base.json` then `oasdiff breaking
      /tmp/openapi.base.json contract/openapi.json --fail-on ERR`. Expected: it **fails**, naming
      the required-property change on the `200` of `getNextItem` at ERR and the added `packRef` at
      INFO. Record the checker ids it actually prints in the pull request body — `design.md` D2
      predicts `response-property-became-optional` and the tool is the authority.
- [ ] 2.2 Put `allow-breaking-contract` on the pull request and confirm the `contract` job passes
      with it, printing what breaks. Check: `.github/workflows/ci.yml`, job `contract`. This is a
      human act — the label is the approval, not a formality.

## 3. The gate that recorded the blocker

- [ ] 3.1 Delete `packages/server/test/an-item-response-cannot-address-a-pack-item.test.ts`, as its
      own closing paragraph instructs, and rewrite `CLAUDE.md`'s `GET /items/next` line so the two
      reasons that remain — the prompt shape, and the undecided issuance policy — are written where
      the reasons for an unbuilt endpoint already live. Check: `npm test` in `packages/server` is
      green with the file gone, and `test/contract-parity.test.ts` still holds `getNextItem`'s
      `501` in both directions, which is what proves the endpoint did not quietly change status.

## 4. Evidence

- [ ] 4.1 Tier 1 with counts: `npm run verify` in `packages/contract`, `packages/core` and
      `packages/server`, and `flutter analyze --fatal-infos` + `flutter test` in `app/` — the last
      because `app/test/api/contract_parity_test.dart` reads the emitted document this change
      rewrites.
- [ ] 4.2 Tier 1b in `packages/contract`: `npm run mutation` and `npm run dry`, with the score
      stated against the 91.71% on record. No Tier 2 — there is no handler to call, and saying so
      is the evidence.
