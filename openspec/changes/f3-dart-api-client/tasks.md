## 1. The model

- [x] 1.1 Red → green: the three frozen fields, the band enum, refusals for a missing field, a
      wrong type and an unknown band.
- [x] 1.2 Red → green: `createdAt` accepts what the pattern accepts and nothing else.

## 2. The gate

- [x] 2.1 Both directions against `contract/openapi.json`, with a count, thrown at load if absent.
- [x] 2.2 The re-derived date rules checked against the frozen pattern over 19 probes.
- [x] 2.3 The one unvalidated field named with its reason, and asserted to be real.

## 3. The client

- [x] 3.1 Red → green over a real `HttpServer`: 200, 401 with its tag, 404, 500, 501.
- [x] 3.2 A 200 that is not a `Me`, a body that is not JSON, an HTML error page.
- [x] 3.3 A refused socket and a server that never answers.

## 4. Evidence

- [x] 4.1 Tier 1: the whole Flutter suite, and `analyze --fatal-infos`.
- [x] 4.2 Tier 2: the real client against the real server, and the defect it found, fixed.
