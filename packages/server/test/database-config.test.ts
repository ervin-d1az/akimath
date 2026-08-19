import { describe, expect, it } from "vitest";

import { readDatabaseConfig } from "../src/database-config.js";

const URL = "postgresql://user:pass@host/db";

describe("which database the request path serves from", () => {
  it("takes the pooled connection string", () => {
    expect(readDatabaseConfig({ DATABASE_URL: URL })).toEqual({ url: URL });
    expect(readDatabaseConfig({ DATABASE_URL: `  ${URL}  ` })).toEqual({ url: URL });
    expect(readDatabaseConfig({ DATABASE_URL: "postgres://h/db" })).toEqual({
      url: "postgres://h/db",
    });
  });

  it("does not fall back to the migration string", () => {
    // The direct string is for DDL and the request path goes through the
    // pooler. A fallback would let a deployment run every request over the
    // direct connection and never find out.
    const config = readDatabaseConfig({ MIGRATE_DATABASE_URL: URL });
    expect("problem" in config && config.problem).toContain("DATABASE_URL is not set");
  });

  it("refuses a missing or blank value, and names what it wanted", () => {
    for (const blank of [undefined, "", "   "]) {
      const config = readDatabaseConfig(blank === undefined ? {} : { DATABASE_URL: blank });
      expect("problem" in config && config.problem, JSON.stringify(blank)).toContain(
        "is not set",
      );
    }
  });

  it("refuses something that is not a PostgreSQL URL", () => {
    // Catches the two real mistakes: pasting the Neon Auth URL in, and pasting
    // a `psql` invocation in.
    for (const wrong of ["https://ep-x.aws.neon.tech/neondb/auth", "psql -h localhost", "db"]) {
      const config = readDatabaseConfig({ DATABASE_URL: wrong });
      expect("problem" in config && config.problem, wrong).toContain("connection string");
    }
  });
});
