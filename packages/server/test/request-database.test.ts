import { afterEach, beforeEach, expect, it } from "vitest";

import {
  createRequestDatabase,
  type PooledRequestDatabase,
} from "../src/adapters/request-database.js";
import {
  describeWithDatabase,
  freshDatabase,
  type TestDatabase,
} from "./support/database.js";

const ACCOUNT = "6f2b1c8d-0000-4000-8000-0000000000a1";
const PLAYER = "018f4e3c-0000-7000-8000-0000000000a1";

describeWithDatabase("the request path connects as app_request", () => {
  let db: TestDatabase;
  let requests: PooledRequestDatabase;

  beforeEach(async () => {
    db = await freshDatabase();
    requests = createRequestDatabase(db.url);
  });

  afterEach(async () => {
    await requests.close();
    await db.close();
  });

  it("runs work under the restricted role, not the owner", async () => {
    // The whole point. The connection string belongs to a login role that owns
    // the schema; the request path must not.
    const who = await requests.inRequestRole(async (client) => {
      const result = await client.query<{ role: string }>("SELECT current_user AS role");
      return result.rows[0]?.role;
    });
    expect(who).toBe("app_request");
  });

  it("and the grants bite through it", async () => {
    // `grants.test.ts` proves `SET ROLE app_request` refuses a DELETE on
    // attempts. This proves the seam is really doing that and not merely
    // reporting a role name — the two would look identical from the line above.
    await expect(
      requests.inRequestRole((client) => client.query("DELETE FROM attempts")),
    ).rejects.toThrow(/permission denied/i);
  });

  it("the role does not leak to whatever uses the connection next", async () => {
    // `SET LOCAL` inside a transaction is the reason this holds: a bare
    // `SET ROLE` would persist on the pooled connection and hand the next
    // request whatever the previous one left behind.
    await requests.inRequestRole((client) => client.query("SELECT 1"));
    const who = await requests.asOwner((client) => client.query<{ role: string }>(
      "SELECT current_user AS role",
    ));
    expect(who.rows[0]?.role).not.toBe("app_request");
  });

  it("a failure rolls back everything the work had done", async () => {
    // One transaction per unit of work, so a handler that throws half way
    // through cannot leave a player with no attempts or an attempt with no
    // player.
    await expect(
      requests.inRequestRole(async (client) => {
        await client.query(
          "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', $2)",
          [PLAYER, ACCOUNT],
        );
        throw new Error("something went wrong after the insert");
      }),
    ).rejects.toThrow("something went wrong");

    const left = await db.client.query("SELECT 1 FROM players WHERE id = $1", [PLAYER]);
    expect(left.rowCount).toBe(0);
  });

  it("and a success keeps it", async () => {
    // The control: a seam that rolled everything back would satisfy the test
    // above and would be a server that cannot write.
    await requests.inRequestRole((client) =>
      client.query("INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', $2)", [
        PLAYER,
        ACCOUNT,
      ]),
    );
    const kept = await db.client.query("SELECT 1 FROM players WHERE id = $1", [PLAYER]);
    expect(kept.rowCount).toBe(1);
  });

  it("hands back the connection either way", async () => {
    // A pool that leaks a connection per failed request stops serving after
    // `max` of them, and does it minutes later, somewhere else.
    for (let attempt = 0; attempt < 12; attempt += 1) {
      await requests
        .inRequestRole(() => Promise.reject(new Error("nope")))
        .catch(() => undefined);
    }
    await expect(requests.inRequestRole((client) => client.query("SELECT 1"))).resolves
      .toBeTruthy();
  });
});

describeWithDatabase("and the erasure path connects as retention_job", () => {
  let db: TestDatabase;
  let requests: PooledRequestDatabase;

  beforeEach(async () => {
    db = await freshDatabase();
    requests = createRequestDatabase(db.url);
  });

  afterEach(async () => {
    await requests.close();
    await db.close();
  });

  it("runs work under the one role that holds DELETE", async () => {
    const who = await requests.inErasureRole(async (client) => {
      const result = await client.query<{ role: string }>("SELECT current_user AS role");
      return result.rows[0]?.role;
    });
    expect(who).toBe("retention_job");
  });

  it("and that role really can delete a player, where app_request cannot", async () => {
    // Both directions in one test, because either alone is satisfiable by
    // accident: a seam that never switched roles would pass the first half, and
    // a seam that switched to the owner would pass the second.
    await db.client.query(
      "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', $2)",
      [PLAYER, ACCOUNT],
    );

    await expect(
      requests.inRequestRole((client) => client.query("DELETE FROM players")),
    ).rejects.toThrow(/permission denied/i);

    const gone = await requests.inErasureRole((client) =>
      client.query("DELETE FROM players WHERE id = $1", [PLAYER]),
    );
    expect(gone.rowCount).toBe(1);
  });

  it("it cannot write, so an erasure cannot become an edit", async () => {
    // `retention_job` holds SELECT and DELETE and nothing else
    // (`grants.test.ts` enumerates every table). This is the seam's half of
    // that: the wider role reached through `inErasureRole` is still narrow in
    // the direction that matters.
    await expect(
      requests.inErasureRole((client) =>
        client.query(
          "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', $2)",
          [PLAYER, ACCOUNT],
        ),
      ),
    ).rejects.toThrow(/permission denied/i);
  });

  it("and it does not leak to whatever uses the connection next", async () => {
    await requests.inErasureRole((client) => client.query("SELECT 1"));

    const who = await requests.asOwner((client) =>
      client.query<{ role: string }>("SELECT current_user AS role"),
    );
    expect(who.rows[0]?.role).not.toBe("retention_job");
  });
});
