## Context

See `proposal.md` — Why. `packages/contract` already emits three schemas, 37 fixtures and
`canon.golden.json` through one adapter, and CI already byte-diffs the result. This change adds a
fourth artifact to that machinery and one genuinely new problem: the document has to be **OpenAPI
3.0.3** and nothing available emits that directly.

Two facts on disk shape it.

- **Zod 4 emits JSON Schema, not OpenAPI.** `z.toJSONSchema()` targets 2020-12 or draft-7. Verified
  against the installed version: `draft-7` output carries `$schema`, and an `z.int().min(1)` becomes
  `{type: "integer", minimum: 1, maximum: 9007199254740991}` — the upper bound is Zod's, not the
  schema author's, and it lands in the document unless something removes it.
- **The endpoint surface is already decided by the documents**, not by this change. ADR 0001's spike
  measured three (`getNextItem`, `submitAttempt`, `getOfflinePack`) and carries their Zod schemas
  verbatim; `ARCHITECTURE.md` §5 names `GET /v1/me`, `GET /v1/me/history`, `GET /v1/me/standing`,
  `DELETE /v1/me` and `POST /v1/players/link`.

## Goals / Non-Goals

**Goals**

- The down-conversion is a pure function over a JSON document, so the hardest part of the change is
  tested without emitting a file or reading one.
- Anything the converter does not understand is an error, not a pass-through.

**Non-Goals** (beyond `proposal.md`'s)

- Round-tripping. Nothing needs to read 3.0.3 back into Zod.
- Covering constructs the schemas do not use. A converter that handles every JSON Schema keyword is
  a library; this one handles what this document contains and refuses the rest loudly.

## Decisions

### D1 · Emit draft-7 from Zod, then down-convert — and make the converter total

`z.toJSONSchema(schema, { target: "draft-7" })` gets closest to 3.0's dialect, and a pure pass turns
what remains into 3.0.3: drop `$schema`, rewrite a nullable union as `nullable: true`, turn a numeric
`exclusiveMinimum` into the boolean-plus-`minimum` form, collapse `const` to a single-valued `enum`,
and rewrite an array-valued `type`.

**The converter refuses what it does not recognise.** A pass-through default is how a 2020-12
construct reaches a Dart client that cannot read it, months later, with the gate green the whole
time. So the walk is exhaustive over the keywords it knows and throws on anything else, naming the
keyword and the path.

*Alternatives.* **Target 2020-12 and pin OpenAPI 3.1** — rejected by `ARCHITECTURE.md` §2 already:
no mature Dart generator digests 3.1 well, and while ADR 0001 makes the client hand-written, the
document is also what a future generator or an external consumer would read. **A converter library**
— a runtime dependency and its transitive tail, in the package whose dependency count is a stated
invariant, for a transformation this narrow. **Hand-write the document** — then the schemas the
runtime validates against and the schemas the document describes are two things that agree by
discipline, which is the failure this repository has already paid for twice.

### D2 · The document builder is PURE; the emitter stays the one adapter

`src/openapi/document.ts` returns the document as a value. `src/adapters/emit.ts` writes it beside
the three artifacts it already writes. That keeps "what the API is" testable with no filesystem, and
it is the split `routing.ts` versus `adapters/` sets across this repository.

### D3 · Variance lives in an opaque object, and a test sweeps for the alternative

Zero response polymorphism is `ARCHITECTURE.md` §2's rule, and the pack format already obeys the
same one: a stimulus payload is `z.record(z.string(), z.unknown())` with a separate validator. The
API does the same for a verdict's diagnosis payload.

Asserted by walking every node of the emitted document for `oneOf`, `anyOf`, `allOf` and
`discriminator` — over the whole document rather than the schemas, because a `$ref` target or a
response wrapper can introduce one without any schema file changing.

### D4 · Two invariants are enforced against the *document*, not against the code

`ARCHITECTURE.md` §4's invariant — *the prompt travels rendered, the answer never travels online* —
is a property of the wire, so the wire description is where it can be checked. Two sweeps:

- **No property named for a template, a template version or a seed**, anywhere. Those three
  reconstruct the problem, and §4 is explicit that they never appear in a response.
- **No `options`.** `ARCHITECTURE.md`:202 still lists it in the item response and §4's own
  resolution contradicts it; a field offering a child a set of answers to pick from is a different
  product. The line is corrected in this change (CMT-2).

A third, on the way in: the attempt submission carries no field asserting correctness. §4 says the
sync endpoint "does not accept an `ok` field — that is what makes the invariant true by construction
rather than by discipline", and a schema is where "by construction" actually lives.

### D5 · `oasdiff` runs against the previous commit's document, in CI only

The breaking-change check needs two documents. The base is the committed `contract/openapi.json` as
of the merge base; the head is what the branch emits. That is a CI-shaped question — it needs git
history — so it lives in the workflow rather than in a test, and the workflow pins the `oasdiff`
version for the same reason the snapshot job pins `pg_dump`: a tool that changes its own output
turns a gate into noise and gets deleted.

**It reports breaking changes only.** A gate that fires on every addition trains people to pass
`--force`.

## Risks / Trade-offs

- **A converter that silently passes an unknown keyword** → D1 makes it throw. This is the failure
  mode that would be discovered by a Dart client at F3, months later.
- **Zod's synthetic bounds leaking into the contract** → `z.int()` emits `maximum:
  9007199254740991`, which is a fact about JavaScript and not about the API. The converter strips
  bounds Zod added rather than the author, and a test pins one.
- **Freezing a shape nobody has built yet** → real, and the reason the Non-goals list is long. Where
  the documents have not decided, it is an open question rather than an invention, because a spec is
  expensive to change once a client is written against it.
- **`oasdiff` unavailable or changed** → pinned by version in the workflow; if it cannot run the job
  fails rather than skipping, since a silently-absent gate is worse than none.

## Open Questions

Answerable later without changing the specs or the task breakdown.

1. **The `/v1/me/standing` response.** Named in `ARCHITECTURE.md` and never shaped. `4.1`'s profile
   screen is F7 and `f3-profile-read` owns the fields; until then the path is described with the
   shape the plan records and marked as such.
2. **Pagination on `/v1/me/history`.** No document names a page size or a cursor. Adding one later is
   a compatible change; guessing one now is a shape a client would encode.
3. **Whether the error envelope is uniform.** ADR 0001 lists error envelopes among the things that
   would reopen the hand-written-client decision if they arrived, so the shape matters beyond this
   document. Recorded, not decided here.
