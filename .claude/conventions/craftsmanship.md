# AkiMath — Clean Code & Project Conventions

The reviewable rulebook for this repository. Every rule has a stable ID so a review can cite it
against a diff (`PURE-1`, `CMT-1`, …). One repo, two languages: rules apply to Dart under `app/`
and to TypeScript under `packages/` unless the rule says otherwise.

This book starts small on purpose. Thirty-one rule IDs — counting `FUN-1a` as the carve-out it
is rather than as a rule — every one of them describing code that is already on disk today, not
a pattern we hope to have. It grows by **PROC-6** and no other way.

`CLAUDE.md` at the repo root is the entry point for *how to work here*; this file is the *contract
the code must satisfy*. Where both cover the same ground this file is the detailed version — and if
they ever conflict, **CLAUDE.md wins and this file must be corrected in the same session** (PROC-6).
`ARCHITECTURE.md` holds the design decisions the rules point at.

Legend: **MUST** = a violation blocks the merge · **SHOULD** = raise it, the author decides ·
**NEVER** = hard prohibition.

---

## PURE — Pure policy, separated from the IO adapter

The one structural pattern the repo already commits to, on both sides of the stack:
`app/lib/design/brand/spec/` vs `app/lib/design/brand/brand_drawing_painter.dart`, and
`packages/server/src/routing.ts` vs `packages/server/src/adapters/http-server.ts`.

- **PURE-1** MUST: every decision — routing, grading, layout geometry, rating, canonicalization,
  what a drawing *is* — lives in a module that performs no IO: no `Canvas`, no `CustomPainter`, no
  widget, no `package:flutter/rendering.dart` or `/material.dart`, no socket, no filesystem, no
  `process.env`, no clock and no randomness. Value types that carry no IO are fine — outside its own
  pure siblings, `app/lib/design/brand/spec/` imports only `dart:ui show Offset, Radius, Rect, Color`
  and `package:meta`, and `routing.ts` imports only `./health.js`. The test
  that decides it: **if proving the decision correct requires faking a canvas, a socket, a clock or
  a seed, the decision is on the wrong side of the boundary.** `app/test/design/brand/aki_spec_test.dart`
  and `packages/server/test/routing.test.ts` both run with zero mocks; that is the bar.

- **PURE-2** MUST: the adapter that performs the IO holds no decisions — it translates and nothing
  else, and stays thin enough that nothing worth testing lives in it.

  ```dart
  // wrong — the adapter now owns a coordinate, so the artwork lives in two places
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(const Offset(68, 96), 16, _inkPaint());  // Aki's left eye
  }

  // right — the adapter walks the spec and knows no geometry of its own
  for (final BrandMark mark in drawing.marks) {
    switch (mark) { case InkDot(): _paintDot(canvas, mark); /* … */ }
  }
  ```

  Same shape on the server: `http-server.ts` owns the socket and knows no route; `routing.ts` owns
  every route and opens no socket.

## FUN — Functions

- **FUN-1** MUST: at most three **positional** parameters on a function or method; past three, use
  Dart named parameters or a TypeScript options object, so every argument is readable at the call
  site. `AkiSpec._face` takes eleven named parameters and complies — the rule is about unreadable
  call sites, not about arity.
  **Carve-out (FUN-1a):** a small private value type may take its fields positionally
  (`_Mouth` in `aki_spec.dart`) when a named constructor would be pure noise; a *function* may not.

- **FUN-2** NEVER take a boolean parameter that selects between two behaviors — a boolean means the
  function does two things. Use a closed enum, or write one function per alternative.

  ```dart
  // wrong
  const SplashScreen({this.onGreen = false});

  // right — the variants are named, and a third one is a compile error away from being handled
  enum SplashVariant { cream, brandGreen }
  const SplashScreen({this.variant = SplashVariant.cream});
  ```

## TYP — Types

- **TYP-1** MUST: in Dart, annotate every declaration explicitly and type every collection literal —
  `final Rect box`, `final double scale`, `<BrandMark>[...]`, not `var` and not a bare `[]`. Nothing
  enforces this: `flutter_lints` does not enable `always_specify_types`, so it is a review rule, and
  the whole `app/lib/` tree already reads this way. On the TypeScript side `strict` and
  `verbatimModuleSyntax` are on in `packages/server/tsconfig.json`, so implicit `any` and a missing
  `import type` are compiler errors already — what the reviewer still checks there is an explicit
  return type on every exported function and `unknown` rather than `any` when a payload is genuinely
  untyped.

## NAM — Naming

- **NAM-1** MUST: identifiers are self-descriptive without their surrounding context, and carry no
  data-type prefix (`strCode`, `blnOk`, `arrMarks`) — the type annotation already says that. Name by
  role. Length scales inversely with scope: a public entry point is short and abstract (`route`,
  `body(pose)`), a private one-job function is long and precise (`_buildFace`, `_paintStroke`,
  `buildHealthReport`). If a comment is needed to say what a function does, rename the function.

## CMT — Comments & documentation

- **CMT-1** MUST: before writing a comment inside a function body, extract the code it would explain
  into a function whose name says what the comment would have said. A comment that survives that
  test states the non-obvious **why** in one or two lines and never restates the code; three lines
  inside a body is the ceiling, and longer rationale belongs in the plan, `ARCHITECTURE.md`, or an
  ADR under `docs/adr/`.

- **CMT-2** MUST: **a comment that states behaviour the code does not have is a defect**, and it is
  fixed with the code in the same commit — a comment is not a softer artifact than the code above
  which it sits. CMT-1 governs whether a comment should exist and what it may say; this one governs
  whether it is true. Found in `f2-onboarding-first-run`, where three doc comments claimed the
  first-run flag was *"set by answering, not by escaping"* and that answering was *"the only path
  that completes the first run"*, while the skip control one row below the close control completed it
  with nothing solved; and where `FirstItemScreen` said *"it measures nothing"* above a screen whose
  verdict displayed `RACHA 1`. A reviewer reading a comment believes it, which is exactly why a false
  one is worse than none: it retires the question.

- **CMT-3** MUST: **a comment that claims a test or a gate exists is a claim to `grep` for, and it
  is checked the moment it is read.** This is CMT-2's nastiest special case, because it does not
  merely mislead — it retires the very question that would have found the gap, and it leaves an
  invariant advertised as guarded while nothing guards it. Found in `req-me-standing`:
  `packages/server/src/adapters/http-server.ts` said its missing-handler branch was *"unreachable
  while the test holding `IMPLEMENTED_OPERATIONS` to these keys passes"*, and **no such test had
  ever been written** — so `route()` could dispatch to a name with no handler behind it, a 500 that
  only production would find. Two obligations follow. When you **write** such a comment, name the
  file (`test/every-built-operation-has-a-handler.test.ts`), never the claim in the abstract, so the
  assertion is one `ls` from being falsified. When you **read** one while working nearby, grep for
  it before relying on it; if it is not there, the missing gate is part of the change that needed
  it, because the next author will believe the comment too.

## WIRE — What crosses between the stacks

- **WIRE-1** NEVER branch on a server's human-readable `message`. The frozen `Error` shape is
  `{error, message}`: `error` is the tag a client may switch on and `message` is prose for a
  developer reading a log. A client that reads the sentence has coupled its behaviour to copy, so a
  reword on the server silently changes what a player is told — a defect that passes every test on
  both sides. Found in `f7-conflicto-de-cuenta`: `linkOutcome` refuses a link for **two** distinct
  reasons and `conflictResponse` sends both as `already_linked`, with the difference surviving only
  in English prose the client already held and was discarding.

  When two outcomes genuinely have to be told apart, in order of preference: **derive it from
  another contracted operation** if one answers the same question — the `GET /me` probe there is
  *exact* rather than heuristic, because the server checks `playerForAccount` before
  `accountForPlayer` and `GET /me` is `playerForAccount` — or **add a distinct `error` tag**, which
  is cheaper than it looks and is measured rather than assumed: `ErrorSchema.error` is
  `z.string()`, not an enum, so a new tag changes no schema, leaves `contract/openapi.json`
  byte-identical, and needs no `allow-breaking-contract` label. What is never acceptable is a
  client that says *"the message contains …"*.

  **The state that claims the least is a real state**, not a placeholder. Where the direction
  cannot be established, say only what the status code said; falling through to either specific
  answer is inventing one, which is the failure being fixed rather than a smaller version of it.

## LANG — Language

- **LANG-1** MUST: code, identifiers, file names, comments, doc comments, test names, commit
  messages and documentation are in **English**. Only strings the player reads are in **Mexican
  Spanish**, and they read as a person talking to a child, not as a system reporting
  (`'Se me desenroscó la cola. Ya vuelve.'`). There is no i18n layer yet, so player-facing Spanish
  sits inline in the widget that shows it; when a layer arrives this rule gains a clause under
  PROC-6. **A verbatim quotation of a Spanish design document, or of player-facing copy, may stand
  inside an English comment** provided the rationale around it is in English — `banner_visual.dart`'s
  *"Sin conexión no es un error del usuario: va en amarillo"* is the reason a decision was taken, and
  paraphrasing a source into English loses the ability to check it against the source. Quoting is not
  writing the comment in Spanish.

## DEP — Dependencies & the audience

- **DEP-1** NEVER add a dependency that sends data off the device — analytics, ads, attribution,
  crash reporting, remote config, remote fonts, any SDK that "phones home". The audience includes
  children under 13 and the compliance posture in `ARCHITECTURE.md` §11 is minimization by
  construction. Before adding *any* dependency, audit what network calls it makes and what it
  collects; "it's only a util" is not an audit. **The audit lives in
  `app/test/architecture/dependency_allowlist_test.dart`, beside the allowlist entry, in the same
  change** — not in a pull-request body, which is not greppable, not versioned next to the thing it
  describes, and fails no build. `shared_preferences`, added 2026-08-16, is the worked example: the
  gate went red on the addition, and the entry carries the publisher, what the package wraps, what it
  stores, and a verified negative for `HttpClient`, `package:http`, `Socket` and `WebSocket` across
  the facade, the platform interface and both mobile implementations. A **dev** dependency is out of
  the allowlist's scope because it does not ship, and the reason is stated at its declaration. Assets ship bundled for the same reason — the
  brand typefaces live in `app/assets/fonts/` precisely so that first launch makes no third-party
  request.

## BRD — Brand invariants

These are not taste. Most of them are enforced by committed tests
(`app/test/design/no_blurred_shadow_test.dart`, `app/test/design/tokens/brand_colors_test.dart`,
`app/test/design/brand/aki_spec_test.dart`), and a change that breaks one of those breaks the build.
Where a clause below is **not** test-backed it says so — an invariant a reviewer must read for is
still an invariant, but claiming a test behind it that does not exist is how a rulebook loses its
credit.

- **BRD-1** MUST: success and error are distinguishable by **shape**, never by hue alone — `AkiPose.correct`
  and `AkiPose.slip` differ in the tail, the ears and the mouth curve, not only in color. Coral means
  error and nothing else; green means action and success and nothing else; pink is never `error`,
  `success` or `action` — it is the accent, and `BrandColorRole.focus` is an input affordance, not a
  verdict. Ask `BrandColorRole` for a role, not `BrandColors` for a hue, in anything that
  communicates state.

- **BRD-2a** NEVER draw a blurred shadow, a gradient, a backdrop filter, or anything with Material
  elevation — shadows are hard, `blurRadius: 0` and `spreadRadius: 0`, offset from `BrandShape`.
  `no_blurred_shadow_test.dart` walks every screen and asserts four of those: no gradient,
  `blurRadius == 0`, `spreadRadius == 0`, and elevation 0 on `PhysicalModel` and `PhysicalShape`.
  It does **not** look for `BackdropFilter`, and none exists in `app/lib/` — that clause is a
  reviewer's read, not a red build, until someone adds
  `expect(find.byType(BackdropFilter), findsNothing)` to that test.

- **BRD-2b** NEVER write a color literal outside `app/lib/design/tokens/` — `brand_colors.dart` says
  so itself and is the single source of the palette; ask `BrandColorRole` for a role rather than
  `BrandColors` for a hue in anything that communicates state. **Carve-out, matching CLAUDE.md
  verbatim:** `Colors.transparent`, used to switch Material's surface tinting off, is the one
  exception on disk (`app/lib/design/theme.dart:37,42,48,53`). Nothing else loosens, and this is a
  red build rather than a `grep` a reviewer has to remember to run:
  `app/test/architecture/no_color_literal_test.dart` scans all of `app/lib/` except
  `design/tokens/` for `Color(0x`, `Color.fromARGB(`, `Color.fromRGBO(` and `Colors.`, with
  comments stripped first. The last is matched on a word boundary — `(?<![A-Za-z0-9_$])Colors\.` —
  because `Colors.` is a substring of `BrandColors.` and a naive match reports **94 correct lines**
  across 12 files. It carves out `Colors.transparent` by name, asserts the `Colors.` arm alone
  returns exactly the four `theme.dart` hits *before* that carve-out is applied, and reports how
  many files it scanned so a mistyped root cannot make it vacuously green. It does not match
  `#RRGGBB` text: the character sheet prints four brand hexes as swatch labels and is correct code.

- **BRD-2c** SHOULD: take geometry from `BrandShape` — radii, stroke widths, spacing — and give any
  deliberate departure a one-line reason next to it. The worked example is the 260px face tile in
  `splash_screen.dart`, whose doc comment justifies its 60px radius; that radius is now the screen's
  only unexplained-looking number and it is the one that has a reason, because the `width: 4` border
  beside it became `BrandShape.borderWidth` in `f0-token-scale` and the screen's uniform 26px rhythm
  is one named `_gap` constant carrying its own one-line reason. Hard-shadow offsets on widget
  surfaces are enforced rather than reviewed: `app/test/architecture/no_geometry_literal_test.dart`
  scans `app/lib/design/widgets/` and `app/lib/features/` for `Offset(`, leaving `app/lib/design/brand/`
  out because that is the artwork layer, where geometry *is* the content. Radii and border widths are
  **not** scanned — a bare `24` is not greppable without parsing — so on those two this stays a
  reviewer's read.

- **BRD-2d** MUST: any interactive target is at least `BrandShape.minTouchTarget` (48 logical
  pixels) in both dimensions — keypad keys and puzzle-board cells alike.

- **BRD-2e** MUST: **a banner action cannot wrap, so a long label does not belong in one.**
  `InlineBanner` lays out glyph, `Flexible(Text)` and `BrandButton.text` in one `Row`; the button
  is inflexible and its label is a single line, so once the label plus the message's longest word
  exceed the width, the row overflows and the chip is squeezed under the 48 px floor. Measured in
  `f7-conflicto-de-cuenta`: *"Cerrar sesión"* beside a two-line Spanish sentence overflowed by
  **65 px** at textScaler 1.3 and failed `touch_target_test` as well as `screen_overflow_test`.
  A one-word chip — *"Detalle"*, *"Reintentar"* — is what the banner is sized for. Anything longer
  goes below the surface as a full-width `BrandButton`, which is the idiom `ProfileScreen` already
  uses for the refused session's sign-in door. **Register the new state's screen before believing
  it fits**: both gates read `app/test/design/screen_registry.dart`, and a state that is not in it
  is a state neither gate has ever measured.

## GIT — Commits & branches

- **GIT-1** MUST: `git config user.email` is `geineryodan@gmail.com` — verify before committing —
  and **NEVER** add a `Co-Authored-By` trailer or any other tool-attribution line to a commit
  message.

- **GIT-2** MUST: one coherent change per commit, small and logical; subject is a conventional prefix
  plus a short lowercase description with no ticket id and no scope in parentheses
  (`chore: name the server package @akimath/server for the workspace`). Never bundle an unrelated
  edit — a `.gitignore` tweak, a formatting sweep, a refactor the change did not need — into a
  commit that describes something else.

- **GIT-3** MUST: **`main` is the trunk.** It is protected by the `protect-main` ruleset — no
  direct push, no force-push, no deletion — and is reached only by a pull request from a branch cut
  from `main`, never from another feature branch. The diff base for any review or audit is
  **`origin/main`**, stated explicitly rather than left to `origin/HEAD`.

  **`dev` is not the working branch and has not been since 2026-08-17**, when it stopped at pull
  request #6. Everything since — #7 through #108 — merged into `main`, which is 155 commits ahead
  and differs in 656 files, and `dev` is a strict ancestor holding nothing `main` does not. This
  rule said the opposite until 2026-08-26; a review that took `origin/dev` as its base read those
  155 commits as the change under it.

## PROC — Process

- **PROC-1** MUST: **TDD.** The test is written first and lands in the same commit as the behavior it
  describes — tests are committed here, they are the deliverable, and a behavior change with no test
  in its commit is incomplete. `app/test/`, `packages/server/test/` and `packages/contract/test/`
  are the three homes; a test that needs a mock to describe a decision is a PURE-1 finding, not a
  test problem.

- **PROC-5** MUST: a change is proven by **evidence**, and the tier reached is stated in words. The
  tier names here are the same three CLAUDE.md uses; an agent file that numbers them differently is
  wrong and gets corrected under PROC-6.
  - **Tier 1 — the committed suite, always.** Run these, verbatim, per package:

    ```sh
    cd app               && flutter analyze --fatal-infos
    cd app               && flutter test
    cd packages/server   && npm run verify      # tsc --noEmit && vitest run
    cd packages/contract && npm run verify      # tsc --noEmit && vitest run
    cd packages/core     && npm run verify      # tsc --noEmit && vitest run
    ```

    `--fatal-infos` is not decoration: these are the commands `.claude/hooks/verify-gate.sh` runs
    as a `PreToolUse` hook on every `git commit` and `git push`, exiting **2** (blocking) on a
    failure, and the same commands `.github/workflows/ci.yml` runs in its `dart`, `ts` and
    `contract` jobs.
    (The hook and CI spell the TypeScript half as `npm run typecheck` then `npm test`, which is
    exactly what `npm run verify` chains — same two checks, one script.)
    The rulebook, the hook and CI must name one set of commands; if they ever diverge, reconcile
    them in the same session (PROC-6). The baseline is **zero**: as of 2026-08-26 the Flutter suite is 3275,
    `packages/server` 325 of 454 (129 skip without a Postgres), `packages/contract` 248 and
    `packages/core` 340, all passing, and every analyzer reports clean, so there is no pre-existing noise to hide a new failure in. Green before, green after,
    stated with the counts.
  - **Tier 1b — SHOULD, when the change is in the pure core: show the tests bite.** A green suite
    that would stay green with the logic inverted is not evidence.
    - TypeScript: `npm run mutation` (Stryker, `break: 70`) and `npm run dry` (jscpd) in the
      package under change — `packages/server` scores 100.00 with 0 clones today,
      `packages/contract` 91.71 with 0 clones. **jscpd's `threshold: 1` means `npm run dry`
      exits 0 with real clones in it**, so the number to read is "clones found", not the exit
      code.
    - Dart: there is **no configured mutation harness** — `mutation_test` is a dev dependency but
      the rules XML that would define its test commands does not exist, so do not write that
      command as if it ran. The substitute is a **falsification step**, and because it edits
      versioned production code its mechanism is part of the rule, not a detail:
      0. **Commit the change first, then falsify.** Every restore below is a restore *to
         something*, and until the work is committed there is nothing safe to restore to. This
         is the cheap fix for both traps in step 1, and it costs one commit.
      0b. **A mutant Stryker calls survived, and a hand falsification kills, is a finding about
         the code — usually module-scope work.** Anything a module *does* at import time
         (`const PARSED = parse(...)`) turns a bad edit into an **import** failure, and an import
         failure is not a test failure: every file importing it dies before its assertions run,
         and Stryker scores the mutant as survived. The fix is not to argue with the tool. Defer
         the work to first use, and the mutant fails where it can be seen. *(2026-08-19:
         `packages/core`'s `misconceptions.ts` read 56.31 with 42 survivors while a hand
         falsification of one of them went red. Making the parse lazy took it to 93.27 with the
         same tests.)*
      1. For a **tracked file with no uncommitted changes**, `git checkout -- <file>` is correct.
         For a **tracked file carrying this session's uncommitted work**, it is not: it restores
         to HEAD and silently deletes the change you are testing, mutation and feature together —
         a green suite afterwards is green because the feature is gone. Use
         `git stash push -- <file>` / `git stash pop`, or the copy below. For an **untracked**
         file — a new file in a session that has not committed — neither works: `git stash push`
         will not take an untracked path and `git checkout --` has nothing to restore from. Copy
         it out of the tree first, and record a `shasum -a 256` of it.
         *(All three failed in one run on 2026-08-19: four falsifications restored with
         `git checkout --` across two tracked files holding uncommitted work and two untracked
         ones. Two reverted to HEAD, two kept the mutation, and the suite was green either way.
         Step 0 is the rule that run bought.)*
      2. Invert one assertion or return value, run `cd app && flutter test`, and record the
         **named** test that went red. **Red is the runner's exit status, never a grep over its
         output.** A pattern matching the failure line is one ANSI escape away from finding
         nothing, and a Tier 1b check that cannot see red reports the mutation as survived — the
         one direction that turns evidence into its opposite. Get the name from the output by all
         means; decide pass or fail from `$?`. *(Reported "STILL GREEN" twice on 2026-08-19 for
         mutations that did bite.)*
      3. Restore: `git checkout -- <file>` (or `git stash pop`, or the copy), then prove it with
         **two** things pasted into the ledger. Tracked: `git diff --quiet -- <file>` and a
         `flutter test` run back to the count you recorded before the mutation. Untracked:
         `git diff --quiet` is **vacuous** — it exits 0 for any path git does not track, whether or
         not the mutation is still in the file — so the proof is the `shasum -a 256` from step 1
         repeated and matching (`diff -q <backup> <file>` is the accepted equivalent for a single
         file), plus that same returned test count. PROC-8 is the general form of this trap.

      A falsification step without that closing proof is not evidence, it is an uncommitted
      mutation waiting to be staged by the next `git add`.
    - **Never report a score you did not produce in this session.**
  - **Tier 2 — exercise the real thing.** The app run on a device or simulator when the change
    surfaces on screen — the 48px touch area, shape-not-hue, the absence of blur are judged there
    and not in a widget test — or the endpoint called for real once endpoints and an environment
    exist. There is no endpoint, dev environment, deploy or database today, so on the server side
    tier 2 is currently unreachable and saying so is the correct outcome. "It should work" and "it
    compiles" are not evidence; neither is a passing suite that was never executed.
  - **`dart run dart_code_linter:metrics analyze lib
    --set-exit-on-violation-level=warning` is tier-1 evidence and is part of the everyday gate.**
    This bullet said the opposite until 2026-08-21 and was stale: it read *"not evidence at any
    tier, `app/analysis_options.yaml` carries no `dart_code_linter:` block"*, and that block has
    since landed (line 43, with the thresholds set at what the code does today). CI runs the step
    in its `dart` job and CLAUDE.md documents it, so CLAUDE.md won and this was corrected in the
    session that noticed — one agent had been told by three documents not to run a gate CI enforces.
    **The flag is not decoration**: without it the command prints its warnings and exits **0**,
    which is the green-by-construction trap the old bullet correctly described, one level deeper.
    The thresholds ratchet *down* as the code gets simpler and never up to accommodate it.
    `.claude/agents/*.md` may still carry the old prohibition; an agent file that does is wrong and
    is corrected under this rule.
  - The root `package.json` `verify`/`typecheck` scripts delegate to `pnpm -r`; **pnpm is not
    installed on this machine**, so they do not run. Use the per-package commands above until the
    pnpm migration lands.

  *(The IDs `PROC-5` and `PROC-6` are preserved verbatim from the parent workflow, gaps and all —
  `PROC-5` is the evidence rule there too — so cross-project references keep resolving. Do not
  renumber either.)*

- **PROC-6** MUST: **this rulebook and the agent instructions are living documents.** Whenever a
  correction lands — the user overrules a decision, a review finding turns out to be wrong, a
  carve-out is discovered, or a failure mode bites twice — write it down in the same session: as a
  new or edited rule here (with an ID), and in the affected `.claude/agents/*.md` when it changes how
  an agent should behave. A lesson that lives only in a chat reply will be relearned the hard way.
  **Corollary:** a review finding's **proposed fix** is a claim to verify against this rulebook, not
  an instruction to apply — findings have suggested rule-violating fixes before.
  A rulebook that did not grow this month is not stable; it means nobody wrote down what they
  learned.

- **PROC-7** MUST: a convention that has to reach **planning** lives in `openspec/config.yaml`, not
  only here. Its `context:` block is what every `/opsx:propose` run reads, and its per-artifact
  `rules:` are what shape `proposal.md`, the delta specs and `tasks.md`. A rule added here and not
  there is invisible at the moment it would have done the most good — before the code exists. Edit
  both in the same commit, or neither.
  Keep `config.yaml` pointing at files rather than restating them: a paraphrase of this rulebook
  copied into it goes stale silently, and nothing will ever fail to warn you.

- **PROC-8** MUST: **git cannot prove anything about a path it does not track.** `git diff
  --quiet -- <file>` and `git diff --exit-code -- <dir>` both exit **0** for an untracked path —
  not because nothing changed, but because git has nothing to compare against. The proof is
  therefore vacuous exactly when the file is new, which is exactly when a session is most likely
  to reach for it. Use a `shasum -a 256` recorded before and repeated after instead, and **say
  which form you used**: for a single file the checksum (or `diff -q <backup> <file>`), for a
  whole directory a checksum of the sorted file list — `find <dir> -type f | sort | xargs shasum
  -a 256` — compared before and after. PROC-5's tier-1b falsification step carries the mechanism;
  this rule is why it has two branches. **For a *tracked* file `git diff --quiet -- <file>` is
  itself the proof** — the checksum is the substitute for the untracked case, not a replacement for
  git. A ledger that reads "the file is versioned, so `shasum` is the proof, not `git diff`" has
  inverted this rule; it was written that way once, in `f2-onboarding-first-run`, by an author who
  had taken in only the rule's first sentence. Found twice independently, in `f0-invariant-tests` (a
  falsification step on a new test file) and in `f0-pack-contract` (a byte-determinism gate over
  an untracked `contract/`), which is what promoted it to a rule.

- **PROC-9** MUST: a mutation score is only evidence if the run's **initial test run** passed.
  Stryker copies the package into a sandbox, so any test that reads a path outside the package
  must discover that path by walking up rather than by counting `..` segments — otherwise the dry
  run dies and there is no score at all, which is not the same as a low one. Measured in
  `f0-pack-contract`: the fixture tests' hard-coded `../../../contract` resolved to nothing under
  the sandbox. Never report a number from a run you did not watch complete.

- **PROC-10** MUST: a gate driven by a registry asserts its registry is **non-empty**. Measured in
  `f0-invariant-tests`: pointing `no_blurred_shadow_test.dart` at an empty `screen_registry.dart`
  took it from 6 tests to `No tests ran. No tests were found.` and **exited 0** — the whole suite
  dropped 72 to 66 in that session and reported success. A gate whose input list silently reaches
  zero is indistinguishable from a gate that found nothing wrong. `expect(registeredScreens,
  isNotEmpty)` in `app/test/design/screen_overflow_test.dart` and the per-root counts in
  `app/test/architecture/pure_boundary_test.dart` are the two forms this takes today. The same
  applies to a path-filtered scan: report how many files it walked, and fail at zero.
- **PROC-11** MUST: **an assertion that holds for any input is not a test.** Green that carries no
  information is worse than a gap, because a gap is visible. Four instances, all in this repository,
  all found by review rather than by the suite:
  - **An `expect` whose sides are algebraically equal.** `round_screen_test.dart` asserted
    `text.width * (slot.width / text.width) <= slot.width + 0.5`, which reduces to
    `slot.width <= slot.width + 0.5`. It was written to hold down a painting defect that had shipped,
    and it held nothing.
  - **A `hasLength` or value-set check over an enum whose arms nothing exercises.** `MathTone.values`
    was pinned at two members while the adapter arm behind one was unreachable;
    `BannerPlacement.values` was pinned at two while neither placement's radius was rendered in a
    test.
  - **A `catch` no test reaches.** Both arms of `PrefsDayLogStore` were unreached, because the only
    backend in the tests never fails — and the write arm was the half the original incident was on.
  - **A test whose name claims more than its body checks.** `'a notice banner renders with its
    glyph'` checked a widget type, a string and a rect ordering, so a grep for glyph coverage
    returned a false positive.
  - **Fixture data that satisfies the mutant as well as the code.** The assertion is sound and the
    *inputs* make it insensitive, which no amount of reading the assertion reveals. In
    `req-me-standing`, `get-standing.test.ts` pinned `ORDER BY skill_id` with rows seeded
    4→900, 1→1200.5, 2→1050 — whose rating-descending order is the same `[1, 2, 4]`, so
    `ORDER BY rating DESC` passed it untouched. The fix was the data, not the assertion: give the
    highest rating to the highest skill id and the two orders disagree. **Whenever a test pins a
    choice between two columns, two keys or two orderings, the fixture must make the alternatives
    produce different output** — otherwise the test documents an intention it cannot enforce.

  The remedy is the same in every case: **state the mutation the test would catch, then make it.**
  When a test is the record of a defect that shipped, PROC-5's tier-1b falsification is not optional
  — invert the fix and watch that specific test go red.

- **PROC-13** MUST: **a value that flows from a parent into a child is asserted on the *second*
  frame, not the first.** A test that pumps a widget once and reads what it drew has checked
  construction and nothing else — and construction is the half that never breaks. Measured in
  `f7-cuenta-y-perfil`: `TabStack` built its root through `onGenerateRoute`, which the Navigator
  calls **once**, so the `pageBuilder` closure captured whichever `child` the first build passed.
  Every later `RootScaffold.setState` produced a root widget that was constructed and never
  mounted. The session the shell holds travels that way, so **signing in changed nothing in the
  running app** — no address, no `POST /players/link`, no history, no sync — while the suite was
  green and `CLAUDE.md` described the behaviour as working. Nothing had ever pumped the shell
  twice.

  The remedy is two lines: `pumpWidget` with one value, `pumpWidget` with another, and assert the
  screen moved. Where the parent is also meant to preserve the child's state — the shell's
  `IndexedStack` exists so the home does not re-read its pack — assert **both halves in one test**,
  because they pull against each other and a fix for either alone is a regression in the other
  (`app/test/features/shell/ui/tab_stack_test.dart`'s `a root keeps its state while a changed
  field reaches it` counts `initState` calls and reads the new value in the same run).

  The general form, beyond Flutter: **any framework callback documented as running once is a place
  a data path can die silently.** `onGenerateRoute`, a route's `builder`, a `late final` field, a
  `Future` created in `initState` — each captures its inputs, and each keeps handing back the
  first ones for ever. Grep for the capture, not for the symptom.

- **PROC-12** MUST: **the change satisfies its approved delta spec.** `CLAUDE.md` makes the
  `#### Scenario:` blocks under `openspec/changes/<id>/specs/**` the acceptance criteria, and each one
  names the test file that must cover it with a `→`. A scenario with no covering test, a `→` pointing
  at a file that does not exist, or a `SHALL` the code does not meet is a **blocking** finding, and it
  is citable as this rule. Added because a reviewer holding two real spec violations — a first run
  completed with no item solved, against `req-first-run`; a tutorial displaying a streak, against
  `req-teaching-item-unrated`'s *"contributing to no rating or streak"* — had to attach both to
  PROC-11 to give them an ID at all.


---

## What is deliberately not here

Rules must describe code that exists, or a reviewer will fire them at innocent code. These wait for
their subject:

| Not yet a rule | Because |
|---|---|
| Layering (`handler → controller → model`) | there are no handlers, controllers or models — PURE-1/PURE-2 is the layering this repo actually has |
| Data access, ORM, migrations, SQL | Neon and Drizzle are planned in `ARCHITECTURE.md` §5, not built |
| i18n mechanics | no i18n layer; LANG-1 covers the language split until there is one |
| Static-auditor gate (`fallow`) | the binary resolves (`fallow 3.15.0`, homebrew) but is a **global, not a project devDependency** — adapting.md §5's named silent-fail mode, where the terminal finds it and a fresh clone does not. It also analyzes TS/JS only: at this root it discovers 7 files and **0 of the 18 Dart files**. `.claude/hooks/verify-gate.sh` replaced it with the toolchains this repo owns. The self-ignoring `.fallow/` cache directory is a by-product of running it, not a tool. |
| Deploy, environments, release train | none exist |
| Ticket ids in branches, commits or PRs | there is no tracker; the backlog is `ARCHITECTURE.md` §9, phases F0–F8 |
| Compliance CI, protected-paths job, `Verdict` without `.color` | designed in `ARCHITECTURE.md` §6–§8, not written |

Each of these becomes a rule the day it becomes code — by PROC-6, in the session where it lands.
