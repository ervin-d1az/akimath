# domain-core Specification

## Purpose
The rederivation machine: what guarantees a recorded attempt can be turned back into the exact
problem it was, years later on another machine, and what the rating does with the result.

## Requirements

### Requirement: req-core-determinism · The core performs no ambient IO

The system SHALL refuse `Math.random`, `Date`, `performance`, `crypto.randomUUID`, `Intl` and
`toLocaleString` anywhere in the core's source, and SHALL permit `Math.exp`, `Math.log`,
`Math.sqrt`, `Math.pow` and `Math.fround` **only** in the rating modules that need them.

#### Scenario: A generator reaches for the clock

- **WHEN** a source file references `Date`, `performance` or `Intl` as a bare identifier, or
  `Math.random`, `crypto.randomUUID` or `.toLocaleString` as a property access
- **THEN** the gate fails naming the file and the line, because an import ban cannot see
  `Math.random()`
  → `packages/core/test/determinism.test.ts`

#### Scenario: The permission is scoped to the half that earned it

- **WHEN** a module outside the rating modules calls `Math.exp`, `Math.log`, `Math.pow` or
  `Math.fround`
- **THEN** the gate fails — the transcendentals are permitted because Glicko needs them, and a
  permission granted over the whole source is a permission the generators inherit for free
  → `packages/core/test/determinism.test.ts`

#### Scenario: The gate reports what it walked

- **WHEN** the gate runs
- **THEN** it reports how many files and how many identifiers it examined, and fails if that is
  zero, so a mistyped root cannot pass vacuously
  → `packages/core/test/determinism.test.ts`

### Requirement: req-core-zero-dependencies · The package ships nothing

The system SHALL declare no runtime dependency at all, SHALL prove it by reading the manifest
rather than by trusting a resolver, and SHALL state at its declaration why each development
dependency is permitted to exist.

#### Scenario: A runtime dependency is added

- **WHEN** the manifest declares any runtime dependency
- **THEN** the gate fails and names it, because a resolution-based invariant dies in a one-line
  diff and this one has to survive an agent running an install command
  → `packages/core/test/dependency-allowlist.test.ts`

#### Scenario: The gate is not vacuous against an empty set

- **WHEN** the gate runs against a manifest with no runtime dependencies
- **THEN** it still asserts something that could fail — the manifest was found, it is the right
  package, and the development dependencies it does declare are present — so "no dependencies" is
  distinguishable from "no file was read"
  → `packages/core/test/dependency-allowlist.test.ts`

### Requirement: req-core-prng · The PRNG is vendored, indexed and externally anchored

The system SHALL generate randomness from a vendored algorithm with no ambient state, SHALL address
its stream by index rather than by advancing a cursor, and SHALL prove its output against a
reference published outside this repository.

#### Scenario: The stream is anchored outside this repository

- **WHEN** the vendored kernel is run against the published reference's own outputs
- **THEN** they agree, and the test cites the source it was transcribed from
  → `packages/core/test/prng/reference.test.ts`

#### Scenario: An indexed draw equals the stream that walked there

- **WHEN** the word at index *n* is requested directly
- **THEN** it equals the word a stateful walk of *n* steps would have produced, for the extremes of
  the seed range as well as the middle — which is what makes statelessness a property of the
  algorithm rather than a discipline callers must keep
  → `packages/core/test/prng/counter_linearity.test.ts`

#### Scenario: A bounded draw is unbiased and its bound is reachable

- **WHEN** a value is drawn from a bounded range
- **THEN** the rejection threshold is the one the range requires, and a range narrow enough to
  force rejection still terminates and still covers both ends
  → `packages/core/test/prng/rejection.test.ts`

#### Scenario: The committed vector is replayed, not recomputed

- **WHEN** the golden vector test runs
- **THEN** it reads the committed artifact from disk and compares the code's output to it,
  reporting how many vectors it compared and failing at zero — a vector the code emits and then
  asserts against itself proves nothing
  → `packages/core/test/prng/golden.test.ts`

### Requirement: req-core-rational · Rationals are BigInt and never become answer strings

The system SHALL represent exact arithmetic as a pair of BigInts in normal form, and SHALL expose
no method or export that renders a rational as text.

#### Scenario: Arithmetic is exact and normalised

- **WHEN** rationals are combined
- **THEN** the result is in lowest terms with the sign on the numerator and zero represented one
  way only, so two equal values are indistinguishable
  → `packages/core/test/rational.test.ts`

#### Scenario: Nothing in the core can render an answer

- **WHEN** the core's public surface is enumerated
- **THEN** no export renders, formats, canonicalises or stringifies a rational — the rule for what
  `5/4` means is frozen elsewhere and checked from two languages, and a second implementation is
  how the two silently disagree
  → `packages/core/test/public_surface.test.ts`

### Requirement: req-contract-render · One implementation of the canonical join

The system SHALL render a canonical answer in exactly one place — the module that already owns
canonicalisation — and SHALL extend that module's cross-language vector set with every shape the
new renderer can produce.

#### Scenario: The renderer and the canonicaliser cannot disagree

- **WHEN** a rendered answer is fed back through the canonicaliser
- **THEN** it is accepted as already-canonical, for every shape the renderer produces, because both
  sides call the same private join rather than two regexes that agree today
  → `packages/contract/test/canon.test.ts`

#### Scenario: The other language sees the new shapes

- **WHEN** the cross-language vector set is regenerated
- **THEN** it contains the rendered shapes that were missing — including a negative-zero fraction,
  the exact hole through which a defect once shipped in Dart — and the Dart parity test iterates
  them without a Dart edit
  → `packages/contract/test/canon.test.ts`, and the Dart canon parity test

### Requirement: req-core-rederivation · A recorded item rederives forever

The system SHALL reconstruct an item from what the schema records about it, SHALL resolve a
template version to the behaviour that version had when it was issued, and SHALL keep a retired
version rederivable after it stops being issued.

#### Scenario: The recorded key is the key the schema stores

- **WHEN** an item is rederived
- **THEN** it is rederived from the template, the version, the seed and the ladder step — all four,
  because all four are what the schema records and the ladder step is not recoverable from the
  others
  → `packages/core/test/template/rederive.test.ts`

#### Scenario: A revised template does not rewrite history

- **WHEN** a template gains a new version and an old attempt is rederived at the old version
- **THEN** it produces exactly what it produced before, and the two versions produce **different**
  items from the same seed — so the test proves the versions are distinguishable rather than
  assuming it
  → `packages/core/test/template/versioning.test.ts`

#### Scenario: A retired version still rederives but is never issued again

- **WHEN** a version is marked retired
- **THEN** rederivation still resolves it, and the set of templates available for issuing excludes
  it
  → `packages/core/test/template/registry.test.ts`

#### Scenario: A seed survives the storage it is recorded in

- **WHEN** a seed at the top of the range makes the round trip through the way packs record it
- **THEN** it comes back exactly, because a seed off by one rederives an unrelated item rather than
  a similar one
  → `packages/server/test/offline-packs.test.ts`

### Requirement: req-core-reference-template · One worked template proves the mechanism

The system SHALL ship one template, versioned, whose output is checked against an item that already
exists in the shipped content, and SHALL prove the generated item is acceptable to the frozen pack
format.

#### Scenario: The reference template reproduces a shipped item

- **WHEN** the reference template is run at a committed seed
- **THEN** it produces the prompt and expected answer of a specific item in the shipped starter
  pack, named in the test
  → `packages/core/test/template/reference_template.test.ts`

#### Scenario: A generated item is acceptable to the frozen format

- **WHEN** a generated item is rendered and validated against the frozen item schema
- **THEN** it is accepted — and the validation reaches the payload rather than stopping at the
  envelope, so the check is about the item and not about its wrapper
  → `packages/core/test/template/contract_parity.test.ts`

### Requirement: req-core-rating · Glicko-1 over the session, decaying in days

The system SHALL rate a batch of outcomes as one rating period, SHALL take each opponent's rating
and deviation as an input rather than deriving them, SHALL decay a prior by elapsed **days**, and
SHALL narrow every output to the precision the schema stores.

#### Scenario: A session is one rating period

- **WHEN** a batch of outcomes is rated together
- **THEN** the result differs from rating them one at a time, because a rating period is the batch
  — two players with identical play must not diverge on whether they had a connection
  → `packages/core/test/rating/glicko.test.ts`

#### Scenario: An inactive player decays by days, not by turns

- **WHEN** a prior is decayed across an elapsed span
- **THEN** the deviation grows as a function of the number of days and is capped, and a span of
  zero days changes nothing
  → `packages/core/test/rating/decay.test.ts`

#### Scenario: The rating is reproducible at the precision it is stored

- **WHEN** a rating is computed and narrowed to the stored precision
- **THEN** it matches the committed fixture exactly, and it still matches when the transcendental
  functions underneath are perturbed by a plausible cross-engine amount — which is what makes a
  byte-exact fixture honest rather than lucky
  → `packages/core/test/rating/golden.test.ts`

### Requirement: req-core-gates · The package is gated everywhere, not just in CI

The system SHALL run the core's suite in continuous integration as a required check, and SHALL
re-run the suites on **both** sides of every cross-package edge this change creates.

#### Scenario: The core's suite is required

- **WHEN** a change touches the core
- **THEN** its job runs and the aggregate gate depends on it, so a golden artifact no required
  check reads cannot exist
  → `.github/workflows/ci.yml`

#### Scenario: A change to the frozen contract re-runs everything bound to it

- **WHEN** the frozen contract or its emitted artifacts change
- **THEN** the core's parity suite runs, and so does the Dart suite, because the cross-language
  vector set binds all three and a filter that watches only one of them lets the other two drift
  → `.github/workflows/ci.yml`
