## 1. The contract admits the status the router can return

- [ ] 1.1 Red → green: `405` joins the shared error responses; re-emit and confirm `oasdiff`
      reports no breaking change.

## 2. Matching

- [ ] 2.1 Red → green: a segment-based template matcher — a parameter matches one non-empty
      segment, not several and not none.

## 3. Answering

- [ ] 3.1 Red → green: every contracted operation routes and answers `401`.
- [ ] 3.2 Red → green: a known path with an unrouted method answers `405`, an unknown path `404`.
- [ ] 3.3 Red → green: every error body carries `error` and a `message` that is not the tag
      repeated, and validates against the frozen `Error` schema.

## 4. The gate

- [ ] 4.1 Red → green: the parity gate compares the table to `contract/openapi.json` in both
      directions, excusing `GET /health` by name, and reports a count.

## 5. Evidence

- [ ] 5.1 Tier 1 with counts, Tier 1b (`npm run mutation`, `npm run dry`).
