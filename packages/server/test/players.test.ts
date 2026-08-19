import { afterEach, beforeEach, expect, it } from "vitest";

import {
  describeWithDatabase,
  freshDatabase,
  type TestDatabase,
} from "./support/database.js";

const ID = "018f4e3c-0000-7000-8000-000000000001";

describeWithDatabase("a player carries a band and never a name", () => {
  let db: TestDatabase;

  beforeEach(async () => {
    db = await freshDatabase();
  });

  afterEach(async () => {
    await db.close();
  });

  it("a row without a band is refused by the database", async () => {
    await expect(
      db.client.query("INSERT INTO players (id) VALUES ($1)", [ID]),
    ).rejects.toThrow(/age_band/);
  });

  it("a band nobody decided is refused too", async () => {
    // Widening the set is a schema change, never a caller's choice.
    await expect(
      db.client.query(
        "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, $2, gen_random_uuid())",
        [ID, "13_15"],
      ),
    ).rejects.toThrow(/players_age_band_known/);
  });

  it("each of the three decided bands is accepted", async () => {
    // The control. "Everything is refused" would satisfy both tests above and
    // would be a table nobody can write to.
    for (const [index, band] of ["under_13", "13_17", "adult"].entries()) {
      await expect(
        db.client.query(
          "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, $2, gen_random_uuid())",
          [`018f4e3c-0000-7000-8000-00000000000${index + 2}`, band],
        ),
      ).resolves.toBeTruthy();
    }
  });

  it("a row without an account is refused", async () => {
    // ADR 0002: a `players` row exists because somebody linked. There is no
    // unlinked player on the server — an unlinked device holds no session and
    // leaves no row at all.
    await expect(
      db.client.query("INSERT INTO players (id, age_band) VALUES ($1, 'adult')", [ID]),
    ).rejects.toThrow(/auth_user_id/);
  });

  it("two players cannot share one account", async () => {
    // `GET /me` returns a single `playerId`, so two rows under one account is a
    // response the frozen contract cannot express. The day a parent needs two
    // children under one login, that is a product decision and a new shape —
    // not something the schema should have quietly allowed in the meantime.
    const account = "6f2b1c8d-0000-4000-8000-00000000f00d";
    await db.client.query(
      "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', $2)",
      [ID, account],
    );
    await expect(
      db.client.query(
        "INSERT INTO players (id, age_band, auth_user_id) VALUES (gen_random_uuid(), 'adult', $1)",
        [account],
      ),
    ).rejects.toThrow(/players_one_per_account/);
  });

  it("nothing in our schema is a foreign key into the managed auth schema", async () => {
    // `neon_auth` belongs to the provider and migrates on their schedule. A
    // constraint of ours pointing into it makes our tables a reason their
    // migration cannot run — and erasure does not need one, because
    // `DELETE /v1/me` is an explicit path rather than a cascade we would only
    // discover had fired.
    //
    // Swept over every constraint rather than over `players`, because the rule
    // is about the schema and the next table is where it would break.
    const result = await db.client.query<{ constraint_name: string; foreign_schema: string }>(
      `SELECT tc.constraint_name, ccu.table_schema AS foreign_schema
         FROM information_schema.table_constraints tc
         JOIN information_schema.constraint_column_usage ccu
           ON ccu.constraint_name = tc.constraint_name
          AND ccu.constraint_schema = tc.constraint_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'`,
    );

    expect(result.rows.length).toBeGreaterThan(0);
    console.log(`  players · swept ${result.rows.length} foreign key(s)`);
    expect(
      result.rows.filter((row) => row.foreign_schema !== "public").map((row) => row.constraint_name),
    ).toEqual([]);
  });

  // The one table excluded from the sweep below, and the assertion that keeps it
  // one. An exclusion list nobody counts is how the second exclusion gets added
  // without anybody deciding to.
  const SWEEP_EXCLUSIONS = ["schema_migrations"] as const;

  it("exactly one table is excused from the personal-data sweep", () => {
    expect(SWEEP_EXCLUSIONS).toEqual(["schema_migrations"]);
  });

  it("no column anywhere stores a name or a date of birth", async () => {
    // Enumerated over the whole schema rather than over `players`, because the
    // rule is about the schema and the next table is where it would break.
    const result = await db.client.query<{
      table_name: string;
      column_name: string;
    }>(
      // `schema_migrations` is the runner's own ledger and its `name` column
      // holds a filename. It is excluded by name rather than by loosening the
      // pattern, so the pattern stays blunt enough to catch a real one.
      `SELECT table_name, column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name <> ALL($1::text[])
        ORDER BY table_name, column_name`,
      [SWEEP_EXCLUSIONS],
    );

    expect(result.rows.length).toBeGreaterThan(0);
    console.log(`  players · swept ${result.rows.length} columns`);

    const forbidden = /name|birth|dob|nombre|apellido|fecha_nac/i;
    const offenders = result.rows
      // `table_name` and `column_name` are the catalogue's own words, and
      // `template_id`/`template_refs` are not personal data; the check is about
      // columns that would *hold* a person's name.
      .filter((row) => forbidden.test(row.column_name))
      .map((row) => `${row.table_name}.${row.column_name}`);

    expect(offenders, "a column looks like it holds personal data").toEqual([]);
  });

  it("identity is the client's — the id has no server-side default", async () => {
    // ARCHITECTURE.md §5: the app mints a UUIDv7 at first launch so phase-2
    // attempts have a foreign key with no server involved. A default here would
    // silently mint a second identity the device cannot match.
    const result = await db.client.query<{ column_default: string | null }>(
      `SELECT column_default FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'players'
          AND column_name = 'id'`,
    );

    expect(result.rows[0]?.column_default).toBeNull();
  });
});
