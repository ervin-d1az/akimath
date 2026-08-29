import pg from "pg";

/**
 * The request path's way into the database, and its only one.
 *
 * **ADAPTER.** It owns a pool and a role. Every query a handler runs goes
 * through `inRequestRole`, and there is no method that opens a connection
 * without one — the restriction is structural rather than a convention someone
 * has to remember.
 *
 * **`SET LOCAL ROLE`, inside a transaction.** The connection string belongs to
 * a login role that owns the schema; `app_request` is `NOLOGIN` and exists to
 * be switched into. A bare `SET ROLE` would persist on a pooled connection and
 * hand the next request whatever the previous one left behind, so the switch is
 * scoped to a transaction that always ends.
 *
 * One transaction per unit of work, which is also what makes a handler that
 * throws half way through safe: nothing it wrote survives.
 */
export interface RequestDatabase {
  /** Runs `work` as `app_request`, in a transaction that commits or rolls back. */
  readonly inRequestRole: <T>(work: (client: pg.PoolClient) => Promise<T>) => Promise<T>;
  /**
   * Runs `work` as `retention_job`, the one role holding DELETE.
   *
   * **The single sanctioned hole in "the request path cannot delete".**
   * `CLAUDE.md`'s invariant is that `attempts` accepts DELETE only through the
   * erasure path and the retention job, *both under this role* — so erasure was
   * always going to need it, and doing it any other way would mean granting
   * `app_request` a DELETE it must not have.
   *
   * Narrow on purpose, and kept narrow by a test:
   * `test/one-way-to-erase.test.ts` names the only file under `src/` allowed to
   * call this, the same shape as `one-way-to-log.test.ts`. A second caller is a
   * failing build, not a code review someone might skip.
   */
  readonly inErasureRole: <T>(work: (client: pg.PoolClient) => Promise<T>) => Promise<T>;
  readonly close: () => Promise<void>;
}

/**
 * What the factory actually returns, and what **no handler is given**.
 *
 * `asOwner` used to sit on `RequestDatabase` itself, and that made it a second,
 * unnamed door past *the request path holds no DELETE*: the owner holds DELETE
 * on every table, where `retention_job` holds it only on the ones it was
 * granted, so the unsanctioned door was the wider of the two.
 * `database.asOwner((client) => deletePlayerForAccount(client, id))` from a
 * handler moved neither assertion in `test/one-way-to-erase.test.ts` —
 * `inErasureRole` still appeared in two files and `DELETE FROM` in one.
 *
 * Two things now stop it, deliberately not one: `createHandlers` takes the
 * narrow interface, so that call does not compile, and
 * `test/one-way-to-erase.test.ts` names the single file under `src/` allowed to
 * say `asOwner`, so widening the field type back is a failing build rather than
 * a review somebody might skip. The same shape as `inErasureRole` above.
 */
export interface PooledRequestDatabase extends RequestDatabase {
  /**
   * Runs `work` as the connecting role, with no transaction.
   *
   * **Not for handlers, and it is the pool's own behaviour it exposes.** It
   * exists so a test can ask what a pooled connection looks like *after*
   * `inRequestRole` has finished with it, which is the only way to show the
   * role did not leak. Rebuilding it in the test support from the same
   * connection string — the tidier-looking fix — would open a *fresh*
   * connection, where `current_user` is the owner whether or not `SET LOCAL
   * ROLE` leaked: an assertion that holds for any input (PROC-11). Borrowing
   * from this pool is the load-bearing part.
   */
  readonly asOwner: <T>(work: (client: pg.PoolClient) => Promise<T>) => Promise<T>;
}

export function createRequestDatabase(connectionString: string): PooledRequestDatabase {
  const pool = new pg.Pool({ connectionString });

  const borrow = async <T>(work: (client: pg.PoolClient) => Promise<T>): Promise<T> => {
    const client = await pool.connect();
    try {
      return await work(client);
    } finally {
      // **`finally`, not the happy path.** A pool that leaks one connection per
      // failed request stops serving after `max` of them, minutes later and
      // somewhere else.
      client.release();
    }
  };

  // Both roles switch the same way, so the mechanism is written once: the only
  // difference between a request and an erasure is the name in `SET LOCAL ROLE`,
  // and a second hand-rolled copy is where the `LOCAL` would eventually be
  // dropped from one of them.
  // The type is the two names, not `string`: this is the one place in the
  // package that interpolates into SQL rather than binding a parameter — `SET
  // ROLE` takes no parameter — so what can reach it is closed at compile time.
  const inRole = (role: "app_request" | "retention_job") => <T>(work: (client: pg.PoolClient) => Promise<T>): Promise<T> =>
    borrow(async (client) => {
      await client.query("BEGIN");
      await client.query(`SET LOCAL ROLE ${role}`);
      try {
        const result = await work(client);
        await client.query("COMMIT");
        return result;
      } catch (cause) {
        await client.query("ROLLBACK");
        throw cause;
      }
    });

  return {
    inRequestRole: inRole("app_request"),
    inErasureRole: inRole("retention_job"),
    asOwner: (work) => borrow(work),
    close: () => pool.end(),
  };
}
