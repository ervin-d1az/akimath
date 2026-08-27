## 1. The policy

- [x] 1.1 Red → green: reading the request, including the header and the
      unknown properties.
- [x] 1.2 Red → green: the four-way outcome, including the rows disagreeing.

## 2. The endpoint

- [x] 2.1 409 on the contract; not breaking, per oasdiff.
- [x] 2.2 The handler seam takes the whole request.
- [x] 2.3 One transaction for both reads and the write.

## 3. The client

- [x] 3.1 `ApiClient.linkPlayer` with its own sealed result, over a real socket.
- [x] 3.2 The parity gate covers the operation, its statuses and its header.

## 4. Evidence

- [x] 4.1 Tier 1 with counts, both stacks.
- [x] 4.2 Tier 1b: mutation read and acted on.
- [x] 4.3 Tier 2: the real clients against real Neon Auth and real Postgres.
