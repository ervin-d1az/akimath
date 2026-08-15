# AkiMath — architecture proposal

Status: **proposal**, not yet accepted. One decision (§1) gates most of the rest.

Produced by fanning six architectural dimensions out to independent agents, giving
each one an adversarial critic that had to verify every library claim against a
live source, then reconciling the contradictions. 13 agents, 311 tool calls. The
critics changed real conclusions — TypeScript 6 rather than 7, `pg` rather than
Neon's serverless driver, Better Auth storing the password hash somewhere other
than where the deletion test was looking. Where a claim could not be verified it
is marked as such rather than smoothed over.

This supersedes `draft.md` where the two disagree. It does not supersede your
judgment on the open questions in §11.

---

## 1 · The decision that gates the rest: one repo, not two

**Recommendation: a single `akimath` repository.** This reverses the two-repo
choice, and the reason is narrow enough to state precisely.

The cross-stack contract is not one file. Three independent critics enumerated
**six** things that must stay in lockstep between TypeScript and Dart:

| Contract | Why it crosses |
|---|---|
| `openapi.json` | request/response shapes |
| `PromptToken` / `KeypadSpec` | the keypad is declared per template, server-side |
| `ErrorTag` | a closed union Dart must exhaustively switch on |
| HMAC message construction | offline answer verification |
| Offline pack format | what the client downloads and replays |
| `canon.golden.json` + `CHAR_MAP` | answer canonicalization, shared by both sides |

Each dimension independently invented its own pinning ceremony for its slice —
a `contract.lock`, a versioned `contract/` directory, a tagged artifact, a
`contract-vN` git release, a byte-for-byte copy. **Five incompatible mechanisms
for the same boundary is the symptom.** In one repo they are files in a commit
that either compiles or does not.

What is *not* the argument, so this doesn't get oversold: during phases 1 and
1b there is no server↔app crossing at all. Two repos cost nothing until the
server exists. Unify now because it costs an hour today and a weekend at 200
commits — not because it blocks anything tomorrow.

The legitimate argument *for* two repos — compliance gates are per-artifact and
the Flutter side wants stricter rules — survives inside the monorepo as
path-filtered CI jobs plus a protected-paths hook. Which is needed anyway (§7).

### Migration, preserving history

Do **not** use `git subtree add`: it produces a merge whose history is reachable
but whose paths are not rewritten, so `git log --follow` and `git blame` break at
the seam.

```bash
# 0. On GitHub: ARCHIVE akimath-app and akimath-api. Do not delete —
#    both have pushed branches, and an old clone pushing to a live remote
#    is how you lose a day.
brew install git-filter-repo
cd /tmp && rm -rf mig && mkdir mig && cd mig

git clone https://github.com/ervin-d1az/akimath-app.git app-src
git clone https://github.com/ervin-d1az/akimath-api.git api-src
# confirm dev holds everything first: git log main..dev  and  dev..main

(cd app-src && git checkout dev && git filter-repo --to-subdirectory-filter app)
(cd api-src && git checkout dev && git filter-repo --to-subdirectory-filter packages/server)

mkdir akimath && cd akimath && git init -b main
git remote add appsrc ../app-src && git remote add apisrc ../api-src
git fetch appsrc dev && git fetch apisrc dev
git merge --allow-unrelated-histories -m "chore: absorb akimath-app history under app/" appsrc/dev
git merge --allow-unrelated-histories -m "chore: absorb akimath-api history under packages/server/" apisrc/dev

# VERIFY CONTINUITY before going further — each must return more than one commit:
git log --follow --oneline app/lib/design/tokens/brand_colors.dart
git log --follow --oneline packages/server/src/routing.ts
```

Then, as separate atomic commits: shared configs to the root (`pnpm-workspace.yaml`
with `catalog:`, `tsconfig.base.json`, root `vitest.config.ts` using `test.projects`);
the TS stack bump in isolation; `flutter clean && flutter pub get` in `app/`
(`ios/Flutter/Generated.xcconfig` carries **absolute** paths to the old directory);
and a hand-merged root `.gitignore`.

**The Dart package and bundle id are already renamed** to `akimath_app` and
`com.akimath.akimathApp`, along with the Kotlin package path, both store display
names, and the web manifest. This was worth doing eagerly rather than as
cosmetics: a bundle id cannot change after the first store submission, and
nothing is submitted yet.

### Tree

```
akimath/
├── contract/openapi.json         COMMITTED ARTIFACT — generated, never hand-edited
├── packages/
│   ├── core/                     @aki/core — pure, zero dependencies
│   ├── contract/                 Zod + route defs + the OpenAPI emitter
│   └── server/                   Hono, Drizzle, Better Auth, batch jobs
├── app/                          the only Dart package
├── swarmforge/                   swarm config, if you keep it (§7)
└── docs/adr/
```

`packages/server` rather than a top-level `server/` — it is a workspace package
like the others. `packages/contract` exists so the spec can be emitted **without
booting Hono or touching `DATABASE_URL`**; if emitting the spec needs a database
the CI gate goes flaky and you will end up disabling it.

**pnpm 11.x via corepack** (not installed yet; `corepack 0.34.5` and `node 24.12.0`
are). **Not melos** — it is alive at 8.3.0 but since 7.x it only delegates to pub
workspaces, and there is exactly one Dart package.

---

## 2 · The contract chain

Generate locally, **verify** in CI. `contract/openapi.json` and the Dart client
are committed; CI runs the generator and does `git diff --exit-code`. Having CI
generate *and commit* races against agent worktrees.

Pin **OpenAPI 3.0.3**, not 3.1 — Zod 4 emits JSON Schema 2020-12 which maps to
3.1, and no mature Dart generator digests that well. Zero response polymorphism:
no `oneOf`, no `discriminator`; variance lives inside an opaque `params`/`payload`.

The Dart client is an **open fork in the road, not a validation**. There is no JVM
and no Docker on this machine, which removes `dart-dio` and `openapi-generator-cli`
from the option space. That leaves `swagger_dart_code_generator` or **a hand-written
client** — ~250 lines for 12–15 endpoints with no polymorphism, and it deletes five
codegen dependencies, the byte-determinism gate, and `build_runner` from every
worktree. Decide it with a half-day spike in phase 0, with an explicit exit
criterion: *if the generated Dart for three representative schemas is not better
than what you would write by hand, write it by hand.*

---

## 3 · Domain core

`packages/core` is not a utility library — it is the **rederivation machine**.
One invariant governs the whole design: `attempts` is append-only and the server
must reconstruct the exact problem years later, on a different Node, from
`(template_id, template_version, seed)`.

- **Zero `dependencies`.** Enforced by a CI check that reads `package.json`, not
  by pnpm's strictness — an agent runs `pnpm add drizzle-orm --filter @aki/core`
  and a resolution-based invariant dies in a one-line diff.
- The check nobody proposed and that actually protects determinism:
  `no-restricted-globals` over `packages/core/**` for `Math.random`, `Date`,
  `performance`, `crypto.randomUUID`, `Intl`, `toLocaleString`. No import ban
  catches `Math.random()`.
- **Rationals as `BigInt`**, vendored PRNG with a golden vector *emitted from the
  code* — the canonical cyrb128+sfc32 snippet does not produce the vector that was
  claimed, which is exactly the kind of thing a hand-written golden test enshrines
  as wrong forever.
- **Glicko-1, and the rating period is the session, not the request.** Grouping by
  request was defended as "consistent by construction"; its critic showed it is
  deterministic but not consistent — two users with identical play get different
  ratings depending on whether they had wifi, in the app whose promise is fair
  adaptive difficulty. A client-generated `session_id` rides on every attempt.
  `decay(prior, elapsedDays)` operates in **days**, or an inactive user never decays.
- **Series uniqueness** needs a rule library floor (`k ≥ dof+2`). With a small
  library "unique" is an illusion that hands you false confidence.

---

## 4 · What the client actually receives

Both the core and server dimensions independently contradicted `draft.md` §4 here,
from different directions: sending `{template, seed}` forces porting every
generator to Dart; and letting the client send `(template_id, seed)` back at
answer time lets it request hard and answer easy.

**Resolution:** the server emits, records in `issued_items`, and returns
`{itemId, prompt: PromptToken[], keypad, options?}`. `templateId`, `templateVersion`,
and `seed` never appear in the response. The client answers with `itemId`.

The invariant gets rewritten to something true:

> The prompt travels rendered. The answer never travels online. Offline, a
> membership verifier travels and its verdict is provisional until sync.

### Offline packs: one row per pack, not fifty

The server needs every offline item to be revalidatable; the data model cannot
pay 4 downloads/day × 50 rows. Both constraints are real, and a manifest satisfies
both:

```sql
offline_packs (
  id uuid PRIMARY KEY, player_id uuid NOT NULL, skill_id smallint,
  template_refs jsonb NOT NULL,   -- [{template_id, template_version, seed, ladder_step}] × N
  pack_salt bytea NOT NULL, issued_at timestamptz, expires_at timestamptz
);
```

Item identity is `(pack_id, index)`; the server rederives and recomputes `ok` at
sync. **The sync endpoint does not accept an `ok` field** — that is what makes the
invariant true by construction rather than by discipline.

---

## 5 · Server, auth, and data

- **Hono confirmed** (4.13.x, releasing every 1–2 weeks). **Better Auth floor
  `>= 1.6.22`** for GHSA-qq9h-g4jm-xgf3, `basePath: "/v1/auth"`, and
  `advanced.ipAddress.disableIpTracking: true` — by default it persists IP and
  user-agent **of minors**.
- **`pg` over TCP, not the Neon serverless driver.** Neon documents TCP for
  long-lived processes, and the HTTP driver cannot run the design's central
  transaction: the sync batch computes Glicko in TypeScript *between* the INSERT's
  `RETURNING` and the `user_skills` upsert. That is an interactive transaction.
  Pooler string at runtime, direct string for migrations, low `idleTimeoutMillis`
  so autosuspend still fires, `pg_advisory_xact_lock` to serialize two devices.
- **Identity: `players` is the game identity; Better Auth's `anonymous()` only
  supplies a session.** The client mints `player_id` as a UUIDv7 on first launch —
  without it there is no foreign key for phase-2 attempts, which run with no
  server at all. Zero rows in the database until first sync. Linking is **not**
  `onLinkAccount` (that hook runs *after* the `createUser` commit, so its
  "no progress lost" promise does not hold) but an idempotent
  `POST /v1/players/link` with an `Idempotency-Key`.
- **`attempts`, restated for `CLAUDE.md`:**

  > `attempts` never accepts UPDATE. It accepts DELETE **only** through the
  > erasure path (`DELETE /v1/me`) and the retention job, both under the
  > `retention_job` role. The request path holds no DELETE grant on `attempts`.

  Deleting is safe because calibration never derives from raw rows:
  `template_stats` is maintained on write, and needs `sum_expected` and
  `sum_user_rating` — without them an 80% success rate is unreadable, because
  adaptive routing guarantees only strong players ever touch the hard items.
- Deletion must also clear `account.password` and `verification.identifier` —
  Better Auth does not keep the hash or the email on the `user` row, so the
  obvious "scan every text column of `user`" test passes over data that is
  still there.
- **Puzzle autosave: the client saves, the server writes once.** The in-progress
  board lives locally, one `POST` on completion. Cross-device resume is lost; v1
  is one device per child.

---

## 6 · App

The Flutter repo must stay **buildable with no network, no server, and no TS repo**.
The boundary is a directory of pinned, versioned artifacts, not a handoff.

- `math_layout` (pure Dart, metrics injected) separated from `math_view`
  (`CustomPainter`) — a package containing a `CustomPainter` cannot run under
  `dart test`. Flutter does not expose x-height; extract `OS/2.sxHeight` from the
  TTF at build time (Darumadrop 435/1000, Jakarta 536/1000).
- The outbox loses the last autosave without a `sent_rev` and a
  `DELETE ... WHERE id=? AND rev=?`.
- **Transport failures must not consume the 8-attempt retry counter** — otherwise
  the airplane scenario dies in about four minutes.
- The brand layer already on disk (1,756 lines, 17 files, 6 test files) is
  continuation, not greenfield. Keep `BrandColors` public and tested; add a
  `Verdict` type on top **without exposing `.color`**, so success/error can never
  be communicated by hue alone.

---

## 7 · Orchestration: what to do instead of SwarmForge as written

You asked not to follow SwarmForge literally, and to get the most out of
multi-agent work. The two are the same answer.

### The correction that matters most

**SwarmForge's constitution is a prompt, not an access control list.** It is
prepended to context. Nothing stops an agent from editing a compliance manifest,
`PrivacyInfo.xcprivacy`, a migration, or `contract/openapi.json`. With agents
writing auth and minors' data against a `CLAUDE.md`, that is not a quality risk —
it is the route to a data incident.

Enforcement has to live where agents cannot reach it:

1. A **protected-paths CI job** that diffs against `origin/main` and fails unless
   a human signature is present. Runs with **no path filter**, always.
2. **`gitleaks`**, also unfiltered, also always.
3. **CODEOWNERS + branch protection.** You already have the ruleset on `main`.
4. A **`gate` job** with `if: always()` and `needs: [everything]`. This one exists
   because *a job skipped by an `if:` reports no status at all* — put the filtered
   jobs directly in required checks and PRs block forever, and the easy way out
   (removing them) disarms the whole thing. Only `gate` goes in required checks.

### Split the work by shape, not by tool

| Work | Run it as | Why |
|---|---|---|
| Architecture, research, review, verification | **Claude Code workflows** (what produced this document) | Deterministic control flow, structured output, adversarial critics, ephemeral. No tmux, no worktrees, nothing to clean up. |
| Long-running parallel implementation | **SwarmForge, or plain git worktrees + sessions** | Agents that need to live for hours on their own branch |
| Anything touching auth, migrations, compliance, contract | **You, through a PR** | See above |

The value you just saw is from the second column being *narrow*. This document's
corrections — TS 6 not 7, `pg` not serverless, the Better Auth hash location, the
PRNG golden vector — came from adversarial verification, not from a long-running
coding swarm. That pattern is cheap, repeatable, and has no runtime state.

### If you run SwarmForge anyway

`four-pack` on the monorepo, one swarm. Concretely required before the first
`./swarm`:

- Replace `swarmforge/constitution/articles/engineering.prompt` **wholesale**
  (same filename — startup skips existing files, and `local-*` is for additions,
  not replacement). Its tool table lists only Go, Clojure, and Java, and orders
  agents to install from `github.com/unclebob/...` repos that do not exist for
  Dart or TypeScript. Replace with: Stryker (TS) / `mutation_test` (Dart) for
  mutation, `jscpd` for duplication both sides, and drop the CRAP gate explicitly
  — there is no off-the-shelf CRAP tool for either language, and the `cleaner`
  role currently *requires* CRAP ≤ 6.
- Extract `four-pack` to a temp directory first: `tar --strip-components=1`
  overwrites your root `.gitignore` with its own six lines.
- Switch every `swarmforge.conf` window from `codex` to `claude`.
- Budget for it: N agents running continuously in tmux is sustained spend, not
  per-task spend.

---

## 8 · CI gates

| # | Job | Runs when | Blocking |
|---|---|---|---|
| 0 | `changes` (`dorny/paths-filter`) | always | — |
| 1 | `protected-paths` | **always, unfiltered** | yes |
| 2 | `secrets` (gitleaks) | **always, unfiltered** | yes |
| 3 | `ts-unit` — `tsc --build`, vitest, core-has-zero-deps check | `ts` | yes |
| 4 | `contract` — emit + `git diff --exit-code` + `oasdiff` breaking-change check | `ts`∨`contract` | yes |
| 5 | `dart` — `flutter analyze --fatal-infos`, `dart_code_linter`, `flutter test`, generated-client diff | `dart`∨`contract` | yes |
| 6 | `compliance` — lockfile allowlist, SDK denylist, merged manifest has no `AD_ID`, `PrivacyInfo.xcprivacy` | `dart` | yes |
| 7 | `integration` — ephemeral Neon branch (**a separate `akimath-ci` project**) | `ts` | yes |
| 8 | `gate` — `if: always()`, needs 1–7 | always | **the only required check** |
| 9 | `mutation` — Stryker over `packages/core`, fast-check 1000 runs | nightly | no |

`fast-check` and Stryker fight: Stryker re-runs the suite per surviving mutant, so
with random seeding a mutant dies on one run and survives the next, the score
oscillates, and `break: 90` fails CI at random. Fix:
`fc.configureGlobal({ seed: <constant>, numRuns: Number(process.env.FC_RUNS ?? 50) })`
— 50 under Stryker, 1000 nightly. And Stryker has no per-directory thresholds, so
"90 in core, none in routes" is achieved by narrowing `mutate` to
`packages/core/**/*.ts` and recording that routes are ungated by choice.

---

## 9 · Critical path

`draft.md` orders phases 0 → core → **server** → app, which puts the most
expensive-to-debug infrastructure ahead of the first playable build. But the
draft's own §4 already designed the offline pack: **the app is playable against a
JSON file in `assets/` — no network, no account, no Neon.** And the math
compositor does not depend on `core` at all, so two tracks run in parallel.

```
F0 ──┬── F1  core (TS)        ──┬── F1.5 pack builder ──┐
     └── F1b compositor (Dart) ─┘                       ├── F2 app: core loop  ← ★ FIRST PLAYABLE
                                                        └── F3 server ── F4 … F8
```

- **F0 · Scaffolding + two forking spikes (1–2 wks).** Migration, pinned toolchain,
  CI skeleton, `CLAUDE.md`. *Spike A (½ day):* three Zod schemas → OpenAPI → Dart,
  and **read the generated code**; run the generator twice and compare bytes — if
  it is not deterministic, the diff gate does not exist. *Spike B (2 days):* render
  **the ugliest expression in v1 with the thick black outline applied**, not a
  clean `1/2`.
- **F1 · `packages/core` (3–5 wks).** Highest TDD density. The schema also freezes
  here, which is why the legal consult belongs **before F1**, not before F2.
- **F1.5 · Pack builder CLI (2–4 days).** Emits the same format the server will
  later emit, including labelled distractors with `explain` copy in es-MX —
  without those the error screen degrades to "incorrecto", and offline is 100% of F2.
- **F1b · Compositor + design system (parallel, 4–6 wks).**
- **F2 · App core loop (4–6 wks).** ★ **Five items played on a plane, no account,
  no server.**
- **F3 · Server (3–4 wks)** — replaces the file with the endpoint, client model
  unchanged. Includes `DELETE /v1/me` **and the web deletion page**, which Play
  requires and which is not optional.
- **F4** ladder calibration · **F5** skill map · **F6** puzzles (KenKen, Kakuro) ·
  **F7** profile/settings/edge states · **F8** Rive.

**Rating never runs in Dart.** Offline, difficulty is fixed by the pack's
`ladder_step`; rating is the server's exclusive authority.

---

## 10 · The five risks that actually kill this

**R1 · Nothing playable in 8 weeks and momentum dies.** Solo dev, no revenue. The
concrete mechanism is the math compositor: it is the only thing between F0 and
playable, and every estimate underrates it roughly 2× — the week of visual
iteration fitting a thick outline onto thin glyphs is in nobody's plan.
*Early signal:* spike B passes two days without one legible nested fraction with
the outline on. Second: week 8 with nothing playable on the phone.

**R2 · Silent drift between TS grading and Dart grading.** `draft.md` claims "zero
equivalence logic in Dart" and that is false: per-item hashing forces porting
`Canon`, `projectForSpec`, HMAC, ten-plus rejection rules, and `CHAR_MAP`. When it
drifts, a child sees "incorrecto" offline and "correcto" on sync — with no
third-party telemetry to catch it and no broken build to announce it. It is the
worst bug the system can have: it punishes a child for a parsing bug.
*Early signal:* `contract/fixtures/` does not exist, or exists without **rejection**
rows (`""`, `"1/0"`, `"x+1"`, U+0660, U+2212, ZWSP, combining marks). Without those
the fixture only tests one direction.

**R3 · Content is the speed ceiling, not code.** 12–15 nodes × ≥3 templates ×
verified uniqueness × diagnostic copy in es-MX. It is the one body of work that
**does not parallelize with agents**, and it sets the pace of the entire project.
*Early signal:* F1 ends with any map node under three templates; or the uniqueness
rule library has under 20 rules.

**R4 · Minors compliance arrives after the schema is frozen.** Three concrete
items in no current plan: the **web deletion URL** Play demands; that Better Auth
keeps the hash in `account` and the email in `verification`, so the proposed
deletion test would go green over data still sitting there; and that amended COPPA
requires a **written retention policy** and forbids indefinite retention — which
collides head-on with keeping `attempts` forever.
*Early signal:* a TestFlight or internal-test build without `DELETE /v1/me`, without
the web page, and without a retention figure written down.

**R5 · Agents erode invariants that live only in prose.** See §7.
*Early signal:* a PR touching `pubspec.yaml`, `package.json`, `AndroidManifest.xml`,
`PrivacyInfo.xcprivacy`, or any migration **when the task did not ask for it**.

---

## 11 · Open questions — only you can answer these

**1 · Which countries ship in v1: Mexico only, or the US too?** Blocks the schema,
and the schema freezes in F1. Mexico only: the LFPDPPP in force contains no article
specific to minors — what bites is LGDNNA arts. 76–77 plus a pending regulation.
Add the US and COPPA brings verifiable parental consent, **and Texas SB2420 has
been in force since 2026-01-01**, imposing obligations on the *developer* (Declared
Age Range API, Significant Change API via PermissionKit), not just the store. That
turns "publish in the US" from an email flow into integrating two iOS frameworks
with real iOS/Android divergence.
*Default if unanswered:* Mexico and Spanish-speaking LatAm, technically ready for
COPPA (minimization, no third parties, deletion) without building verifiable consent.

**2 · Do you accept that the first playable build has no account and no sync?**
It is the premise of the entire critical path. If you need early TestFlight with
persistent progress, the server returns to the critical path and playable slips a
full phase. *Default:* yes.

**3 · What monthly infrastructure spend are you willing to carry?** This changes
schema decisions, not just ops. Neon Free is 0.5 GB and **100 CU-hours per project
per month** — at 0.25 CU that is 400 h against the month's 720, and with a
non-disableable 5-minute autosuspend, mere reachability during waking hours is
~105 CU-h. Exhausting it **suspends the project until the next billing period**: a
multi-day outage. CI with branch-per-PR plus a four-agent swarm is plausibly the
dominant consumer before the first user exists.
*Default:* Free throughout development with a **separate Neon project for CI**;
`akimath-prod` on Launch (~$5–19/mo) at public launch. `attempts` retained 400
days, `diag_events` 30.

**4 · Free entry for all item families, or does some family need multiple choice?**
With multiple choice the answer travels in the payload by construction, so the
"answer never travels" invariant is false online and the protection becomes
server-side regrading, not cryptography. It also decides the per-template keypad,
the `AnswerSpec`, and whether distractors are on-screen options or a server-side
diagnostic table. *Default:* free entry everywhere; labelled distractors used
server-side only.

**5 · Will there be a leaderboard?** It decides whether a `display_name` written by
a minor exists — free text traveling to a server and shown to others, with its own
moderation, reporting, and retention. *Default:* no. Own percentile against your
cohort, a batch-recomputed `rating_distribution`, hard k-anonymity (cohort < 100 →
`percentile: null`), zero new columns on `players`.

**6 · Will anything ever be open-sourced, or the backend handed to a third party?**
The only question whose answer reverses §1, and the only condition under which
melos regains value. *Default:* no. If it ever applies, `git filter-repo` splits it
in an afternoon.

---

*None of the above is legal advice. The consult with someone specialized in
children's data protection belongs **before F1**, not before F2 — `players`,
`age_band`, deletion semantics, and the retention policy are schema decisions made
there.*
