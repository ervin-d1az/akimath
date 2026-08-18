# Route the API the contract already describes

## Why

`contract/openapi.json` freezes eight operations across seven paths. `packages/server`
routes **one** endpoint, `GET /health`, which is not one of them — so the contract and the
server have never been compared, and nothing would notice if they diverged further. This is
R2 in its API form: two descriptions of the same surface, free to disagree.

Three concrete faults today:

1. **The 404 body does not validate against the frozen contract.** `route()` returns
   `{ error: "not_found" }`; the `Error` schema requires `error` *and* `message`. The one
   error the server can emit is already off-contract.
2. **A contracted path answers 404**, which the contract defines as *"No such resource."*
   `/v1/me` is a resource that exists and is not built; saying "no such resource" is a
   different claim, and a client cannot tell the two apart.
3. **A wrong method is indistinguishable from a wrong path.** `POST /health` and
   `GET /nonsense` return the same body.

## What changes

- `route()` gains a **route table** and a matcher that understands a path template, so
  `/packs/{packId}` matches `/packs/2f1c…`. Still pure: method and path in, status and body
  out.
- **Every contracted operation is routed, and answers `401` until auth exists.** The
  contract declares `401 — No valid session` on all eight, and there is no session mechanism
  at all, so that is not a placeholder: it is the true answer. A client that gets 401 from
  `GET /v1/me` learns something correct.
- **A known path with an unrouted method answers `405`**, and `405` is added to the shared
  error responses in the emitted contract — additive, so `oasdiff` stays green.
- **Every error body carries `error` and `message`**, so every response the router can
  produce validates against the frozen `Error` schema.
- **A parity gate** compares the route table to `contract/openapi.json` and fails on a
  mismatch in either direction, reporting a count. `GET /health` is the one route outside the
  contract and is excused **by name**, as an ops endpoint, not by a wildcard.

## Out of scope

Auth, and any operation's real behaviour. This change makes the surface true; it implements
none of it. `GET /health` keeps its current body.
