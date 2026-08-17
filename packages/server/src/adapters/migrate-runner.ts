import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

import type { Client } from "pg";

import {
  planMigrations,
  type AppliedMigration,
  type MigrationFile,
} from "../migrate.js";

/**
 * The IO half of the migration runner. It reads a directory, opens a
 * connection and executes a plan; every decision about *what* to run belongs to
 * `planMigrations`, which is pure.
 *
 * **Direct connection string, never the pooler.** DDL through a transaction
 * pooler is how a migration half-applies (`ARCHITECTURE.md` §5).
 */

const LEDGER = `
  CREATE TABLE IF NOT EXISTS schema_migrations (
    name        text        PRIMARY KEY,
    checksum    text        NOT NULL,
    applied_at  timestamptz NOT NULL DEFAULT now()
  )
`;

export interface MigrationRun {
  readonly applied: readonly string[];
}

/** SHA-256 of the file's bytes — what "this file has changed" means. */
export function checksumOf(contents: string): string {
  return createHash("sha256").update(contents, "utf8").digest("hex");
}

async function filesIn(directory: string): Promise<
  readonly (MigrationFile & { readonly sql: string })[]
> {
  const names = (await readdir(directory)).filter((name) =>
    name.endsWith(".sql"),
  );
  return Promise.all(
    names.map(async (name) => {
      const sql = await readFile(path.join(directory, name), "utf8");
      return { name, checksum: checksumOf(sql), sql };
    }),
  );
}

async function appliedIn(client: Client): Promise<readonly AppliedMigration[]> {
  await client.query(LEDGER);
  const result = await client.query<AppliedMigration>(
    "SELECT name, checksum FROM schema_migrations",
  );
  return result.rows;
}

/**
 * Applies whatever is outstanding, and returns what it applied.
 *
 * **One transaction per file, not one for the run.** A file that raises partway
 * leaves nothing of itself applied and is not recorded, so re-running retries
 * it whole — which is the contract the `0001` header relies on when it says the
 * file carries no `BEGIN` of its own. Wrapping the whole run instead would make
 * a failure in file five roll back files one to four, and a database that has
 * silently gone backwards is worse than one that stopped.
 */
export async function runMigrations(
  client: Client,
  directory: string,
): Promise<MigrationRun> {
  const onDisk = await filesIn(directory);
  const plan = planMigrations({ onDisk, applied: await appliedIn(client) });

  if (!plan.ok) {
    throw new Error(`refusing to migrate: ${plan.error}`);
  }

  const byName = new Map(onDisk.map((file) => [file.name, file]));
  const applied: string[] = [];

  for (const pending of plan.pending) {
    const file = byName.get(pending.name);
    /* c8 ignore next 3 -- the plan is built from `onDisk`, so this cannot miss. */
    if (file === undefined) {
      throw new Error(`refusing to migrate: ${pending.name} vanished mid-run`);
    }

    await client.query("BEGIN");
    try {
      await client.query(file.sql);
      await client.query(
        "INSERT INTO schema_migrations (name, checksum) VALUES ($1, $2)",
        [file.name, file.checksum],
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw new Error(
        `${file.name} failed and was rolled back whole: ${String(error)}`,
      );
    }
    applied.push(file.name);
  }

  return { applied };
}
