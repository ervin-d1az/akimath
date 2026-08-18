import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { runMigrations } from "../src/adapters/migrate-runner.js";
import { planMigrations, type AppliedMigration, type MigrationFile } from "../src/migrate.js";
import {
  MIGRATIONS_DIR,
  describeWithDatabase,
  emptyDatabase,
  fixtures,
  type TestDatabase,
} from "./support/database.js";

const file = (name: string, checksum: string): MigrationFile => ({
  name,
  checksum,
});

const applied = (name: string, checksum: string): AppliedMigration => ({
  name,
  checksum,
});

describe("the planner returns what is left to apply, in order", () => {
  it("an empty database gets every file, sorted by name", () => {
    const plan = planMigrations({
      onDisk: [
        file("0002_second.sql", "bbb"),
        file("0001_first.sql", "aaa"),
        file("0010_tenth.sql", "ccc"),
      ],
      applied: [],
    });

    expect(plan.ok).toBe(true);
    expect(plan.ok && plan.pending.map((m) => m.name)).toEqual([
      "0001_first.sql",
      "0002_second.sql",
      "0010_tenth.sql",
    ]);
  });

  it("sorts by name and not by the order they were read", () => {
    // A directory read is not sorted, and `0010` must not land before `0002`
    // just because a filesystem handed it over first. Zero-padded names make
    // lexicographic order the right order; this is what pins that.
    const plan = planMigrations({
      onDisk: [file("0010_tenth.sql", "c"), file("0002_second.sql", "b")],
      applied: [],
    });

    expect(plan.ok && plan.pending.map((m) => m.name)).toEqual([
      "0002_second.sql",
      "0010_tenth.sql",
    ]);
  });

  it("a fully applied database gets nothing", () => {
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "aaa")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(true);
    expect(plan.ok && plan.pending).toEqual([]);
  });

  it("a partially applied database gets only the rest", () => {
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "aaa"), file("0002_second.sql", "bbb")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok && plan.pending.map((m) => m.name)).toEqual([
      "0002_second.sql",
    ]);
  });
});

describe("a migration edited after it shipped stops the runner", () => {
  it("the refusal names the file", () => {
    // Naming it is the whole point. An error that says "checksum mismatch" and
    // nothing else leaves a human diffing eleven files by hand.
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "EDITED")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(false);
    expect(plan.ok === false && plan.error).toContain("0001_first.sql");
    // And it says what to do instead. A refusal that names a file but not the
    // remedy sends a reader to the git history to work out the rule.
    expect(plan.ok === false && plan.error).toContain("forward-only");
    // Both checksums, so a reader can see *what* changed without re-hashing.
    expect(plan.ok === false && plan.error).toContain("EDITED");
    expect(plan.ok === false && plan.error).toContain("aaa");
  });

  it("it refuses rather than re-applying or warning", () => {
    // Re-applying is how a partial schema happens and warning is how nobody
    // notices, so the contract is that there is no plan at all.
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "EDITED"), file("0002_second.sql", "bbb")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(false);
    expect("pending" in plan).toBe(false);
  });

  it("an unchanged recorded file refuses nothing", () => {
    // PROC-11: a refusal that fires for every input is not a check. This is the
    // other half of the test above — same shape, matching checksum, no error.
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "aaa")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(true);
  });

  it("a recorded file that has vanished from disk also stops it", () => {
    // The other way a history can be rewritten: delete the file rather than
    // edit it. Left unhandled the planner would silently proceed on a database
    // whose schema nobody can reconstruct.
    const plan = planMigrations({
      onDisk: [file("0002_second.sql", "bbb")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(false);
    expect(plan.ok === false && plan.error).toContain("0001_first.sql");
    expect(plan.ok === false && plan.error).toContain("not on disk");
    expect(plan.ok === false && plan.error).toContain("restore the file");
  });
});

describeWithDatabase("the runner, against a real database", () => {
  // The scenarios the pure planner cannot answer: whether the SQL applies at
  // all, whether a second run is a no-op, and what a half-failed file leaves
  // behind.
  let db: TestDatabase;

  beforeEach(async () => {
    db = await emptyDatabase();
  });

  afterEach(async () => {
    await db.close();
  });

  it("the first run applies everything and the second applies none", async () => {
    const first = await runMigrations(db.client, MIGRATIONS_DIR);
    expect(first.applied.length).toBeGreaterThan(0);

    const second = await runMigrations(db.client, MIGRATIONS_DIR);
    expect(second.applied).toEqual([]);

    const ledger = await db.client.query<{ count: string }>(
      "SELECT count(*)::text AS count FROM schema_migrations",
    );
    expect(Number(ledger.rows[0]?.count)).toBe(first.applied.length);
  });

  it("a file that raises partway leaves nothing of itself applied", async () => {
    // One transaction per file, not one for the run: the good file before it
    // stays applied, and the broken one is neither applied nor recorded, so
    // re-running retries it whole.
    await expect(
      runMigrations(db.client, fixtures.migrationsDir("broken-run")),
    ).rejects.toThrow("0002_breaks_halfway.sql");

    const tables = await db.client.query<{ table_name: string }>(
      `SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name LIKE 'fixture%'
        ORDER BY table_name`,
    );
    expect(tables.rows.map((r) => r.table_name)).toEqual(["fixture_first"]);

    const ledger = await db.client.query<{ name: string }>(
      "SELECT name FROM schema_migrations ORDER BY name",
    );
    expect(ledger.rows.map((r) => r.name)).toEqual(["0001_ok.sql"]);
  });

  it("an edited migration stops the runner before it touches anything", async () => {
    await runMigrations(db.client, MIGRATIONS_DIR);
    await db.client.query(
      "UPDATE schema_migrations SET checksum = 'not-what-it-was'",
    );

    await expect(runMigrations(db.client, MIGRATIONS_DIR)).rejects.toThrow(
      /0001_initial\.sql/,
    );
  });
});
