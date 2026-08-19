import { afterEach, beforeEach, expect, it } from "vitest";

import { requestBodyOf } from "./support/contract.js";
import {
  describeWithDatabase,
  freshDatabase,
  type TestDatabase,
} from "./support/database.js";

/**
 * How a column's name is spelled in a JSON body.
 *
 * Snake to camel, with **one named exception**: the table calls its key `id`,
 * and the contract calls it `playerId`, because a bare `id` in a body that is
 * *about* a player reads as the id of the link rather than of the player. The
 * exception is a map entry rather than a rule so that adding a second one is a
 * visible decision.
 */
const SPELLING_EXCEPTIONS: Readonly<Record<string, string>> = { id: "playerId" };

function propertyNameFor(column: string): string {
  return (
    SPELLING_EXCEPTIONS[column] ??
    column.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase())
  );
}

/**
 * The columns the database will not fill in for you.
 *
 * NOT NULL, no default, not generated and not an identity: each of these has to
 * arrive from the caller or the INSERT cannot be written at all.
 *
 * Asked of `information_schema` rather than parsed out of the migration,
 * because the question is what the *applied* schema requires and a regular
 * expression over SQL answers a different one.
 */
async function columnsTheCallerMustSupply(
  db: TestDatabase,
  table: string,
): Promise<readonly string[]> {
  const result = await db.client.query<{ column_name: string }>(
    `SELECT column_name FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = $1
        AND is_nullable = 'NO'
        AND column_default IS NULL
        AND is_generated = 'NEVER'
        AND identity_generation IS NULL
      ORDER BY column_name`,
    [table],
  );
  return result.rows.map((row) => row.column_name);
}

describeWithDatabase("the link request can create the row it claims to create", () => {
  let db: TestDatabase;

  beforeEach(async () => {
    db = await freshDatabase();
  });

  afterEach(async () => {
    await db.close();
  });

  it("supplies every column of players the database will not supply", async () => {
    // **This is the R2 seam for the API half.** `contract/openapi.json` and
    // `migrations/` are two frozen artifacts that nothing forces to agree, and
    // the way they disagree is silent: the contract compiles, the migration
    // applies, and the mismatch only surfaces in the handler nobody has written
    // yet. `POST /players/link` is the one request that creates a `players`
    // row — ADR 0002 removed guest sync, so there is no earlier writer — which
    // makes "the body carries what the row needs" checkable now.
    const required = await columnsTheCallerMustSupply(db, "players");
    const body = requestBodyOf("POST", "/players/link");
    const carried = new Set(body.required ?? []);

    expect(required.length).toBeGreaterThan(0);
    console.log(
      `  link request · players needs ${required.length} caller-supplied column(s) → ` +
        `${required.filter((column) => carried.has(propertyNameFor(column))).length} carried`,
    );

    const missing = required.filter((column) => !carried.has(propertyNameFor(column)));
    expect(missing, `POST /players/link carries no ${missing.map(propertyNameFor).join(", ")}`)
      .toEqual([]);
  });

  it("and the band it carries is a band the database accepts", async () => {
    // The names agreeing is not the whole claim. A body offering `ageBand: "18+"`
    // satisfies the test above and still fails the CHECK constraint at insert
    // time, so the value sets have to be compared too — against the constraint
    // itself rather than against a list retyped here, which would be a third
    // copy of the same three strings.
    const body = requestBodyOf("POST", "/players/link");
    const offered = body.properties?.["ageBand"]?.enum ?? [];
    expect(offered.length).toBeGreaterThan(0);

    for (const band of offered) {
      await expect(
        db.client.query("INSERT INTO players (id, age_band) VALUES (gen_random_uuid(), $1)", [
          band,
        ]),
      ).resolves.toBeTruthy();
    }
    console.log(`  link request · ${offered.length} offered band(s) → ${offered.length} accepted`);
  });
});
