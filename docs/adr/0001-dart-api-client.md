# 1. The Dart API client is hand-written

**Status:** Accepted — 2026-08-16, produced by change `f0-dart-client-spike` (phase F0, Spike A).

This is the first ADR in this repository and mints the convention every later one follows: a
zero-padded four-digit sequence, a kebab-case subject, one decision per file, never renumbered.
The headings are Nygard's — *Status · Context · Decision · Consequences* — plus two this project
earns: **Evidence**, because `PROC-5` says a claim without its command output is not evidence, and
**Inputs**, because a spike whose scaffold is deleted must still be reproducible from its record.

---

## Context

`ARCHITECTURE.md` §2 left the Dart API client an explicit open fork, and `CLAUDE.md` carried it as
its only *Open decision*: **`swagger_dart_code_generator`** against **a hand-written client**.
`dart-dio` and `openapi-generator-cli` were already out of the option space for want of a JVM and
Docker; this spike re-proved that with the commands rather than repeating the claim, because the
obvious check reports the opposite of the truth on macOS (see *Evidence*, §1).

§2 also wrote the exit criterion, and it is asymmetric on purpose:

> *if the generated Dart for three representative schemas is not better than what you would write
> by hand, write it by hand.*

The burden of proof is therefore on codegen. A tie, an inconclusive result, or an expired timebox
all decide for the hand-written client.

The decision was blocking more than a directory layout. `ARCHITECTURE.md` §2 hangs the whole
contract chain on a CI job that runs the generator and asserts `git diff --exit-code` — a gate that
is only real if the generator is byte-stable across runs on the same input. Nobody had checked, and
a CI job asserting a property the tool does not have is worse than no job at all. `f1-contract-emitter`
declares this spike as an upstream and inherits both answers.

**Method.** Three representative schemas (chosen for shape coverage, §*Inputs*) → an OpenAPI 3.0.3
document → Dart, twice, from a cold cache. The hand-written client was written **first** and its
digest frozen before the generator was installed; writing it afterwards would mean writing it
against the generated output, which is not the comparison §2 asks for. All scaffolding lived
outside the working tree and was deleted; the repository's committed diff from this change is
documentation only.

---

## Decision

**The Dart API client in `app/lib/api/` is hand-written.** `swagger_dart_code_generator` is
rejected.

It follows the shape the hand-written baseline established: immutable model types with explicit
`fromJson`, a thin `AkiMathApi` translating calls to requests, and a narrow transport seam behind
which the socket lives. It is a **PURE-2 adapter** and holds no decisions — no retry policy, no
verdict interpretation, no offline-fallback rule, no canonicalization. Those are PURE-1 modules
elsewhere, and `CLAUDE.md`'s invariant that *the answer never travels online* is decided in policy,
never in the client.

`app/lib/api/` is an **F3** directory. This decision fixes its shape and writes nothing into it.

### The rubric, measured

`design.md`, Decision 6 fixed these six rows before any measurement was taken.

| Dimension | Hand-written | `swagger_dart_code_generator` 4.1.1 | Winner |
|---|---|---|---|
| `flutter analyze --fatal-infos`, zero infos | **clean**, 0 issues | **3 warnings** (`unused_import`); the files carry `// ignore_for_file: type=lint`, which silences lints but not warnings | **hand-written** |
| Optional vs nullable fidelity | distinct: `skillId` omitted from JSON, `expiresAt` emitted as `null` | **collapsed**; `toJson` emits `'skillId': null` unconditionally — a wire-shape defect, not a style complaint | **hand-written** |
| The opaque `payload` slot | `Map<String, Object?>`, unread | `Map<String, dynamic>` — survives typed, but `dynamic` makes every read unchecked | hand-written, narrowly |
| Byte determinism over two runs | n/a | **byte-identical across three cold runs** | **generated** |
| Dependency cost (runtime) | `meta` only — already in `app/pubspec.yaml`. **0 net-new** on mobile, **1** on web | `chopper` + `json_annotation` → a **16-package** runtime closure, **14 net-new** | **hand-written** |
| Readability / size for the same 3 endpoints | **364 lines** (279 code), 4 files | **1174 lines** (985 code), 7 files — **3.2×** | **hand-written** |

Codegen won exactly one row. Under an asymmetric criterion that is not close.

### The three findings that decided it

**1. The generated code does not pass this repository's enforced gate.** `flutter analyze
--fatal-infos` is not a preference here — `.claude/hooks/verify-gate.sh` runs it on every commit and
`.github/workflows/ci.yml` runs it on every push. The generated directory produces three
`unused_import` warnings. There are only two ways out, and both are permanent costs: exclude a
directory from the repository's own gate, or hand-patch generated files, which destroys the byte
determinism the gate in §2 depends on. Note also that the generated files open with
`// ignore_for_file: type=lint` — they opt themselves out of the entire lint set, so "the generated
code analyzes clean" would have been true by construction and worth nothing, the same failure mode
that makes `dart_code_linter` inadmissible as evidence in this project.

**2. A generated client is *not* a PURE-2 adapter by construction.** `design.md` asserted it was and
treated it as a cost of the hand-written option. **The reading disproves that**, and the correction
matters more than the original claim:

- every generated enum gains a synthetic `swaggerGeneratedUnknown` member bound to `@JsonValue(null)`,
  so an unrecognised wire value is silently absorbed instead of surfacing;
- every required array is annotated `defaultValue: <T>[]`, so a missing **required** field silently
  becomes an empty list — `prompt` and `templateRefs` both.

Silently absorbing an unknown value and silently substituting an empty list are *decisions*, taken
inside the adapter, invisibly, on data this app shows to children. The hand-written baseline fails
loudly on both: an unrecognised enum raises `FormatException`, and a missing required array raises a
`TypeError` from `json['prompt'] as List<dynamic>`. The second is a crash rather than a diagnosable
error and is worth improving in F3 — but a crash is recoverable engineering, whereas an empty
`prompt` list renders a blank problem to a child and looks like success. The generated option was
the one at risk on this axis, not the hand-written one.

**3. The dependency asymmetry is not close, though DEP-1 disqualifies neither.** Stated plainly
because the audit is what makes an option admissible at all (`DEP-1`), and it belongs on the record
even for the option that lost: **nothing in either option phones home.** `chopper` performs only the
requests the app asks for; `json_annotation` is annotations with no runtime behaviour; `http` is the
Dart team's transport; the four build-time packages have no runtime presence, and `build_daemon`'s
websocket is localhost-only. So this row is about surface area, not compliance: 14 net-new runtime
packages and 4 dev dependencies against a floor of zero, plus `build_runner` in every worktree and
~13–18 s of cold generation per build.

### What was *not* measured, and where the result stops

- **The generated client was analyzed and read, never executed.** The hand-written baseline ran 4/4
  tests. The verdict does not rest on that asymmetry — it rests on the analyzer gate, the fidelity
  defects and the dependency surface, all three of which are visible statically.
- **Determinism holds for one machine, one input, one version pair** — macOS arm64, Dart 3.11.5,
  `swagger_dart_code_generator` 4.1.1, three cold runs. CI runs `ubuntu-latest`; cross-platform byte
  stability was **not** tested. Nobody should read the result as broader than that.
- **Three schemas are three schemas.** They cover nested object arrays, enums, `date-time`, `byte`,
  an opaque `additionalProperties` slot, and the optional-versus-nullable distinction. They do
  **not** cover **authentication flows**, **pagination**, or **error envelopes**. If any of those
  three turns out to be where the hand-written client hurts, this decision is revisitable on
  evidence rather than on memory.
- **The OpenAPI document was hand-transcribed**, not emitted (see *Inputs*). A human transcriber
  writes a cleaner document than an emitter does, which **flatters the generator** — so this threat
  runs against the option that lost, and cannot have produced the verdict.

---

## Consequences

**Immediately:**

- `app/pubspec.yaml` gains **no** codegen dependency. `swagger_dart_code_generator`, `build_runner`,
  `json_serializable`, `json_annotation` and `chopper` are all out of the project's future. (§2 and
  `proposal.md` both named `dio` as the transport of the generated path; that is wrong on the
  measurement — 4.1.1 emits **chopper**.)
- **`.github/workflows/ci.yml` gains no `contract` job that runs a generator and diffs bytes.** Not
  because the generator is unstable — it proved byte-identical across three cold runs — but because
  the chosen path has **no generator to run**. The gate has nothing left to guard.
- `contract/openapi.json` is still emitted and still committed. It remains the cross-stack source of
  truth; what changes is that its Dart consumer is written by a person.
- `f1-contract-emitter` inherits both answers: its output feeds a hand-written client, and it owes CI
  no byte-diff job.

**On the record for `ARCHITECTURE.md` §2 (lines 121–138), which this ADR contradicts in two places:**

1. *"`contract/openapi.json` and the Dart client are committed; CI runs the generator and does
   `git diff --exit-code`"* — the Dart client is committed but **not generated**, so the CI clause
   describes a gate that will never exist.
2. *"~250 lines for 12–15 endpoints"* — **measured at 3.**  Three endpoints and seven types already
   cost **364 lines**, of which the models are 223 (61%). The cost scales with **type count, not
   endpoint count**, which the original estimate did not model. A realistic figure for the full
   surface is several hundred lines more than §2 assumes. This does not change the decision — the
   generated equivalent is 3.2× larger — but an estimate wrong by roughly 3× will be quoted back as
   a reason to reopen this, so it is corrected rather than left standing.

This ADR **records** both findings; the amendment to `ARCHITECTURE.md` §2 and the rewrite of
`CLAUDE.md`'s *Open decision* are applied by the session that consolidates the governance
documents, because three concurrent changes touch them (PROC-6).

**The supersede threshold — what makes this reversible on evidence, not on taste.** This ADR is
superseded by a **new** ADR, never edited, if any of these becomes true:

- the hand-written client passes **600 lines** in `app/lib/api/` excluding tests, or
- the endpoint count passes **15**, or
- the contract adopts response polymorphism (`oneOf` / `discriminator`), which `ARCHITECTURE.md` §2
  currently forbids and which is where hand-writing genuinely stops paying, or
- authentication, pagination or error envelopes — the three shapes this spike did not cover — turn
  out to need more hand-written machinery than the endpoints themselves.

---

## Evidence

Every command below was run on 2026-08-16, macOS arm64, Flutter 3.41.8 / Dart 3.11.5. Output is
quoted, not paraphrased.

### 1. The removed options, closed by command

`command -v java` **succeeds on a machine with no Java runtime** — macOS ships a 135 KB stub at
`/usr/bin/java`. It is not the check:

```console
$ command -v java
/usr/bin/java                      # exit 0 — the stub, not a runtime

$ java -version
The operation couldn't be completed. Unable to locate a Java Runtime.
Please visit http://www.java.com for information on installing Java.
                                   # exit 1

$ command -v docker
                                   # no output, exit 1
```

`dart-dio` and `openapi-generator-cli` stay out of the option space.

### 2. The committed suite, before and unchanged after

```console
$ cd app && flutter analyze --fatal-infos
No issues found! (ran in 1.2s)

$ cd app && flutter test
00:00 +34: All tests passed!

$ cd packages/server && npm run verify
 Test Files  1 passed (1)
      Tests  3 passed (3)
```

No code under test was changed by this spike, so **Tier 1 is unchanged rather than passed**, and
this change reaches **no evidence tier** — Tier 1b has no logic to falsify and Tier 2 has nothing to
exercise. That is the honest outcome, not a skipped step.

### 3. The hand-written baseline, frozen before the generator was installed

```console
$ cd $SPIKE/client && flutter analyze --fatal-infos
No issues found! (ran in 1.3s)

$ cd $SPIKE/client && flutter test
00:00 +4: All tests passed!

$ wc -l lib/akimath_api.dart lib/src/models.dart lib/src/transport.dart lib/src/api_client.dart
       6 lib/akimath_api.dart
     223 lib/src/models.dart
      55 lib/src/transport.dart
      80 lib/src/api_client.dart
     364 total

$ cd lib && find . -type f | sort | xargs shasum | shasum
acaad428338c6edf615df9746f6707617a1e5aad  -
```

Re-verified **after** the generated code had been read, proving the baseline was not rewritten
against it:

```console
$ cd $SPIKE/client/lib && find . -type f | sort | xargs shasum | shasum
acaad428338c6edf615df9746f6707617a1e5aad  -     # unchanged
```

### 4. Byte determinism — the gate `ARCHITECTURE.md` §2 depends on

`dart run build_runner clean` is **not** sufficient to force a cold run: it exited 0, printed
nothing, and left all seven outputs and `.dart_tool/build` in place. A comparison after it would
have reported determinism that was never measured. The cache and outputs were removed by hand
instead. (`--delete-conflicting-outputs` is also gone: *"W These options have been removed and were
ignored: --delete-conflicting-outputs"*.)

```console
$ rm -rf lib/generated .dart_tool/build && dart run build_runner build
Built with build_runner/aot in 13s; wrote 8 outputs.

$ diff -r $SPIKE/run1 lib/generated
                                   # no output, exit 0 — byte-identical
```

Three cold runs total, all byte-identical, the third after moving the generator to `dev_dependencies`.
**The generator is deterministic**; the gate would have been real. Scope: one machine, one input,
one version pair — CI's `ubuntu-latest` was not tested.

### 5. The generated code against the enforced gate

```console
$ cd $SPIKE/generated && flutter analyze --fatal-infos
warning • Unused import: 'package:collection/collection.dart' • lib/generated/akimath.enums.swagger.dart:5:8 • unused_import
warning • Unused import: 'package:json_annotation/json_annotation.dart' • lib/generated/akimath.swagger.dart:6:8 • unused_import
warning • Unused import: 'package:http/http.dart' • lib/generated/akimath.swagger.dart:15:8 • unused_import

3 issues found. (ran in 0.8s)
```

### 6. Fidelity, read from the generated source

Optional and nullable collapse into the same Dart shape, and serialization loses the distinction:

```dart
// lib/generated/akimath.swagger.dart — both optional and nullable become `T?`
this.skillId,          // optional on the wire: key absent
this.expiresAt,        // nullable on the wire: key present, value null

// lib/generated/akimath.swagger.g.dart — the distinction is gone on the way out
Map<String, dynamic> _$OfflinePackManifestToJson(OfflinePackManifest instance) =>
    <String, dynamic>{
  'skillId': instance.skillId,                       // emits `"skillId": null`
  'expiresAt': instance.expiresAt?.toIso8601String(),
};
```

Decisions taken silently inside the adapter:

```dart
// unknown wire values are absorbed, not surfaced
enum PromptTokenKind {
  @JsonValue(null)
  swaggerGeneratedUnknown(null),
  @JsonValue('operator')
  $operator('operator'),
  ...
}

// a missing *required* array silently becomes empty
@JsonKey(name: 'prompt', defaultValue: <PromptToken>[])
final List<PromptToken> prompt;
@JsonKey(name: 'templateRefs', defaultValue: <TemplateRef>[])
final List<TemplateRef> templateRefs;
```

Two further readability costs: the document's `operationId`s (`getNextItem`, `submitAttempt`,
`getOfflinePack`) are **discarded** in favour of path-derived names (`v1ItemsNextGet`,
`v1AttemptsPost`, `v1PacksPackIdGet`), and enum members are lower-cased (`digitswithminus` for wire
`digitsWithMinus`). Every method also returns `chopper.Response<T>` whose `body` is `T?`, so each
call site unwraps a nullable the contract said was required.

### 7. The DEP-1 audit

```console
$ cd $SPIKE/generated && dart pub deps   # runtime closure of chopper + json_annotation
runtime packages added: 16
async, chopper, collection, equatable, http, http_parser, json_annotation, logging,
meta, path, qs_dart, source_span, string_scanner, term_glyph, typed_data, web

$ cd $SPIKE/client && dart pub deps      # the hand-written baseline
dependencies:
- flutter 0.0.0
- meta 1.17.0
```

`meta` is already a runtime dependency of `app/` today, so the hand-written floor is **0 net-new
packages** — with one honest caveat: it reaches that floor through `dart:io`'s `HttpClient`, which
**does not exist on web**, and `app/web/` is present. A web build swaps the one transport class for
one over `package:http`, making the true floor **1** package if web stays a target. Against 14.

Network behaviour of every candidate, per DEP-1: `chopper` issues only the requests the caller asks
for and pulls `qs_dart` (query strings), `equatable`, `logging` (local); `json_annotation` is
annotations with no runtime behaviour; `http` is the Dart team's transport. `build_runner`,
`chopper_generator`, `json_serializable` and `swagger_dart_code_generator` are build-time only and
have no runtime presence; `build_daemon` opens a **localhost** websocket for the build daemon, not
an external one. **No candidate phones home.** Neither option is disqualified by DEP-1; the
difference between them is surface area.

### 8. Teardown

The scaffold lived at `$TMPDIR/akimath-spike-a/`, entirely outside the working tree, and was
deleted. **This change modified no file under `app/`, `packages/` or `contract/`** — its entire
committed footprint is this ADR. `app/pubspec.yaml` and `app/pubspec.lock` are byte-identical to
their pre-spike state.

Both checks below were captured at **12:58 on 2026-08-16** and are claims about *this change*, not
about the tree's later state:

```console
$ git diff --exit-code -- app packages contract                    # exit 0
$ git diff --exit-code -- app/pubspec.yaml app/pubspec.lock        # exit 0
```

**Do not re-run them as a verification of this ADR.** Other changes were being implemented in the
same working tree concurrently — `packages/contract/` and `app/test/architecture/` appeared at 12:49
and 12:55, and tracked files under `app/` were modified afterwards by those sessions. A later re-run
will exit non-zero for reasons that have nothing to do with this spike. The durable claim is the
footprint, verifiable from the diff of the commit that carries this file.

---

## Inputs

Embedded so the chain is reproducible after the scaffold is gone. These are **throwaway spike
inputs**, chosen for shape coverage — not the beginning of `packages/contract`, and they fix no
endpoint, path or field name.

Why these three (`design.md`, Decision 3): between them they exercise every shape the real 12–15
endpoints can produce under §2's zero-polymorphism rule — a nested array of objects and an enum
(schema 1); a request body, a `date-time`, a client-generated `sessionId` and the opaque `payload`
slot variance hides in (schema 2); an array of records in one field, a `byte` column, and the
optional/nullable pair that is invisible in the other two (schema 3).

### The three Zod schemas

Authored against `zod@4.4.3`; `npx tsc --noEmit` exits 0 with no output under `strict` and
`verbatimModuleSyntax`.

```ts
import { z } from 'zod';

// --- Schema 1: the item response (ARCHITECTURE.md:179, `options` removed) ---
export const PromptTokenSchema = z.object({
  kind: z.enum(['number', 'operator', 'blank', 'text']),
  text: z.string(),
});

export const ItemResponseSchema = z.object({
  itemId: z.uuid(),
  prompt: z.array(PromptTokenSchema),
  keypad: z.enum(['digits', 'digitsWithMinus', 'fraction']),
});

// --- Schema 2: the attempt submission and its verdict ---
export const AttemptSubmissionSchema = z.object({
  itemId: z.uuid(),
  sessionId: z.uuid(),
  answer: z.string(),
  clientTs: z.iso.datetime(),
});

export const VerdictSchema = z.object({
  itemId: z.uuid(),
  ok: z.boolean(),
  payload: z.record(z.string(), z.unknown()),
});

// --- Schema 3: the offline pack manifest (ARCHITECTURE.md:194-198) ---
export const TemplateRefSchema = z.object({
  templateId: z.string(),
  templateVersion: z.int(),
  seed: z.int(),
  ladderStep: z.int(),
});

export const OfflinePackManifestSchema = z.object({
  id: z.uuid(),
  playerId: z.uuid(),
  skillId: z.int().optional(),          // OPTIONAL: key absent
  templateRefs: z.array(TemplateRefSchema),
  packSalt: z.base64(),
  issuedAt: z.iso.datetime(),
  expiresAt: z.iso.datetime().nullable(), // NULLABLE: key present, value null
});
```

### The OpenAPI 3.0.3 document

**Hand-transcribed, not emitted** (`design.md`, Decision 4): Zod 4's `z.toJSONSchema` emits JSON
Schema 2020-12, which maps to OpenAPI 3.1, and §2 pins **3.0.3**. Choosing an emitter is
`f1-contract-emitter`'s decision, and making it here would have consumed the timebox. Transcription
was mechanical: `z.uuid()` → `{"type":"string","format":"uuid"}`, `z.iso.datetime()` →
`format: date-time`, `z.base64()` → `format: byte`, `z.record(z.string(), z.unknown())` →
`{"type":"object","additionalProperties":true}`, `.optional()` → omitted from `required`,
`.nullable()` → kept in `required` plus `"nullable": true`.

Verified: the `openapi` field reads `3.0.3`, and a grep for `oneOf`, `anyOf` and `discriminator`
returns nothing (exit 1) — §2's zero response polymorphism.

```json
{
  "openapi": "3.0.3",
  "info": {
    "title": "AkiMath spike API",
    "version": "0.0.0-spike",
    "description": "Three representative endpoints for f0-dart-client-spike. Not the real contract."
  },
  "servers": [{ "url": "https://api.example.invalid" }],
  "paths": {
    "/v1/items/next": {
      "get": {
        "operationId": "getNextItem",
        "summary": "Fetch the next item to solve",
        "parameters": [
          { "name": "sessionId", "in": "query", "required": true,
            "schema": { "type": "string", "format": "uuid" } }
        ],
        "responses": {
          "200": { "description": "The rendered prompt",
            "content": { "application/json": {
              "schema": { "$ref": "#/components/schemas/ItemResponse" } } } }
        }
      }
    },
    "/v1/attempts": {
      "post": {
        "operationId": "submitAttempt",
        "summary": "Submit an attempt and receive its verdict",
        "requestBody": { "required": true,
          "content": { "application/json": {
            "schema": { "$ref": "#/components/schemas/AttemptSubmission" } } } },
        "responses": {
          "200": { "description": "The verdict",
            "content": { "application/json": {
              "schema": { "$ref": "#/components/schemas/Verdict" } } } }
        }
      }
    },
    "/v1/packs/{packId}": {
      "get": {
        "operationId": "getOfflinePack",
        "summary": "Fetch one offline pack manifest",
        "parameters": [
          { "name": "packId", "in": "path", "required": true,
            "schema": { "type": "string", "format": "uuid" } }
        ],
        "responses": {
          "200": { "description": "The pack manifest",
            "content": { "application/json": {
              "schema": { "$ref": "#/components/schemas/OfflinePackManifest" } } } }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "PromptToken": {
        "type": "object",
        "required": ["kind", "text"],
        "properties": {
          "kind": { "type": "string", "enum": ["number", "operator", "blank", "text"] },
          "text": { "type": "string" }
        }
      },
      "ItemResponse": {
        "type": "object",
        "required": ["itemId", "prompt", "keypad"],
        "properties": {
          "itemId": { "type": "string", "format": "uuid" },
          "prompt": { "type": "array", "items": { "$ref": "#/components/schemas/PromptToken" } },
          "keypad": { "type": "string", "enum": ["digits", "digitsWithMinus", "fraction"] }
        }
      },
      "AttemptSubmission": {
        "type": "object",
        "required": ["itemId", "sessionId", "answer", "clientTs"],
        "properties": {
          "itemId": { "type": "string", "format": "uuid" },
          "sessionId": { "type": "string", "format": "uuid" },
          "answer": { "type": "string" },
          "clientTs": { "type": "string", "format": "date-time" }
        }
      },
      "Verdict": {
        "type": "object",
        "required": ["itemId", "ok", "payload"],
        "properties": {
          "itemId": { "type": "string", "format": "uuid" },
          "ok": { "type": "boolean" },
          "payload": { "type": "object", "additionalProperties": true,
            "description": "The opaque slot all response variance hides in (ARCHITECTURE.md section 2)." }
        }
      },
      "TemplateRef": {
        "type": "object",
        "required": ["templateId", "templateVersion", "seed", "ladderStep"],
        "properties": {
          "templateId": { "type": "string" },
          "templateVersion": { "type": "integer" },
          "seed": { "type": "integer" },
          "ladderStep": { "type": "integer" }
        }
      },
      "OfflinePackManifest": {
        "type": "object",
        "required": ["id", "playerId", "templateRefs", "packSalt", "issuedAt", "expiresAt"],
        "properties": {
          "id": { "type": "string", "format": "uuid" },
          "playerId": { "type": "string", "format": "uuid" },
          "skillId": { "type": "integer" },
          "templateRefs": { "type": "array", "items": { "$ref": "#/components/schemas/TemplateRef" } },
          "packSalt": { "type": "string", "format": "byte" },
          "issuedAt": { "type": "string", "format": "date-time" },
          "expiresAt": { "type": "string", "format": "date-time", "nullable": true }
        }
      }
    }
  }
}
```

### The hand-written baseline, in outline

Four files, 364 lines, reproduced here in the shape `app/lib/api/` should follow. The full source is
not embedded — it is the *shape* that is the decision, and F3 writes the real one against the real
contract.

```dart
// lib/src/transport.dart — the socket seam. Exists so the client is provable without a
// socket, and so a web build swaps one class rather than the client (dart:io has no web).
abstract class AkiMathTransport {
  Future<HttpResponseParts> send({
    required String method,
    required Uri url,
    String? jsonBody,
  });
}

// lib/src/api_client.dart — the adapter. Translates, decides nothing (PURE-2).
class AkiMathApi {
  const AkiMathApi({required this.baseUrl, required AkiMathTransport transport});

  Future<ItemResponse> getNextItem({required String sessionId});
  Future<Verdict> submitAttempt(AttemptSubmission submission);
  Future<OfflinePackManifest> getOfflinePack({required String packId});
}

// lib/src/models.dart — immutable, explicitly typed, unknown wire values rejected.
PromptTokenKind _promptTokenKindFromWire(String wire) {
  // ... exhaustive lookup
  throw FormatException('Unknown PromptToken kind: $wire');
}

// Optional and nullable stay distinct on the way out — the generated client loses this.
Map<String, dynamic> toJson() => <String, dynamic>{
  if (skillId != null) 'skillId': skillId,          // optional: key omitted
  'expiresAt': expiresAt?.toUtc().toIso8601String(), // nullable: key kept, value null
};
```

The `operator` wire value is a Dart built-in identifier; the baseline names it `operatorToken` and
keeps the wire mapping in one table, where the generator emits `$operator`.
