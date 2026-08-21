import pg from "pg";

import { createProcessLogger } from "../adapters/logger.js";
import { runRetention } from "../adapters/retention-job.js";

const log = createProcessLogger(process.env);

/**
 * Deletes what has expired and reports the counts.
 *
 * **`RETENTION_DATABASE_URL`.** This is the one process that connects as
 * `retention_job` — the only role holding DELETE — so it takes its own
 * credential rather than borrowing the request path's.
 */
const url = process.env.RETENTION_DATABASE_URL;

if (url === undefined) {
  log.error("refusing to guess a database", { wanted: ["RETENTION_DATABASE_URL"] });
  process.exit(1);
}

const client = new pg.Client({ connectionString: url });
await client.connect();

try {
  // The clock is read here, at the edge, and handed to a module that has none.
  const run = await runRetention(client, new Date());
  log.info("retention run complete", {
    attemptsDeleted: run.attempts,
    diagEventsDeleted: run.diagEvents,
    sessionDeltasDeleted: run.sessionDeltas,
    offlinePacksDeleted: run.offlinePacks,
    issuedItemsDeleted: run.issuedItems,
  });
} finally {
  await client.end();
}
