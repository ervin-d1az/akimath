import { describe, expect, it } from "vitest";

import { planMigrations, type AppliedMigration, type MigrationFile } from "../src/migrate.js";

const file = (name: string, checksum: string): MigrationFile => ({
  name,
  checksum,
});

const applied = (name: string, checksum: string): AppliedMigration => ({
  name,
  checksum,
});

describe("the planner returns what is left to apply, in order", () => {
  it("an empty database gets every file, sorted by name", () => {
    const plan = planMigrations({
      onDisk: [
        file("0002_second.sql", "bbb"),
        file("0001_first.sql", "aaa"),
        file("0010_tenth.sql", "ccc"),
      ],
      applied: [],
    });

    expect(plan.ok).toBe(true);
    expect(plan.ok && plan.pending.map((m) => m.name)).toEqual([
      "0001_first.sql",
      "0002_second.sql",
      "0010_tenth.sql",
    ]);
  });

  it("sorts by name and not by the order they were read", () => {
    // A directory read is not sorted, and `0010` must not land before `0002`
    // just because a filesystem handed it over first. Zero-padded names make
    // lexicographic order the right order; this is what pins that.
    const plan = planMigrations({
      onDisk: [file("0010_tenth.sql", "c"), file("0002_second.sql", "b")],
      applied: [],
    });

    expect(plan.ok && plan.pending.map((m) => m.name)).toEqual([
      "0002_second.sql",
      "0010_tenth.sql",
    ]);
  });

  it("a fully applied database gets nothing", () => {
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "aaa")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(true);
    expect(plan.ok && plan.pending).toEqual([]);
  });

  it("a partially applied database gets only the rest", () => {
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "aaa"), file("0002_second.sql", "bbb")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok && plan.pending.map((m) => m.name)).toEqual([
      "0002_second.sql",
    ]);
  });
});

describe("a migration edited after it shipped stops the runner", () => {
  it("the refusal names the file", () => {
    // Naming it is the whole point. An error that says "checksum mismatch" and
    // nothing else leaves a human diffing eleven files by hand.
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "EDITED")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(false);
    expect(plan.ok === false && plan.error).toContain("0001_first.sql");
  });

  it("it refuses rather than re-applying or warning", () => {
    // Re-applying is how a partial schema happens and warning is how nobody
    // notices, so the contract is that there is no plan at all.
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "EDITED"), file("0002_second.sql", "bbb")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(false);
    expect("pending" in plan).toBe(false);
  });

  it("an unchanged recorded file refuses nothing", () => {
    // PROC-11: a refusal that fires for every input is not a check. This is the
    // other half of the test above — same shape, matching checksum, no error.
    const plan = planMigrations({
      onDisk: [file("0001_first.sql", "aaa")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(true);
  });

  it("a recorded file that has vanished from disk also stops it", () => {
    // The other way a history can be rewritten: delete the file rather than
    // edit it. Left unhandled the planner would silently proceed on a database
    // whose schema nobody can reconstruct.
    const plan = planMigrations({
      onDisk: [file("0002_second.sql", "bbb")],
      applied: [applied("0001_first.sql", "aaa")],
    });

    expect(plan.ok).toBe(false);
    expect(plan.ok === false && plan.error).toContain("0001_first.sql");
  });
});
