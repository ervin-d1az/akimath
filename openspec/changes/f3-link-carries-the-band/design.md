# Design

## D1 — The band travels with the link; it is not read off the account

ADR 0002 says linking is an adult's act. The tempting shortcut is to conclude that a linked player
is therefore an adult and set the band from the credential.

That is the one mistake `age_band` exists to prevent. `CLAUDE.md` is explicit that the band is
*"the routing decision that sends a player into child protections or not"*, and the adult who
creates an account is often not the player — a parent linking a child's device is the ordinary
case, not the edge one. Reading `adult` off the credential would route that child out of their own
protections, silently, with no error anywhere.

So the band is the device's to declare, resolved before any session exists, exactly as the
migration's comment already requires. What ADR 0002 changed is *when* it arrives, not *who* decides
it.

## D2 — The gate compares two artifacts, not two beliefs

`contract/openapi.json` and `migrations/` are both frozen and nothing forces them to agree. The way
they disagree is silent: the contract emits, the migration applies, and the mismatch surfaces only
in a handler nobody has written. That is the R2 failure mode — the Dart/TypeScript drift the
`contract/fixtures/` gates exist for — reappearing between the contract and the schema.

So the new test reads the **committed artifact** through `test/support/contract.ts` and the
**applied schema** through `information_schema`, and neither through the TypeScript that produced
it. It resolves the request body from `POST /players/link` rather than naming `PlayerLink`: a gate
that names a schema goes green the day the operation points at a different one.

The column-to-property spelling is snake-to-camel with one named exception, `id` → `playerId`. A
map entry rather than a rule, so a second exception has to be typed by somebody who meant it.

## D3 — The escape is a label, not an ignore file

This change is breaking by `oasdiff`'s own classification — verified locally against the pinned
`1.29.1`: `new-required-request-property`, exit 1. Three ways to land it:

- **`--err-ignore` file.** Rejected. The pattern keeps matching after the break has merged, so it
  silences the *next* identical break too, and nothing ever prunes it.
- **Relax `--fail-on`.** Rejected outright — that is deleting the gate.
- **A pull-request label.** Chosen. It is what `protected-paths` already does in this repository,
  including the carve-out for push events, which carry no pull request and therefore no label.

Simulated all four ways before committing: unlabelled → 1, labelled → 0, push → 0, and a lookalike
label (`allow-breaking-contract-please`) → 1, because the match is comma-delimited.

## D4 — Why this is cheap now

Nothing consumes the contract. `app/lib/api/` does not exist, the endpoint returns 401, and there
is no client anywhere. The same change after a client ships costs a version negotiation. That is
the whole argument for making it today rather than when the handler is written.

## D5 — The gate it escapes had never run

Pushing this change proved the escape by not needing it: the `contract` job went green on a
breaking change with no label at all.

`actions/checkout@v7` defaults to a shallow clone of one commit, and the step's own guard reads

```sh
git cat-file -e "$BASE:contract/openapi.json"
```

which is false when the **path** is absent and equally false when the **commit** is absent. With
no base commit in the object database it took the second for the first, printed *"this is its
first appearance"*, and exited 0 — on every pull request since the gate landed. `protected-paths`
checks out with `fetch-depth: 0` and has always worked; this job never asked for one.

Two fixes, because either alone leaves the trap: the checkout is deepened, **and** the commit is
now asked about separately, with its absence treated as a broken gate rather than a passing one.
That is PROC-10 in its original form — a gate that cannot tell "nothing is wrong" from "nothing
was checked" is not a gate — and the repository's own comments warn about it in three other
places.

A gate nobody has seen run also has no measured false-positive rate. `contract/` holds three
schemas, thirty-seven fixtures and `canon.golden.json` besides `openapi.json`, and the `changes`
filter starts this job for any of them — so the common case from now on is a pull request whose
`openapi.json` is **identical** to the base. Simulated that too, with the document restored to the
base bytes: *"No changes detected"*, exit 0. Everyone else's pull requests still pass.
