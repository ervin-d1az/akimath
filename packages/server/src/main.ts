import { createHandlers, startHttpServer } from "./adapters/http-server.js";
import { createProcessLogger } from "./adapters/logger.js";
import { createRequestDatabase } from "./adapters/request-database.js";
import { createSessionVerifier, remoteKeySet } from "./adapters/session-verifier.js";
import { readAuthConfig } from "./auth-config.js";
import { readDatabaseConfig } from "./database-config.js";

const log = createProcessLogger(process.env);

const port = Number(process.env["PORT"] ?? 3000);
const version = process.env["APP_VERSION"] ?? "0.1.0";

// **Refuse to start rather than refuse every request.** A server with no key
// set answers 401 to everything, and an operator reads that as "authentication
// is broken" rather than "I forgot a variable". The check is pure and lives in
// `auth-config.ts`; this is the one line that acts on it.
const config = readAuthConfig(process.env);
if ("problem" in config) {
  log.error("cannot start", { problem: config.problem });
  process.exit(1);
}

const database = readDatabaseConfig(process.env);
if ("problem" in database) {
  log.error("cannot start", { problem: database.problem });
  process.exit(1);
}

startHttpServer({
  version,
  port,
  verify: createSessionVerifier(remoteKeySet(config.jwksUrl), config.issuer),
  log,
  handlers: createHandlers(createRequestDatabase(database.url)),
});

log.info("listening", { port, version, jwksUrl: config.jwksUrl, issuer: config.issuer });
