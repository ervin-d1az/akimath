# Erasure is reachable from the open web, without the app

## Why

Phase **F3**. `ARCHITECTURE.md` §9 lists it inside F3 by name: *"Includes `DELETE /v1/me`
**and the web deletion page**, which Play requires and which is not optional."*
`docs/IMPLEMENTATION-PLAN.md`:2023 carries it as `f3-deletion-web`.

`DELETE /me` is built. `packages/server/src/erasure.ts` runs it under `SET LOCAL ROLE
retention_job`, `test/delete-me.test.ts` counts the rows in every referencing table, and
`app/lib/features/preferences/` gives it a door in Ajustes. **Every one of those paths starts
inside the app.** Play requires the deletion route to be reachable *without installing it*, and
there is no such route: no page, no operation, no host.

Four concrete faults today:

1. **Counsel has been told the page does not exist, and it is on the consult as an open item.**
   `docs/gates/gate-a-adult-data-consult.md` §3.1, the closing bullet of what is collected:
   *"The public deletion page does not exist yet. Erasure is available inside the app. The page
   that works without installing the app is designed and unbuilt (`f3-deletion-web`), which also
   means the retention figures in Q-A7 are published nowhere user-facing today."* Q-A6 carries it
   again as *"also open, and unbuilt"*. **This fault read the other way round when it was
   written**, and both halves of that citation have since moved: the 2026-08-16 children's brief
   promised counsel that everything its §2.1 lists is deleted *"both inside the app and from a
   public web page that works without installing the app"*, the promise was withdrawn on
   2026-08-26 for the plain statement quoted above, and the brief itself was superseded on
   2026-08-29 by the adults-only one and stamped *do not send*. Cited by section rather than by
   line, because the line number this list carried was already three lines stale on the day it
   was written.
2. **The service cannot find an account by its email address.** `players` holds `auth_user_id`
   and no address; `grep -rn neon_auth packages/server/migrations/` returns **nothing but a
   comment**. The one thing a web form can offer is the one thing the server cannot resolve.
3. **An unauthenticated contracted operation is unrepresentable.** `route()` answers `401` to
   `caller.kind === "absent"` for **every** entry in `ALL_ROUTES`, and `Decision`'s `dispatch`
   variant carries a non-optional `userId`. There is no way to express a public operation except
   the way `/health` does it — outside the contract entirely.
4. **The retention figures reach nobody.** `RETENTION_DAYS` is 400 and 30 in
   `packages/server/src/retention.ts`, the nightly job enforces them, and no surface a person can
   read states them. `gaps.md` §4.5 and Q-A7 both name this.

## What changes

- **`packages/web/` — a static site, no framework, no analytics, no remote font, no external
  request of any kind.** Three pages' worth of state on one route: *requested* · *link expired* ·
  *done*, plus the form itself. es-MX copy, written for a reader who may be a child (DR-8, LANG-1).
- **The page states the retention figures, read from `RETENTION_DAYS` at build time**, and a test
  fails the build if the published text and the module disagree. The promise and the job cannot
  drift.
- **Two new contracted operations**, `POST /deletion-requests` and `POST /deletion-confirmations`,
  the only two in the document that carry `security: []`. Adding them is additive; the emitted
  document is re-emitted and `oasdiff` re-run as a task, not asserted here (D6).
- **`ANONYMOUS_OPERATIONS`** — a named literal in `routing.ts`, and a `Decision` variant that
  dispatches with no `userId`. Named, never a predicate: the same shape `f3-router` D5 gave
  `GET /health`.
- **`deletion_requests`** — one table, forward-only migration: the account, a **hash** of the
  token, an expiry and a `consumed_at`. Single use needs state; a signed stateless token cannot be
  spent.
- **The response is identical for an address with an account and one without** — status, body and
  rendered page. That behaviour is already specified in the plan; this change is where it acquires
  a test.
- **Following the link runs the same erasure `DELETE /me` runs**, through the same
  `inErasureRole` seam, so `test/one-way-to-erase.test.ts` keeps naming two files and the erasure
  path stays one path.
- **The copy says what erasure does and does not do.** The player row and everything referencing
  it go; **the Neon Auth account, the email and the sign-in survive** — identity lives in the
  provider's schema and this service holds no credential that could remove it. That is
  `contract/openapi.json`'s own `deleteMe.description` and `packages/server/src/erasure.ts`:18,
  carried into es-MX.
- **`packages/web/**` gets a CI filter and a job.** It matches none of `dart`, `ts`, `contract`,
  `core` or `spec` today, so a new package's suite would never run on a pull request.

## Out of scope

- **The aviso de privacidad and the términos.** They belong on the same site for the same reason
  (`req-legal-reachable`), and they are authored documents in R3's budget with an owner in Gate A
  Q-A10. This change builds the site that will hold them and publishes one page on it.
- **`Pedir mi archivo`.** The export rides the same email path and is Q-A6, undecided.
- **Anything that deletes the identity.** Out of scope because it is out of reach, not because it
  is deferred — see D5.
- **`f3-store-artifacts`.** It declares this page's URL in Data Safety and is the change after
  this one.
- **The final es-MX wording.** The states, the tone rule and every claim the copy must and must
  not make are specified here; the sentences themselves are DR-8 content in R3's budget.

## The plan text this change contradicts, deliberately

`docs/IMPLEMENTATION-PLAN.md`:2069 states, as `req-web-deletion`'s second scenario, that after the
emailed link is followed *"`account.password` and `verification.identifier` hold no row for that
user."* **This change does not promise that and its scenarios do not assert it.** That post-state
belongs to `f3-server-foundation`'s `req-deletion-completeness`, which is unbuilt, and it is
directly disclaimed by the shipped contract:

> This does not delete the Neon Auth account — the email and the sign-in survive it, and removing
> those is a separate act at the identity provider.

Writing the plan's sentence into a spec would either fail the build for ever or, worse, be
satisfied by copy that tells a parent their child's account is gone when it is not. The scenario
below asserts **the same post-state `DELETE /me` produces**, and the difference is named in the
page's own words rather than hidden.

## Gate A, and what this change may and may not do while it is deferred

**Partly. The static half can proceed; nothing that sends mail can.**

Gate A is *"Deferred, deliberately — Ervin, 2026-08-16"*, and its §7 lists four tripwires that
reopen it. The fourth is **"The server exists and holds a real person's row."** The provisioned
Neon project is **reported** to hold a player row and two verified accounts as of 2026-08-26 —
reported, not measured here: `TEST_DATABASE_URL` is deliberately unset on this machine and
querying the live project is a production read nobody asked for. If it holds, that tripwire is
met and the deferral no longer rests on its own stated ground. **Confirm it before touching §7**,
and flipping that checkbox is Ervin's rather than an agent's — it is his deferral decision.

What can be built with the gate exactly as it stands, because each has a default recorded in the
plan's own idiom:

- the page, its three states, the tone rule and the copy's claims (DR-8);
- the retention figures on the page and the drift test (Q-A7 default: 400 and 30, published on
  this page, read from the source the job reads);
- the enumeration-safe response, the token, the table and the erasure call;
- the anonymous operation and its gates.

What cannot, because it has **no default at all**:

- **sending the email.** Q-A8 reads *"Default encoded: none. No provider chosen"*, and this flow
  cannot exist without one. The provider will hold children's email addresses and is *"the only
  external company that will ever hold any personal data of ours"*. That is a processor decision
  with a contract behind it, not an implementation detail.

It looks as though an email path already exists, and it does not: Neon Auth sends the verification
mail for the two accounts that exist today, from the provider's own sender. Managed Better Auth
exposes no way to send an arbitrary message, so nothing in the system today can put a link in
somebody's inbox.

## What a human has to do

Four things, and none of them can be done from here.

1. **Answer Gate A Q-A8 and choose the transactional email provider.** Tasks 5.1–5.3 are blocked
   on it and are marked so. Everything before task 5 is not.
2. **Decide where the API runs.** There is no deployment of anything and no deploy workflow. A
   page whose form reaches nothing is not a deletion route, so this change reaches Tier 1 and
   Tier 1b on its own and reaches Tier 2 — and clears R4 — only after the API has a public
   address. Naming that is out of this change's scope and is on nobody's list today.
3. **Decide the site's address, and register a domain if it is to have one.** The plan's *"the
   project's own domain"* is a default with nothing behind it: no domain is registered.
   The cheapest honest option is **GitHub Pages on this public repository — $0, no new vendor,
   no new account, a workflow in a repository that already runs Actions** — at
   `https://ervin-d1az.github.io/akimath/borrar-cuenta`, which Play accepts. A custom domain is
   roughly $10–15 a year and is an upgrade, not a requirement. Either way the URL becomes a
   constant `f3-store-artifacts` reads, so choosing late is cheap and changing it later is not.
4. **Label the pull request `allow-protected-edit`, and run `npm run migrate` against Neon after
   it merges.** The change adds migration `0009` and re-dumps `schema.sql`. It also needs a
   read on `neon_auth."user"`, which may not be ours to grant — see D3, whose verification task
   comes before the migration is written and may hand this question back.
