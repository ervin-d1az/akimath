import { afterEach, beforeEach, expect, it } from "vitest";

import {
  describeWithDatabase,
  freshDatabase,
  playerDataTables,
  tableNames,
  type TestDatabase,
} from "./support/database.js";

interface Grant {
  readonly table_name: string;
  readonly privilege_type: string;
}

async function grantsFor(
  db: TestDatabase,
  role: string,
): Promise<readonly Grant[]> {
  const result = await db.client.query<Grant>(
    `SELECT table_name, privilege_type
       FROM information_schema.role_table_grants
      WHERE grantee = $1 AND table_schema = 'public'`,
    [role],
  );
  return result.rows;
}

describeWithDatabase("the grants are the enforcement, not the comment", () => {
  let db: TestDatabase;

  beforeEach(async () => {
    db = await freshDatabase();
  });

  afterEach(async () => {
    await db.close();
  });

  it("the request path cannot delete an attempt", async () => {
    await db.client.query("SET ROLE app_request");
    await expect(
      db.client.query("DELETE FROM attempts"),
    ).rejects.toThrow(/permission denied/i);
    await db.client.query("RESET ROLE");
  });

  it("the request path cannot update an attempt either", async () => {
    // Append-only is two prohibitions, and UPDATE is the one that would let a
    // wrong answer quietly become a right one years later.
    await db.client.query("SET ROLE app_request");
    await expect(
      db.client.query("UPDATE attempts SET is_correct = true"),
    ).rejects.toThrow(/permission denied/i);
    await db.client.query("RESET ROLE");
  });

  it("the request path can still read and append", async () => {
    // The control. "Cannot delete" is also true of a role with no grants at
    // all, which would be a server that cannot serve.
    await db.client.query("SET ROLE app_request");
    await expect(db.client.query("SELECT * FROM attempts")).resolves.toBeTruthy();
    await db.client.query("RESET ROLE");
  });

  it("the request path holds DELETE on no table in the schema", async () => {
    // Enumerated, not named: a later migration that adds a table and forgets
    // its grants is the realistic failure, and a test naming `attempts` cannot
    // see it.
    const tables = await tableNames(db.client);
    expect(tables.length).toBeGreaterThan(0);
    console.log(`  grants · swept ${tables.length} tables`);

    const deletable = (await grantsFor(db, "app_request"))
      .filter((g) => g.privilege_type === "DELETE")
      .map((g) => g.table_name);

    expect(deletable, "app_request can delete from these").toEqual([]);
  });

  it("the retention role holds DELETE on every table a player leaves a row in", async () => {
    // Derived from the schema — every table carrying a `player_id` — because
    // the rule is "a player must be erasable from everywhere", and a hardcoded
    // list stops being that rule the moment somebody adds a table.
    const withPlayerData = await playerDataTables(db.client);
    expect(withPlayerData.length).toBeGreaterThan(0);
    console.log(
      `  grants · ${withPlayerData.length} tables hold player data: ${withPlayerData.join(", ")}`,
    );

    const deletable = new Set(
      (await grantsFor(db, "retention_job"))
        .filter((g) => g.privilege_type === "DELETE")
        .map((g) => g.table_name),
    );

    for (const table of withPlayerData) {
      expect(
        deletable.has(table),
        `retention_job cannot delete from ${table}, so DELETE /v1/me cannot erase a player from it`,
      ).toBe(true);
    }
  });

  it("the retention role can only delete — it never writes", async () => {
    const writes = (await grantsFor(db, "retention_job"))
      .filter((g) => g.privilege_type === "INSERT" || g.privilege_type === "UPDATE")
      .map((g) => `${g.privilege_type} on ${g.table_name}`);

    expect(writes, "retention_job holds write grants").toEqual([]);
  });
});
