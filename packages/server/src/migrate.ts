/**
 * A migration file as it sits on disk: its name, and the checksum of its bytes.
 */
export interface MigrationFile {
  readonly name: string;
  readonly checksum: string;
}

/** A row in `schema_migrations`: what was applied, and what it looked like. */
export interface AppliedMigration {
  readonly name: string;
  readonly checksum: string;
}

export interface MigrationInputs {
  readonly onDisk: readonly MigrationFile[];
  readonly applied: readonly AppliedMigration[];
}

export type MigrationPlan =
  | { readonly ok: true; readonly pending: readonly MigrationFile[] }
  | { readonly ok: false; readonly error: string };

/**
 * What is left to apply, or why the runner must not start.
 *
 * **PURE.** Two lists in, a plan or a named error out — no filesystem, no
 * socket, no clock. The whole reason the runner splits this way is that
 * "a migration was edited after it shipped" is then a unit test rather than a
 * scenario needing a database, and this repository has no database to test
 * against yet.
 *
 * The schema is **forward-only**: after a file is applied it is history, and
 * history that changes underneath a database is a schema nobody can
 * reconstruct. So a recorded file that no longer matches — edited, or deleted —
 * is a refusal to start, not a warning and not a re-apply. Warning is how
 * nobody notices; re-applying is how a partial schema happens.
 */
export function planMigrations(inputs: MigrationInputs): MigrationPlan {
  const onDisk = new Map(inputs.onDisk.map((file) => [file.name, file]));

  for (const record of inputs.applied) {
    const file = onDisk.get(record.name);
    if (file === undefined) {
      return {
        ok: false,
        error:
          `${record.name} is recorded as applied but is not on disk. ` +
          "A migration is history once it has run; restore the file rather " +
          "than removing it.",
      };
    }
    if (file.checksum !== record.checksum) {
      return {
        ok: false,
        error:
          `${record.name} has changed since it was applied ` +
          `(recorded ${record.checksum}, on disk ${file.checksum}). ` +
          "Migrations are forward-only: add a new file rather than editing " +
          "one that has run.",
      };
    }
  }

  const done = new Set(inputs.applied.map((record) => record.name));
  const pending = inputs.onDisk
    .filter((file) => !done.has(file.name))
    // Sorted by name, because a directory read is not sorted and the order
    // files run in is the order they were written. Names are zero-padded so
    // lexicographic order is numeric order.
    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));

  return { ok: true, pending };
}
