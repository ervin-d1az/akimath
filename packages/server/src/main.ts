import { startHttpServer } from "./adapters/http-server.js";
import { createSessionVerifier, remoteKeySet } from "./adapters/session-verifier.js";
import { readAuthConfig } from "./auth-config.js";

const port = Number(process.env["PORT"] ?? 3000);
const version = process.env["APP_VERSION"] ?? "0.1.0";

// **Refuse to start rather than refuse every request.** A server with no key
// set answers 401 to everything, and an operator reads that as "authentication
// is broken" rather than "I forgot a variable". The check is pure and lives in
// `auth-config.ts`; this is the one line that acts on it.
const config = readAuthConfig(process.env);
if ("problem" in config) {
  console.error(`akimath-api cannot start: ${config.problem}`);
  process.exit(1);
}

startHttpServer(
  version,
  port,
  createSessionVerifier(remoteKeySet(config.jwksUrl), config.issuer),
);
console.log(`akimath-api listening on http://localhost:${port}`);
console.log(`sessions verified against ${config.jwksUrl} for issuer ${config.issuer}`);
