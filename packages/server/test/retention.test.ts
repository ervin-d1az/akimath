import { readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { runRetention } from "../src/adapters/retention-job.js";
import { retentionCutoffs, RETENTION_DAYS } from "../src/retention.js";
import {
  describeWithDatabase,
  freshDatabase,
  type TestDatabase,
} from "./support/database.js";

const DAY_MS = 24 * 60 * 60 * 1000;

describe("the cutoffs are computed from an injected instant", () => {
  it("attempts expire after 400 days and diagnosis events after 30", () => {
    const now = new Date("2026-08-17T09:00:00.000Z");
    const cutoffs = retentionCutoffs(now);

    expect(cutoffs.attempts.toISOString()).toBe(
      new Date(now.getTime() - 400 * DAY_MS).toISOString(),
    );
    expect(cutoffs.diagEvents.toISOString()).toBe(
      new Date(now.getTime() - 30 * DAY_MS).toISOString(),
    );
  });

  it("the two figures are not the same figure", () => {
    // PROC-11: a test that only checks "some cutoff came back" passes for a
    // module returning `now` twice.
    const cutoffs = retentionCutoffs(new Date("2026-08-17T09:00:00.000Z"));
    expect(cutoffs.attempts.getTime()).toBeLessThan(
      cutoffs.diagEvents.getTime(),
    );
  });

  it("it reads no clock — the same instant always gives the same answer", () => {
    const now = new Date("2026-08-17T09:00:00.000Z");
    expect(retentionCutoffs(now)).toEqual(retentionCutoffs(now));
  });
});

describe("a cutoff is absolute elapsed time, not a walk over local midnights", () => {
  it("400 days spanning a daylight-saving transition is still 400 x 24 h", () => {
    // **The Dart side already paid for the other reading.** `StreakPolicy`
    // walked back with `subtract(Duration(days: 1))` over local midnights and
    // lost a child's whole 30-day streak across a Tijuana transition. Here the
    // calendar reading would be the bug: retention is a policy about elapsed
    // time, and 400 days must not become 399 or 401 because a clock moved.
    //
    // Run under `TZ=America/Tijuana` as well as UTC — CI runs UTC, so a
    // zone-dependent bug is invisible unless the zone is named.
    const now = new Date("2026-03-09T15:00:00.000Z"); // the day after a US transition
    const cutoff = retentionCutoffs(now).attempts;

    expect(now.getTime() - cutoff.getTime()).toBe(400 * DAY_MS);
  });

  it("the same holds for the 30-day figure", () => {
    const now = new Date("2026-11-02T15:00:00.000Z"); // the day after the other one
    const cutoff = retentionCutoffs(now).diagEvents;

    expect(now.getTime() - cutoff.getTime()).toBe(30 * DAY_MS);
  });
});

describe("the figures live in exactly one module", () => {
  /** Every `.ts` under `src/`, so a mistyped glob cannot pass vacuously. */
  function sourceFiles(directory: string): string[] {
    return readdirSync(directory).flatMap((entry) => {
      const full = path.join(directory, entry);
      if (statSync(full).isDirectory()) {
        return sourceFiles(full);
      }
      return full.endsWith(".ts") ? [full] : [];
    });
  }

  // **Skipped when the tree is instrumented, on purpose.** This is a gate on
  // the shape of the source, not on behaviour, and Stryker runs the suite
  // against a rewritten copy of `src/` in a sandbox — every file it touches
  // gains numeric mutant ids, so a bare-number search finds them and reports a
  // duplication that exists only inside the mutation run.
  //
  // **Decided from the files, not from an environment variable.** It used to
  // read `STRYKER_MUTATOR_RUNNER`, which is not set during the *dry* run — so
  // the gate did run against the instrumented tree, and passed only because no
  // rewritten file happened to contain a bare `400`. Adding a source file
  // shifted the ids, one landed on 400, and the whole mutation run aborted on a
  // failure that had nothing to do with retention. Asking whether the bytes
  // carry Stryker's marker cannot go stale that way.
  const marker = "stry" + "MutAct_";
  const allSources = sourceFiles(fileURLToPath(new URL("../src", import.meta.url)));
  const instrumented = allSources.some((file) => readFileSync(file, "utf8").includes(marker));

  it.skipIf(instrumented)("400 appears in retention.ts and nowhere else in src/", () => {
    const src = fileURLToPath(new URL("../src", import.meta.url));
    const files = sourceFiles(src);

    // PROC-10: report what was scanned, and scanning nothing is a failure.
    expect(files.length).toBeGreaterThan(0);
    console.log(`  retention figures · scanned ${files.length} source files`);

    const offenders = files.filter((file) => {
      if (path.basename(file) === "retention.ts") {
        return false;
      }
      const contents = readFileSync(file, "utf8");
      // `400` only. `30` is a number ordinary code may legitimately hold, and a
      // gate that forbids it everywhere is a gate someone disables; the 30 is
      // protected by living in the same literal as the 400.
      return /\b400\b/.test(contents);
    });

    expect(
      offenders.map((file) => path.relative(src, file)),
      "the retention figures are duplicated outside retention.ts",
    ).toEqual([]);
  });

  it.skipIf(instrumented)("RETENTION_DAYS is declared in exactly one file", () => {
    const src = fileURLToPath(new URL("../src", import.meta.url));
    const declaring = sourceFiles(src).filter((file) =>
      /export const RETENTION_DAYS/.test(readFileSync(file, "utf8")),
    );

    expect(declaring.map((file) => path.basename(file))).toEqual([
      "retention.ts",
    ]);
  });

  it("the constant is what the function uses, not a second copy", () => {
    // Exported so the adapter and the SQL can name it rather than restating it.
    const now = new Date("2026-08-17T09:00:00.000Z");
    expect(RETENTION_DAYS.attempts).toBe(400);
    expect(RETENTION_DAYS.diagEvents).toBe(30);
    expect(now.getTime() - retentionCutoffs(now).attempts.getTime()).toBe(
      RETENTION_DAYS.attempts * DAY_MS,
    );
  });
});

describeWithDatabase("the job, against a real database", () => {
  const PLAYER = "018f4e3c-0000-7000-8000-0000000000f1";
  let db: TestDatabase;

  /** An attempt aged by `days`, hung off the offline pack. */
  async function aged(id: string, days: number): Promise<void> {
    await db.client.query(
      `INSERT INTO attempts
         (id, player_id, pack_id, pack_index, skill_id, is_correct,
          elapsed_ms, answered_at, created_at)
       VALUES ($1, $2, $3, 1, 1, true, 4200,
               now() - ($4 || ' days')::interval,
               now() - ($4 || ' days')::interval)`,
      [id, PLAYER, PACK, String(days)],
    );
  }

  const PACK = "018f4e3c-0000-7000-8000-0000000000f2";

  beforeEach(async () => {
    db = await freshDatabase();
    await db.client.query(
      "INSERT INTO players (id, age_band, auth_user_id) VALUES ($1, 'adult', gen_random_uuid())",
      [PLAYER],
    );
    await db.client.query(
      `INSERT INTO offline_packs (id, player_id, template_refs, pack_salt, expires_at)
       VALUES ($1, $2, '[]'::jsonb, $3, now() + interval '7 days')`,
      [PACK, PLAYER, Buffer.from("salt")],
    );
    await db.client.query(
      `INSERT INTO template_stats
         (template_id, template_version, attempts, correct, sum_expected, sum_user_rating)
       VALUES ('t-1', 1, 17, 12, 8.5, 21000)`,
    );
  });

  afterEach(async () => {
    await db.close();
  });

  it("deletes what has expired and leaves what has not", async () => {
    await aged("018f4e3c-0000-7000-8000-000000000101", 401);
    await aged("018f4e3c-0000-7000-8000-000000000102", 399);
    await db.client.query(
      `INSERT INTO diag_events (id, player_id, attempt_id, created_at)
       VALUES ($1, $2, $3, now() - interval '31 days')`,
      [
        "018f4e3c-0000-7000-8000-000000000201",
        PLAYER,
        "018f4e3c-0000-7000-8000-000000000102",
      ],
    );

    const run = await runRetention(db.client, new Date());

    expect(run.attempts).toBe(1);
    expect(run.diagEvents).toBe(1);

    const left = await db.client.query<{ id: string }>("SELECT id FROM attempts");
    expect(left.rows.map((r) => r.id)).toEqual([
      "018f4e3c-0000-7000-8000-000000000102",
    ]);
  });

  it("a second run with the same instant deletes nothing", async () => {
    await aged("018f4e3c-0000-7000-8000-000000000103", 401);
    const now = new Date();

    const first = await runRetention(db.client, now);
    const second = await runRetention(db.client, now);

    expect(first.attempts).toBe(1);
    expect(second.attempts).toBe(0);
    expect(second.diagEvents).toBe(0);
  });

  it("the aggregates calibration reads are untouched by either run", async () => {
    // Deleting attempts is only safe because `template_stats` is maintained on
    // write. If a future path starts deriving from raw rows, this breaks a test
    // rather than a child's history.
    await aged("018f4e3c-0000-7000-8000-000000000104", 401);
    const before = await db.client.query("SELECT * FROM template_stats");

    const now = new Date();
    await runRetention(db.client, now);
    await runRetention(db.client, now);

    const after = await db.client.query("SELECT * FROM template_stats");
    expect(after.rows).toEqual(before.rows);
  });
});
