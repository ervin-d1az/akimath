# 3. The Dart client crossed its threshold and stays hand-written

**Status:** Accepted — 2026-08-28. **Supersedes
[ADR 0001](0001-dart-api-client.md)** and **reaffirms its decision**: the Dart API client in
`app/lib/api/` is hand-written, and `swagger_dart_code_generator` stays rejected.

A supersede here is a statement about **which document is authoritative**, not about which way the
decision went. ADR 0001 said it is *"superseded by a **new** ADR, never edited, if any of these
becomes true"* — two of its four conditions became true, so the mechanism fired and this file is
what it produces. If a fired tripwire could only ever produce a reversal, it would be a one-way
ratchet toward codegen rather than a reopening, and nobody would set one honestly.

---

## Context

ADR 0001 chose the hand-written client on a six-row rubric and then, unusually, wrote down what
would make it wrong. Verbatim:

> **The supersede threshold — what makes this reversible on evidence, not on taste.** This ADR is
> superseded by a **new** ADR, never edited, if any of these becomes true:
>
> - the hand-written client passes **600 lines** in `app/lib/api/` excluding tests, or
> - the endpoint count passes **15**, or
> - the contract adopts response polymorphism (`oneOf` / `discriminator`), […] or
> - authentication, pagination or error envelopes […] turn out to need more hand-written machinery
>   than the endpoints themselves.

`docs/solid/network-edge.md` measured all four on 2026-08-27 against `main` at `653a17b` and
reported two met. Its numbers are the input to this ADR. They were re-measured today rather than
quoted, and one of them does not reproduce.

### The threshold, re-measured

`main` at `7e70214`, 2026-08-28. Every figure below is produced by a command in *Evidence*.

| # | Trigger | Audit, 2026-08-27 | Re-measured, 2026-08-28 | Met? |
|---|---|---|---|---|
| 1 | `app/lib/api/` passes **600 lines**, excluding tests | 1942 raw · 1036 code | **1944 raw · 1236 code**, ten files | **YES — 3.2× raw, 2.1× code** |
| 2 | The endpoint count passes **15** | 14 HTTP operations | **7 called · 8 modelled · 14 spoken · 15 by a fourth arithmetic** | **the trigger is underdetermined — resolved below** |
| 3 | The contract adopts response polymorphism | absent | **absent** — `grep -nE '"(oneOf\|anyOf\|discriminator)"' contract/openapi.json` exits 1 | no |
| 4 | Envelopes cost more than the endpoints | 506 : 246 = 2.1 : 1 | **508 : 245 = 2.07 : 1** | **YES** |

**Trigger 1 reproduces on the raw count and not on the code count.** The two-line raw difference is
explained: the only change to `app/lib/api/` since `653a17b` is `c5a743a`, five comment lines
replacing three in `history.dart`. The code count is another matter — the audit reported 1036 and
the same method gives **1236**, with the per-file figures the audit quoted elsewhere reproducing
exactly (`me_result.dart` at 226, `_Answer` at 75, the seven request bodies at 126). The audit's
total appears to be an arithmetic slip in a sum, not a method difference. **1236 is the number that
goes in.** It changes no verdict — both are past 600, and so is either number after any refactor
available (below) — but a figure quoted forward from a document is a figure nobody re-derives, and
this one would have been quoted forward.

**Trigger 4 reproduces within two lines.** The audit's envelope figure of 506 is 508 by the same
declaration ranges (its `api_client.dart` sub-total of 174 measures 176 here, a boundary
difference); its endpoint figure of 246 is 245. The ratio is unmoved.

### What the threshold cannot tell you, and this is the whole difficulty

**Two triggers fired and neither of them argues for a generator.** ADR 0001 decided on six rubric
rows. Five were about correctness and dependency surface — the analyzer gate, optional-versus-
nullable fidelity, the opaque slot, unknown-enum absorption and missing-required-array defaulting,
and fourteen net-new runtime packages. Exactly one was about size, and **that row favoured the
hand-written client**: 364 lines against the generated 1174, *"3.2×"*.

Three of the four triggers measure size. So the tripwire, when it fires, fires on the one axis
where hand-writing was already winning, and produces no evidence about the five axes the decision
actually rested on. That is a defect in the tripwire's design. It is not a reason to switch, and —
stated because it is the tempting move — it is not a reason to write 2000 where 600 was written
either. A number chosen to be un-hit is a tripwire deleted with extra steps.

The one trigger 0001 named as *"where hand-writing genuinely stops paying"* — response
polymorphism — is clean, and `ARCHITECTURE.md` §2 still forbids it.

---

## Decision

**The client stays hand-written.** Three questions were costed; two were rejected with reasons, and
they are recorded because a decision whose alternatives are not costed is a preference.

### 1 · Adopt a generator — rejected, and the objections were re-verified rather than remembered

ADR 0001 is twelve days old and rested on `swagger_dart_code_generator` **4.1.1**. Twelve days is
short enough that nothing should have moved and long enough that assuming it is a habit worth not
having — the obvious way for this ADR to be wrong is for the package to have fixed the defects. It
has not, and that is checkable rather than assumed:

**4.1.1 is still the latest published version.** `pub.dev`'s API reports `latest.version` as
`4.1.1`, published **2025-12-11** — before the spike measured it, and nothing has shipped in the
eight and a half months since. The version 0001 rejected is the version on offer today.

The four correctness objections were re-read in the cached 4.1.1 source, not inferred from the
changelog:

- **`// ignore_for_file: type=lint`** is emitted by the generator itself
  (`lib/swagger_dart_code_generator.dart:371,390`, `swagger_enums_generator.dart:96`), so the
  generated tree opts out of the lint set and "it analyzes clean" remains true by construction and
  worth nothing.
- **`swaggerGeneratedUnknown(null)`** is still the synthetic enum member
  (`swagger_enums_generator.dart:22`, `enum_model.dart:59`), and the parse still ends
  `?? enums.$name.swaggerGeneratedUnknown` (`enum_model.dart:132`) — an unrecognised wire value is
  absorbed, not surfaced.
- **`defaultValue: <$typeName>[]`** is still written into the `@JsonKey` of a required array
  (`swagger_models_generator.dart:1255`) — a missing required field silently becomes an empty list.
- **Optional and nullable are still one Dart shape, and the reading is worse than 0001 recorded.**
  0001 reported the collapse as a `toJson` that emits `"skillId": null`. The mechanism is
  structural: `include_if_null` is a **global build option**
  (`generator_options.dart:72`, applied through `generateIncludeIfNullString()` at every one of the
  eight `@JsonKey` emission sites), so it takes one value for every property in the document. There
  is no setting that keeps an absent optional absent *and* keeps a required-and-nullable field
  present as `null`. Leaving it unset emits `"skillId": null`; setting it `false` drops
  `"expiresAt": null`, which `contract/openapi.json` marks required. **The distinction is not
  representable**, rather than defaulted the wrong way.

The dependency arithmetic is unchanged: 14 net-new runtime packages against `app/`'s floor. To be
precise about the weight this carries — 0001 says plainly *"DEP-1 disqualifies neither"* and
*"nothing in either option phones home"*, and that is still true. What the audience clause in
`CLAUDE.md` makes architectural is not a prohibition but an obligation: **every one of those
fourteen is a package somebody has to audit for phoning home, unconditionally, on every version
bump, for the life of the product.** Fourteen recurring audits bought in exchange for a smaller
directory is a bad trade at any line count, and the line count is what fired.

### 2 · Keep hand-writing and factor the envelope — a good change, and *not* the remedy

`docs/solid/network-edge.md` finding 3 is right on its own terms and should land: `api_client.dart`
re-derives the error envelope seven times where `auth_client.dart` factored it once into `_send` +
`_Answer`, and the duplication is exact and countable — seven copies of the `_errorOr` hoist, the
`switch (status)`, the bearer-header block, the close-with-timeout, the body decode and the
`on Exception` arm, and six of the `message` hoist and the `on FormatException` arm.

Where it is wrong is in one inference. The audit says finding 3 *"is also the one change that moves
ADR-0001's trigger 4 back below its line."* It is not, and the reason is in the finding's own
*Discarded* list: *"Nothing about the seven result unions has to change."* Take that at its word and
the envelope side has a **hard floor**, no estimate required:

| | code lines | moved by factoring? |
|---|---|---|
| `me_result.dart` — the seven sealed result unions | 226 | **no**, by the finding's own scope |
| `auth_result.dart` — the `AuthResult` union | 31 | **no**, same |
| **envelope floor** | **257** | |
| endpoint side, today | **245** | can only shrink |

**257 > 245.** Trigger 4 survives the maximal factoring, because what dominates the envelope side is
the *vocabulary of answers* — seven result unions that exist because a 404 on a pack means something
different from a 404 on a profile — and no de-duplication touches a single line of it. Under the
audit's own hostile classification, which files `me_result.dart` as domain types rather than
envelope machinery, factoring does clear the line. Which is the point: **trigger 4's answer depends
on a classification the trigger never specified.**

Trigger 1 is not moved either. The measured duplication is on the order of 160 code lines of 1236;
the directory lands somewhere near 1075 and stays roughly 1.8× past 600. The client is large because
it models eight contract shapes, seven result unions and a second server's auth flow — not because
it repeats itself, though it does.

So finding 3 lands on its merits, and this ADR neither waits for it nor is answered by it.

### 3 · Raise the threshold — rejected as an answer, accepted as a diagnosis

The number is not wrong by being too small. The *quantity* is wrong. Three independent reasons, each
measured above rather than asserted:

1. **Size is the axis where hand-writing already won** (0001's rubric row six), so a size trigger
   firing carries no information about the decision.
2. **Trigger 4 has no stable answer** — 2.07 : 1 or 1.15 : 1 depending on where one file is filed.
3. **Trigger 2 has four defensible arithmetics**, one of which lands exactly on the line.

A threshold that can be met three ways and read four ways is replaced, not re-tuned.

### 4 · Which endpoint count trigger 2 means — the question settled

The plain reading of *"the endpoint count passes 15"* is **what the client speaks: 14, one away.**
That reading is named first because it is the one a reader arrives with, and overriding it needs an
argument in the open. The four arithmetics, all defensible:

| count | what it counts |
|---|---|
| **7** | contract operations `ApiClient` calls — `getMe`, `linkPlayer`, `issuePack`, `fetchPack`, `submitAttempts`, `getHistory`, `eraseMe`. `CLAUDE.md`'s figure |
| **8** | contract operations `app/lib/api/` holds a model for — the seven plus `standing.dart` |
| **14** | HTTP operations the directory speaks — the seven plus `AuthClient`'s seven Neon Auth calls |
| **15** | the eight modelled plus the seven auth calls — **exactly the line** |

**Trigger 2 counts operations declared in `contract/openapi.json`.** Today that is **8 of the
contract's 9**, and the trigger is not met.

The argument is what the trigger is *for*. Every one of 0001's four conditions is a proxy for one
question — *has hand-writing stopped paying, relative to generating?* — and a generator generates
from a document. This repository commits exactly one: `contract/openapi.json`, nine operations,
emitted and byte-diffed in CI. **No OpenAPI document for the Neon Auth surface is committed here**,
so no generator could ever produce `auth_client.dart`. Counting those seven operations toward a
codegen tripwire means arriving at "adopt a generator" and then generating eight of fifteen, leaving
the client hand-written *and* adding a generator — the worst cell in the matrix, reached by
arithmetic.

The seam is visible in the test suite and not only in the argument. `app/test/api/contract_parity_test.dart`
reads `contract/openapi.json` from disk, throws at load if it is missing, and holds the models to
it. It is the only file under `app/test/` that opens that document. **Seven operations are
machine-checked against a committed specification and seven are held to nothing** — which is the
same line the codegen question falls along, drawn independently and for a different reason.

Note what this reading costs, stated rather than buried: trigger 2 becomes near-unreachable. The
contract must grow from nine operations to sixteen. That is the honest consequence of tying the
count to the document, and it is one more reason the replacement below does not keep a count at all.
It is also, for what it is worth, what `ARCHITECTURE.md` §2's original *"~250 lines for 12–15
endpoints"* was measuring — §2 is a section about `contract/openapi.json`, and 0001 quotes that
phrase as the estimate it is correcting.

### 5 · The threshold that replaces it

ADR 0001's four conditions are retired. This ADR is superseded by a **new** ADR, never edited, if
any of these becomes true:

- **`contract/openapi.json` adopts response polymorphism** (`oneOf` / `anyOf` / `discriminator`).
  This is 0001's third condition, carried over unchanged and unmet, and it is the only one of the
  four that named a mechanism rather than a size. `ARCHITECTURE.md` §2 forbids it today, so this
  trigger fires only after that rule is deliberately changed — which is the right moment to ask the
  question again.
- **A Dart generator exists whose output clears all four correctness objections**, checked against
  this repository's own contract and its own gate: it passes `flutter analyze --fatal-infos`
  unmodified and without opting itself out of the lint set; it keeps optional distinct from nullable
  *per field*; it surfaces an unrecognised enum value rather than absorbing it; and it fails on a
  missing required array rather than substituting an empty one. Any generator, not only
  `swagger_dart_code_generator` — the objections are the trigger, not the vendor.
- **A second consumer needs the same models.** One hand-written client is a cost paid once; two
  hand-copied ones are R2, and the argument changes shape entirely.

Each of those, if it fires, produces evidence that bears on the answer. None of them is a line
count. **The client's size is no longer a supersede condition** — deliberately, and with the
measurement that earned it: at 1236 code lines for eight contract operations, seven result unions
and a second server's auth flow, the hand-written client costs what ADR 0001 predicted it would
(*"the cost scales with type count, not endpoint count"*) and the generated equivalent would cost
3.2× more of it.

---

## Consequences

**Immediately:**

- **`docs/adr/0001-dart-api-client.md` gains a status line and a forward pointer, and nothing else.**
  0001 forbids being *edited* in the sense that matters — its findings, its rubric and its
  measurements are the record of what was measured on 2026-08-16 and stay verbatim. A pointer at the
  top saying which document now governs is the opposite of a revision: without it, a reader arriving
  at 0001 through `CLAUDE.md` or a code comment reads a live threshold that has already fired.
- **`CLAUDE.md`'s *Decided* paragraph is corrected in this change** rather than deferred. Its last
  sentence — *"The ADR carries a supersede threshold (600 lines, 15 endpoints, response
  polymorphism, or auth/pagination/error envelopes), so this reopens on evidence rather than on
  memory"* — describes a threshold that no longer exists. 0001 deferred its own governance edits to
  a consolidation session for a stated reason (three concurrent changes were touching the same
  files); no such reason applies here, and PROC-6 says a correction is written down in the session
  that finds it. `ARCHITECTURE.md` §2 needs nothing: it records that the client is committed and not
  generated, which is still true.
- **No code changed.** `app/lib/api/` was read and measured and not touched.

**What this unblocks, which is the practical half:**

- **`docs/solid/network-edge.md` finding 5 is free to be fixed.** That finding — `standing.dart`
  parses `GET /me/standing` and no method fetches it — noted that wiring the eighth operation *"takes
  the HTTP count to 15 and trips ADR-0001's trigger 2 as well, which is an argument for sequencing it
  after the successor ADR rather than before it."* Under §4 above it does not: the count that matters
  is contract operations, wiring `getStanding` takes it from 8 to 9 of 9, and no trigger fires. The
  sequencing constraint is discharged, and finding 5's two options can be weighed on their own.
- **Findings 1, 2, 3, 4, 6 and 7 of that audit stand on their own merits** and are gated on nothing
  here. Finding 1 — an `AttemptSubmission` invariant enforced by an `assert` that release builds
  strip, on a path that ends in a deleted batch — is the one with a data-loss cost attached and is
  the one worth doing first. Finding 3 should land as a duplication fix, described as one, and not
  as a threshold remedy, because §2 above shows it is not one.

**What this does not decide.**

- **Nothing about the seven `AuthClient` operations.** Whether the Neon Auth surface should be
  described by a committed document at all — which would give it a parity gate like the contract's,
  and would also make it generatable — is a real question this ADR raises and does not answer.
  Raising it is the honest residue of §4: the reason those seven are excluded from the count is that
  no document describes them, and that is a fact about this repository rather than a law.
- **Nothing about a web build.** 0001's caveat holds — `dart:io`'s `HttpClient` has no web
  implementation, so the hand-written floor is 0 net-new packages on mobile and 1 on web. `app/web/`
  is still present and still unbuilt.

---

## Evidence

Every command below was run on 2026-08-28 against `main` at `7e70214`, macOS arm64, Flutter 3.41.8 /
Dart 3.11.5. Output is quoted, not paraphrased.

### 1. Trigger 1 — the line count

```console
$ find app/lib/api -name '*.dart' | sort | xargs wc -l
     434 app/lib/api/api_client.dart
     346 app/lib/api/auth_client.dart
     103 app/lib/api/auth_result.dart
      40 app/lib/api/endpoints.dart
     147 app/lib/api/history.dart
      60 app/lib/api/instant.dart
      78 app/lib/api/me.dart
     376 app/lib/api/me_result.dart
     156 app/lib/api/standing.dart
     204 app/lib/api/sync.dart
    1944 total

$ cat app/lib/api/*.dart | grep -v '^[[:space:]]*$' | grep -vE '^[[:space:]]*//' | wc -l
    1236
```

*Excluding tests* is satisfied by construction rather than by a filter — the client's tests live in
`app/test/api/`, outside the path walked.

The audit's raw figure was 1942 and the two-line difference is accounted for exactly:

```console
$ git log --oneline 653a17b..HEAD -- app/lib/api/
c5a743a docs: the comments and the documents catch up with the rating (#121)

$ git diff --stat 653a17b..HEAD -- app/lib/api/
 app/lib/api/history.dart | 8 +++++---
 1 file changed, 5 insertions(+), 3 deletions(-)
```

The diff is a doc comment and nothing else, so the **code** count at `653a17b` was also 1236 and the
audit's 1036 does not reproduce. Its per-file figures do, which is what localises the discrepancy to
a sum rather than to a method.

### 2. Trigger 2 — the four counts

```console
$ grep -cE '^[[:space:]]*(Future|Stream)' app/lib/api/api_client.dart
7

$ grep -cE '^[[:space:]]*Future<AuthResult' app/lib/api/auth_client.dart
14                                 # 7 on the AuthApi interface, 7 implementing them

$ grep -c '"operationId"' contract/openapi.json
9

$ grep -rn 'getStanding' app/lib/
                                   # no output, exit 1 — modelled, never called

$ grep -rln 'openapi.json' app/test/
app/test/api/contract_parity_test.dart
```

Nine contract operations; eight modelled in `app/lib/api/`; seven called; seven more spoken to Neon
Auth. One parity gate, reading one document, covering the contract half only.

### 3. Trigger 3 — polymorphism

```console
$ grep -nE '"(oneOf|anyOf|discriminator)"' contract/openapi.json
                                   # no output, exit 1
```

### 4. Trigger 4 — envelope against endpoints

Non-blank, non-comment lines by declaration range, the audit's method.

| side | where | lines |
|---|---|---|
| envelope | `api_client.dart` — `_readIssue:135`, `_readFetchPack:190`, `_readSync:243`, `_readHistory:299`, `_readErase:346`, `_readLink:364`, `_read:388`, `_object:412`, `_errorOr:424` | 176 |
| envelope | `me_result.dart` — the seven sealed unions, whole file | 226 |
| envelope | `auth_client.dart` — `_Answer`, `263-346` | 75 |
| envelope | `auth_result.dart` — the `AuthResult` union, `62-103` | 31 |
| | **envelope total** | **508** |
| endpoints | `api_client.dart` — the seven request bodies (`52`, `87`, `119`, `168`, `220`, `283`, `328`) | 126 |
| endpoints | `auth_client.dart` — the seven operations, `82-216` | 80 |
| endpoints | `auth_client.dart` — `_send` / `_post` / `_get`, `217-262` | 39 |
| | **endpoint total** | **245** |

**508 : 245 = 2.07 : 1.** Hostile classification, `me_result.dart` filed as domain types: 282 : 245
= 1.15 : 1, still above one.

The duplication behind it, counted exactly. Each row is `grep -c '<pattern>'
app/lib/api/api_client.dart`, a file holding **seven** operations:

| pattern | copies |
|---|---|
| `final Map<String, Object?> error = _errorOr(body);` | 7 |
| `final String message = error['message'] as String? ?? '';` | 6 |
| `switch (status) {` | 7 |
| `tag: error['error'] as String? ?? 'unauthenticated',` | 7 |
| `request.headers.set(HttpHeaders.authorizationHeader` | 7 |
| `acceptHeader` | 7 |
| `await request.close().timeout(timeout)` | 7 |
| `await response.transform(utf8.decoder).join()` | 7 |
| `on Exception catch (cause)` | 7 |
| `on FormatException catch (cause)` | 6 |
| `accessToken.trim().isNotEmpty` | 7 |

The two sixes are two different things, and only one of them is a hole. `_readErase` has no
`on FormatException` because a 204 has no body to parse — legitimately absent. `_read` has no
hoisted `message` because it computes `_errorOr(body)` twice, once inside its 401 arm and once in
its `default` — which is the audit's observation that the sixth copy has already begun to diverge
from the other six.

### 5. The generator, verified rather than assumed

**This is the check that could have overturned the ADR, and it was reachable.** The package registry
answered, so nothing here rests on a vendor claim or on memory of the 2026-08-16 spike:

```console
$ curl -s https://pub.dev/api/packages/swagger_dart_code_generator | python3 -c \
    "import json,sys; d=json.load(sys.stdin); print('latest:', d['latest']['version'], \
     d['latest']['published']); vs=d['versions']; print('versions:', len(vs)); \
     print('newest three:', [(v['version'], v['published']) for v in vs[-3:]])"
latest: 4.1.1 2025-12-11T14:24:24.546096Z
versions: 222
newest three: [('4.0.2', '2025-09-29T20:35:50.182415Z'),
               ('4.1.0', '2025-11-06T11:34:05.997451Z'),
               ('4.1.1', '2025-12-11T14:24:24.546096Z')]
```

4.1.1 is the version ADR 0001 measured and the latest published today. The four objections, re-read
in the cached source at `~/.pub-cache/hosted/pub.dev/swagger_dart_code_generator-4.1.1/`:

```console
$ grep -rn "swaggerGeneratedUnknown" lib/
lib/src/code_generators/swagger_enums_generator.dart:22:  static const String defaultEnumValueName = 'swaggerGeneratedUnknown';
lib/src/code_generators/enum_model.dart:59:swaggerGeneratedUnknown(null),
lib/src/code_generators/enum_model.dart:132:${enumParse(true)} ?? enums.$name.swaggerGeneratedUnknown;

$ grep -rn "defaultValue: <" lib/src/code_generators/swagger_models_generator.dart
lib/src/code_generators/swagger_models_generator.dart:1255:            "@JsonKey(name: '$validatedPropertyKey'$includeIfNullString, defaultValue: <$typeName>[])\n";

$ grep -rn "ignore_for_file" lib/ | head -3
lib/swagger_dart_code_generator.dart:371:// ignore_for_file: type=lint
lib/swagger_dart_code_generator.dart:390:// ignore_for_file: type=lint
lib/src/code_generators/swagger_enums_generator.dart:96:// ignore_for_file: type=lint

$ grep -rn "includeIfNull" lib/src/ | head -6
lib/src/models/generator_options.dart:24:    this.includeIfNull,
lib/src/models/generator_options.dart:72:  final bool? includeIfNull;
lib/src/models/generator_options.g.dart:53:  includeIfNull: json['include_if_null'] as bool?,
lib/src/models/generator_options.g.dart:154:  'include_if_null': instance.includeIfNull,
lib/src/code_generators/swagger_models_generator.dart:470:    if (options.includeIfNull == null) {
lib/src/code_generators/swagger_models_generator.dart:474:    return ', includeIfNull: ${options.includeIfNull}';

$ grep -c 'generateIncludeIfNullString()' \
    lib/src/code_generators/swagger_models_generator.dart
9                                  # one definition at :469, eight call sites
```

The last of those is the finding 0001 did not have: `include_if_null` is one **document-wide**
switch threaded into every `@JsonKey` emission site, so optional-versus-nullable is not a default
set wrongly — it is a distinction the generator has no place to put.

**What was not verified, and it matters:** the generated output was not regenerated and re-analyzed
today. The scaffold 0001 built was deleted, `contract/openapi.json` is a different and larger
document than the spike's three schemas, and rebuilding it would mean installing `build_runner` and
four dev dependencies to re-answer a question the source already answers. What is claimed here is
narrow and matches what was checked: **the code paths that produce the four defects are present in
the current published version.** Whether they fire on every schema in `contract/openapi.json`
specifically was not measured, and nobody should read this section as broader than that.

### 6. The committed suite

No code under test was changed by this ADR, so **Tier 1 is unchanged rather than passed**, and this
change reaches **no evidence tier** — Tier 1b has no logic to falsify and Tier 2 has nothing to
exercise. That is the honest outcome, not a skipped step, and it is the same one ADR 0001's
*Evidence* §2 records for its own documentation-only change.
