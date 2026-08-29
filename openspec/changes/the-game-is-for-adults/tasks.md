## 0. Decisions a session cannot take

> **ANSWERED 2026-08-29 — 0.1, 0.3 and the `age_band` question are settled, and two of them change
> what is below.** See `docs/adr/0004-the-game-is-for-adults.md`'s *Amendment: the answers*, which
> is the record; this is the pointer. **0.1 → D3 option 1**, the refusal happens at link time.
> **0.3 → the category refusal stays**, re-grounded, and it does **not** go to
> `docs/decisions/OPEN.md` after all — that file is for what nobody has decided and this was
> decided. **The `age_band` CHECK is left exactly as it is**: no migration `0009`, no narrowing of
> `AGE_BANDS`, no re-emitted contract, and therefore **neither `allow-protected-edit` nor
> `allow-breaking-contract`**. That retires **1.1, 1.2, section 3, section 4 and most of 0.6**, and
> with them the `data-schema`, `api-contract`, `api-client` and `api-transport` delta specs in
> `specs/`, every one of which is written for a set of one — **do not implement them as they
> stand.** Section 2's de-duplication of `link.ts`:23 never depended on the narrowing and stands on
> its own merits. **Section 7 has largely landed elsewhere**, in the change
> `docs-the-adults-only-decisions-are-answered` of 2026-08-29: 7.1, 7.3, 7.4, 7.6 and 7.7 are done,
> 7.2 is done for `CLAUDE.md`, and what is left of it is 7.5's shipping-code comments under
> `app/lib`, 7.8's note to `f3-deletion-web`'s author, and `ARCHITECTURE.md` beyond §1 if that
> change did not reach it. **0.2 and 0.5 are still open**, and 0.5 is now recorded as entry 8 in
> `docs/decisions/OPEN.md`. Nothing below is deleted: a plan whose costing lost is still the record
> of what the choice cost.

**Nothing below section 1 starts until 0.1 is answered**, because option 3 in `design.md` D3 makes
sections 3 and 5 wrong rather than merely different. Sections 1 and 2 are safe under all three and
may start immediately.

- [x] 0.1 **A human picks where the refusal happens** — *answered 2026-08-29: option 1, link time.* — link time (D3 option 1), app open (option 2),
      or store-only (option 3) — and records the choice beside the sibling ADR.
      Check: the ADR names one of the three, and `tasks.md` section 5 is rewritten if it is option 3.
- [ ] 0.2 **The design owner draws the under-18 refusal and writes its es-MX copy**, confirmed
      against the raw `.dc.html` rather than a prose digest. This plan invents no Spanish for it.
      Check: a named screen in the design project, or a written statement that option 3 was chosen
      and no screen is needed.
- [x] 0.3 **A human answers DEP-1's standing "no"** — *answered 2026-08-29: it stays a category
      refusal, re-grounded in ADR 0004's amendment §2, `CLAUDE.md` and DEP-1 itself rather than in
      `OPEN.md`.* — does analytics, ads, attribution and crash
      reporting stay refused as a category, or go back to being asked per dependency under DEP-1?
      Recorded as a new entry in `docs/decisions/OPEN.md`, in the style of the existing five.
      Check: the entry states what the code does today, why that was the safe interim, and what
      reverses it.
- [ ] 0.4 **A human re-scopes the Gate A consult.** Its question to counsel — *"what does a
      general-audience app that owes child protections have to do"* — is now the wrong question, and
      Q-A9 already flags its own premise as unstable.
      Check: `docs/gates/gate-a-childrens-data-consult.md` §2 carries a third dated correction, or a
      successor document exists.
- [ ] 0.5 **A human declares the app-store age rating.** No document swept states one, so this is a
      gap rather than an edit. *Still open as of 2026-08-29: Ervin is researching it separately, and
      the gap itself is now recorded as entry 8 in `docs/decisions/OPEN.md` so it survives the
      archiving of this plan.*
      Check: the rating is written down somewhere `f3-store-artifacts` can read it.
- [ ] 0.6 **A human labels the pull request `allow-protected-edit` and `allow-breaking-contract`,
      and runs `npm run migrate` against Neon after it merges.** Recording `0009` in
      `schema_migrations` makes that file's checksum load-bearing for ever — a production change and
      a person's to make, exactly as `f3-players-belong-to-an-account` recorded.
      Check: both labels on the pull request; `npm run migrate` against Neon reports `applied: 1`,
      and a second run reports `applied: 0`.

## 1. What is true before anything moves

- [ ] 1.1 Census the live `players` rows before the migration is written — the same check
      `f3-players-belong-to-an-account` D3 made before a `NOT NULL` add.
      Check: `select age_band, count(*) from players group by 1` against Neon, its output recorded
      in the pull-request body with its date. A non-adult row is **erased** through the existing
      path, never rewritten with an `UPDATE`.
- [ ] 1.2 Record `oasdiff`'s actual verdict for the narrowing, against the pinned `1.29.1` CI uses.
      Check: the rule id and the exit code, written into `design.md` D4 the way
      `f3-link-carries-the-band` D3 recorded `new-required-request-property`, exit 1. A verdict of
      *not breaking* is a finding about the gate, not a reason to skip the label.

## 2. The band set gets one home, before it gets one value

Independent of every decision in section 0, and worth doing on its own.

- [ ] 2.1 Red: a test asserting that `packages/server/src` states **no** band literal of its own and
      that the reader's set is the committed contract's `PlayerLink.ageBand` enum. It fails on the
      unmodified tree, because `link.ts`:23 retypes the set today — that is the red, and it is a
      real one rather than a comparison of a copy against itself.
      Check: `packages/server/test/link.test.ts` (beside `link-request.test.ts`'s existing
      contract-to-CHECK cross-check), reporting the count it compared.
- [ ] 2.2 Green: `packages/server/src/link.ts` derives its set from `@akimath/contract` instead of
      retyping it, and `const BANDS` at :23 is gone. `link.ts` stays pure — importing a frozen
      literal is not IO (design D5).
      Check: 2.1 goes green; `grep -c '"under_13"' packages/server/src` returns 0; `npm run verify`
      in `packages/server` is green.
- [ ] 2.3 Tier 1b, and labelled as **falsification** rather than as a red: edit the contract's
      `AGE_BANDS` by one character and watch 2.1 fail, then revert. A gate over a value that is now
      derived from one place is exactly the shape that can pass by comparing something to itself,
      and the rulebook's PROC-5 is the only thing that catches it on this stack.
      Check: the failure message quoted in the pull-request body, and the tree unchanged after.
- [ ] 2.4 Green: the chain is closed end to end — contract source → `contract/openapi.json` → the
      server's reader → the `CHECK` — with no hand-retyped copy left in it.
      Check: `packages/server/test/link-request.test.ts` still reports
      `N offered band(s) → N accepted`, with N stated.

## 3. The contract narrows

Blocked on 0.1. Under option 3 this section is deleted and replaced by `design.md` D2's answer (b).

- [ ] 3.1 Red: `AGE_BANDS` is narrowed to `["adult"]` in
      `packages/contract/src/openapi/api-schemas.ts`, and the suite says which assertions were
      standing on three values.
      Check: `packages/contract/test/openapi.test.ts` fails at :373 and at the sweep on :349–366.
- [ ] 3.2 Green: the sweep that finds band enums stops detecting them by the literal `"under_13"`
      and **cannot go vacuous** — it fails at zero enums found and reports the count, the same shape
      as `no_color_literal_test.dart` and `touch_target_test.dart`.
      Check: `packages/contract/test/openapi.test.ts` prints `2 band enums → 1 value each`.
- [ ] 3.3 Green: `ageBand` stays **required** on both `PlayerLink` and `Me`, over one value
      (design D2 answer (a)).
      Check: `packages/contract/test/openapi.test.ts`, and `npm run verify` in `packages/contract`.
- [ ] 3.4 Emit; the tree does not move afterwards.
      Check: `npm run emit` in `packages/contract`, then `git add -A -- contract/` and
      `git diff --cached --exit-code -- contract/`.
- [ ] 3.5 The doc comments at `api-schemas.ts`:144–150 and :157–166 stop arguing for the three-value
      set. They are the strongest written argument against this change and are replaced by the
      reason that is now true, not deleted silently.
      Check: read back; no sentence claims the band routes a player into child protections.

## 4. The schema narrows

Blocked on 1.1. `0001_initial.sql` is not edited — three locks say so (design's proposal, section A).

- [ ] 4.1 Red: a player row with `'13_17'` is still accepted, which is what the new CHECK must stop.
      Check: `packages/server/test/players.test.ts`, against a real PostgreSQL 18.
- [ ] 4.2 Green: `packages/server/migrations/0009_the_only_band_is_adult.sql` — forward-only, drops
      `players_age_band_known` and adds it back over `('adult')`. No backfill and no `UPDATE`.
      Check: `npm run migrate` applies it; a second run reports `applied: 0`.
- [ ] 4.3 Green: `packages/server/test/players.test.ts` accepts `adult` and rejects `under_13`,
      `13_17` and `13_15` alike, reporting `1 permitted band → 1 accepted, 3 refused`.
      Check: the suite, with `TEST_DATABASE_URL` set.
- [ ] 4.4 Regenerate the snapshot; the tree does not move afterwards.
      Check: `npm run schema:dump`, then `git add -A -- packages/server/schema.sql` and
      `git diff --cached --exit-code`.
- [ ] 4.5 Green: every TypeScript suite that seeded a non-adult band is corrected — the list is in
      the proposal's "The tests that go red", and `test/offline-packs.test.ts`:36 dies at setup
      rather than at an assertion, so it is the one to fix first.
      Check: `npm run verify` in `packages/server`, with the green and skipped counts stated.

## 5. The gate refuses instead of routing

Blocked on 0.1 and 0.2. Written for options 1 and 2, which differ only in *where* the refusal is
reached — sections 5.1 to 5.4 are identical under both.

- [ ] 5.1 Red → green: `AgeGate` answers a **refusal** rather than a route for anyone below the
      threshold, and the pure policy still reads no clock and no store.
      Check: `app/test/features/auth/policy/age_gate_test.dart`, and
      `app/test/architecture/pure_boundary_test.dart` still reports `features/*/policy/` covered
      with its file count.
- [ ] 5.2 Red → green: no path in the app can produce a link request naming a band other than
      `adult`, including the sign-in path that reads the band off `GET /me`
      (`auth_flow.dart`:427–438) rather than off the gate.
      Check: `app/test/features/auth/auth_flow_test.dart` and
      `app/test/features/profile/ui/sign_in_door_test.dart`.
- [ ] 5.3 Red → green: `AgeBand` holds one member and `fromWire` still **throws** on anything else
      rather than defaulting, and the parity test agrees with the emitted enum by value and order.
      Check: `app/test/api/contract_parity_test.dart` and `app/test/api/me_test.dart`.
- [ ] 5.4 Red → green: a `shared_preferences` store holding a band this build no longer knows is
      refused rather than coerced — a device that ran an older build can have one on disk
      (`session_store.dart`:123–155).
      Check: `app/test/features/account/data/session_store_test.dart`.
- [ ] 5.5 Red → green: the refusal screen from 0.2 is drawn, is registered, and **offers nothing it
      cannot do** (DR-P2) — it says what remains true and draws no control that cannot act.
      Check: `app/test/features/auth/ui/` plus an entry in `app/test/design/screen_registry.dart`.
- [ ] 5.6 Green: `tutor_consent_screen.dart` is deleted or repurposed, and its registry entry with
      it. Nothing enumerates screen filenames, so a stale file trips no gate — this is a read, not
      a test.
      Check: `grep -rn TutorConsent app/` returns only what 0.2 decided should remain.
- [ ] 5.7 Green: `app/test/features/preferences/link_on_session_test.dart` is rewritten rather than
      retyped — its scenario, an `under13` band travelling verbatim to the link request, cannot
      occur any more and a fixture edit would leave a test asserting nothing.
      Check: the file, read back.

## 6. The gates that would otherwise have gone quiet

- [ ] 6.1 Green: the six suites reading `app/test/design/screen_registry.dart` re-count without being
      edited to fit.
      Check: `screen_overflow_test`, `touch_target_test`, `no_blurred_shadow_test`,
      `quiet_while_you_solve_test` and `screen_text_style_test` at both viewports, with their new
      totals stated against today's 85 screens and 425 presses.
- [ ] 6.2 Green: `packages/server/test/link-request.test.ts`'s `expect(offered.length)
      .toBeGreaterThan(0)` guard is the only thing standing between that sweep and vacuity now, and
      its comment says so.
      Check: the file, read back.
- [ ] 6.3 Green: `app/test/architecture/dependency_allowlist_test.dart` and the three TypeScript
      allowlist tests all still bite — the audience premise changed and the gate did not.
      Check: all four suites, with their package counts stated (5 direct / 28 transitive in `app/`,
      0 in `packages/core`, 6 in `packages/server`, 1 in `packages/contract`).

## 7. The prose that stops being true

One commit per document, so the diff is readable. Category C in the proposal — nothing red, and the
largest surface.

- [ ] 7.1 `openspec/config.yaml`:18–21 and `.claude/conventions/craftsmanship.md`:185–199 (DEP-1),
      **in the same commit** — PROC-7 requires it: *"Edit both in the same commit, or neither."*
      DEP-1 keeps its rule and loses its unconditional (design D6).
      Check: `openspec list` — no `could not parse` on stderr, and the change list still renders.
      **Not** `openspec list --no-interactive`, which CI's config-parse guard runs and which
      `openspec@1.9.0` rejects as an unknown option, exit 1, before it ever reads the file. Found
      while validating this change; out of scope to fix here, and flagged in the pull request.
- [ ] 7.2 `CLAUDE.md`:7–21 and `ARCHITECTURE.md`:21–26 — amended with a third dated correction, not
      rewritten. §5:270–283, §10 R4:488–493 and §11 decisions 1 and 5 follow.
      Check: read back; the record of the 2026-08-17 audience remains legible.
- [ ] 7.3 `docs/adr/0002-neon-auth-and-no-sync-until-linked.md` — an amendment in place, the way it
      already carries the 2026-08-19 one. The decision survives; the reason stops naming a child.
      Check: the ADR's Status still reads Accepted and the amendment is dated.
- [ ] 7.4 The four agent definitions: `.claude/agents/craftsman-engineer.md`:9,
      `craftsman-lead.md`:221–222, `craftsman-reviewer.md`:143, `craftsman-bug-hunter.md`:20 and its
      `description` frontmatter.
      Check: `grep -rn "under 13\|children" .claude/agents/` returns nothing stale.
- [ ] 7.5 The shipping-code comments listed in the proposal's category C, including
      `app/lib/features/account/policy/session.dart`:97–100, which is factually superseded rather
      than merely stale.
      Check: `flutter analyze --fatal-infos` green, and a read-back of each site.
- [ ] 7.6 `app/test/design/touch_target_test.dart`:16–17 and `screen_registry.dart`:74 — the
      justifications change and **the thresholds do not**. 48 px and `textScaler` 1.3 stay exactly
      where they are.
      Check: the constants are unchanged in the diff.
- [ ] 7.7 `docs/IMPLEMENTATION-PLAN.md` — `req-age-gate` at :2122–2144, the routing decision at
      :1553–1560, D13 at :2560 and D21 at :2568 (both citing `CLAUDE.md`:7 by line number), and the
      stale `18_plus` band set at :2164 and :2947, which has disagreed with the live CHECK since the
      2026-08-17 freeze.
      Check: `grep -n "18_plus" docs/IMPLEMENTATION-PLAN.md` returns nothing.
- [ ] 7.8 Tell `f3-deletion-web`'s author that `req-the-page-reads-as-a-person · A child may read
      this page` and four proposal sites are affected. **Not edited from here** — a change's plan
      belongs to that change.
      Check: a note in this change's pull-request body under "what has to happen after it merges".

## 8. Evidence

- [ ] 8.1 Tier 1 with numbers: `flutter analyze --fatal-infos`, `flutter test`, and `npm run verify`
      in all three TypeScript packages, each count stated against today's 3291 Flutter tests, 454
      server tests (325 green / 129 skipped) and 257 contract tests.
- [ ] 8.2 Tier 1b: `npm run mutation` and `npm run dry` in `packages/server` and
      `packages/contract`, quoting a **range** for `packages/contract` rather than a number, and
      using `--tempDirName ../../tmp` there. On the Dart side, the PROC-5 falsification step over
      the new gate in 3.2 and the refusal in 5.1.
- [ ] 8.3 Tier 2 on a real PostgreSQL 18: migrate, re-migrate, re-dump — the shape
      `f3-players-belong-to-an-account` used. **Neon is not touched by a session**; task 0.6's human
      runs `npm run migrate` after the merge.
- [ ] 8.4 Tier 2 on a simulator: the age gate reached and refused, with `integration_test/` run
      explicitly — `flutter test` does not reach it, which is how three suites sat broken for weeks.
