# Design

## D1 — A static site, not a route on the Hono server

Three candidates for where the page lives:

| | Argument | Why not |
|---|---|---|
| A route on the API | One deployment, one origin, no CORS | **The API autosuspends on Neon Free.** A deletion route that is down while the database sleeps is a deletion route that fails a store review at the moment somebody checks it. And it makes the page's availability a function of the very service the page exists to delete from. |
| A rendered page from the API | Same, plus server-side state | Same, plus it puts HTML into a service whose `req-every-response-is-json` says one content type. |
| **A static site** | Outlives API downtime; no framework, no script from anywhere; the legal documents land beside it later | Costs an origin, and therefore CORS. Chosen. |

`packages/web/` emits HTML and nothing else. The build is a script — the one adapter — and every
decision it makes (which state, which copy, which figure) is a pure function tested without a
browser, the same split `packages/contract`'s emitter uses.

**Vendor is a default, not a fact.** The requirement is *any host that adds no script to the page*.
GitHub Pages satisfies it at zero cost on a public repository; so do several others. The proposal
hands the choice over rather than spending it.

## D2 — An anonymous operation is named, never inferred

`route()` today refuses every entry in `ALL_ROUTES` without a credential, and `Decision`'s
`dispatch` carries `userId: string`. A public operation is not merely unbuilt — it does not
typecheck.

Three ways to get one, and the third wins:

- **Outside the contract, like `/health`.** `req-secure-by-default`'s second scenario points
  straight at this: *"an unauthenticated operation has to be written deliberately, and `/health`
  is outside this document entirely rather than excused inside it."* Rejected because the
  justification does not transfer. `/health` is an ops probe with no client; this is the most
  client-facing endpoint in the system and the most destructive. Leaving the only public,
  irreversible operation out of the one document that describes the surface is the opposite of
  what that document is for.
- **A session-bearing flow.** There is no session: the whole premise is a visitor who cannot open
  the app. Rejected by the requirement.
- **Inside the contract, with `security: []`, on a named list.** Chosen. `req-secure-by-default`'s
  first half — the requirement is declared once at the root, so nothing is open by *omission* —
  survives intact. Its second half changes from *"no operation overrides it"* to *"only these two
  do, by name, and a third fails the sweep."* That is the deliberate act the scenario's own prose
  anticipated.

`ANONYMOUS_OPERATIONS` is a literal list of two `operationId`s, not a predicate and not a prefix,
for `f3-router` D5's reason: the next public operation must be argued for in the diff.

`Decision` gains `dispatchAnonymous`, a separate variant rather than an optional `userId`. Same
argument as `NoContent` versus an optional `body` two types above it: an optional field makes *"I
forgot the caller"* and *"there is no caller"* indistinguishable, and the handler that erases a
row is the last place to blur those.

## D3 — Resolving an address to an account is the real blocker, and its answer is conditional

A web form offers one thing: an email address. Erasure needs one thing: an `auth_user_id`.
Nothing in this service can get from the first to the second. `players` carries the id and no
address, and the only three occurrences of `neon_auth` under `packages/server` are two comments
and a doc comment — the schema is in the same database and this service holds **no grant on it**.

| | | |
|---|---|---|
| `SELECT (id, email)` on `neon_auth."user"`, to a dedicated read-only role | Smallest thing that works; no new credential, no new vendor, no network hop inside a request | **We may not own the tables.** The grant is against a schema the managed provider owns and migrates on its own schedule |
| A provider REST credential | No coupling to their table shape | No such credential exists in the project; it is a secret to provision, store and rotate, and it puts a network call inside a request path that today has none |
| Store the address ourselves | No lookup at all | A second copy of the one datum the plan is most careful about, in the service that promises it holds no credential. Rejected outright |

**Default: the grant — conditional on a task that runs before the migration is written.**
Task 1.1 checks `\dp neon_auth."user"` and attempts the grant on a throwaway branch. If it is
refused, this change stops and the question goes back to the human with an answer rather than a
guess, because the fallback is a vendor credential and that is not an agent's to provision.

`f3-players-belong-to-an-account` D2 refused a **foreign key** into `neon_auth` on two grounds:
their migration schedule, and an unwritten cascade. A read carries the first and not the second —
a `SELECT` cannot delete anything, and a column that disappears under us is a red integration
suite rather than a silent erasure. That is why the answer here differs from that one, and it is
the whole of the difference.

## D4 — A single-use token is a row, not a signature

`jose` is already a dependency and a signed token needs no table. It also cannot be **spent**: a
stateless token is valid until it expires, however many times it is presented, and the plan asks
for single use.

So `deletion_requests` holds one row per request: the account, `token_hash`, `expires_at`,
`consumed_at`. The token itself is 32 random bytes, and **only its hash is stored** — a database
dump is not a set of live deletion links.

Three token outcomes, three pages, and the split is about who is holding what:

- **valid** → the erasure runs, `consumed_at` is set, the page says *done*;
- **already consumed** → *done* again, because whoever presents it held the link, the post-state
  is the one they asked for, and telling them "expired" would send them round the loop for
  something already finished;
- **expired, unknown or malformed** → *link expired*, one page for all three. An unknown token is
  told nothing an expired one is not, so guessing tokens teaches a stranger nothing.

**Spending the token is the request role's act, and it happens after the erasure.**
`req-erasure-grants` gives the retention role DELETE and *"no INSERT and no UPDATE on any table"*,
so the role that erases cannot also set `consumed_at`. Marking first and erasing second would let
a failed erasure spend a link for something that did not happen; erasing first and marking second
leaves, at worst, a live link to a row that is already gone — and a second use of it erases
nothing, which is the same idempotence `DELETE /me` already has.

The row carries an `auth_user_id` and is therefore personal data with no cascade to remove it —
there is no foreign key into `neon_auth` and, after erasure, no `players` row either. The
retention job sweeps it. That is a **third** figure in `RETENTION_DAYS`, whose comment says the
two there *"appear here and nowhere else"*; it joins them rather than being written somewhere
else, and the enumeration test that keeps that true is widened, not excused.

## D5 — The page says what erasure does not do, in the same breath as what it does

The one sentence this page must not contain is *"your account has been deleted."* It has not
been. `DELETE /me` removes the player row and the five tables that cascade from it;
`packages/server/src/erasure.ts`:18 records why the identity is untouched, and the contract's
`deleteMe.description` says so where both halves of the stack read it.

A page that overclaims here is worse than an absent page: the reader stops, believing they are
finished, and the address and sign-in they wanted gone are still there. So the copy carries three
things, in the reader's order — **what goes**, **what stays**, and **what to do about what
stays** — and the third is honest about being a separate act at the provider rather than a button
we can offer.

**Tone.** LANG-1's rule, applied to a page rather than a widget: a person talking to a child, not
a system reporting. No `error`, no `token`, no `request id`, no English. The *link expired* state
is the test of it — it is the one page a reader arrives at having done nothing wrong, and it must
not read as a rejection.

## D6 — The contract change is expected to be additive, and that is checked rather than claimed

Adding a path is not a breaking change and the `contract` job fails only on breaking ones. Two
things could still make this red, and both are answered by running the gate rather than by
reasoning about it:

- the per-operation `security: []` override, which is the first in the document;
- `req-secure-by-default`'s sweep, which is a **test** and will go red on purpose, in the same
  diff that widens it.

So `tasks.md` re-emits and runs the pinned `oasdiff`, and records its verdict. If it does report a
break, the answer already exists and is a human's: `allow-breaking-contract` on the pull request,
the same shape as `allow-protected-edit`. Pre-declaring the label would be claiming a verdict this
change has not measured.

## D7 — The page needs script, and the reason is a requirement elsewhere

The form has to reach a JSON API on another origin. A plain `<form method="post">` would send
`application/x-www-form-urlencoded` and render whatever came back, which collides with
`req-every-response-is-json` and would put HTML in the API.

So: **inline script, same origin, nothing fetched from anywhere.** `fetch` to the API, and a
`<noscript>` that tells the reader the in-app path under *Ajustes* exists. The confirmation token
travels in the **fragment** of the page URL — never sent to the static host, never in a `Referer`
— and reaches the API in a request body rather than a path, so it stays out of access logs on
both sides.

CORS is therefore part of this change's server surface: an allowlist of exactly the site's origin,
on exactly the two anonymous operations. Not a wildcard — a wildcard would let any page on the
internet spend a token it had somehow obtained.

## D8 — The figure on the page and the figure in the job are one figure

`packages/web` takes `@akimath/server` as a **dev** dependency by `file:` link, reads
`RETENTION_DAYS`, and inlines the numbers at build time. The published page carries no import and
no script from that package; the test compares the built HTML against the module.

The alternative was moving `RETENTION_DAYS` into `packages/contract`, where both sides could
import it as a runtime dependency. Rejected: retention is not part of the wire contract — nothing
about it crosses to a client — and the test that keeps the figures to one home lives in
`packages/server`, so moving the constant moves the gate away from the job it guards. DEP-1's
scope does not reach a dev dependency, and the reason is stated at the declaration as that rule
requires.
