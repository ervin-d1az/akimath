import pg from "pg";

import { runRetention } from "../adapters/retention-job.js";

/**
 * Deletes what has expired and reports the counts.
 *
 * **`RETENTION_DATABASE_URL`.** This is the one process that connects as
 * `retention_job` — the only role holding DELETE — so it takes its own
 * credential rather than borrowing the request path's.
 */
const url = process.env.RETENTION_DATABASE_URL;

if (url === undefined) {
  console.error("no RETENTION_DATABASE_URL — refusing to guess a database");
  process.exit(1);
}

const client = new pg.Client({ connectionString: url });
await client.connect();

try {
  // The clock is read here, at the edge, and handed to a module that has none.
  const run = await runRetention(client, new Date());
  console.log(
    `retention: deleted ${run.attempts} attempts, ${run.diagEvents} diagnosis events`,
  );
} finally {
  await client.end();
}
