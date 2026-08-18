## 1. The contract admits the status the router can return

- [x] 1.1 Red → green: `405` joins the shared error responses; re-emit and confirm `oasdiff`
      reports no breaking change.

## 2. Matching

- [x] 2.1 Red → green: a segment-based template matcher — a parameter matches one non-empty
      segment, not several and not none.

## 3. Answering

- [x] 3.1 Red → green: every contracted operation routes and answers `401`.
- [x] 3.2 Red → green: a known path with an unrouted method answers `405`, an unknown path `404`.
- [x] 3.3 Red → green: every error body carries `error` and a `message` that is not the tag
      repeated, and validates against the frozen `Error` schema.

## 4. The gate

- [x] 4.1 Red → green: the parity gate compares the table to `contract/openapi.json` in both
      directions, excusing `GET /health` by name, and reports a count.

## 5. Evidence

- [x] 5.1 Tier 1 with counts, Tier 1b (`npm run mutation`, `npm run dry`).
