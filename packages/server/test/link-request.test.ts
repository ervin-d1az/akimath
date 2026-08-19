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
 * Columns the caller must not be able to set, and where they come from instead.
 *
 * **`auth_user_id` is the session's**, and the request body must never carry
 * it. A body that names the account it is attaching to is an account-takeover
 * with extra steps: the caller would choose whose player this becomes. So it is
 * excluded from the "must be in the body" gate below — **by name, with the
 * source written down**, because an exclusion nobody can read is how the second
 * one gets added without anybody deciding to.
 */
const FROM_THE_SESSION: Readonly<Record<string, string>> = {
  auth_user_id: "the verified token's subject",
};

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
    const unsupplied = await columnsTheCallerMustSupply(db, "players");
    const required = unsupplied.filter((column) => !(column in FROM_THE_SESSION));
    const body = requestBodyOf("POST", "/players/link");
    const carried = new Set(body.required ?? []);

    expect(required.length).toBeGreaterThan(0);
    console.log(
      `  link request · players needs ${unsupplied.length} value(s) the database will not ` +
        `supply → ${required.length} from the body, ${unsupplied.length - required.length} ` +
        `from the session`,
    );

    const missing = required.filter((column) => !carried.has(propertyNameFor(column)));
    expect(missing, `POST /players/link carries no ${missing.map(propertyNameFor).join(", ")}`)
      .toEqual([]);
  });

  it("and the body cannot set the ones the session owns", async () => {
    // The other half, and the one that matters. The gate above would be
    // satisfied by putting `authUserId` in the body — and that request would
    // let any caller with any valid session attach themselves to, or claim,
    // somebody else's player.
    const body = requestBodyOf("POST", "/players/link");
    const offered = new Set([...(body.required ?? []), ...Object.keys(body.properties ?? {})]);

    for (const [column, source] of Object.entries(FROM_THE_SESSION)) {
      expect(offered, `${propertyNameFor(column)} must come from ${source}`).not.toContain(
        propertyNameFor(column),
      );
    }
    console.log(
      `  link request · ${Object.keys(FROM_THE_SESSION).length} session-owned column(s) → ` +
        `0 settable from the body`,
    );
  });

  it("every excluded column is excluded for a reason somebody wrote down", async () => {
    // An exclusion list with an empty reason is an exclusion list nobody
    // reviewed. This also fails if the list grows a column the schema does not
    // have, which is how a stale exclusion silently starts excusing nothing.
    const unsupplied = new Set(await columnsTheCallerMustSupply(db, "players"));
    for (const [column, source] of Object.entries(FROM_THE_SESSION)) {
      expect(source.length, column).toBeGreaterThan(0);
      expect(unsupplied, `${column} is not a column players requires`).toContain(column);
    }
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
        db.client.query(
          "INSERT INTO players (id, age_band, auth_user_id) " +
            "VALUES (gen_random_uuid(), $1, gen_random_uuid())",
          [band],
        ),
      ).resolves.toBeTruthy();
    }
    console.log(`  link request · ${offered.length} offered band(s) → ${offered.length} accepted`);
  });
});
