import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { describe } from "vitest";

import { runMigrations } from "../../src/adapters/migrate-runner.js";

/**
 * The database these tests run against, or nothing.
 *
 * Set `TEST_DATABASE_URL` to a Postgres you do not mind being wiped — every
 * helper here drops the public schema first. CI points it at a service
 * container; locally it is whatever cluster you started.
 *
 * **When it is absent the database suites skip rather than fail.** A developer
 * with no Postgres still gets the pure half green, and the skip is visible in
 * the run rather than silent.
 */
export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL;

export const describeWithDatabase: typeof describe = TEST_DATABASE_URL
  ? describe
  : (describe.skip as unknown as typeof describe);

export const MIGRATIONS_DIR = fileURLToPath(
  new URL("../../migrations", import.meta.url),
);

export interface TestDatabase {
  readonly client: pg.Client;
  readonly close: () => Promise<void>;
}

/**
 * One database per vitest worker.
 *
 * Every helper here drops and recreates the `public` schema, so two test files
 * sharing a database tear each other's tables out from under them — which is
 * exactly what happened the first time these suites ran together, in a spray of
 * "no schema has been selected to create in". A worker runs one file at a time,
 * so a database per worker is the smallest unit that cannot collide.
 */
const WORKER = process.env.VITEST_WORKER_ID ?? "1";
const WORKER_DATABASE = `akimath_test_w${WORKER}`;

function urlForDatabase(base: string, database: string): string {
  const url = new URL(base);
  url.pathname = `/${database}`;
  return url.toString();
}

async function connectToWorkerDatabase(): Promise<pg.Client> {
  const admin = new pg.Client({ connectionString: TEST_DATABASE_URL });
  await admin.connect();
  try {
    await admin.query(`CREATE DATABASE "${WORKER_DATABASE}"`);
  } catch (error) {
    // 42P04 is "database already exists" — two workers can race here, and the
    // loser is not a failure.
    if ((error as { code?: string }).code !== "42P04") {
      throw error;
    }
  } finally {
    await admin.end();
  }

  const client = new pg.Client({
    connectionString: urlForDatabase(TEST_DATABASE_URL!, WORKER_DATABASE),
  });
  await client.connect();
  return client;
}

async function wipe(client: pg.Client): Promise<void> {
  await client.query("DROP SCHEMA IF EXISTS public CASCADE");
  await client.query("CREATE SCHEMA public");
}

/** Connects, wipes, and applies the real migrations from `migrations/`. */
export async function freshDatabase(
  migrationsDir: string = MIGRATIONS_DIR,
): Promise<TestDatabase> {
  const client = await connectToWorkerDatabase();
  await wipe(client);
  await runMigrations(client, migrationsDir);
  return { client, close: () => client.end() };
}

/** Connects and wipes, without applying anything. */
export async function emptyDatabase(): Promise<TestDatabase> {
  const client = await connectToWorkerDatabase();
  await wipe(client);
  return { client, close: () => client.end() };
}

/**
 * Every table the migrations created, excluding the runner's own ledger.
 *
 * Tests enumerate this rather than naming tables, because a later migration
 * that adds a table and forgets its grants is the realistic failure and a test
 * naming today's tables cannot see it.
 */
export async function tableNames(client: pg.Client): Promise<string[]> {
  const result = await client.query<{ table_name: string }>(
    `SELECT table_name FROM information_schema.tables
      WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
        AND table_name <> 'schema_migrations'
      ORDER BY table_name`,
  );
  return result.rows.map((row) => row.table_name);
}

/**
 * The tables that hold player data — those carrying a `player_id`.
 *
 * Derived rather than listed, for the same reason as `tableNames`: the rule is
 * "a player must be erasable from everywhere they left a row", and a hardcoded
 * list stops being that rule the first time somebody adds a table.
 */
export async function playerDataTables(client: pg.Client): Promise<string[]> {
  const result = await client.query<{ table_name: string }>(
    `SELECT table_name FROM information_schema.columns
      WHERE table_schema = 'public' AND column_name = 'player_id'
      ORDER BY table_name`,
  );
  return result.rows.map((row) => row.table_name);
}

export const fixtures = {
  migrationsDir: (name: string): string =>
    fileURLToPath(new URL(`../fixtures/${name}`, import.meta.url)),
  path,
};
