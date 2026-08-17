# Tasks — the contract emitter

**Nothing here invents an endpoint shape.** Every schema comes from a document that already decided
it — ADR 0001's spike carries three verbatim, `ARCHITECTURE.md` §5 names the rest. Where a shape is
unstated it goes to `design.md`'s open questions, because a specification is expensive to change once
a client is written against it and that is the whole reason for freezing it early.

## 1 · The down-converter, which is the actual work

- [ ] 1.1 Write `packages/contract/test/openapi-downconvert.test.ts` for the constructs Zod's draft-7
      output actually produces: `$schema`, a nullable union, a numeric `exclusiveMinimum`, `const`,
      an array-valued `type`.
      **Check:** red. Table-driven, one row per construct, each with its 3.0.3 spelling.
- [ ] 1.2 Add the case that matters most: an **unknown** keyword is refused, naming the keyword and
      its path.
      **Check:** red. A pass-through default is how a 2020-12 construct reaches a Dart client that
      cannot read it, months later, with the gate green throughout.
- [ ] 1.3 Add the case for Zod's synthetic bounds: `z.int()` emits `maximum: 9007199254740991`, which
      is a fact about JavaScript and not about the API.
      **Check:** red, then green once the converter strips it.
- [ ] 1.4 Write `packages/contract/src/openapi/downconvert.ts`. **PURE** — a JSON document in, a
      3.0.3 document out, no IO.
      **Check:** `npm run verify` green with the count; `npm run mutation` covers it.

## 2 · The document

- [ ] 2.1 Add the request and response schemas beside the pack schemas, transcribed from ADR 0001's
      spike (`ItemResponse`, `AttemptSubmission`, `Verdict`) and from `ARCHITECTURE.md` §5's endpoint
      list. **`options` is not among them** — §4's resolution contradicts `ARCHITECTURE.md`:202, and
      that line is corrected in task 5.1.
      **Check:** the schemas typecheck and the ADR's three match it field for field.
- [ ] 2.2 Write `packages/contract/src/openapi/document.ts`. **PURE** — returns the document as a
      value, so what the API *is* stays testable with no filesystem.
      **Check:** green.
- [ ] 2.3 Add `contract/openapi.json` to `src/adapters/emit.ts`, the package's one adapter.
      **Check:** `npm run emit` twice produces no diff.

## 3 · What the document must never contain

- [ ] 3.1 Sweep every node for `oneOf`, `anyOf`, `allOf` and `discriminator`.
      **Check:** the sweep reports how many nodes it visited and fails at zero (PROC-10); falsify by
      adding a union to one schema and confirming red.
- [ ] 3.2 Sweep every property name for a template identifier, a template version and a seed.
      **Check:** `ARCHITECTURE.md` §4 — the prompt travels rendered and those three reconstruct the
      problem. Falsify by adding one.
- [ ] 3.3 Assert the item response carries the item identifier, the prompt and the keypad and
      **nothing else**, and that the attempt submission carries no correctness field.
      **Check:** §4 says the sync endpoint "does not accept an `ok` field — that is what makes the
      invariant true by construction rather than by discipline". A schema is where by-construction
      lives.
- [ ] 3.4 Assert the 3.0.3 dialect over the emitted document: the declared version, and none of the
      later-version spellings.
      **Check:** the same list task 1.1 converts, asserted on the real artifact rather than on a
      fixture.

## 4 · The breaking-change gate

- [ ] 4.1 Add the `oasdiff` step to the `contract` job, **version-pinned**, comparing the merge
      base's committed document against what the branch emits.
      **Check:** the same reasoning that pins `pg_dump` in the `integration` job — a tool that
      changes its own output turns a gate into noise and gets deleted.
- [ ] 4.2 Falsify it both ways: remove a response field and confirm the job fails; add an **optional**
      field and confirm it passes.
      **Check:** a gate that fires on every addition trains people to pass `--force`. Both directions
      or it is not a gate.

## 5 · Documents this change corrects

- [ ] 5.1 `ARCHITECTURE.md`:202 — `options` comes out of the item response (CMT-2).
- [ ] 5.2 `CLAUDE.md` — `contract/openapi.json` stops being listed as planned, and the `contract` job
      stops being described as missing its `oasdiff` half.

## 6 · Evidence

- [ ] 6.1 **Tier 1** — `npm run verify` green in all three TypeScript packages with the counts, and
      `app/` unchanged at its current count.
- [ ] 6.2 **Tier 1b** — `npm run mutation` and `npm run dry` in `packages/contract`. The
      down-converter is pure string-and-object work with no IO, so a weak test has nowhere to hide.
- [ ] 6.3 **Tier 2** — does not apply: no endpoint, no screen, nothing observable to a player. Stated
      rather than skipped (PROC-5). The nearest real check is `oasdiff` running against an actual
      previous document, which task 4.2 exercises in both directions.
