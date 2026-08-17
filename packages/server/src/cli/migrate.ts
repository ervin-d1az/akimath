import { fileURLToPath } from "node:url";
import pg from "pg";

import { runMigrations } from "../adapters/migrate-runner.js";

/**
 * Applies outstanding migrations and says what it applied.
 *
 * **`MIGRATE_DATABASE_URL` and not `DATABASE_URL`.** DDL goes over the direct
 * connection string; the pooler is for the request path (`ARCHITECTURE.md` §5),
 * and a migration half-applied through a transaction pooler is the failure this
 * separation exists to prevent. It falls back to `DATABASE_URL` so a local
 * cluster needs one variable, and says which one it used.
 */
const url = process.env.MIGRATE_DATABASE_URL ?? process.env.DATABASE_URL;
const which = process.env.MIGRATE_DATABASE_URL
  ? "MIGRATE_DATABASE_URL"
  : "DATABASE_URL";

if (url === undefined) {
  console.error(
    "no MIGRATE_DATABASE_URL or DATABASE_URL — refusing to guess a database",
  );
  process.exit(1);
}

const directory = fileURLToPath(new URL("../../migrations", import.meta.url));
const client = new pg.Client({ connectionString: url });
await client.connect();

try {
  const run = await runMigrations(client, directory);
  console.log(
    run.applied.length === 0
      ? `nothing to apply (${which})`
      : `applied ${run.applied.length} via ${which}: ${run.applied.join(", ")}`,
  );
} finally {
  await client.end();
}
