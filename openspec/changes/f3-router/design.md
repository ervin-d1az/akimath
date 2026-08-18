# Design

## D1 — The route table is code, the contract is the check

The table could be *derived* from `contract/openapi.json` at startup, which would make
divergence impossible. It is not, for two reasons: reading a file is IO, and `routing.ts` is
the package's one pure module — the thing every quality gate runs against. A router that
parsed JSON at import time would take the whole surface out of the reach of mutation testing.

So the table is a literal, and a **test** compares it to the contract. That is the same shape
as `canon.golden.json` and the stimulus parity gate: two independent derivations, held equal
by a gate that reports a count.

## D2 — 401, not 501 or 404

Three candidates for "contracted but unbuilt":

| | Says | Problem |
|---|---|---|
| `404` | no such resource | False. `/me` is a resource; it is unbuilt. And a client cannot distinguish it from a typo. |
| `501` | not implemented | True, but **not in the contract** — returning it would make the router emit a status the contract does not declare, which is the exact drift this change exists to close. |
| `401` | no valid session | True — there is no session mechanism at all — **and declared on all eight operations**. |

`401` wins because it is simultaneously honest and on-contract. It also degrades correctly:
when auth lands, the operations that still have no body return `401` for the *old* reason
until they are built, and the change is invisible to a client that never had a session.

## D3 — 405 is added to the contract rather than assumed

OpenAPI describes operations, and `405` is a response to a request that matched a *path* but
no operation on it — so it belongs to no operation, and the conventional workaround is to
declare it on all of them. The alternative was to return `404` for a wrong method and keep the
contract untouched, which collapses the very distinction the requirement is about.

Adding a response is additive, so the `oasdiff` job stays green: a gate that fired on every
addition would train people to switch it off.

## D4 — The matcher is segment-based, not a regular expression

`/packs/{packId}` becomes `["packs", {param}]` and matches on segment count first. A regular
expression built from the template would have to escape the literal segments, and getting that
wrong is a silent routing bug rather than a compile error. Segment comparison has no escaping
and no catastrophic backtracking.

An empty segment does not match a parameter: `/packs/` is a malformed request, not a pack with
an empty id.

## D5 — `/health` is excused by name

The parity gate needs an allowlist, because `/health` is an ops endpoint and does not belong in
a client-facing contract. The allowlist is one literal entry. It is deliberately **not** a
prefix or a predicate: the next route added outside the contract must be argued for in the diff,
which is the whole value of the gate.
