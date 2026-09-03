# SOLID audit — the network edge and the identity

**Scope:** `app/lib/api/`, `app/lib/features/auth/`, `app/lib/features/account/`,
`app/lib/features/sync/`, `app/lib/demo/`.
**Base:** `main` at `653a17b`, 2026-08-27. Documentation only — no production code was changed.

> **Superseded in one part, 2026-09-02.** `app/lib/demo/` **no longer exists**, so this audit's
> scope line and its *"`demo_figures.dart` is not dead"* finding below are a record of what was
> true at that base and not of the tree today. The finding was correct then and the reason it
> stopped being correct is that the switch it rested on did not work: three of the four readers sat
> behind `DemoFigures.enabled` and `series_summary_screen.dart`'s `_ratingTile()` did not, so a
> build with the switch off still printed an invented `+ 12 RATING`. The quarantine was deleted
> rather than flipped (`fix-only-what-the-product-can-prove`), the three screens draw only measured
> figures, and `app/test/design/only_what_it_can_prove_test.dart` is what holds them there. The rest
> of this document is untouched by that change.

---

## Verdict

**The modules are, with two exceptions, well separated and honestly documented — and ADR 0001 is
superseded on its own terms by two of its four triggers.** The pure/adapter split holds everywhere
the pure-boundary gate reaches: `sessionRestore`, `packRefresh`, `journalAfter`, `playerIdFrom` and
`CredentialRules` are each one decision made once in a module with no socket, and each names the
other two in its own doc comment so the family is legible from any member. The three things the
brief asked to be checked as suspicious came back clean: the `ApiClient`/`AuthClient` split is a
real seam and not an accident, the four-way failure vocabulary is *not* scattered across call
sites, and `demo_figures.dart` is **not** dead. What is not clean is one value type enforcing its
invariant with a mechanism the shipping build removes, and one of the two clients never factoring
the error envelope its sibling factored — which is also the measurement that reopens the ADR.

### ADR-0001 threshold, measured

The ADR is superseded by a **new** ADR — never edited — if any of four conditions becomes true.
All four, measured today:

| # | Trigger | Measured | Met? |
|---|---|---|---|
| 1 | `app/lib/api/` passes **600 lines**, excluding tests | **1942** raw · **1036** non-blank non-comment | **YES — 3.2×** |
| 2 | The endpoint count passes **15** | **14** HTTP operations | no — one away |
| 3 | The contract adopts response polymorphism (`oneOf`/`discriminator`) | **absent** — `grep -nE '"(oneOf\|anyOf\|discriminator)"' contract/openapi.json` returns nothing | no |
| 4 | **auth, pagination or error envelopes** need more hand-written machinery than the endpoints | envelope **506** code lines vs endpoints **246** — **2.1 : 1** | **YES** |

**Two of four. A new ADR is owed.**

**Trigger 1** — `find app/lib/api -name '*.dart' \| xargs wc -l` gives 1942 across ten files. The
ADR says *excluding tests*, and this excludes them by construction rather than by a filter: the
client's tests live in `app/test/api/`, outside the path walked. The sub-count excluding blanks,
`//` and `///` is 1036, quoted because the ADR's own baseline was recorded that way (*"364 lines
(279 code)"* for three endpoints). Both numbers are past 600; the ADR did not say which it meant,
and it does not matter here.

**Trigger 2 — the endpoint count, and the "seven" the brief asked about.** There are three
defensible counts and they are not in conflict once each is named:

- **7** — contract operations `ApiClient` actually calls: `getMe`, `linkPlayer`, `issuePack`,
  `fetchPack`, `submitAttempts`, `getHistory`, `eraseMe`. This is CLAUDE.md:69's figure and it is
  correct.
- **8** — contract operations `app/lib/api/` holds a model for. `standing.dart` parses
  `GET /me/standing` and no method fetches it (finding 5).
- **14** — HTTP operations the hand-written client speaks, which is what the ADR's threshold
  counts: the 7 above plus `AuthClient`'s `signUp`, `sendVerificationCode`, `verifyEmail`,
  `signIn`, `sendPasswordReset`, `resetPassword`, `accessToken`.

The brief's premise that CLAUDE.md contradicts itself here does not hold: *"seven of the contract's
operations"* (CLAUDE.md:69) is about the client, and *"`POST /packs` is the ninth operation"*
(CLAUDE.md:346) is about the **server's** nine contracted operations — `contract/openapi.json`
declares exactly nine paths and the server answers eight. Two true statements about two different
things. The count that is genuinely under-reported is 14, because nothing in the governance
documents counts the Neon Auth half as client surface, and the ADR's threshold does.

**Trigger 4 — the measurement, with its method.** Envelope machinery = the seven `_read*`
dispatchers plus `_object`/`_errorOr` in `api_client.dart` (174), `me_result.dart`'s seven sealed
unions (226), `AuthClient._Answer` (75), and `auth_result.dart`'s `AuthResult` union (31) = **506**.
Endpoint machinery = the seven request-issuing bodies in `api_client.dart` (126), `AuthClient`'s
seven operations (81), and `_send`/`_post`/`_get` (39) = **246**. Non-blank, non-comment lines,
by declaration range.

**The trigger survives the most hostile classification available.** The one arguable step is
counting `me_result.dart`'s 226 lines as envelope machinery rather than as domain types. Drop that
file from the envelope side entirely and the ratio is still **280 : 246** — above one, and so still
"more machinery than the endpoints themselves". Nothing about trigger 4 rests on where that file is
filed.

Reading the two together: **auth and error envelopes cost twice what the endpoints cost.** That is
the shape the spike explicitly did not cover — *"authentication flows, pagination, or error
envelopes … If any of those three turns out to be where the hand-written client hurts, this
decision is revisitable on evidence rather than on memory"* — and it is now measured rather than
remembered. Trigger 3 stays clean, which matters: the ADR named polymorphism as *"where
hand-writing genuinely stops paying"*, and the contract has none. So the successor ADR is not
obviously a vote for codegen. It is a decision to be taken with these numbers in hand, and finding
3 below is the cheapest thing that moves trigger 4 back the other way.

---

## Findings, highest cost first

### 1 · A value type enforces its invariant with a mechanism release builds delete

**Principle:** the invariant is in the right *place* — a value type refusing to be built wrong is
exactly right, and the same construction the repo already uses for `Verdict` carrying no colour and
the server's `NoContent` being a separate type from `Response`. It is the *mechanism* that is
wrong. `assert` is a debug-only construct; `flutter build --release` strips it, so the guarantee
holds in every test and in no shipping build.

**Where:** `app/lib/api/sync.dart:55-67`

```dart
AttemptSubmission({
  this.itemId,
  this.packRef,
  ...
}) : assert(
        (itemId == null) != (packRef == null),
        'an attempt names exactly one source: itemId or packRef',
      ),
```

and the claim it is meant to support, `app/lib/api/sync.dart:49-52`: *"Neither and both are a 400,
and the constructor refuses to build either, so a malformed batch cannot leave the device and come
back as an error a player waits for."* In a release build the constructor refuses nothing.

**Cost.** The failure path is fully wired and ends in data loss. A release build constructs a
submission naming both sources or neither → the server's `attempts_one_source` mirror refuses the
batch with **400** → `_readSync` maps it to `SyncMalformed` (`api_client.dart:261-262`) →
`journalAfter` puts `SyncMalformed()` in the `landed` arm (`attempt_journal.dart:162`) → the whole
batch is deleted from the journal. The comment's own worst case is *"an error a player waits for"*;
the actual worst case is that up to two hundred answers are erased with nothing on screen and
nothing in a log. **Latent today** — both production construction sites
(`attempt_sync.dart:115`, `attempt_journal.dart:70`) pass `packRef` and never `itemId`, so nothing
can currently reach it. That is what makes it a finding rather than a bug: the type advertises a
guarantee the shipping build does not have, and the first caller of the `itemId` half — the one
`GET /items/next` needs, which is the one contracted operation still unbuilt — inherits it.

**Direction.** Make both-and-neither unrepresentable rather than asserted: two named constructors,
`AttemptSubmission.forPackItem({required PackRef ref, …})` and
`AttemptSubmission.forIssuedItem({required String itemId, …})`, each setting the other field to
null itself. The generative constructor goes private. Same total lines, and the invariant becomes
a compile error instead of a debug-only throw.

---

### 2 · Two definitions of how a journalled attempt becomes a wire submission, and the tested one is not the one that ships

**Principle:** SRP, read as *who asks for the change*. The frozen `AttemptSubmission` schema is the
one that asks, and it would have to ask twice.

**Where:** `app/lib/features/sync/policy/attempt_journal.dart:70-77` defines
`JournalledAttempt.toSubmission()`. It has **zero production callers** — `grep -rn toSubmission
lib/ test/` returns the definition and two tests. The shipping path,
`app/lib/features/sync/attempt_sync.dart:113-121`, builds the identical object inline inside
`flush`'s batch comprehension.

**Cost.** Two things, and the second is worse. First, a schema change is a two-site edit that looks
like a one-site edit, because the search hit that matters is buried in a list literal. Second,
`app/test/features/sync/policy/attempt_journal_test.dart:57` —
`expect(at(0).toSubmission().toJson().containsKey('ok'), isFalse)` — is the test that pins
CLAUDE.md's *"the answer never travels online"* invariant at the client edge, and it pins it on the
method the app does not call. Invert the shipping construction and that test stays green. Under
PROC-11 that is a gate that cannot fail on the path it exists to guard.

**Direction.** One line: `for (final JournalledAttempt held in sending) held.toSubmission()`. The
policy module already owns the mapping and is already tested for it; the adapter should ask it
rather than repeat it.

---

### 3 · `api_client.dart` re-derives the error envelope once per operation, and its sibling file does not

**Principle:** SRP again by the same reading. There is one thing that asks these seven functions to
change — the frozen `Error` shape `{error, message}` and the status vocabulary around it — and it
has to ask seven times. `auth_client.dart` is the counter-example sitting in the same directory,
which is what makes this a finding rather than an aesthetic preference.

**Where:** seven near-identical dispatchers in `app/lib/api/api_client.dart` —
`_readIssue:135`, `_readFetchPack:190`, `_readSync:243`, `_readHistory:299`, `_readErase:346`,
`_readLink:364`, `_read:388` — each opening with the same two lines (`_errorOr(body)`, then
`message`), each carrying its own `401 → …Rejected(tag: error['error'] as String? ?? 'unauthenticated', message: …)`
arm, its own `default → …Failed(status:, reason: message.isEmpty ? body : message)` arm, and its
own `try/on FormatException → …Failed`. Against `app/lib/api/auth_client.dart:223-257` (`_send`,
one transport path) and `:263-346` (`_Answer` with `map<T>`, `mapSession` and one `_early<T>`
holding the whole status vocabulary once).

The same asymmetry runs through the request half: the four lines that set the bearer header,
`Accept`, close the request with a timeout and decode the body are written out seven times in
`api_client.dart:52-344`, and once in `auth_client.dart:_send`.

**Cost.** Measured above: 174 code lines of envelope-reading against 126 of request-issuing in one
file — the reading of an answer costs more than the asking. Concretely, adding a contracted error
tag, or changing what a `429` means, or draining a body differently, is a seven-site edit where six
sites are copies and one has already drifted: `_read` (`:388-410`) computes `_errorOr(body)` inside
its 401 case and again in its `default`, where the other six hoist it. Behaviourally identical
today; structurally it is the sixth copy diverging from the other six, which is how the seventh
comes out wrong.

**Direction.** The shape is already on disk two files away. Lift `_Answer` — status, text, an
`unreachableReason`, and a lazily decoded body — into a small shared type, give it one
`map<T>({required T Function(Map) onOk, …})`, and let each operation supply only the arms that are
genuinely its own: `SyncMalformed` on 400, `FetchPackGone` on 404, `EraseDone` on 204. Nothing about
the seven result unions has to change (see *Discarded*). This is also the one change that moves
ADR-0001's trigger 4 back below its line.

---

### 4 · A pure decision — which sentence a failure gets — lives inside a `StatefulWidget`, and is already three copies

**Principle:** PURE-1, which this repository enforces with a red build wherever the decision sits
under a `policy/` root. `features/auth/policy/` exists, has three modules in it, and is covered by
`pure_boundary_test.dart`. This decision is not in it.

**Where:** `app/lib/features/auth/ui/auth_flow.dart:483-490` — `_explain`, a total pure function
from `AuthResult` to `String?`. Its two invented sentences are written a second time twelve and
seventeen lines above it, at `:458` (`'Algo falló de nuestro lado. Inténtalo otra vez.'`) and
`:463` (`'Sin conexión. Revisa tu internet.'`), inside `_bandTheServerAlreadyHas`'s switch over
`MeResult` — a second, hand-copied translation of the same four outcomes for a different result
type. A third spelling of the first sentence, without its second half, is at
`app/lib/features/preferences/policy/erasure.dart:132`.

**Cost.** The es-MX copy on the account flow's error path cannot be exercised without pumping a
widget, so the one thing a reviewer would want to check by reading — that the four outcomes each
get the right register, and that "no conexión" never reads as the player's fault — is checked
through a `testWidgets`. And a copy edit lands on one of three sites: the two in this file are
eight lines apart and already differ in nothing, which is exactly the state a divergence starts
from. `erasure.dart` shows what the intended arrangement looks like — the copy is in a pure policy
module, keyed by a closed enum.

**Direction.** Move `_explain` to `features/auth/policy/`, keyed on the same four `AuthResult` arms,
and have `_bandTheServerAlreadyHas`'s `MeRejected`/`MeFailed`/`MeUnreachable` cases read from it
rather than restate it. `AuthResult` is already in `auth_result.dart`, which imports no `dart:io`
precisely so a pure module may switch on it — the seam this needs is the one that file was split
out to create.

---

### 5 · `standing.dart` parses an answer nothing asks for

**Principle:** not, strictly, a SOLID violation — it is a capability the directory advertises and
does not have. Reported here because the cost is real and because it is one of the three counts in
the threshold above.

**Where:** `app/lib/api/standing.dart:1-156` — `Standing`, `SkillStanding`, `fromJson`, `toJson`,
`isUnrated`, all tested by `app/test/api/standing_test.dart`. `ApiClient` has no `getStanding`,
`me_result.dart` has no `StandingResult`, and `grep -rn getStanding lib/` returns nothing.
`GET /me/standing` is implemented on the server (CLAUDE.md:292) and reachable from no line of Dart.

**Cost.** It reads as wired from three directions at once. The model is complete and tested; the
parity test names it — `app/test/api/contract_parity_test.dart:242-255`, *"the operation is one the
contract describes, and no longer unbuilt"* — which asserts a fact about `contract/openapi.json`
and nothing about the client, so a grep for the operation returns a green test; and
`features/profile/policy/profile_readout.dart:23,53` discusses what `api/standing.dart` will and
will not do as though a call site existed. A screen author who wants a rating reads all three and
believes the figure is one request away. It is a request, a result union, a call site and a state
away.

**Direction.** Two honest options and no third. Wire the eighth operation — and note that doing so
takes the HTTP count to 15 and trips ADR-0001's trigger 2 as well, which is an argument for
sequencing it after the successor ADR rather than before it. Or delete the model and let it come
back with its caller, which is `demo_figures.dart`'s own stated rule (*"the day a real figure
arrives its caller stops reading this and the constant goes"*) applied in the other direction.

---

### 6 · `journalAfter`'s `landed` is `true` for a batch that did not land

**Principle:** NAM-1 — *identifiers are self-descriptive without their surrounding context*.

**Where:** `app/lib/features/sync/policy/attempt_journal.dart:160-167`

```dart
final bool landed = switch (result) {
  SyncDone() => true,
  SyncMalformed() => true,
  SyncNoSuchItem() => true,
  ...
```

**Cost.** The name asks *did the server record it?* and the switch answers *may we forget it?* —
opposite answers for two of the six arms, and the doc comment three lines above correctly explains
the second question while the identifier states the first. This is the single decision point the
brief asked to be verified as still one place, and it is: `journalAfter` (`:155-176`) is the only writer, the
switch is exhaustive over the sealed type, and `AttemptSync.flush` delegates to it without a second
opinion. The exposure is entirely in the next arm somebody adds. A seventh `SyncResult` case
answered by reading the identifier instead of the comment gets `false` where the intent was
"drop" — the direction that keeps an unsendable batch for ever — or `true` where the intent was
"keep", which deletes work. Finding 1's failure path runs straight through this line.

**Direction.** One word: `forget`, or `discardTheBatch`. `if (!landed) return journal;` becomes
`if (!forget) return journal;` and the switch reads as its own documentation.

---

### 7 · A doc comment says a credential never reaches the device; it has reached it since the wiring landed

**Principle:** CMT-2 — *a comment that states behaviour the code does not have is a defect.*

**Where:** `app/lib/features/account/policy/session.dart:44-53`, on `LinkedSession.provider`:
*"**Nullable, because today it does not arrive.** `auth_flow.dart` holds the `AuthSession` long
enough to call `accessToken(session)` and then drops it — `LinkedAccount` carries the token, the
band and the address and not the cookie — so every session the running app builds has none of this
and nothing is stored. The two one-line edits that change that are named in this change's report;
until they land, persistence is code that is right and unreached."*

Every clause of that is now false. `LinkedAccount.provider` is **required**
(`auth_flow.dart:23,34`), and both of `LinkedSession`'s producers pass it non-null —
`profile_route.dart:465-470` from the flow's own `account.provider`, and `StoredSession.linkedWith`
at `session.dart:117-122`, whose `provider` is non-nullable. Persistence is reached:
`root_scaffold.dart:171-176` writes `storable` on every session change.

**Cost.** The comment retires the one question a reader of this file most needs to answer — *is a
long-lived credential being written to disk?* It is, by `PrefsSessionStore`, in plain
`shared_preferences`, which is a deliberate and well-argued decision (`session_store.dart:56-64`)
that a reader of `session.dart` is told does not apply to them. The structural residue is smaller
but real: `storable`'s `provider == null` branch (`:63-65`) is unreachable, and the `provider!` on
`:65` exists to satisfy a null no producer can create.

**Direction.** Make `provider` required, delete the branch and the bang, and delete the comment —
CMT-2 says the comment is fixed with the code in the same commit. If a producer without a cookie is
genuinely foreseen, say which one; today there is none. **Costed honestly, this is not the one-line
edit it looks like**: 23 sites under `app/test/` construct a `LinkedSession` and none of them passes
`provider`, so requiring it is a test sweep. The stale comment is the defect either way and is one
line; the nullability is a separate, larger decision that the corrected comment should record.

---

## Verified clean

Four claims the brief asked to be checked, each of which came back the good way. Stated because
"this module is clean" is a conclusion, not an absence of one.

**The `ApiClient` / `AuthClient` split is a real seam, not an accident.** Two servers, two base
URLs (`Endpoints.apiBaseUrl` vs `authBaseUrl`), two authentication mechanisms (`Bearer` header vs
`Cookie`), two error envelopes (`{error, message}` vs `{code, message}`), and zero shared model
types. `_Answer` is private to `auth_client.dart` and correctly so — it decodes the provider's
envelope, not the contract's. Nothing in either file belongs in the other. The asymmetry between
them is *quality*, not overlap, and that is finding 3.

**The four-way failure vocabulary is one decision per place, not scattered — and the copy that
renders it is a separate question, answered less well.** Read this clause and finding 4 together:
what is *not* scattered is the **disposition** — drop, keep, forget, issue — which is decided once
per question in a pure module. What *is* duplicated is the **es-MX sentence** each outcome is shown
as, and that is finding 4. Two different things, and only the second has copies.

The brief's specific worry — that a previous *"refactor: split the auth result vocabulary out of
the client"* had drifted back — does not hold either, checked directly: `AuthOk`, `AuthRefused`,
`AuthFailed` and `AuthUnreachable` are declared in `auth_result.dart` and in no other file, and
`auth_client.dart` declares none of them. What sits in the client is `_early<T>()`
(`auth_client.dart:326-345`), which maps a status range onto one of those four types — translation,
which is PURE-2's job, and not a decision. The vocabulary is where the refactor put it. `journalAfter` (drop / keep, `attempt_journal.dart:155-176`), `sessionRestore`
(forget / keep / restored, `session_restore.dart:64-76`) and `packRefresh` (none / issue / fetch,
`pack_refresh.dart:38-54`) are three separate questions, each answered exactly once, each in a pure
module with no socket, and each doc comment names the other two as the same shape. No call site
re-decides any of them: `AttemptSync.flush` hands `journalAfter` the result and writes what comes
back; `RootScaffold._restoreTheStoredSession` switches on `sessionRestore`'s answer and adds
nothing. Collapsing the three into one type would be the finding, not the fix.

**`app/lib/demo/demo_figures.dart` is not dead.** Three live production readers —
`features/round/ui/summary/series_summary_screen.dart` (lines 168, 173, 257, 300, 383, 385),
`features/onboarding/ui/calibration_result_screen.dart` (104, 154) and
`features/onboarding/ui/save_progress_screen.dart` (110, 115) — plus three tests. #103's clean-up
was real and is recorded accurately in the file's own doc comment: the four figures `4.1 Perfil`
drew are gone, and the file names its remaining readers (`0.5`, `1.3`, `2.5`) one constant at a
time. The quarantine is still a true claim about the app, and `DemoFigures.enabled` is still the
one switch.

**`auth` and `account` are two modules, not one wearing two names.** The seam is the credential's
lifetime, and it holds: `features/auth/` is the *transaction* — seven provider calls, seven screens
and a step trail, ending the moment a `LinkedAccount` is handed over — and `features/account/` is
the *state* that outlives it, which is why it holds the two stores, the id minting and the restore
policy and no screen at all. Nothing in `account/` imports `features/auth/`; the coupling runs one
way through `api/auth_result.dart`, which is a model file both may hold. The three types that look
duplicated are three genuinely different lifetimes — `LinkedAccount` (what the flow produced),
`LinkedSession` (what is held in memory, token included) and `StoredSession` (what may touch disk,
token deliberately excluded so the shape cannot hold a JWT). That last split is the same
construction as the server's `NoContent` and it is worth keeping.

---

## Discarded as taste

Ten candidates were considered and dropped for want of a nameable cost. Listed so the same ground
is not re-walked:

1. **Collapsing the seven result unions in `me_result.dart` into one generic `ApiResult<T>`.** The
   file argues each separation and the arguments are right: the two 404s mean different things,
   a 204 has no body to parse, an empty history is a success. No cost beats that.
2. **A unifying `FailureDisposition { drop, keep, retry, dead }` enum** over the three decisions
   above. See *Verified clean* — each is asked once, and a shared enum would couple three
   independent questions.
3. **`journalWith`'s 200-entry eviction** as a second place an answer can be lost. It is, but it is
   a different question from "what survives a failed sync", and it is documented with its reason.
4. **`AttemptSubmission` asserting `!elapsed.isNegative` while `AttemptSync.record` clamps the same
   value** (`attempt_sync.dart:86`). Two answers to one invariant; no cost I can state.
5. **`_read<T>` duplicated verbatim** in `me.dart:28-34` and `standing.dart:19-25`. Seven lines, no
   behavioural coupling between the two models.
6. **`AuthFlow`'s 545 lines and seven-step state machine** as an SRP finding. Line count is not a
   finding, and the responsibilities genuinely co-vary with the flow. Only `_explain` separates
   cleanly, which is finding 4.
7. **`ApiClient` having no interface while `AuthApi` does** — a DIP finding on paper. Callers
   already inject the narrower seam (`whoAmI`, `submit`, the erasure closure), which is lighter than
   an interface and is the documented reason for it.
8. **`IssuedPack.pack` carried as an unparsed `Map<String, Object?>`.** Deliberate, documented, and
   the alternative is parsing the pack twice.
9. **`Endpoints` as a static holder** read straight from `String.fromEnvironment`. Const, with
   nothing to inject.
10. **`AuthApi` declaring no `close()`** while `AuthClient` has one, forcing `profile_route.dart` to
    hold the concrete type. Real asymmetry; the ownership comment covers it and nothing follows.

---

## Coverage

Read completely: all ten files of `app/lib/api/`; all five of `features/account/`; all five of
`features/sync/`; `features/auth/`'s three policy modules and `auth_flow.dart`; `demo_figures.dart`.
Read in the parts that bear on a finding: `features/auth/ui/`'s seven screens,
`features/profile/ui/profile_route.dart`, `features/shell/ui/root_scaffold.dart`,
`features/preferences/policy/erasure.dart`, `app/test/api/contract_parity_test.dart`,
`app/test/features/sync/policy/attempt_journal_test.dart`, `contract/openapi.json`. Governance read
in full: `CLAUDE.md`, `.claude/conventions/craftsmanship.md`, `docs/adr/0001-dart-api-client.md`.

Every line count in this document was produced by command in this session; no score is quoted from
memory. The threshold table's four rows are the four the ADR names and no others.

**Not covered, and deliberately:** the server half of every operation
(`packages/server/src/**` was not read), the seven auth screens as UI, and every test suite except
the four named above. No evidence tier was reached and none was available to reach: this change
runs no code and alters none. Tier 1 is unchanged rather than passed — the same honest outcome
ADR 0001's own *Evidence* §2 records for a documentation-only change.
