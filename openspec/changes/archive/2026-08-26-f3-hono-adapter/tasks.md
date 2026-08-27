## 1. The dependency

- [x] 1.1 DEP-1 audit for both packages, recorded in the allowlist as the rule requires.
- [x] 1.2 Both pinned exactly; the gate reports three runtime packages.

## 2. The adapter

- [x] 2.1 Red → green: the transport returns exactly what the policy decided.
- [x] 2.2 Red → green: an unregistered path and a wrong method reach the policy, not Hono's own
      handlers.
- [x] 2.3 Red → green: a query string is not part of the path.

## 3. Evidence

- [x] 3.1 Tier 1 with counts, and the server called for real over a socket.
