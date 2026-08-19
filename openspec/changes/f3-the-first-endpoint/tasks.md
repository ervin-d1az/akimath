## 1. The seam

- [x] 1.1 Red → green: work runs as `app_request` and the grants bite through it.
- [x] 1.2 The role does not outlive the transaction; a failure rolls back; the connection returns.

## 2. Dispatch

- [x] 2.1 The route table carries the contract's `operationId`, checked against it.
- [x] 2.2 `route()` answers or dispatches; only a verified caller reaches a handler.
- [x] 2.3 The 501 list is `IMPLEMENTED_OPERATIONS` inverted, checked both ways.

## 3. GET /me

- [x] 3.1 Red → green: the pure answer, including the `date-time` the frozen pattern demands.
- [x] 3.2 Red → green against a real database: the right player, never another's, 404 for none.
- [x] 3.3 A failure says nothing to the client and everything to the log.
- [x] 3.4 A `sub` that is not an account id is refused at verification.

## 4. Evidence

- [x] 4.1 Tier 1 with counts.
- [x] 4.2 Tier 1b: mutation read and acted on; a gate that had never really run, fixed.
- [x] 4.3 Tier 2: the real `main.ts`, a real JWKS, a real PostgreSQL.
