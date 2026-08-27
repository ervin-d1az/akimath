## Purpose

The published page that erases an account without the app: what it is reachable from, what it
says, what it must never say, and how the request it makes is authenticated when the whole point
is that the visitor has no session.

## ADDED Requirements

### Requirement: req-web-deletion-is-reachable-without-the-app · The page needs nothing installed and nothing signed in

The system SHALL publish a static page that requests erasure with no app install, no login SDK
and no session, and the emitted HTML SHALL reference no origin other than its own.

#### Scenario: The page is fetched by someone who has never installed the app

- **WHEN** the published page is loaded
- **THEN** it renders its form with no session, because Play requires the deletion route to work
  for a person who has uninstalled the app or never had it
  → `packages/web/test/deletion_page.test.ts`

#### Scenario: The page makes no third-party request

- **WHEN** the built HTML is swept for `src`, `href`, `srcset`, `@import`, `url(` and every
  fetchable attribute
- **THEN** every one of them is same-origin or a data URI — no script, no font, no image, no
  stylesheet and no analytics from anywhere else, which is DEP-1 applied to a page rather than to
  a package
  → `packages/web/test/deletion_page.test.ts`

#### Scenario: The page carries no third-party script even in comments

- **WHEN** the built HTML is swept for a host name
- **THEN** none appears, because a commented-out tag is one uncomment away from being a request
  and the sweep above would not see it
  → `packages/web/test/deletion_page.test.ts`

### Requirement: req-the-page-has-three-states · Requested, expired and done are pages, not messages

The page SHALL render exactly three outcome states — *requested*, *link expired* and *done* —
each a full page reachable by its own address, and SHALL render the *done* state only after an
erasure has actually run.

#### Scenario: The form is submitted

- **WHEN** an address is submitted
- **THEN** the *requested* state renders, saying that if that address has an account a link is on
  its way, because saying anything more specific is the enumeration leak this flow exists to avoid
  → `packages/web/test/deletion_page.test.ts`

#### Scenario: A spent, expired or unknown link is followed

- **WHEN** a link is followed whose token has expired, was never issued, or does not parse
- **THEN** the *link expired* state renders, identically for all three, because a stranger
  guessing tokens must not be able to tell an expired one from an invented one
  → `packages/web/test/deletion_page.test.ts`,
  `packages/server/test/deletion-web.test.ts`

#### Scenario: The erasure runs

- **WHEN** a valid link is followed and the erasure completes
- **THEN** the *done* state renders, and it is the only state that says anything has been deleted
  → `packages/web/test/deletion_page.test.ts`

#### Scenario: A completed link is followed again

- **WHEN** the same link is followed a second time
- **THEN** the *done* state renders again rather than *link expired*, because whoever presents it
  held the link and the post-state is the one they asked for — sending them back round the loop
  for something already finished is the failure this distinction prevents
  → `packages/server/test/deletion-web.test.ts`

### Requirement: req-the-page-does-not-promise-the-identity · The copy states what survives erasure

The page SHALL state, on the state that confirms the erasure, that the Neon Auth account, the
email address and the sign-in survive it, and SHALL NOT claim the account has been deleted.

#### Scenario: The done state is read

- **WHEN** the *done* state's copy is read
- **THEN** it names what was deleted, names that the address and the sign-in remain, and says that
  removing those is a separate act at the identity provider — the same scope
  `contract/openapi.json`'s `deleteMe.description` and `packages/server/src/erasure.ts` state,
  because a reader who stops here believing they are finished is worse off than one who never
  found the page
  → `packages/web/test/deletion_copy_test.ts`

#### Scenario: No state overclaims

- **WHEN** all three states' copy is swept for a claim that the account, the email or the sign-in
  is gone
- **THEN** none makes one, over every state rather than over the one that was written last
  → `packages/web/test/deletion_copy_test.ts`

### Requirement: req-the-page-reads-as-a-person · A child may read this page

Every string the page renders SHALL be Mexican Spanish, SHALL name no protocol artifact, and the
*link expired* state SHALL NOT read as a refusal.

#### Scenario: The copy is swept for the system talking

- **WHEN** every rendered string is swept
- **THEN** none contains `error`, `token`, `request`, `id`, an HTTP status or any English, because
  LANG-1 asks for a person talking rather than a system reporting and this is the one page in the
  project a stranger reaches with no app around it to explain it
  → `packages/web/test/deletion_copy_test.ts`

#### Scenario: The expired state is read

- **WHEN** the *link expired* state's copy is read
- **THEN** it says the link stopped working and offers the way to ask for a new one, and blames
  nobody — it is the one page a reader arrives at having done nothing wrong
  → `packages/web/test/deletion_copy_test.ts`

### Requirement: req-the-page-states-the-retention-figures · The promise and the job cannot drift

The page SHALL state how long attempts and diagnosis events are kept, and those figures SHALL be
the ones the retention job enforces.

#### Scenario: The figures are compared to the job's

- **WHEN** the built page's figures are compared to `RETENTION_DAYS`
- **THEN** they are equal, and a change to either alone fails the build — the numbers have a legal
  consequence and a figure with two homes is a figure that will disagree with itself
  → `packages/web/test/deletion_page.test.ts`

#### Scenario: The figures are readable as a sentence

- **WHEN** the page's retention text is read
- **THEN** each figure appears with what it applies to and why it is kept, rather than as a bare
  number, because a retention policy a person cannot read is not a published policy
  → `packages/web/test/deletion_copy_test.ts`

### Requirement: req-the-answer-is-the-same-either-way · A deletion request does not confirm an account exists

The request operation SHALL answer identically for an address that has an account and one that
does not — the same status, the same body, and the same rendered page.

#### Scenario: Two addresses, one answer

- **WHEN** the form is submitted with an address that has an account and with one that does not
- **THEN** the status, the response body and the rendered page are identical, because a difference
  of any kind turns this page into an oracle for whether a given person has an account
  → `packages/server/test/deletion-web.test.ts`

#### Scenario: The answer does not leak through timing

- **WHEN** the two submissions above are compared
- **THEN** the response is not gated on whether the mail was sent, because a request that waits
  for a send and one that does not are distinguishable without reading either body
  → `packages/server/test/deletion-web.test.ts`

#### Scenario: A malformed address is refused the same way for everyone

- **WHEN** a string that is not an address is submitted
- **THEN** the refusal names the field and nothing about accounts
  → `packages/server/test/deletion-web.test.ts`

### Requirement: req-the-link-is-single-use-and-short-lived · A token is spent, not merely valid

The system SHALL store only a hash of each deletion token, SHALL expire it, and SHALL refuse a
token that has already been spent.

#### Scenario: The stored row holds no usable token

- **WHEN** `deletion_requests` is read
- **THEN** it holds a hash and not the token, so a database dump is not a set of live deletion
  links
  → `packages/server/test/deletion-web.test.ts`, CI job `integration`

#### Scenario: A token past its expiry

- **WHEN** a token is presented after its expiry
- **THEN** nothing is erased and the answer is the one an unknown token gets
  → `packages/server/test/deletion-web.test.ts`

#### Scenario: The token is spent after the erasure, never before

- **WHEN** the erasure fails part way
- **THEN** the token is still spendable, because marking it first would spend a link for something
  that did not happen, and `req-erasure-grants` puts the mark and the erasure under different
  roles anyway
  → `packages/server/test/deletion-web.test.ts`, CI job `integration`

### Requirement: req-the-web-path-is-the-same-erasure · One erasure path, two doors

Following the link SHALL run the erasure `DELETE /me` runs, through the same seam, and SHALL leave
the same post-state.

#### Scenario: The post-state is the one DELETE /me leaves

- **WHEN** a valid link is followed for an account with a player
- **THEN** the player row and every row referencing it are gone — attempts, issued items, offline
  packs, skill ratings and diagnosis events — counted table by table rather than trusted to the
  schema, and the aggregates that carry no player identifier are unchanged
  → `packages/server/test/deletion-web.test.ts`, CI job `integration`

#### Scenario: The identity is untouched

- **WHEN** the same erasure completes
- **THEN** the Neon Auth account still exists, because this service holds no credential that could
  remove it and a scenario asserting otherwise would be satisfied only by copy that lies
  → `packages/server/test/deletion-web.test.ts`, CI job `integration`

#### Scenario: There is still one way to erase

- **WHEN** `src/` is swept for `inErasureRole`
- **THEN** the same two files name it, so the web door reaches the erasure rather than opening a
  second one beside it
  → `packages/server/test/one-way-to-erase.test.ts`

#### Scenario: An account that never linked a player

- **WHEN** a valid link is followed for an account with no player row
- **THEN** nothing is erased, the answer is the one a successful erasure gets, and the *done* state
  renders — the account holds nothing this service recorded, which is the post-state that was asked
  for
  → `packages/server/test/deletion-web.test.ts`

### Requirement: req-a-pending-request-expires-on-its-own · The table that holds an account id is swept

The retention job SHALL delete deletion-request rows past their window, and the figure SHALL live
beside the other retention figures.

#### Scenario: A spent or expired request is swept

- **WHEN** the job runs against rows past the window
- **THEN** they are deleted under the retention role, and a run over rows inside it deletes nothing
  → `packages/server/test/retention.test.ts`, CI job `integration`

#### Scenario: The new figure has one home

- **WHEN** the source is enumerated for the figure
- **THEN** it appears only in `packages/server/src/retention.ts`, alongside the two already there
  and under the same test, rather than in a second module
  → `packages/server/test/retention.test.ts`

#### Scenario: The retention role can delete from the new table

- **WHEN** the grant catalogue is enumerated over every table in the schema
- **THEN** `deletion_requests` is a table the retention role may delete from and the request-path
  role may not, which the existing sweep asserts without being told the table's name
  → `packages/server/test/grants.test.ts`, CI job `integration`

### Requirement: req-the-web-package-is-built-by-ci · A new package that no job runs is untested

Continuous integration SHALL run the web package's checks on a change to it.

#### Scenario: A change under the web package

- **WHEN** a pull request touches `packages/web/**`
- **THEN** a job runs its typecheck and its suite, because that path matches none of today's
  `dart`, `ts`, `contract`, `core` or `spec` filters and a package no job runs is a package whose
  tests are decoration
  → `.github/workflows/ci.yml`, asserted by the filter list and the `gate` job's `needs`

#### Scenario: The page is built twice

- **WHEN** the build script runs twice
- **THEN** both runs produce byte-identical HTML and `git diff --exit-code` passes, the same
  determinism gate `contract/` and `pack/starter.json` are held to
  → `packages/web/test/deletion_page.test.ts`, CI job `web`
