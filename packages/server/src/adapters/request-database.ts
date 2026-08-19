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
   * Runs `work` as the connecting role, with no transaction.
   *
   * **Not for handlers.** It exists so a test can ask what a pooled connection
   * looks like *after* `inRequestRole` has finished with it, which is the only
   * way to show the role did not leak. Nothing under `src/` calls it.
   */
  readonly asOwner: <T>(work: (client: pg.PoolClient) => Promise<T>) => Promise<T>;
  readonly close: () => Promise<void>;
}

export function createRequestDatabase(connectionString: string): RequestDatabase {
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

  return {
    inRequestRole: (work) =>
      borrow(async (client) => {
        await client.query("BEGIN");
        await client.query("SET LOCAL ROLE app_request");
        try {
          const result = await work(client);
          await client.query("COMMIT");
          return result;
        } catch (cause) {
          await client.query("ROLLBACK");
          throw cause;
        }
      }),
    asOwner: (work) => borrow(work),
    close: () => pool.end(),
  };
}
