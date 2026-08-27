## 0. Before anything is written

- [ ] 0.1 **Verify the address lookup is possible at all.** Against a throwaway Neon branch, run
      `\dp neon_auth."user"` and attempt `GRANT SELECT (id, email) ON neon_auth."user"` to a test
      role. Report the catalogue output either way. **If the grant is refused, stop here** — D3's
      fallback is a provider credential, which is a human's to provision, and every task below
      that reads an address is blocked on it.

## 1. The page, before there is anything to talk to

- [ ] 1.1 Red → green: `packages/web/` exists, `npm run verify` runs, and the build emits one HTML
      file twice byte-identically → `packages/web/test/deletion_page.test.ts`.
- [ ] 1.2 Red → green: the built HTML references no origin but its own — every fetchable attribute,
      plus a host-name sweep that catches a commented-out tag
      → `packages/web/test/deletion_page.test.ts`.
- [ ] 1.3 Red → green: the four surfaces render — the form and the three states, each at its own
      address → `packages/web/test/deletion_page.test.ts`.
- [ ] 1.4 Red → green: the copy sweep — es-MX only, no protocol artifact, no state claiming the
      account or the sign-in is gone, the *done* state naming what survives, the *expired* state
      blaming nobody → `packages/web/test/deletion_copy_test.ts`. **The strings themselves are
      DR-8** and land as the honest interim the sweep already constrains; the sweep is what makes
      the final copy a drop-in.
- [ ] 1.5 Red → green: the retention figures are inlined from `RETENTION_DAYS` and the built page
      is compared against the module → `packages/web/test/deletion_page.test.ts`. State at the
      `file:` devDependency why DEP-1's allowlist does not reach it (D8).
- [ ] 1.6 Red → green: CI runs the new package — a `packages/web/**` filter, a `web` job, and the
      job in `gate`'s `needs` → `.github/workflows/ci.yml`, verified by pushing a web-only change
      and reading which jobs ran.

## 2. The contract admits two public operations

- [ ] 2.1 Red → green: the two operations are declared, each with a `description` carrying
      `deleteMe`'s scope sentence, and neither request schema admits an account id
      → `packages/contract/test/openapi.test.ts`.
- [ ] 2.2 Red → green: `req-secure-by-default`'s sweep is widened — exactly the two named
      operations may carry `security: []`, a third fails → `packages/contract/test/openapi.test.ts`.
      **This test goes red on purpose in 2.1 and is repaired here, in the same diff.**
- [ ] 2.3 `npm run emit`, commit the artifact, and run the pinned `oasdiff` against `main`.
      **Record its verdict in this file.** Expected non-breaking (D6); if it reports a break, the
      pull request needs `allow-breaking-contract` and that is a human's label.

## 3. The router can dispatch without a caller

- [ ] 3.1 Red → green: `Decision` gains a variant that carries no `userId`, and a public operation
      routed with no credential dispatches instead of answering 401
      → `packages/server/test/routing.test.ts`.
- [ ] 3.2 Red → green: every other contracted operation still answers 401 with no credential, over
      the whole table → `packages/server/test/routing.test.ts`.
- [ ] 3.3 Red → green: a bad credential on a public operation still dispatches
      → `packages/server/test/routing.test.ts`.
- [ ] 3.4 Red → green: the parity gate compares `ANONYMOUS_OPERATIONS` to the contract's empty
      security requirements in both directions and reports a count
      → `packages/server/test/contract-parity.test.ts`.

## 4. The row, the token and the erasure

- [ ] 4.1 Red → green: migration `0009` adds `deletion_requests`, with its grants, and
      `npm run schema:dump` leaves the tree unmoved → `packages/server/test/grants.test.ts`,
      `packages/server/test/migrate.test.ts`. Applied to a local PostgreSQL 18, **not to Neon** —
      recording `0009` in `schema_migrations` there is a production act (`f3-players-belong-to-an-account`
      D5). The pull request needs `allow-protected-edit`.
- [ ] 4.2 Red → green: the request operation resolves an address to an account, stores only a hash
      with an expiry, and answers identically for an address with an account and one without —
      status, body, and not gated on the send → `packages/server/test/deletion-web.test.ts`.
- [ ] 4.3 Red → green: a malformed address is refused naming the field and nothing about accounts
      → `packages/server/test/deletion-web.test.ts`.
- [ ] 4.4 Red → green: the confirmation operation runs the erasure through `inErasureRole`, leaves
      the post-state `DELETE /me` leaves counted table by table, leaves the identity untouched, and
      keeps `one-way-to-erase.test.ts` naming two files
      → `packages/server/test/deletion-web.test.ts`,
      `packages/server/test/one-way-to-erase.test.ts`.
- [ ] 4.5 Red → green: expired, unknown and malformed tokens are one answer; a spent token answers
      *done*; the token is spent after the erasure and survives a failed one
      → `packages/server/test/deletion-web.test.ts`.
- [ ] 4.6 Red → green: an account with no player row answers as a success and erases nothing
      → `packages/server/test/deletion-web.test.ts`.
- [ ] 4.7 Red → green: the retention job sweeps `deletion_requests`, the figure sits beside the
      other two in `retention.ts`, and the enumeration test is widened to cover it
      → `packages/server/test/retention.test.ts`.
- [ ] 4.8 Red → green: CORS admits the site's origin and refuses every other, from a literal
      allowlist → `packages/server/test/deletion-web.test.ts`.

## 5. Sending the mail — blocked on Gate A Q-A8

**Do not start these without an answer.** Q-A8 records *"Default encoded: none. No provider
chosen"*, the provider will hold children's email addresses, and choosing one is a processor
decision with a contract behind it. Nothing in 1–4 is blocked by this; the flow is not usable
until it is done.

- [ ] 5.1 DEP-1 audit of the chosen provider's client, in
      `packages/server/test/dependency-allowlist.test.ts` beside the entry, in the same change.
- [ ] 5.2 Red → green: the deletion email is sent for an address with an account and not for one
      without, with the send behind the response → `packages/server/test/deletion-web.test.ts`.
- [ ] 5.3 Red → green: the email's copy passes the same sweep the page's does — es-MX, no protocol
      artifact, no claim the identity is gone → `packages/server/test/deletion_email_copy.test.ts`.

## 6. Publishing — blocked on a human's two decisions

- [ ] 6.1 The site's address is chosen and becomes one constant the page, the CORS allowlist and
      `f3-store-artifacts` all read. **Not three strings.**
- [ ] 6.2 A deploy workflow publishes `packages/web/` on merge to `main`. There is no deploy
      workflow in this repository today; this is the first.
- [ ] 6.3 The API has a public address. Out of this change's scope and on nobody's list — until it
      exists the form reaches nothing, and this change cannot clear R4.

## 7. Evidence

- [ ] 7.1 Tier 1 with counts, in all three TypeScript packages plus the new one, and the
      integration suites against a real PostgreSQL.
- [ ] 7.2 Tier 1b: `npm run mutation` and `npm run dry` in `packages/server` and `packages/web`.
- [ ] 7.3 Tier 2: the page loaded in a browser through all three states, and the flow run end to
      end against the deployed API. **Reachable only after 5 and 6**; state plainly which tier the
      change stopped at if they are still open.
