## 1. The client

- [x] 1.1 Shim `pg_dump` into the service container; verify it reports a version.
- [x] 1.2 `createdb` from the container too, so no runner client is needed.

## 2. The bound

- [x] 2.1 `timeout-minutes` on both steps.

## 3. Evidence

- [x] 3.1 The shim generated and its argument passthrough checked locally.
- [x] 3.2 CI green, with the snapshot diff still comparing bytes.
