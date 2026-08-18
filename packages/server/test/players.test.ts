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
        "INSERT INTO players (id, age_band) VALUES ($1, $2)",
        [ID, "13_15"],
      ),
    ).rejects.toThrow(/players_age_band_known/);
  });

  it("each of the three decided bands is accepted", async () => {
    // The control. "Everything is refused" would satisfy both tests above and
    // would be a table nobody can write to.
    for (const [index, band] of ["under_13", "13_17", "adult"].entries()) {
      await expect(
        db.client.query("INSERT INTO players (id, age_band) VALUES ($1, $2)", [
          `018f4e3c-0000-7000-8000-00000000000${index + 2}`,
          band,
        ]),
      ).resolves.toBeTruthy();
    }
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
