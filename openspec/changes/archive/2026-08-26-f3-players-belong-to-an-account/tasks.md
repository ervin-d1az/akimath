## 1. The column

- [x] 1.1 Verify `players` is empty in production before writing a NOT NULL add.
- [x] 1.2 `0003_a_player_belongs_to_an_account.sql`, forward-only.
- [x] 1.3 Regenerate `schema.sql` from a plain PostgreSQL 18.

## 2. The rules

- [x] 2.1 Red → green: a row without an account is refused; two players cannot share one.
- [x] 2.2 Red → green: nothing in `public` is a foreign key into `neon_auth`.
- [x] 2.3 The link-request gate excludes the column by name, and the body cannot set it.

## 3. Evidence

- [x] 3.1 Tier 1 with counts.
- [x] 3.2 Tier 2 on a real PostgreSQL 18: migrate, re-migrate, re-dump.
