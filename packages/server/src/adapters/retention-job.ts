import type { Client } from "pg";

import { retentionCutoffs } from "../retention.js";

/**
 * Deletes what has expired, and reports what it deleted.
 *
 * The IO half: it reads the clock and runs the statements. Every figure comes
 * from `retention.ts`, which reads neither.
 *
 * **It must connect as `retention_job`.** That role is the only one holding
 * DELETE, and it holds it on every table a player leaves a row in, because
 * `ARCHITECTURE.md`:242 puts the erasure path `DELETE /v1/me` under the same
 * role. This job uses two of those grants; the endpoint will use the rest.
 *
 * Deleting attempts is safe because calibration never derives from raw rows —
 * `template_stats` is maintained on write. A test asserts those aggregates are
 * unchanged by a run, so a future path that starts deriving from raw rows
 * breaks a test rather than a child's history.
 */
export interface RetentionRun {
  readonly attempts: number;
  readonly diagEvents: number;
}

export async function runRetention(
  client: Client,
  now: Date,
): Promise<RetentionRun> {
  const cutoffs = retentionCutoffs(now);

  // Diagnosis events first: they reference attempts, and deleting the parent
  // first would cascade rows this job has not counted.
  const diagEvents = await client.query(
    "DELETE FROM diag_events WHERE created_at < $1",
    [cutoffs.diagEvents],
  );
  const attempts = await client.query(
    "DELETE FROM attempts WHERE created_at < $1",
    [cutoffs.attempts],
  );

  return {
    attempts: attempts.rowCount ?? 0,
    diagEvents: diagEvents.rowCount ?? 0,
  };
}
