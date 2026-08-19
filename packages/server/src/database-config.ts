/**
 * Which database the request path connects to.
 *
 * **PURE** — a function of the environment map handed to it. Separate from
 * `auth-config.ts` because they fail for different reasons and an operator
 * fixing one should not have to read about the other.
 */

/** A resolved connection string, or the reason there is not one. */
export type DatabaseConfig =
  | { readonly url: string }
  | { readonly problem: string };

const URL_NAME = "DATABASE_URL";

/**
 * Reads the pooled connection string.
 *
 * **`DATABASE_URL`, never `MIGRATE_DATABASE_URL`.** The direct string is for
 * DDL; the request path goes through the pooler (`ARCHITECTURE.md` §5). Falling
 * back from one to the other would let a deployment run every request over the
 * direct connection and never notice — so there is no fallback, and the refusal
 * names the variable it wanted.
 */
export function readDatabaseConfig(
  env: Record<string, string | undefined>,
): DatabaseConfig {
  const url = (env[URL_NAME] ?? "").trim();
  if (url.length === 0) {
    return { problem: `${URL_NAME} is not set, so there is no database to serve from.` };
  }
  if (!url.startsWith("postgres://") && !url.startsWith("postgresql://")) {
    return { problem: `${URL_NAME} does not look like a PostgreSQL connection string.` };
  }
  return { url };
}
